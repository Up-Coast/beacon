// What GitHub says about the person who signed in: enough to fill the
// reporter's name and email so they do not type them again.

import Foundation
import BeaconCore

public struct GitHubProfile: Sendable, Equatable {
    public var login: String
    public var name: String?
    public var email: String?

    public init(login: String, name: String? = nil, email: String? = nil) {
        self.login = login
        self.name = name
        self.email = email
    }

    /// From the `user` endpoint's JSON. Empty strings count as missing.
    public init(json: [String: Any]) {
        func text(_ key: String) -> String? {
            ReporterIdentity.clean(json[key] as? String ?? "")
        }
        self.init(login: text("login") ?? "unknown", name: text("name"), email: text("email"))
    }

    /// The reporter this profile files as: the name GitHub has (the login
    /// when it has none), and the email when GitHub returns one (the
    /// @login handle when it does not).
    public func reporter(login: String? = nil) -> Reporter {
        let account = login ?? self.login
        return Reporter(accountID: account, displayName: name ?? account,
                        contact: email ?? "@\(account)")
    }
}
