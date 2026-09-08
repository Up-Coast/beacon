import Testing
import Foundation
@testable import BeaconCore
@testable import BeaconGitHub

private func submission() -> ReportSubmission {
    let report = FeedbackReport(
        reporter: Reporter(accountID: "sam@example.com"),
        body: .bug(BugBody(whatHappened: "It went white", expected: "It should save",
                           steps: ["Click Save"], reproducibility: .everyTime)))
    return ReportSubmission(report: report,
                            issue: IssueRenderer.render(report, index: nil),
                            attachments: [])
}

struct FailingTransport: ReportTransport {
    var destinationDescription = "a place that is down"
    func submit(_ submission: ReportSubmission) async throws -> SubmissionReceipt {
        throw TransportError.network("the network is down")
    }
}

@Suite("Transports")
struct TransportTests {

    /// The local transport must never claim a report was filed. Somebody
    /// who believes their report is on its way when it is sitting in a
    /// folder is worse off than somebody who knows.
    @Test func savingLocallyIsNeverReportedAsFiled() async throws {
        let folder = URL(fileURLWithPath: "/tmp/beacon-test")
        let transport = LocalBundleTransport(folderProvider: { folder })
        let receipt = try await transport.submit(submission())
        #expect(!receipt.isFiled)
        #expect(receipt.issueNumber == nil)
        #expect(receipt.url == folder)
    }

    @Test func theFallbackTakesOverAndSaysWhatHappened() async throws {
        let transport = FallbackTransport(
            primary: FailingTransport(),
            fallback: LocalBundleTransport(folderProvider: { URL(fileURLWithPath: "/tmp/x") }))
        let receipt = try await transport.submit(submission())
        #expect(!receipt.isFiled)
        #expect(receipt.summary.contains("couldn't reach GitHub"))
    }

    @Test func theFallbackIsToldWhyItWasNeeded() async throws {
        let box = ErrorBox()
        let transport = FallbackTransport(
            primary: FailingTransport(),
            fallback: LocalBundleTransport(folderProvider: { nil }),
            onFallback: { box.record($0) })
        _ = try await transport.submit(submission())
        #expect(box.message()?.contains("network is down") == true)
    }

    @Test func attachmentFilenamesBecomeLinksWithoutChangingTheProse() {
        let transport = GitHubIssueTransport(
            client: GitHubClient(owner: "your-org", repository: "harbour", token: "x"))
        let body = "## What they attached\n\n- `shot.png` (12 KB)\n"
        let rewritten = transport.insertAttachmentLinks(
            [("shot.png", URL(string: "https://example.com/shot.png")!)], into: body)
        #expect(rewritten.contains("[`shot.png`](https://example.com/shot.png)"))
        #expect(rewritten.contains("(12 KB)"))
    }
}

final class ErrorBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: String?
    func record(_ error: any Error) {
        lock.lock(); defer { lock.unlock() }
        stored = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
    func message() -> String? {
        lock.lock(); defer { lock.unlock() }
        return stored
    }
}

@Suite("GitHub's answers, said in words a reporter can act on")
struct ErrorExplanationTests {

    @Test func aDeadSignInSaysToSignInAgain() {
        #expect(GitHubClient.explain(401, "Bad credentials").contains("Signing in again"))
    }

    @Test func rateLimitingSaysTheReportIsSafe() {
        let message = GitHubClient.explain(403, "API rate limit exceeded")
        #expect(message.contains("saved"))
    }

    @Test func aMissingRepositoryDoesNotBlameTheReporter() {
        #expect(GitHubClient.explain(404, "Not Found").contains("couldn't be found"))
    }
}

@Suite("Size limits are hit before the upload, not after")
struct RelaySizeTests {

    @Test func anOversizeReportIsRefusedLocally() async {
        let big = Attachment(kind: .screenRecording, filename: "recording.mp4",
                             data: Data(count: AcceptedFormats.maximumTotalBytes))
        let report = FeedbackReport(reporter: Reporter(accountID: "a@b.c"),
                                    body: .feedback(FeedbackBody(message: "here")),
                                    attachments: [big])
        let transport = RelayTransport(endpoint: URL(string: "https://example.invalid/beacon")!)
        let submission = ReportSubmission(report: report,
                                          issue: IssueRenderer.render(report, index: nil),
                                          attachments: [big])
        await #expect(throws: TransportError.self) {
            _ = try await transport.submit(submission)
        }
    }
}
