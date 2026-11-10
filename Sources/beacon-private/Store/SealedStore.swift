// Where the owner's reading tool finds sealed messages, with the HTTP client passed in
// so a test can answer for the store. Two stores: a Supabase Storage bucket and a
// Google Cloud Storage bucket. Both hold only ciphertext.

import BeaconCore
import CryptoKit
import Foundation

/// Sends one request and answers its status and body; 0 and no data when nothing answered.
public typealias HTTPSend = @Sendable (URLRequest) async -> (status: Int, data: Data)

/// One sealed message in a store: the app that sent it, and where it sits.
public struct SealedObject: Equatable, Sendable {
    public let app: String
    public let path: String
}

public enum StoreError: Error, Equatable {
    case listFailed(status: Int)
}

public protocol SealedStore: Sendable {
    /// Every `<app>/<id>.bin` message the store holds.
    func list() async throws -> [SealedObject]
    func read(_ object: SealedObject) async -> Data?
    func delete(_ object: SealedObject) async
}

/// A Supabase Storage bucket, read with the project's secret key.
public struct SupabaseStore: SealedStore {
    let base: URL
    let bucket: String
    let access: String
    let send: HTTPSend

    public init(base: URL, bucket: String, access: String, send: @escaping HTTPSend) {
        self.base = base
        self.bucket = bucket
        self.access = access
        self.send = send
    }

    private func call(_ method: String, _ path: String, body: [String: Any]? = nil) async -> (status: Int, data: Data) {
        var request = URLRequest(url: base.appendingPathComponent("storage/v1/\(path)"))
        request.httpMethod = method
        request.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { request.httpBody = try? JSONSerialization.data(withJSONObject: body) }
        return await send(request)
    }

    /// The entries under `prefix`: folders have no id, objects do.
    private func entries(_ prefix: String) async throws -> [(path: String, isFolder: Bool)] {
        let (status, data) = await call("POST", "object/list/\(bucket)", body: ["prefix": prefix, "limit": 1000])
        guard status == 200, let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { throw StoreError.listFailed(status: status) }
        return entries.compactMap { entry in
            guard let entryName = entry["name"] as? String else { return nil }
            let path = prefix.isEmpty ? entryName : "\(prefix)/\(entryName)"
            return (path, entry["id"] is NSNull || entry["id"] == nil)
        }
    }

    public func list() async throws -> [SealedObject] {
        var found: [SealedObject] = []
        for app in try await entries("") where app.isFolder {
            for object in try await entries(app.path) where !object.isFolder && object.path.hasSuffix(".bin") {
                found.append(SealedObject(app: app.path, path: object.path))
            }
        }
        return found
    }

    public func read(_ object: SealedObject) async -> Data? {
        let (status, data) = await call("GET", "object/\(bucket)/\(object.path)")
        return status == 200 ? data : nil
    }

    public func delete(_ object: SealedObject) async {
        _ = await call("DELETE", "object/\(bucket)/\(object.path)")
    }
}

/// A Google Cloud Storage bucket, read with an access token from the Cloud CLI. Messages sit
/// under `prefix`, as `<prefix><app>/<id>.bin`.
public struct CloudStorageStore: SealedStore {
    /// Where the private store keeps its objects in the bucket.
    public static let defaultPrefix = "beacon-private/"
    private static let api = "https://storage.googleapis.com/storage/v1/b"

    let bucket: String
    let accessToken: String
    let prefix: String
    let send: HTTPSend

    public init(bucket: String, accessToken: String, prefix: String = defaultPrefix, send: @escaping HTTPSend) {
        self.bucket = bucket
        self.accessToken = accessToken
        self.prefix = prefix
        self.send = send
    }

    private func request(_ method: String, object: String? = nil, query: [URLQueryItem] = []) -> URLRequest {
        var parts = URLComponents(string: "\(Self.api)/\(bucket)/o")!
        if let object {
            // The object's name is one path segment: its slashes must stay encoded.
            let encoded = object.addingPercentEncoding(withAllowedCharacters: .urlUnreserved) ?? object
            parts.percentEncodedPath += "/\(encoded)"
        }
        parts.queryItems = query.isEmpty ? nil : query
        var request = URLRequest(url: parts.url!)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    public func list() async throws -> [SealedObject] {
        var found: [SealedObject] = []
        var pageToken: String?
        repeat {
            var query = [URLQueryItem(name: "prefix", value: prefix), URLQueryItem(name: "maxResults", value: "1000")]
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            let (status, data) = await send(request("GET", query: query))
            guard status == 200, let page = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { throw StoreError.listFailed(status: status) }
            for item in page["items"] as? [[String: Any]] ?? [] {
                guard let name = item["name"] as? String, name.hasSuffix(".bin") else { continue }
                let parts = name.dropFirst(prefix.count).split(separator: "/", omittingEmptySubsequences: false)
                if parts.count == 2 { found.append(SealedObject(app: String(parts[0]), path: name)) }
            }
            pageToken = page["nextPageToken"] as? String
        } while pageToken != nil
        return found
    }

    public func read(_ object: SealedObject) async -> Data? {
        let (status, data) = await send(request("GET", object: object.path, query: [URLQueryItem(name: "alt", value: "media")]))
        return status == 200 ? data : nil
    }

    public func delete(_ object: SealedObject) async {
        _ = await send(request("DELETE", object: object.path))
    }
}

private extension CharacterSet {
    /// The characters a URL path segment may carry unescaped, and no slash.
    static let urlUnreserved = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
}

/// What a read left behind.
public struct ReadSummary: Equatable, Sendable {
    public var saved = 0
    /// Messages this key could not open; they stay in the store.
    public var unreadable = 0
}

/// Opens every message in `store` with `key`, writes each to `<folder>/<app>/<id>.json`, and
/// deletes it from the store unless `keep`, so the store holds only what has not been read.
public func readSealedMessages(
    from store: some SealedStore, key: Curve25519.KeyAgreement.PrivateKey, into folder: URL, keep: Bool
) async throws -> ReadSummary {
    var summary = ReadSummary()
    for object in try await store.list() {
        guard let blob = await store.read(object), let details = try? PrivateSealing.open(blob, with: key) else {
            summary.unreadable += 1
            continue
        }
        let target = folder.appendingPathComponent(object.app, isDirectory: true)
        try? FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let json = try? encoder.encode(details),
            (try? json.write(to: target.appendingPathComponent("\(details.id).json"), options: .atomic)) != nil
        else { continue }
        if !keep { await store.delete(object) }
        summary.saved += 1
    }
    return summary
}
