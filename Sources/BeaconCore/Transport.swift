// How a finished report leaves the machine.
//
// Deliberately one small protocol, because this is the decision most
// likely to differ per app and per year. A host that has GitHub access can
// post directly; a host whose testers have no GitHub account posts through
// a relay; a host with neither writes a bundle to disk and hands it over.
// All three are real answers and Beacon ships all three, so adopting it
// never blocks on standing a service up first.

import Foundation

/// Everything the transport needs, already checked, swept and rendered.
public struct ReportSubmission: Sendable, Equatable {
    public var report: FeedbackReport
    public var issue: IssueDraft
    /// The attachments, after the redaction sweep.
    public var attachments: [Attachment]

    public init(report: FeedbackReport, issue: IssueDraft, attachments: [Attachment]) {
        self.report = report
        self.issue = issue
        self.attachments = attachments
    }
}

/// What the reporter is shown afterwards. Every transport returns one,
/// including the ones that didn't reach a network — a person who hit send
/// is owed a specific answer about where their report went.
public struct SubmissionReceipt: Sendable, Equatable {
    /// One sentence: where it went, in plain words.
    public var summary: String
    /// The issue number, when the transport made one.
    public var issueNumber: Int?
    /// A link the reporter can open — the issue, or the folder on disk.
    public var url: URL?
    /// True when the report is filed and nothing more is needed. False
    /// means it is saved but someone still has to carry it the last step,
    /// and `summary` says who and how.
    public var isFiled: Bool

    public init(summary: String, issueNumber: Int? = nil,
                url: URL? = nil, isFiled: Bool = true) {
        self.summary = summary
        self.issueNumber = issueNumber
        self.url = url
        self.isFiled = isFiled
    }
}

public protocol ReportTransport: Sendable {
    /// A name for the review screen, so the reporter can see where this is
    /// about to go before they send it.
    var destinationDescription: String { get }
    func submit(_ submission: ReportSubmission) async throws -> SubmissionReceipt
}

public enum TransportError: Error, LocalizedError, Equatable {
    case notConfigured(String)
    case rejected(status: Int, detail: String)
    case network(String)
    case tooLarge(bytes: Int, limit: Int)

    public var errorDescription: String? {
        switch self {
        case .notConfigured(let detail):
            "This app isn't set up to send reports yet: \(detail)"
        case .rejected(let status, let detail):
            "The report was turned away (\(status)). \(detail)"
        case .network(let detail):
            "The report couldn't be sent: \(detail). It's saved on \(PlatformWording.thisDevice), so nothing is lost."
        case .tooLarge(let bytes, let limit):
            "The report is \(bytes / 1024 / 1024) MB, over the \(limit / 1024 / 1024) MB limit. "
                + "Removing the largest attachment usually does it."
        }
    }
}
