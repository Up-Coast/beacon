// The relay route: what the app sends, and what the reporter is told.

import Testing
import Foundation
@testable import BeaconCore
@testable import BeaconGitHub

private let relay = RelayTransport(endpoint: URL(string: "https://example.invalid/beacon")!,
                                   appToken: "app-token")

private func submission(reporter: Reporter) -> ReportSubmission {
    let report = FeedbackReport(
        reporter: reporter,
        body: .feedback(FeedbackBody(message: "The colours are lovely")),
        attachments: [Attachment(kind: .screenshot, filename: "shot.png", data: Data([1, 2, 3]))],
        context: ReportContext(app: AppIdentity(name: "Harbour", bundleIdentifier: "com.example.harbour")))
    return ReportSubmission(report: report, issue: IssueRenderer.render(report, index: nil),
                            attachments: report.attachments)
}

@Suite("The relay route")
struct RelayTests {

    @Test func thePayloadNamesTheAppAndCarriesTheContact() throws {
        var reporter = Reporter.anonymous(deviceID: "abc")
        reporter.contact = "sam@example.com"
        let request = try relay.request(for: submission(reporter: reporter))
        let body = try #require(request.httpBody)
        let payload = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])

        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer app-token")
        #expect(payload["app"] as? String == "com.example.harbour")
        #expect(payload["contact"] as? String == "sam@example.com")
        #expect(payload["account"] as? String == "anonymous-abc")
        #expect(payload["anonymous"] as? Bool == true)
        #expect((payload["reference"] as? String)?.hasPrefix("BN-") == true)
        let attachments = try #require(payload["attachments"] as? [[String: String]])
        #expect(attachments.first?["base64"] == "AQID")
    }

    @Test func noContactMeansNoContactField() {
        let payload = relay.payload(for: submission(reporter: .anonymous(deviceID: "abc")))
        #expect(payload["contact"] == nil)
    }

    /// The receipt says the team has it, keeps the issue for the saved
    /// copy, and shows the reporter nothing about it.
    @Test func theReceiptThanksThemAndHidesTheIssue() throws {
        let answer = Data(#"{"issue_number": 42, "html_url": "https://example.com/42"}"#.utf8)
        let receipt = try relay.receipt(status: 201, data: answer)
        #expect(receipt.summary.hasPrefix("Sent to the team. Thank you."))
        #expect(!receipt.summary.contains("42"))
        #expect(receipt.issueNumber == 42)
        #expect(receipt.url?.absoluteString == "https://example.com/42")
        #expect(ReporterWords(destination: relay.destination).link(for: receipt) == nil)
    }

    @Test func aRefusalWithoutAReasonStillSaysNothingAboutGitHub() {
        #expect(throws: TransportError.rejected(status: 500,
                                                detail: "The report couldn't be delivered just now.")) {
            try relay.receipt(status: 500, data: Data())
        }
    }

    /// Every sentence the relay route puts in front of a reporter.
    @Test func noReporterFacingWordNamesGitHub() throws {
        let receipt = try relay.receipt(status: 201, data: Data(#"{"issue_number": 1}"#.utf8))
        var sentences = ReporterWords(destination: relay.destination).everySentence()
        sentences += [relay.destinationDescription, receipt.summary]
        for sentence in sentences {
            for word in ["github", "issue", "repositor", "label"] {
                #expect(!sentence.lowercased().contains(word), "\(word) in: \(sentence)")
            }
        }
    }

    @Test func onlyTheGitHubAccountTransportsNameGitHub() {
        let client = GitHubClient(owner: "o", repository: "r", token: "t")
        #expect(GitHubIssueTransport(client: client).destination == .gitHub)
        #expect(SignedInGitHubIssueTransport(owner: "o", repository: "r",
                                             account: GitHubAccount(clientID: "c")).destination == .gitHub)
        #expect(relay.destination == .team)
        #expect(LocalBundleTransport(folderProvider: { nil }).destination == .team)
    }
}
