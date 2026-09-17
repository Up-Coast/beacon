// The GitHub account this app's reports are filed as.
//
// The device flow hands back a token; something has to remember it, know
// whose it is, and turn it into the reporter the sheet asks for. Every host
// on the GitHub route needs exactly that, so it lives here once rather than
// being rewritten in each app.
//
// Two keychain items, both under the same service: the login of whoever is
// signed in, and that person's token filed under their login. Reading the
// login first means a second person signing in on the same device replaces
// the first cleanly instead of leaving a token nobody can reach.

import Foundation
import Security
import BeaconCore

public struct GitHubAccount: Sendable {

    /// The OAuth App's client id. Public by design.
    public var clientID: String
    /// The keychain service both items live under.
    public var service: String

    public init(clientID: String, service: String = "beacon.github") {
        self.clientID = clientID
        self.service = service
    }

    /// The keychain account the signed-in login is stored under. Not a
    /// GitHub login itself, and one GitHub logins can't collide with: they
    /// may not start with a period.
    static let loginItem = ".signed-in-login"

    /// Who is signed in, or nil.
    public var login: String? {
        GitHubTokenStore.read(account: Self.loginItem, service: service)
    }

    /// The signed-in person's token, read at the moment it's needed.
    public var token: String? {
        login.flatMap { GitHubTokenStore.read(account: $0, service: service) }
    }

    /// What `BeaconConfiguration.currentReporter` returns on the GitHub
    /// route: the GitHub login, which is also where anyone replies.
    public var reporter: Reporter? {
        login.map { Reporter(accountID: $0, displayName: $0, contact: "@\($0)") }
    }

    public var deviceFlow: GitHubDeviceFlow {
        GitHubDeviceFlow(clientID: clientID)
    }

    /// Whether this build has a keychain to keep a sign-in in, asked
    /// before anybody is sent to GitHub. An app built without a signing
    /// team has none, and a tester who signs in anyway watches it fail at
    /// the last step and concludes that GitHub reporting is broken.
    public var canKeepASignIn: Bool { keychainStatus == errSecSuccess }

    /// The keychain's answer to a harmless write, for the message that
    /// explains a refusal.
    public var keychainStatus: OSStatus {
        let probe = ".can-keep-a-sign-in"
        let status = GitHubTokenStore.write("probe", account: probe, service: service)
        GitHubTokenStore.delete(account: probe, service: service)
        return status
    }

    /// Keep a token the device flow returned. GitHub is asked whose it is,
    /// so the login on every report is the one GitHub vouches for rather
    /// than anything typed. Returns that login.
    @discardableResult
    public func connect(token: String) async throws -> String {
        let login = try await GitHubClient(owner: "", repository: "", token: token).currentLogin()
        try remember(token: token, login: login)
        return login
    }

    func remember(token: String, login: String) throws {
        signOut()
        var status = GitHubTokenStore.write(token, account: login, service: service)
        if status == errSecSuccess {
            status = GitHubTokenStore.write(login, account: Self.loginItem, service: service)
        }
        guard status == errSecSuccess else {
            signOut()
            throw TransportError.notConfigured(
                "the GitHub sign-in couldn't be kept on \(PlatformWording.thisDevice) \u{2014} "
                + GitHubTokenStore.explain(status))
        }
    }

    /// Forget whoever is signed in. The next report asks them to sign in.
    public func signOut() {
        if let login { GitHubTokenStore.delete(account: login, service: service) }
        GitHubTokenStore.delete(account: Self.loginItem, service: service)
    }
}
