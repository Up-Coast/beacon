// What a reporter is actually filing. Three kinds, one envelope.
//
// The envelope (`FeedbackReport`) carries everything that is true of any
// report: who filed it, which app and build, what they attached, and what
// the machine collected. The kind-specific body sits inside it, so every
// later stage — the completeness check, the markdown, the labels, the
// transport — works on one shape.

import Foundation

/// The three things a person can file.
public enum FeedbackKind: String, Codable, Sendable, CaseIterable {
    case bug
    case featureRequest = "feature-request"
    case feedback

    /// The word the reporter sees.
    public var title: String {
        switch self {
        case .bug: "Something's broken"
        case .featureRequest: "Something's missing"
        case .feedback: "Something else"
        }
    }

    /// The sentence under the title on the picker.
    public var blurb: String {
        switch self {
        case .bug: "The app did something you didn't expect, or stopped working."
        case .featureRequest: "You want the app to do something it doesn't do yet."
        case .feedback: "Anything else you want to tell us."
        }
    }
}

/// How much this is costing the person who filed it. The reporter answers
/// this in their own terms — they are not asked to guess at severity, which
/// is an engineering judgement and gets set during triage instead.
public enum Impact: String, Codable, Sendable, CaseIterable {
    case blocked = "blocked"
    case slowed = "slowed"
    case irritating = "irritating"
    case noticed = "noticed"

    /// The answer as the reporter reads it on the form.
    public var question: String {
        switch self {
        case .blocked: "I can't do what I came to do"
        case .slowed: "I found a way around it, but it costs me time"
        case .irritating: "It bothers me, but I can keep working"
        case .noticed: "I noticed it — it doesn't really affect me"
        }
    }

    /// Ordering for triage: 0 is worst.
    public var rank: Int {
        switch self {
        case .blocked: 0
        case .slowed: 1
        case .irritating: 2
        case .noticed: 3
        }
    }
}

/// Set during triage, never by the reporter. Kept here because the label
/// vocabulary has to be one list that both halves of the system agree on.
public enum Severity: String, Codable, Sendable, CaseIterable {
    case critical, high, medium, low
}

/// Who filed it. Beacon reports are not anonymous by design (see
/// `ConsentNotice`) — this is the part that says so in data.
public struct Reporter: Codable, Sendable, Equatable {
    /// The account identifier the host app already knows — an email, a
    /// username, whatever the host uses. Required: an anonymous report
    /// can't be followed up on, and following up is the point.
    public var accountID: String
    /// Shown on the issue so a human reading it knows who to thank.
    public var displayName: String?
    /// Where to reach them, when that isn't the account id itself.
    public var contact: String?

    public init(accountID: String, displayName: String? = nil, contact: String? = nil) {
        self.accountID = accountID
        self.displayName = displayName
        self.contact = contact
    }
}

/// A bug, as the person filing it describes it. All three of the required
/// fields are required for a real reason: without them nobody — human or
/// agent — can tell whether the thing that happened was wrong.
public struct BugBody: Codable, Sendable, Equatable {
    /// What actually happened.
    public var whatHappened: String
    /// What they expected instead. This one does double duty: it is also
    /// how the system finds out where the product is explaining itself
    /// badly (see the expectation-mismatch rule in the triage policy).
    public var expected: String
    /// The steps, in order, that get you there. Blank rows are dropped.
    public var steps: [String]
    /// Whether they can make it happen again on demand. An agent is not
    /// allowed to work on what it cannot reproduce, so this is the single
    /// most valuable answer on the form after the steps themselves.
    public var reproducibility: Reproducibility

    public init(whatHappened: String = "", expected: String = "",
                steps: [String] = [], reproducibility: Reproducibility = .unknown) {
        self.whatHappened = whatHappened
        self.expected = expected
        self.steps = steps
        self.reproducibility = reproducibility
    }

