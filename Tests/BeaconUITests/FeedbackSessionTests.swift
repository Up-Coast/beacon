// The session behind the sheet: who a report is from, and what dropping a
// file does. Everything here runs without a window.

import Testing
import Foundation
import BeaconCore
@testable import BeaconUI

private struct NoTransport: ReportTransport {
    var destinationDescription: String { "nowhere" }
    func submit(_ submission: ReportSubmission) async throws -> SubmissionReceipt {
        SubmissionReceipt(summary: "ok")
    }
}

private final class Memory: ConsentStoring, @unchecked Sendable {
    var records: [String: ConsentRecord] = [:]
    func record(for accountID: String) -> ConsentRecord? { records[accountID] }
    func save(_ record: ConsentRecord) { records[record.accountID] = record }
}

private func makeStore() -> UserDefaultsReporterIdentityStore {
    UserDefaultsReporterIdentityStore(
        defaults: UserDefaults(suiteName: "beacon.tests.\(UUID().uuidString)")!)
}

@MainActor
private func makeSession(host: Reporter? = .anonymous(deviceID: "abc"),
                         store: UserDefaultsReporterIdentityStore = makeStore(),
                         consent: Memory = Memory()) -> FeedbackSession {
    let archive = FileManager.default.temporaryDirectory
        .appendingPathComponent("beacon-ui-tests-\(UUID().uuidString)")
    return FeedbackSession(configuration: BeaconConfiguration(
        app: AppIdentity(name: "Test", bundleIdentifier: "test.app", version: "1", build: "1"),
        organizationName: "the team",
        currentReporter: { host },
        transport: NoTransport(),
        consentStore: consent,
        identityStore: store,
        reportArchiveDirectory: archive))
}

@MainActor
@Suite("Who a report is from")
struct IdentitySessionTests {

    @Test func whatWasGivenOnceIsFilledInOnTheNextSheet() {
        let store = makeStore()
        let first = makeSession(store: store)
        first.name = "Sam"
        first.contact = "sam@example.com"
        first.acceptConsent()

        let next = makeSession(store: store)
        #expect(next.name == "Sam")
        #expect(next.contact == "sam@example.com")
        #expect(next.draftReport().reporter.displayName == "Sam")
        #expect(next.draftReport().reporter.contact == "sam@example.com")
    }

    @Test func clearingForgetsItOnThisDevice() {
        let store = makeStore()
        let session = makeSession(store: store)
        session.name = "Sam"
        session.contact = "sam@example.com"
        session.acceptConsent()
        session.clearIdentity()

        #expect(store.load() == nil)
        #expect(makeSession(store: store).name.isEmpty)
        #expect(session.draftReport().reporter.displayName == nil)
    }

    @Test func aNameTheHostSuppliesWinsOverTheRememberedOne() {
        let store = makeStore()
        store.save(ReporterIdentity(name: "Remembered", email: "r@example.com", decided: true))
        let host = Reporter(accountID: "pat", displayName: "Pat", contact: "pat@example.com")
        let session = makeSession(host: host, store: store)

        #expect(!session.asksForIdentity)
        #expect(session.draftReport().reporter.displayName == "Pat")
        #expect(session.draftReport().reporter.contact == "pat@example.com")
    }

    @Test func stayingAnonymousIsAChoiceAndItIsKept() {
        let store = makeStore()
        let session = makeSession(store: store)
        session.name = "Sam"
        session.chooseToSendWithoutName()

        #expect(session.draftReport().reporter.displayName == nil)
        #expect(session.draftReport().reporter.contact == nil)
        #expect(session.draftReport().reporter.isAnonymous)
        let next = makeSession(store: store)
        #expect(next.sendsWithoutName)
        #expect(next.draftReport().reporter.displayName == nil)
    }

    @Test func nothingBlocksAReportWithNoName() {
        let session = makeSession()
        session.kind = .feedback
        session.feedback.message = "The export button is easy to find and it works well."
        #expect(CompletenessRules.blocking(session.draftReport(), offersAreas: false).isEmpty)
    }

    @Test func aGitHubAccountTakesOverAsTheReporter() {
        let session = makeSession()
        session.name = "Typed"
        session.adoptGitHub(Reporter(accountID: "octocat", displayName: "Mona", contact: "@octocat"))
        #expect(!session.asksForIdentity)
        #expect(session.draftReport().reporter.accountID == "octocat")
        #expect(session.draftReport().reporter.displayName == "Mona")
    }
}

@MainActor
@Suite("Dropping files on the attachments step")
struct DropSessionTests {

    private func tempFile(_ name: String, bytes: Int = 16) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("beacon-drop-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try Data(count: bytes).write(to: url)
        return url
    }

    @Test func aReadableFileIsAttached() throws {
        let session = makeSession()
        #expect(session.addFiles([try tempFile("notes.txt")]) == nil)
        #expect(session.attachments.map(\.filename) == ["notes.txt"])
        #expect(session.attachments.first?.kind == .userFile)
    }

    @Test func anUnreadableTypeGetsTheSameSentenceAsThePicker() throws {
        let session = makeSession()
        let url = try tempFile("app.dmg")
        #expect(session.addFiles([url]) == AcceptedFormats.refusal(for: url))
        #expect(session.attachments.isEmpty)
        #expect(session.attachmentProblem == AcceptedFormats.refusal(for: url))
    }

    @Test func aFolderIsRefused() throws {
        let session = makeSession()
        let folder = try tempFile("a.txt").deletingLastPathComponent()
        #expect(session.addFiles([folder]) == AcceptedFormats.folderRefusal)
    }

    @Test func anOversizedFileIsRefusedAndTheRestStillGoIn() throws {
        let session = makeSession()
        let big = try tempFile("big.pdf", bytes: AcceptedFormats.maximumFileBytes + 1)
        let small = try tempFile("small.txt")
        let refusal = session.addFiles([big, small])
        #expect(refusal?.contains("big.pdf") == true)
        #expect(session.attachments.map(\.filename) == ["small.txt"])
    }
}
