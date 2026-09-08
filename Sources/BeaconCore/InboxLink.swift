// The link into the shared inbox — the browser-based way to report.
//
// Some hosts can't file through the native sheet: an iOS build without the
// capture layer, a tester with no GitHub account, a team whose reports are
// picked up by a Claude session watching one shared page rather than by a
// GitHub queue. For those, the app opens the inbox page in a browser with
// everything the machine knows already in the link, so the reporter writes
// only the part only they know. The page lives in `Inbox/index.html` in
// this repository and is published as a Claude artifact; the query keys
// below are the contract between the two, and the page reads exactly
// these names — change one side, change the other.

import Foundation

/// Where the inbox page is and which repository its reports are about.
/// Both are facts about the deployment, so both arrive from the host
/// rather than being written here.
public struct BeaconInbox: Sendable, Equatable {
    /// The published inbox page.
    public var page: URL
    /// `owner/name` of the repository triage works in for this app.
    public var repository: String

    public init(page: URL, repository: String) {
        self.page = page
        self.repository = repository
    }

    /// The query keys the page reads. One list, so a renamed key can't
    /// silently stop arriving.
    public enum Key: String, CaseIterable, Sendable {
        case app, bundle, version, build, commit, repo
        case os, osVersion, device, arch, locale, tz, appearance, textSize
        case reporter, area
    }

    /// The link to open, with the machine's half of the report filled in.
    /// Empty values are left out rather than sent as blanks, so the page
    /// can tell "unknown" from "".
    public func url(for app: AppIdentity,
                    environment: EnvironmentSnapshot,
                    reporter: Reporter? = nil,
                    area: String? = nil) -> URL {
        let pairs: [(Key, String?)] = [
            (.app, app.name), (.bundle, app.bundleIdentifier),
            (.version, app.version), (.build, app.build), (.commit, app.commit),
            (.repo, repository),
            (.os, environment.operatingSystem), (.osVersion, environment.osVersion),
            (.device, environment.deviceModel), (.arch, environment.architecture),
            (.locale, environment.locale), (.tz, environment.timeZone),
            (.appearance, environment.appearance), (.textSize, environment.textSize),
            (.reporter, reporter.map(Self.reporterLabel)),
            (.area, area),
        ]
        var components = URLComponents(url: page, resolvingAgainstBaseURL: false)!
        components.queryItems = (components.queryItems ?? []) + pairs.compactMap { key, value in
            guard let value, !value.isEmpty else { return nil }
            return URLQueryItem(name: key.rawValue, value: value)
        }
        return components.url!
    }

    /// "Sam <sam@example.com>" when there is a name, the account alone
    /// when there isn't — the same form an email header uses.
    static func reporterLabel(_ reporter: Reporter) -> String {
        guard let name = reporter.displayName, !name.isEmpty else { return reporter.accountID }
        return "\(name) <\(reporter.accountID)>"
    }
}
