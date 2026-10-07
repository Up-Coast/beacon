import Testing
import Foundation
@testable import BeaconGitHub

@Suite("The name and email GitHub gives")
struct GitHubProfileTests {

    @Test func aFullProfileFillsNameAndEmail() {
        let profile = GitHubProfile(json: ["login": "octocat", "name": "Mona", "email": "m@example.com"])
        let reporter = profile.reporter()
        #expect(reporter.accountID == "octocat")
        #expect(reporter.displayName == "Mona")
        #expect(reporter.contact == "m@example.com")
    }

    @Test func missingPartsFallBackToTheLogin() {
        let profile = GitHubProfile(json: ["login": "octocat", "name": NSNull(), "email": ""])
        let reporter = profile.reporter()
        #expect(reporter.displayName == "octocat")
        #expect(reporter.contact == "@octocat")
    }
}
