// A remembered name and email, and the limits files are held to.

import Testing
import Foundation
@testable import BeaconCore

private func freshStore() -> UserDefaultsReporterIdentityStore {
    UserDefaultsReporterIdentityStore(
        defaults: UserDefaults(suiteName: "beacon.tests.\(UUID().uuidString)")!)
}

private let bug = BugBody(whatHappened: "The window went white.", expected: "It should have saved.",
                          steps: ["Click Save"], reproducibility: .everyTime)

@Suite("A remembered reporter identity")
struct ReporterIdentityTests {

    @Test func whatWasSavedComesBack() {
        let store = freshStore()
        #expect(store.load() == nil)
        store.save(ReporterIdentity(name: "Sam", email: "sam@example.com", decided: true))
        #expect(store.load()?.name == "Sam")
        #expect(store.load()?.email == "sam@example.com")
    }

    @Test func clearingForgetsIt() {
        let store = freshStore()
        store.save(ReporterIdentity(name: "Sam", email: "sam@example.com", decided: true))
        store.clear()
        #expect(store.load() == nil)
    }

    @Test func anAnonymousInstallCarriesTheNameAndEmail() {
        let sender = Reporter.anonymous(deviceID: "abc")
            .carrying(ReporterIdentity(name: " Sam ", email: "sam@example.com"))
        #expect(sender.accountID == "anonymous-abc")
        #expect(sender.displayName == "Sam")
        #expect(sender.contact == "sam@example.com")
    }

    @Test func aReporterTheHostNamesWins() {
        let hosts = [Reporter(accountID: "pat", displayName: "Pat", contact: "pat@example.com"),
                     Reporter(accountID: "anonymous-abc", displayName: "Host Name"),
                     Reporter(accountID: "anonymous-abc", contact: "host@example.com")]
        for host in hosts {
            #expect(!host.acceptsRememberedIdentity)
            #expect(host.carrying(ReporterIdentity(name: "Sam", email: "sam@example.com")) == host)
        }
        #expect(Reporter.anonymous(deviceID: "abc").acceptsRememberedIdentity)
    }

    @Test func sendingWithoutAName() {
        let sender = Reporter.anonymous(deviceID: "abc").carrying(ReporterIdentity(decided: true))
        #expect(sender.displayName == nil)
        #expect(sender.contact == nil)
        #expect(sender.isAnonymous)
    }

    @Test func theIssueFromLineNamesThemAndTheEmail() {
        let sender = Reporter.anonymous(deviceID: "abc")
            .carrying(ReporterIdentity(name: "Sam", email: "sam@example.com"))
        let body = IssueRenderer.render(FeedbackReport(reporter: sender, body: .bug(bug)), index: nil).body
        #expect(body.contains("Reported by **Sam** (`anonymous-abc`)"))
        #expect(body.contains("Reach them at **sam@example.com**."))
    }

    @Test func aNameWithNoEmailStillRenders() {
        let sender = Reporter.anonymous(deviceID: "abc").carrying(ReporterIdentity(name: "Sam"))
        let body = IssueRenderer.render(FeedbackReport(reporter: sender, body: .bug(bug)), index: nil).body
        #expect(body.contains("Reported by **Sam**"))
        #expect(!body.contains("Reach them"))
    }

    @Test func theReviewScreenShowsWhatWillBeSent() {
        let words = ReporterWords(destination: .team)
        let sender = Reporter.anonymous(deviceID: "abc")
            .carrying(ReporterIdentity(name: "Sam", email: "sam@example.com"))
        #expect(words.from(sender) == "Sam, sam@example.com")
        #expect(!words.from(sender).contains("abc"))
    }

    /// A report saved before this release has no name or email of its own;
    /// the reporter shape did not change, so it still decodes.
    @Test func aReportSavedBeforeStillDecodes() throws {
        let old = FeedbackReport(reporter: Reporter(accountID: "sam"), body: .bug(bug))
        let data = try JSONEncoder().encode(old)
        #expect(try JSONDecoder().decode(FeedbackReport.self, from: data).reporter.accountID == "sam")
        let bare = Data(#"{"accountID":"anonymous-abc"}"#.utf8)
        let reporter = try JSONDecoder().decode(Reporter.self, from: bare)
        #expect(reporter.displayName == nil && reporter.contact == nil)
    }
}

@Suite("The limits on attached files")
struct AttachmentLimitTests {

    private func file(_ name: String, bytes: Int) -> BeaconCore.Attachment {
        BeaconCore.Attachment(kind: .userFile, filename: name, data: Data(count: bytes))
    }

    @Test func typesThatCanBeReadAreAccepted() {
        for name in ["notes.txt", "shot.PNG", "report.pdf", "clip.mov"] {
            #expect(AcceptedFormats.accepts(URL(fileURLWithPath: "/tmp/\(name)")), "\(name)")
        }
    }

    @Test func otherTypesAreRefusedInPlainWords() {
        let url = URL(fileURLWithPath: "/tmp/app.dmg")
        #expect(!AcceptedFormats.accepts(url))
        #expect(AcceptedFormats.refusal(for: url).contains("A .dmg file can't be read"))
    }

    @Test func aFileWithinTheLimitsFits() {
        #expect(AcceptedFormats.sizeRefusal(for: [file("a.txt", bytes: 1024)], alreadyAttached: 0) == nil)
    }

    @Test func aFileOverTheSingleFileLimitIsRefused() {
        let big = file("big.pdf", bytes: AcceptedFormats.maximumFileBytes + 1)
        let refusal = AcceptedFormats.sizeRefusal(for: [big], alreadyAttached: 0)
        #expect(refusal?.contains("big.pdf") == true)
        #expect(refusal?.contains("limit for one file") == true)
    }

    @Test func aFileThatTipsTheTotalOverIsRefused() {
        let refusal = AcceptedFormats.sizeRefusal(
            for: [file("a.txt", bytes: 2 * 1024 * 1024)],
            alreadyAttached: AcceptedFormats.maximumTotalBytes - 1024)
        #expect(refusal?.contains("in total") == true)
    }

    @Test func foldersHaveASentenceOfTheirOwn() {
        #expect(AcceptedFormats.folderRefusal.contains("folder"))
    }
}
