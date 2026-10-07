// Every sentence a reporter reads that depends on where reports go.
//
// Some apps' testers sign in to GitHub from the sheet, and for them the
// words GitHub and issue are true and useful. Most apps' reporters have no
// GitHub account and should never need to know what happens to a report
// after it leaves: for them it goes to the team, and that is the whole
// story. Both sets of words live here, side by side, so no screen can name
// GitHub while the next one says "the team", and so one test can read
// every team sentence and check that none of them gives the plumbing away.

import Foundation

/// Whether a reporter may be told how a report is filed.
public enum ReportDestination: Sendable, Equatable {
    /// The reporter signs in to GitHub to send, so naming GitHub, issues
    /// and repositories is honest and necessary.
    case gitHub
    /// Everyone else. The report goes to the team; nothing on screen says
    /// how it gets there or what it becomes.
    case team
}

/// A reporter with no account. The app has nobody signed in, or does not
/// want to send who it is, and the report still goes.
extension Reporter {
    /// The prefix every anonymous account id starts with, so anything that
    /// reads a report can tell an anonymous one apart without a new field.
    public static let anonymousPrefix = "anonymous-"

    /// A reporter known only by a random id made for this app on this
    /// device. It carries no name, no email and nothing the device already
    /// knows about the person; it exists so two reports from one install
    /// can be told apart, and so a relay can rate-limit one install.
    public static func anonymous(deviceID: String = AnonymousDeviceID.current()) -> Reporter {
        Reporter(accountID: anonymousPrefix + deviceID)
    }

    /// True for a reporter made with `anonymous(deviceID:)`.
    public var isAnonymous: Bool { accountID.hasPrefix(Self.anonymousPrefix) }
}

/// The random id behind an anonymous reporter: made once, the first time
/// it is asked for, and kept in the app's own defaults. Deleting the app
/// forgets it, which is the point.
public enum AnonymousDeviceID {
    public static let defaultsKey = "beacon.anonymous-device-id"

    public static func current(defaults: UserDefaults = .standard) -> String {
        if let stored = defaults.string(forKey: defaultsKey), !stored.isEmpty { return stored }
        let made = UUID().uuidString.lowercased()
        defaults.set(made, forKey: defaultsKey)
        return made
    }
}

/// The words for one destination.
public struct ReporterWords: Sendable, Equatable {
    public var destination: ReportDestination
    /// Who the report goes to, as the reporter reads it.
    public var teamName: String

    public init(destination: ReportDestination, teamName: String = "the team") {
        self.destination = destination
        self.teamName = teamName
    }

    var isGitHub: Bool { destination == .gitHub }

    // MARK: The review screen

    /// The "From" line, so an anonymous reporter is not shown a random id
    /// as if it were their name.
    public func from(_ reporter: Reporter?) -> String {
        guard let reporter else { return "\u{2014}" }
        return reporter.isAnonymous ? "You, without your name" : reporter.accountID
    }

    /// Whether the sheet asks how to reach the reporter. A GitHub account
    /// already is a way to reach someone; everywhere else it is optional.
    public var asksForContact: Bool { !isGitHub }

    public var contactLabel: String { "How can we reach you? (optional)" }

    public var contactHint: String {
        "An email or a phone number, if you'd like us to be able to ask you about this. "
            + "Leave it empty and your report is sent without one."
    }

    // MARK: After sending

    /// The receipt for a report that reached the team.
    public var sentToTeam: String {
        "Sent to \(teamName). Thank you. If you get in touch about it, quote the reference below."
    }

    /// What a service that delivers reports says when it turns one away
    /// without saying why.
    public var deliveryRefused: String {
        "The report couldn't be delivered just now."
    }

    /// The first sentence of a receipt when the primary way of sending
    /// failed and the report was saved instead.
    public var couldNotReach: String {
        "We couldn't reach \(isGitHub ? "GitHub" : teamName) just now, so your report "
            + "is saved on \(PlatformWording.thisDevice) instead. "
    }

    /// The link the receipt may open. On the team route a filed report is
    /// never linked: the reporter can't open it, and it would show them
    /// where it went. A folder on the device is still shown.
    public func link(for receipt: SubmissionReceipt?) -> URL? {
        guard let url = receipt?.url else { return nil }
        return isGitHub || url.isFileURL ? url : nil
    }

    public var openLinkButton: String { "Open the issue" }

    // MARK: Nobody to send as

    public var noReporterTitle: String { "You'll need to be signed in first" }

    public var noReporterSubtitle: String {
        "Reports go out with your account so we can come back to you about them. "
            + "Sign in and the report button will work."
    }

    // MARK: The privacy notice

    /// The notice this reporter reads, with the organisation named.
    public func notice(for reporter: Reporter?, organizationName: String) -> ConsentNotice {
        let notice: ConsentNotice = switch (destination, reporter?.isAnonymous == true) {
        case (.gitHub, _): .current
        case (.team, false): .team
        case (.team, true): .teamAnonymous
        }
        return notice.naming(organizationName)
    }

    // MARK: For the guard

    /// Every sentence above that a reporter can read, for the test that
    /// checks the team route never names GitHub. Add new sentences here.
    public func everySentence(organizationName: String = "the Harbour team") -> [String] {
        var sentences = [
            from(.anonymous(deviceID: "test")), contactLabel, contactHint, sentToTeam,
            deliveryRefused, couldNotReach, noReporterTitle, noReporterSubtitle,
        ]
        for reporter in [Reporter(accountID: "sam"), Reporter.anonymous(deviceID: "test")] {
            let notice = notice(for: reporter, organizationName: organizationName)
            sentences += [notice.headline, notice.acceptButton] + notice.points
        }
        return sentences
    }
}