    /// The steps with blank rows dropped and whitespace trimmed — what
    /// actually files, and what a reproduction attempt replays.
    public var cleanSteps: [String] {
        steps.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

public enum Reproducibility: String, Codable, Sendable, CaseIterable {
    case everyTime = "every-time"
    case sometimes
    case once
    case unknown

    public var question: String {
        switch self {
        case .everyTime: "Every time I follow those steps"
        case .sometimes: "Sometimes — it doesn't always happen"
        case .once: "It happened once and I haven't seen it since"
        case .unknown: "I haven't tried to make it happen again"
        }
    }
}

/// A feature request. It either attaches to something that already exists
/// in the app — which is what makes it actionable — or it is honestly
/// marked as something new.
public struct FeatureBody: Codable, Sendable, Equatable {
    /// What they want to be able to do, in their words.
    public var whatIWant: String
    /// Why — the problem behind the request. Optional, but it is what lets
    /// triage propose something better than the literal ask.
    public var why: String
    /// The part of the app this belongs to, chosen from the real index.
    /// Nil means "this is something new" and is a legitimate answer.
    public var areaID: String?
    /// Set when the reporter picked "something new" rather than leaving
    /// the picker untouched — the two are different signals.
    public var isNewArea: Bool

    public init(whatIWant: String = "", why: String = "",
                areaID: String? = nil, isNewArea: Bool = false) {
        self.whatIWant = whatIWant
        self.why = why
        self.areaID = areaID
        self.isNewArea = isNewArea
    }
}

/// Everything else — praise, confusion, a question, a note.
public struct FeedbackBody: Codable, Sendable, Equatable {
    public var message: String
    public var areaID: String?

    public init(message: String = "", areaID: String? = nil) {
        self.message = message
        self.areaID = areaID
    }
}

/// The kind-specific half of a report.
public enum ReportBody: Codable, Sendable, Equatable {
    case bug(BugBody)
    case feature(FeatureBody)
    case feedback(FeedbackBody)

    public var kind: FeedbackKind {
        switch self {
        case .bug: .bug
        case .feature: .featureRequest
        case .feedback: .feedback
        }
    }
}

/// One finished report, ready to be checked, rendered and sent.
public struct FeedbackReport: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    /// When the reporter started the session, not when they hit send —
    /// the gap between the two is itself useful during triage.
    public var startedAt: Date
    public var reporter: Reporter
    /// A one-line summary. Left blank, the renderer derives one.
    public var title: String
    public var body: ReportBody
    public var impact: Impact
    /// The part of the app, from the index. Bugs get this from where they
    /// said they saw it; features from the picker.
    public var areaID: String?
    /// Files the reporter chose to attach, plus anything the capture
    /// surfaces produced (screenshots, recordings).
    public var attachments: [Attachment]
    /// What the machine collected without being asked.
    public var context: ReportContext
    /// The exact consent wording the reporter accepted, recorded with the
    /// report so there is never a question about what they were told.
    public var consentVersion: String
    /// What the on-device pass made of it, when there was one. Recorded so
    /// a report nothing reviewed can be told apart from one that was
    /// reviewed and came back clean.
    public var review: CompletenessReview?

    public init(id: UUID = UUID(),
                startedAt: Date = Date(),
                reporter: Reporter,
                title: String = "",
                body: ReportBody,
                impact: Impact = .slowed,
                areaID: String? = nil,
                attachments: [Attachment] = [],
                context: ReportContext = ReportContext(),
                consentVersion: String = ConsentNotice.current.version,
                review: CompletenessReview? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.reporter = reporter
        self.title = title
        self.body = body
        self.impact = impact
        self.areaID = areaID
        self.attachments = attachments
        self.context = context
        self.consentVersion = consentVersion
        self.review = review
    }

    public var kind: FeedbackKind { body.kind }

    /// A short reference a person can say out loud — it goes in the issue
    /// title and on the confirmation screen so the reporter can find their
    /// own report again.
    public var reference: String {
        "BN-" + id.uuidString.prefix(6).uppercased()
    }
}
