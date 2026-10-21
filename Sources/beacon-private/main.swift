// The owner's end of private delivery: the keypair, and reading back what
// apps sent. Runs on the owner's Mac only.
//
//   beacon-private keygen <name>
//       Makes the keypair for <name> (a label you choose, such as your app's
//       name). The private key goes into this Mac's keychain and is never
//       printed. The public key is printed: it goes into the app's
//       `PrivateDelivery`, and it is not a secret. Refuses when a key for
//       <name> already exists, because replacing it would make everything
//       sent so far unreadable.
//
//   beacon-private read <name> --project-ref <ref> [--bucket <bucket>] [--keep]
//       Downloads every sealed message from the private bucket, opens each
//       with <name>'s private key, writes it to
//       ~/Library/Application Support/Beacon/private/<name>/<app>/<id>.json
//       and deletes it from the bucket (unless --keep), so the bucket holds
//       only what has not been read. The bucket's secret key comes from the
//       Supabase CLI's own sign-in each time and is never written anywhere.
//       What it writes is the owner's to read; it does not belong in an
//       issue, a pull request or a commit.

import BeaconCore
import CryptoKit
import Foundation
import Security

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func keychainQuery(_ name: String) -> [String: Any] {
    [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "beacon-private.\(name)",
        kSecAttrAccount as String: "owner-key",
    ]
}

func storedKey(_ name: String) -> Curve25519.KeyAgreement.PrivateKey? {
    var query = keychainQuery(name)
    query[kSecReturnData as String] = true
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data
    else { return nil }
    return try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
}

func keygen(_ name: String) {
    if storedKey(name) != nil { fail("A key for \(name) already exists in this Mac's keychain. Not replacing it.") }
    let key = Curve25519.KeyAgreement.PrivateKey()
    var attributes = keychainQuery(name)
    attributes[kSecValueData as String] = key.rawRepresentation
    let status = SecItemAdd(attributes as CFDictionary, nil)
    if status != errSecSuccess { fail("The keychain refused the key (status \(status)).") }
    print(key.publicKey.rawRepresentation.base64EncodedString())
}

func projectAccess(_ projectRef: String) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["supabase", "projects", "api-keys", "--project-ref", projectRef, "-o", "json"]
    let pipe = Pipe()
    process.standardOutput = pipe
    do { try process.run() } catch { fail("Could not run the Supabase CLI: \(error.localizedDescription)") }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard let keys = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
        let value = keys.first(where: { ($0["name"] as? String) == "service_role" })?["api_key"] as? String
    else { fail("Could not read the project's keys. Is the Supabase CLI signed in?") }
    return value
}

struct Store {
    let base: URL
    let bucket: String
    let access: String

    func call(_ method: String, _ path: String, body: [String: Any]? = nil) async -> (Int, Data) {
        var request = URLRequest(url: base.appendingPathComponent("storage/v1/\(path)"))
        request.httpMethod = method
        request.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { request.httpBody = try? JSONSerialization.data(withJSONObject: body) }
        guard let (data, response) = try? await URLSession.shared.data(for: request) else { return (0, Data()) }
        return ((response as? HTTPURLResponse)?.statusCode ?? 0, data)
    }

    /// The entries under `prefix`: folders have no id, objects do.
    func list(_ prefix: String) async -> [(path: String, isFolder: Bool)] {
        let (status, data) = await call("POST", "object/list/\(bucket)", body: ["prefix": prefix, "limit": 1000])
        guard status == 200, let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { fail("Could not list the bucket (status \(status)).") }
        return entries.compactMap { entry in
            guard let entryName = entry["name"] as? String else { return nil }
            let path = prefix.isEmpty ? entryName : "\(prefix)/\(entryName)"
            return (path, entry["id"] is NSNull || entry["id"] == nil)
        }
    }
}

func read(_ name: String, projectRef: String, bucket: String, keep: Bool) async {
    guard let key = storedKey(name) else { fail("No key for \(name) in this Mac's keychain.") }
    let store = Store(
        base: URL(string: "https://\(projectRef).supabase.co")!, bucket: bucket, access: projectAccess(projectRef))
    let folder = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Beacon/private/\(name)")
    var saved = 0
    var unreadable = 0
    for app in await store.list("") where app.isFolder {
        for object in await store.list(app.path) where !object.isFolder && object.path.hasSuffix(".bin") {
            let (status, blob) = await store.call("GET", "object/\(bucket)/\(object.path)")
            guard status == 200, let details = try? PrivateSealing.open(blob, with: key) else {
                unreadable += 1
                continue
            }
            let target = folder.appendingPathComponent(app.path, isDirectory: true)
            try? FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            guard let json = try? encoder.encode(details),
                (try? json.write(to: target.appendingPathComponent("\(details.id).json"), options: .atomic)) != nil
            else { continue }
            if !keep { _ = await store.call("DELETE", "object/\(bucket)/\(object.path)") }
            saved += 1
        }
    }
    print("Saved \(saved) message(s) to \(folder.path).")
    if unreadable > 0 { print("\(unreadable) message(s) could not be opened with this key and were left in the bucket.") }
}

let arguments = Array(CommandLine.arguments.dropFirst())
func option(_ flag: String) -> String? {
    guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}

switch (arguments.first, arguments.dropFirst().first) {
case ("keygen", let name?):
    keygen(name)
case ("read", let name?):
    guard let projectRef = option("--project-ref") else { fail("read needs --project-ref <ref>.") }
    await read(name, projectRef: projectRef, bucket: option("--bucket") ?? "beacon-private",
               keep: arguments.contains("--keep"))
default:
    fail("usage: beacon-private keygen <name> | read <name> --project-ref <ref> [--bucket <bucket>] [--keep]")
}
