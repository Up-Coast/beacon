import Testing
import Foundation
@testable import BeaconCore
@testable import BeaconGitHub

/// Files one real issue, with one real attachment, on a real repository.
///
/// Skipped unless both environment variables are set, so `swift test` on a
/// laptop or in CI never touches the network. Run it on purpose:
///
///     BEACON_LIVE_GITHUB_REPO=owner/name BEACON_LIVE_GITHUB_TOKEN=$(gh auth token) \
///         swift test --filter LiveTransportTests
///
/// It proves the three REST calls the direct transport makes — ensure the
/// attachment branch, put a file on it, create the issue — against GitHub
/// as it is today, which no mock can. The issue it files is titled so it
/// can be found and closed afterwards.
private enum LiveGitHub {
    static var configured: Bool {
        ProcessInfo.processInfo.environment["BEACON_LIVE_GITHUB_REPO"] != nil
            && ProcessInfo.processInfo.environment["BEACON_LIVE_GITHUB_TOKEN"] != nil
    }
}

@Suite("Live GitHub transport", .enabled(if: LiveGitHub.configured))
struct LiveTransportTests {

    @Test func filesAnIssueWithAnAttachment() async throws {
        let env = ProcessInfo.processInfo.environment
        let parts = env["BEACON_LIVE_GITHUB_REPO"]!.split(separator: "/").map(String.init)
        try #require(parts.count == 2)
        let client = GitHubClient(owner: parts[0], repository: parts[1],
                                  token: env["BEACON_LIVE_GITHUB_TOKEN"]!)
        let transport = GitHubIssueTransport(client: client)

        // The attachment goes on the report, so the renderer writes the
        // "What they attached" section the transport puts the link under —
        // the same way the sheet builds a submission.
        let attachment = Attachment(kind: .userFile, filename: "live-test.txt",
                                    data: Data("filed by LiveTransportTests\n".utf8))
        let report = FeedbackReport(
            reporter: Reporter(accountID: "beacon-live-test", displayName: "Beacon live test"),
            title: "[Beacon live test] the direct transport files an issue",
            body: .bug(BugBody(
                whatHappened: "This issue was filed by LiveTransportTests to prove the direct GitHub transport.",
                expected: "An issue with this title, the beacon labels, and one attachment link.",
                steps: ["Run swift test --filter LiveTransportTests with the two variables set"],
                reproducibility: .everyTime)),
            impact: .noticed,
            attachments: [attachment])
        let submission = ReportSubmission(report: report,
                                          issue: IssueRenderer.render(report, index: nil),
                                          attachments: report.attachments)

        let receipt = try await transport.submit(submission)
        #expect(receipt.isFiled)
        #expect(receipt.issueNumber != nil)
        #expect(receipt.url != nil)

        // The issue must link the file, not merely name it.
        let number = try #require(receipt.issueNumber)
        let issue = try await client.send("GET", "\(client.repoPath)/issues/\(number)")
        let body = issue["body"] as? String ?? ""
        #expect(body.contains("live-test.txt"))
        #expect(body.contains("beacon-attachments"))
        print("LIVE_ISSUE_NUMBER=\(receipt.issueNumber ?? -1) \(receipt.url?.absoluteString ?? "")")
    }
}
