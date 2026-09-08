// What the reporter is told before anything leaves their machine.
//
// A feedback report is not anonymous and cannot be — the whole point is
// that somebody can come back and ask a follow-up question. That is a fair
// deal, but only if it is said plainly and said first. So the wording lives
// here as data, it is versioned, and the version the reporter accepted is
// written onto every report they file. Change the wording and the version
// changes with it, which means everyone is asked again rather than being
// held to a promise they never read.

import Foundation

/// The notice a reporter reads once, before their first report.
public struct ConsentNotice: Sendable, Equatable {
    /// Bumped whenever any line below changes. Acceptance is per version.
    public let version: String
    public let headline: String
    /// The points, each one a sentence a support person would say out loud.
    public let points: [String]
    public let acceptButton: String

    public init(version: String, headline: String, points: [String], acceptButton: String) {
        self.version = version
        self.headline = headline
        self.points = points
        self.acceptButton = acceptButton
    }

    /// The shipped wording. `organizationName` is substituted by the host
    /// app's configuration so the notice names a real group of people
    /// rather than "the team".
    public static let current = ConsentNotice(
        version: "2026-09-07.1",
        headline: "Before you send this, here's what happens to it",
        points: [
            "Your report is not anonymous. It goes out with the account "
                + "you're signed in with, so we know it came from you.",
            "We may come back to you with a question about it. That's "
                + "usually how a report gets fixed quickly.",
            "Your report is copied to GitHub, where it becomes an issue. "
                + "Right now only $ORG can read it — but treat it as "
                + "something other people will see, because they will.",
            "We collect your app version, your settings, and details about "
                + "this device. You can read all of it on the next screen "
                + "before you send.",
            "We list the names and folder structure of your project files "
                + "so we can see how things are laid out. We never open "
                + "them and never read what's inside.",
            "Anything you attach yourself — a screenshot, a recording, a "
                + "file — we do read. That's the point of attaching it, and "
                + "it's entirely your choice what to add.",
        ],
        acceptButton: "I understand — let's go")

    /// The notice with the host's organisation name filled in.
    public func naming(_ organizationName: String) -> ConsentNotice {
        ConsentNotice(
            version: version,
            headline: headline,
            points: points.map { $0.replacingOccurrences(of: "$ORG", with: organizationName) },
            acceptButton: acceptButton)
    }
}

/// What Beacon remembers about acceptance. Stored by the host through
/// `ConsentStore`; nothing here reaches for a particular storage system.
public struct ConsentRecord: Codable, Sendable, Equatable {
    public var acceptedVersion: String
    public var acceptedAt: Date
    public var accountID: String

    public init(acceptedVersion: String, acceptedAt: Date, accountID: String) {
        self.acceptedVersion = acceptedVersion
        self.acceptedAt = acceptedAt
        self.accountID = accountID
    }
}

/// Where acceptance is kept. The default writes to UserDefaults, which is
/// right for every host that hasn't got an opinion; a host with its own
/// account store hands in its own.
public protocol ConsentStoring: Sendable {
    func record(for accountID: String) -> ConsentRecord?
    func save(_ record: ConsentRecord)
}

/// `@unchecked Sendable` because `UserDefaults` is documented as thread-safe
/// but not annotated as `Sendable`; the only stored state here is that
/// reference and two immutable strings.
public struct UserDefaultsConsentStore: ConsentStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let keyPrefix: String

    public init(defaults: UserDefaults = .standard, keyPrefix: String = "beacon.consent.") {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    public func record(for accountID: String) -> ConsentRecord? {
        guard let data = defaults.data(forKey: keyPrefix + accountID) else { return nil }
        return try? JSONDecoder().decode(ConsentRecord.self, from: data)
    }

    public func save(_ record: ConsentRecord) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: keyPrefix + record.accountID)
    }
}

extension ConsentStoring {
    /// Whether this person still needs to read the notice — true when they
    /// have never accepted, or accepted wording that has since changed.
    public func needsAcceptance(accountID: String,
                                notice: ConsentNotice = .current) -> Bool {
        record(for: accountID)?.acceptedVersion != notice.version
    }
}
