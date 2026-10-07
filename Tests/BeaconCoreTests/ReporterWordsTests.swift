// Reporting with no account, and the words a reporter reads on each route.

import Testing
import Foundation
@testable import BeaconCore

private func freshDefaults() -> UserDefaults {
    UserDefaults(suiteName: "beacon.tests.\(UUID().uuidString)")!
}

private let bug = BugBody(whatHappened: "The window went white.", expected: "It should have saved.",
                          steps: ["Click Save"], reproducibility: .everyTime)

@Suite("An anonymous reporter")
struct AnonymousReporterTests {

    @Test func theIdIsMadeOnceAndKeptForThisInstall() {
        let defaults = freshDefaults()
        let first = AnonymousDeviceID.current(defaults: defaults)
        #expect(AnonymousDeviceID.current(defaults: defaults) == first)
        #expect(AnonymousDeviceID.current(defaults: freshDefaults()) != first)
    }

    /// Nothing about the person: a random id, no name, no contact.
    @Test func itCarriesNoPersonalData() {
        let id = AnonymousDeviceID.current(defaults: freshDefaults())
        let reporter = Reporter.anonymous(deviceID: id)
        #expect(reporter.accountID == "anonymous-" + id)
        #expect(UUID(uuidString: id) != nil)
        #expect(reporter.displayName == nil)
        #expect(reporter.contact == nil)
        #expect(reporter.isAnonymous)
        #expect(!Reporter(accountID: "sam@example.com").isAnonymous)
    }

    @Test func theIssueSaysItIsAnonymousAndThatNobodyCanBeReached() {
        let report = FeedbackReport(reporter: .anonymous(deviceID: "abc"), body: .bug(bug))
        let body = IssueRenderer.render(report, index: nil).body
        #expect(body.contains("Reported anonymously (`anonymous-abc`)"))
        #expect(body.contains("left no way to reach them"))
        #expect(!body.contains("agreed to be contacted"))
    }

    @Test func aContactTheyLeftRidesInTheIssue() {
        var reporter = Reporter.anonymous(deviceID: "abc")
        reporter.contact = "  sam@example.com\n"
        let report = FeedbackReport(reporter: reporter, body: .bug(bug))
        #expect(IssueRenderer.render(report, index: nil).body
            .contains("they can be reached at **sam@example.com**."))
    }

    @Test func aSignedInReporterKeepsTheirLineAndGainsTheContact() {
        let report = FeedbackReport(
            reporter: Reporter(accountID: "sam", contact: "555-0100"), body: .bug(bug))
        let body = IssueRenderer.render(report, index: nil).body
        #expect(body.contains("agreed to be contacted"))
        #expect(body.contains("Reach them at **555-0100**."))
    }
}

@Suite("The words a reporter reads")
struct ReporterWordsTests {

    static let forbidden = ["github", "issue", "repositor", "label"]

    /// The team route never gives away where a report goes.
    @Test func theTeamRouteNeverNamesGitHub() {
        let words = ReporterWords(destination: .team)
        for sentence in words.everySentence() {
            for word in Self.forbidden {
                #expect(!sentence.lowercased().contains(word), "\(word) in: \(sentence)")
            }
        }
    }

    @Test func theNoticeDependsOnTheRouteAndTheReporter() {
        let team = ReporterWords(destination: .team)
        let signedIn = team.notice(for: Reporter(accountID: "sam"), organizationName: "the Harbour team")
        let anonymous = team.notice(for: .anonymous(deviceID: "x"), organizationName: "the Harbour team")
        let gitHub = ReporterWords(destination: .gitHub)
            .notice(for: Reporter(accountID: "sam"), organizationName: "the Harbour team")

        #expect(gitHub.version == ConsentNotice.current.version)
        #expect(signedIn.version == ConsentNotice.team.version)
        #expect(anonymous.version == ConsentNotice.teamAnonymous.version)
        #expect(Set([gitHub.version, signedIn.version, anonymous.version]).count == 3)
        #expect(anonymous.points.contains { $0.contains("don't need an account") })
        #expect(signedIn.points.contains { $0.contains("the Harbour team") })
        #expect(!anonymous.points.contains { $0.contains("$ORG") })
    }

    /// A filed report is never linked on the team route; a saved folder is.
    @Test func theTeamReceiptHasNoLink() {
        let filed = SubmissionReceipt(summary: "Sent", issueNumber: 7,
                                      url: URL(string: "https://example.com/7"))
        let folder = SubmissionReceipt(summary: "Saved", url: URL(fileURLWithPath: "/tmp/r"),
                                       isFiled: false)
        #expect(ReporterWords(destination: .team).link(for: filed) == nil)
        #expect(ReporterWords(destination: .team).link(for: folder) == folder.url)
        #expect(ReporterWords(destination: .gitHub).link(for: filed) == filed.url)
    }

    @Test func anAnonymousReporterIsNotShownTheirRandomId() {
        let words = ReporterWords(destination: .team)
        #expect(!words.from(.anonymous(deviceID: "abc")).contains("abc"))
        #expect(words.from(Reporter(accountID: "sam")) == "sam")
    }

    @Test func onlyTheTeamRouteAsksHowToReachSomeone() {
        #expect(ReporterWords(destination: .team).asksForContact)
        #expect(!ReporterWords(destination: .gitHub).asksForContact)
    }
}
