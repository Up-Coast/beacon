// Who a reporter is, asked once and remembered on this device.
//
// An app whose reporters have no accounts sends `Reporter.anonymous()`.
// Asking the same person for a name and a way to reach them on every report
// is how they stop reporting, so the answer is kept in the app's defaults,
// shown again on the next report, and can be edited or cleared at any time.
// It is sent nowhere except in the report itself. A host that supplies an
// identity of its own is never overridden by this one.

import Foundation

/// A name and an email, both optional, plus whether the reporter has made
/// the choice already (including the choice to send without either).
public struct ReporterIdentity: Codable, Sendable, Equatable {
    public var name: String
    public var email: String
    /// True once the reporter has been asked and answered, even with
    /// nothing, so the question is not put to them again as if new.
    public var decided: Bool

    public init(name: String = "", email: String = "", decided: Bool = false) {
        self.name = name
        self.email = email
        self.decided = decided
    }

    /// The name with surrounding space removed; nil when empty.
    public var cleanName: String? { Self.clean(name) }
    /// The email with surrounding space and line breaks removed; nil when empty.
    public var cleanEmail: String? { Self.clean(email) }
    /// Whether the reporter gave neither.
    public var isEmpty: Bool { cleanName == nil && cleanEmail == nil }

    public static func clean(_ text: String) -> String? {
        let trimmed = text.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension Reporter {
    /// True when the host sent only an anonymous install: no name and no way
    /// to reach them of its own. Only then does a remembered identity apply;
    /// anything the host supplies wins.
    public var acceptsRememberedIdentity: Bool {
        isAnonymous && displayName == nil && contact == nil
    }

    /// This reporter carrying the identity, when the identity applies. The
    /// account id stays the install's, so a relay can still tell installs
    /// apart; the name and email ride in the display name and contact.
    public func carrying(_ identity: ReporterIdentity) -> Reporter {
        guard acceptsRememberedIdentity else { return self }
        var sender = self
        sender.displayName = identity.cleanName
        sender.contact = identity.cleanEmail
        return sender
    }
}

/// Where the identity is kept. The default writes to UserDefaults, like the
/// consent record; a host with its own store hands in its own.
public protocol ReporterIdentityStoring: Sendable {
    func load() -> ReporterIdentity?
    func save(_ identity: ReporterIdentity)
    func clear()
}

/// `@unchecked Sendable` for the same reason as `UserDefaultsConsentStore`:
/// `UserDefaults` is thread-safe but not annotated.
public struct UserDefaultsReporterIdentityStore: ReporterIdentityStoring, @unchecked Sendable {
    public static let defaultsKey = "beacon.reporter-identity"

    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = Self.defaultsKey) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> ReporterIdentity? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ReporterIdentity.self, from: data)
    }

    public func save(_ identity: ReporterIdentity) {
        guard let data = try? JSONEncoder().encode(identity) else { return }
        defaults.set(data, forKey: key)
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
