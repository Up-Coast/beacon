// The reading tool's stores, answered by a pretend bucket instead of the network.

import BeaconCore
import CryptoKit
import Foundation
import Testing
@testable import BeaconPrivateStore

/// A Cloud Storage bucket that lists two pages and serves, records and deletes objects.
private final class PretendBucket: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var objects: [String: Data]
    private(set) var requests: [URLRequest] = []

    init(_ objects: [String: Data]) { self.objects = objects }

    func send(_ request: URLRequest) -> (status: Int, data: Data) {
        lock.lock()
        defer { lock.unlock() }
        requests.append(request)
        let url = request.url!
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let value = { (name: String) in query.first { $0.name == name }?.value }
        let object = url.absoluteString.components(separatedBy: "/o/").dropFirst().first?
            .components(separatedBy: "?").first?.removingPercentEncoding
        switch (request.httpMethod, object) {
        case ("GET", nil):
            // Two names a page; the second page is asked for with the first one's token.
            let names = objects.keys.sorted()
            let page = value("pageToken") == nil ? Array(names.prefix(2)) : Array(names.dropFirst(2))
            var body: [String: Any] = ["items": page.map { ["name": $0] }]
            if value("pageToken") == nil && names.count > 2 { body["nextPageToken"] = "next" }
            return (200, try! JSONSerialization.data(withJSONObject: body))
        case ("GET", let name?):
            return objects[name].map { (200, $0) } ?? (404, Data())
        case ("DELETE", let name?):
            return objects.removeValue(forKey: name) == nil ? (404, Data()) : (204, Data())
        default:
            return (400, Data())
        }
    }
}

private let owner = Curve25519.KeyAgreement.PrivateKey()

private func sealed(_ id: String, app: String, to key: Curve25519.KeyAgreement.PrivateKey = owner) throws -> Data {
    let details = PrivateDetails(
        id: id, app: app, version: "1", build: "1", sealedAt: Date(timeIntervalSince1970: 1_700_000_000),
        agreement: nil, noticeVersion: "v1", fields: ["cause": "disk full"], removed: [])
    return try PrivateSealing.seal(details, to: key.publicKey.rawRepresentation)
}

private func folder() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("beacon-store-test-\(UUID().uuidString)")
}

@Suite("The Cloud Storage store")
struct CloudStorageStoreTests {

    private func bucket() throws -> PretendBucket {
        PretendBucket([
            "beacon-private/com.example.a/aaaaaaaa-0000-0000-0000-000000000001.bin": try sealed("aaaaaaaa-0000-0000-0000-000000000001", app: "com.example.a"),
            "beacon-private/com.example.a/aaaaaaaa-0000-0000-0000-000000000002.bin": try sealed("aaaaaaaa-0000-0000-0000-000000000002", app: "com.example.a"),
            "beacon-private/com.example.b/bbbbbbbb-0000-0000-0000-000000000003.bin": try sealed("bbbbbbbb-0000-0000-0000-000000000003", app: "com.example.b"),
            "beacon-private/com.example.b/not-a-message.txt": Data("x".utf8),
        ])
    }

    private func store(_ pretend: PretendBucket) -> CloudStorageStore {
        CloudStorageStore(bucket: "the-bucket", accessToken: "token") { pretend.send($0) }
    }

    @Test func itListsEveryPageUnderThePrefixAndOnlyMessages() async throws {
        let pretend = try bucket()
        let found = try await store(pretend).list()
        #expect(found.map(\.app).sorted() == ["com.example.a", "com.example.a", "com.example.b"])
        let lists = pretend.requests.filter { $0.url!.path.hasSuffix("/o") }
        #expect(lists.count == 2, "the second page is asked for with the first page's token")
        #expect(lists.allSatisfy { $0.url!.query!.contains("prefix=beacon-private/") })
        #expect(lists.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer token" })
    }

