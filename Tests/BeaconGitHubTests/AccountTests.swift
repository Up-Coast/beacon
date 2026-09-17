import Testing
import Foundation
@testable import BeaconCore
@testable import BeaconGitHub

/// The keychain is the real one. Each test uses its own service so a run
/// can't disturb a signed-in app on the same Mac, and clears it afterwards.
/// Where there is no usable keychain — a locked one on a build machine —
/// there is nothing to test, and the suite says so rather than passing.
private enum Keychain {
    static let probeService = "beacon.test.probe"

    static var isUsable: Bool {
        let saved = GitHubTokenStore.save("probe", account: "probe", service: probeService)
        GitHubTokenStore.delete(account: "probe", service: probeService)
        return saved
    }
}

private func makeAccount() -> GitHubAccount {
    GitHubAccount(clientID: "Iv1.test", service: "beacon.test.\(UUID().uuidString)")
}

@Suite("The signed-in GitHub account", .enabled(if: Keychain.isUsable))
struct GitHubAccountTests {

    @Test func nobodyIsSignedInUntilSomebodyIs() {
        let account = makeAccount()
        #expect(account.login == nil)
        #expect(account.token == nil)
        #expect(account.reporter == nil)
    }

    @Test func aRememberedTokenComesBackWithItsReporter() throws {
        let account = makeAccount()
        defer { account.signOut() }
        try account.remember(token: "gho_example", login: "octocat")

        #expect(account.login == "octocat")
        #expect(account.token == "gho_example")
        #expect(account.reporter?.accountID == "octocat")
        #expect(account.reporter?.contact == "@octocat")
    }

    /// A second person on the same device replaces the first, rather than
    /// leaving a token behind that nothing can reach or revoke.
    @Test func signingSomebodyElseInReplacesTheFirstPerson() throws {
        let account = makeAccount()
        defer { account.signOut() }
        try account.remember(token: "gho_first", login: "octocat")
        try account.remember(token: "gho_second", login: "hubot")

        #expect(account.login == "hubot")
        #expect(account.token == "gho_second")
        #expect(GitHubTokenStore.read(account: "octocat", service: account.service) == nil)
    }

    @Test func signingOutLeavesNothingBehind() throws {
        let account = makeAccount()
        try account.remember(token: "gho_example", login: "octocat")
        account.signOut()

        #expect(account.login == nil)
        #expect(GitHubTokenStore.read(account: "octocat", service: account.service) == nil)
    }
}

@Suite("Reports from whoever is signed in", .enabled(if: Keychain.isUsable))
struct SignedInTransportTests {

    @Test func nobodySignedInIsSaidPlainlyRatherThanSentWithNoToken() async {
        let account = makeAccount()
        let transport = SignedInGitHubIssueTransport(
            owner: "your-org", repository: "harbour", account: account)
        let report = FeedbackReport(reporter: Reporter(accountID: "octocat"),
                                    body: .feedback(FeedbackBody(message: "hello")))
        let submission = ReportSubmission(report: report,
                                          issue: IssueRenderer.render(report, index: nil),
                                          attachments: [])
        await #expect(throws: TransportError.notConfigured("nobody is signed in to GitHub")) {
            _ = try await transport.submit(submission)
        }
    }

    @Test func theDestinationNamesTheRepositoryBeforeAnybodySignsIn() {
        let transport = SignedInGitHubIssueTransport(
            owner: "your-org", repository: "harbour", account: makeAccount())
        #expect(transport.destinationDescription == "an issue on your-org/harbour")
    }
}

@Suite("An account that may read but not write")
struct AttachmentRefusalTests {

    /// GitHub lets anyone who can read a repository open an issue, but
    /// only someone who can write to it commit a file. Those two refusals
    /// mean "file the words anyway"; a dead network does not.
    @Test func onlyPermissionRefusalsLetTheIssueGoWithoutItsFiles() {
        #expect(GitHubIssueTransport.isWriteRefusal(.rejected(status: 403, detail: "no")))
        #expect(GitHubIssueTransport.isWriteRefusal(.rejected(status: 404, detail: "no")))
        #expect(!GitHubIssueTransport.isWriteRefusal(.rejected(status: 422, detail: "no")))
        #expect(!GitHubIssueTransport.isWriteRefusal(.network("down")))
    }

    @Test func theIssueSaysTheFilesDidNotComeWithIt() {
        let note = GitHubIssueTransport.attachmentsRefusedNote
        #expect(note.contains("can't add files to this repository"))
    }
}
