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

    /// The relay's own message is never shown: only a fixed sentence chosen by status.
    @Test func aRefusalShowsOurWordsNotTheRelays() {
        let said = Data(#"{"error": "GitHub issue creation failed on repository x"}"#.utf8)
        #expect(throws: TransportError.rejected(status: 500,
                                                detail: "The report couldn't be delivered just now.")) {
            try relay.receipt(status: 500, data: said)
        }
        #expect(throws: TransportError.rejected(status: 413, detail: ReporterWords(destination: .team)
            .refusal(status: 413))) {
            try relay.receipt(status: 413, data: said)
        }
    }

    @Test func anAttachmentOverTheRelaysLimitIsRefusedBeforeUpload() {
        let big = Attachment(kind: .screenRecording, filename: "r.mp4",
                             data: Data(count: RelayTransport.defaultMaximumEncodedBytes))
        var oversize = submission(reporter: .anonymous(deviceID: "abc"))
        oversize.attachments = [big]
        #expect(throws: TransportError.self) { _ = try relay.request(for: oversize) }
    }

    /// The relay passes on only Beacon's own labels, so its list must hold every label the app makes.
    @Test func theRelayKnowsEveryLabelTheAppMakes() throws {
        let relaySource = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Relay/supabase-edge/supabase/functions/beacon-relay/relay.ts")
        let source = try String(contentsOf: relaySource, encoding: .utf8)
        let labels = [IssueRenderer.Labels.beacon]
            + FeedbackKind.allCases.map(IssueRenderer.Labels.kind)
            + Impact.allCases.map(IssueRenderer.Labels.impact)
        for label in labels { #expect(source.contains("\"\(label)\""), "relay.ts lacks \(label)") }
    }

    /// Every sentence the relay route puts in front of a reporter.
    @Test func noReporterFacingWordNamesGitHub() throws {
        let receipt = try relay.receipt(status: 201, data: Data(#"{"issue_number": 1}"#.utf8))
        let words = ReporterWords(destination: relay.destination)
        var sentences = words.everySentence()
        sentences += [relay.destinationDescription, receipt.summary]
        // The errors the relay route can raise, as the sheet shows them.
        let errors: [TransportError] = [
            .network(words.notReachable), .tooLarge(bytes: 40 << 20, limit: 30 << 20),
        ] + [400, 401, 413, 429, 500, 502].map { .rejected(status: $0, detail: words.refusal(status: $0)) }
        sentences += errors.compactMap(\.errorDescription)
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