    @Test func itReadsAndDeletesTheObjectByItsWholeName() async throws {
        let pretend = try bucket()
        let object = SealedObject(app: "com.example.a", path: "beacon-private/com.example.a/aaaaaaaa-0000-0000-0000-000000000001.bin")
        let blob = try #require(await store(pretend).read(object))
        #expect(try PrivateSealing.open(blob, with: owner).id == "aaaaaaaa-0000-0000-0000-000000000001")
        await store(pretend).delete(object)
        #expect(pretend.objects[object.path] == nil)
        let urls = pretend.requests.map { $0.url!.absoluteString }
        #expect(urls.contains { $0.contains("/o/beacon-private%2Fcom.example.a%2F") && $0.hasSuffix("?alt=media") })
    }

    @Test func readingDeletesWhatItSavedAndKeepsWhatItCouldNotOpen() async throws {
        let pretend = try bucket()
        let stranger = Curve25519.KeyAgreement.PrivateKey()
        let other = "beacon-private/com.example.c/cccccccc-0000-0000-0000-000000000004.bin"
        let everything = PretendBucket(pretend.objects.merging(
            [other: try sealed("cccccccc-0000-0000-0000-000000000004", app: "com.example.c", to: stranger)]) { $1 })
        let target = folder()
        defer { try? FileManager.default.removeItem(at: target) }

        let summary = try await readSealedMessages(from: store(everything), key: owner, into: target, keep: false)

        #expect(summary == ReadSummary(saved: 3, unreadable: 1))
        #expect(FileManager.default.fileExists(atPath: target.appendingPathComponent("com.example.a/aaaaaaaa-0000-0000-0000-000000000001.json").path))
        #expect(everything.objects.keys.sorted() == [other, "beacon-private/com.example.b/not-a-message.txt"].sorted())
    }

    @Test func readingWithKeepLeavesEveryObject() async throws {
        let pretend = try bucket()
        let before = pretend.objects.keys.sorted()
        let target = folder()
        defer { try? FileManager.default.removeItem(at: target) }

        let summary = try await readSealedMessages(from: store(pretend), key: owner, into: target, keep: true)

        #expect(summary.saved == 3)
        #expect(pretend.objects.keys.sorted() == before)
        #expect(!pretend.requests.contains { $0.httpMethod == "DELETE" })
    }

    @Test func aRefusedListingIsAnError() async {
        let refused = CloudStorageStore(bucket: "b", accessToken: "t") { _ in (403, Data()) }
        await #expect(throws: StoreError.listFailed(status: 403)) { _ = try await refused.list() }
    }
}

@Suite("The Supabase store")
struct SupabaseStoreTests {

    @Test func itListsFoldersThenTheirMessagesAndKeepsTheSameRequests() async throws {
        let seen = Recorder()
        let store = SupabaseStore(base: URL(string: "https://x.supabase.co")!, bucket: "beacon-private", access: "key") { request in
            seen.add(request)
            let body = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any]
            let entries: [[String: Any]] = (body?["prefix"] as? String) == ""
                ? [["name": "com.example.a", "id": NSNull()]]
                : [["name": "m.bin", "id": "1"], ["name": "note.txt", "id": "2"]]
            return (200, try! JSONSerialization.data(withJSONObject: entries))
        }
        let found = try await store.list()
        #expect(found == [SealedObject(app: "com.example.a", path: "com.example.a/m.bin")])
        let first = try #require(seen.requests.first)
        #expect(first.url?.absoluteString == "https://x.supabase.co/storage/v1/object/list/beacon-private")
        #expect(first.value(forHTTPHeaderField: "Authorization") == "Bearer key")
    }
}

private final class Recorder: @unchecked Sendable {
    private let lock = NSLock()
    private var all: [URLRequest] = []
    var requests: [URLRequest] { lock.withLock { all } }
    func add(_ request: URLRequest) { lock.withLock { all.append(request) } }
}
