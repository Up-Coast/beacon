// Whether a report is good enough to be worth someone's time.
//
// Two layers, deliberately different in strength:
//
//   The rules below are DETERMINISTIC and they BLOCK. A bug with no
//   expected result, no actual result, or no steps cannot be filed at all,
//   because none of the three can be recovered later — the reporter is the
//   only person who knows them, and by the time anyone notices they're
//   missing the reporter has moved on.
//
//   The on-device pass (BeaconIntelligence) is ADVISORY and it ASKS. It
//   reads what was written and says "these steps stop before the thing you
//   said went wrong". It never blocks: it is a model's opinion about
//   prose, and a reporter who has said everything they know must always be
//   able to send. Where there is no on-device model, this layer is simply
//   absent — the deterministic gate still holds, which is why the hard
//   requirements live there and not here.

import Foundation

/// One thing wrong with a report.
public struct CompletenessIssue: Sendable, Equatable, Identifiable {
    public var id: String { field.rawValue + ":" + message }
    public var field: ReportField
    /// Said to the reporter, in their terms, with what to do about it.
    public var message: String
    public var blocking: Bool

    public init(field: ReportField, message: String, blocking: Bool) {
        self.field = field
        self.message = message
        self.blocking = blocking
    }
}

public enum ReportField: String, Sendable, Equatable, CaseIterable {
    case title
    case whatHappened = "what-happened"
    case expected
    case steps
    case impact
    case area
    case whatIWant = "what-i-want"
    case why
    case message
    case attachments
    case reproducibility
}

/// The deterministic gate. Nothing here needs a model, a network, or a
/// person — which is exactly why the non-negotiable requirements live here.
public enum CompletenessRules {

    /// The shortest a required answer can be and still say anything. Two
    /// words is not a description; this catches "broke" and "idk" without
    /// catching a genuinely terse but real answer.
    public static let minimumMeaningfulCharacters = 12

    /// Answers that are technically filled in and actually empty. Matched
    /// whole, case-insensitively, after trimming punctuation.
    static let placeholders: Set<String> = [
        "n/a", "na", "none", "nothing", "idk", "i don't know", "i dont know",
        "test", "asdf", "asd", "qwerty", "x", "xx", "xxx", "-", "--", ".",
        "?", "??", "todo", "tbd", "see above", "same", "same as above",
        "it broke", "broke", "doesn't work", "does not work", "not working",
        "it doesn't work", "error", "bug", "help",
    ]

    static func isEmptyInSubstance(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        let bare = trimmed.lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?,;:\"' "))
        return placeholders.contains(bare)
    }

    static func tooShort(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).count < minimumMeaningfulCharacters
    }

    /// Everything wrong with this report. An empty result means it can be
    /// filed; anything with `blocking == true` means it cannot.
    public static func check(_ report: FeedbackReport) -> [CompletenessIssue] {
        var issues: [CompletenessIssue] = []

        switch report.body {
        case .bug(let bug):
            issues += checkBug(bug)
        case .feature(let feature):
            issues += checkFeature(feature)
        case .feedback(let feedback):
            if isEmptyInSubstance(feedback.message) || tooShort(feedback.message) {
                issues.append(.init(field: .message,
                    message: "Tell us what's on your mind — a sentence or two is plenty.",
                    blocking: true))
            }
        }

        // Impact is asked of every kind: it is the answer that decides what
        // gets looked at first, and only the reporter can give it.
        // (It is non-optional in the model, so there is nothing to check
        // here beyond kinds that might grow their own rules later.)

        return issues
    }

    static func checkBug(_ bug: BugBody) -> [CompletenessIssue] {
        var issues: [CompletenessIssue] = []

        if isEmptyInSubstance(bug.whatHappened) {
            issues.append(.init(field: .whatHappened,
                message: "Say what actually happened. Even \u{201C}the window "
                    + "went white and stayed white\u{201D} is enough to start from.",
                blocking: true))
        } else if tooShort(bug.whatHappened) {
            issues.append(.init(field: .whatHappened,
                message: "A few more words about what happened would help — "
                    + "what did you see on screen?",
                blocking: true))
        }

        if isEmptyInSubstance(bug.expected) {
            issues.append(.init(field: .expected,
                message: "Say what you expected instead. This is the one that "
                    + "tells us whether the app is broken or just confusing.",
                blocking: true))
        } else if tooShort(bug.expected) {
            issues.append(.init(field: .expected,
                message: "What did you think would happen? A short sentence is fine.",
                blocking: true))
        }

        let steps = bug.cleanSteps
        if steps.isEmpty {
            issues.append(.init(field: .steps,
                message: "Add the steps you took. Start from where you were "
                    + "when you opened the app.",
                blocking: true))
        } else if steps.count == 1 && tooShort(steps[0]) {
            issues.append(.init(field: .steps,
                message: "One short step isn't enough to follow. What did you "
                    + "do just before this, and what did you click?",
                blocking: true))
        } else if steps.allSatisfy({ isEmptyInSubstance($0) }) {
            issues.append(.init(field: .steps,
                message: "The steps need to say what you did — each one an action.",
                blocking: true))
        }

        // Not blocking: a reporter who genuinely hasn't tried again is
        // giving a true answer, and refusing it would only teach them to
        // pick a lie. But it is worth saying out loud what it costs.
        if bug.reproducibility == .unknown {
            issues.append(.init(field: .reproducibility,
                message: "If you can, try it once more. A bug nobody can make "
                    + "happen again can't be worked on \u{2014} so this one answer "
                    + "changes more than any other.",
                blocking: false))
        }

        return issues
    }

    static func checkFeature(_ feature: FeatureBody) -> [CompletenessIssue] {
        var issues: [CompletenessIssue] = []
        if isEmptyInSubstance(feature.whatIWant) || tooShort(feature.whatIWant) {
            issues.append(.init(field: .whatIWant,
                message: "Say what you want to be able to do. Describe it as "
                    + "the thing you're trying to get done, not the button.",
                blocking: true))
        }
        if isEmptyInSubstance(feature.why) {
            issues.append(.init(field: .why,
                message: "What are you trying to do that the app makes hard "
                    + "right now? Knowing this often finds a better answer "
                    + "than the one you asked for.",
                blocking: false))
        }
        if feature.areaID == nil && !feature.isNewArea {
            issues.append(.init(field: .area,
                message: "Pick the part of the app this belongs to \u{2014} or "
                    + "say it's something new. Either answer is fine.",
                blocking: true))
        }
        return issues
    }

    public static func blocking(_ report: FeedbackReport) -> [CompletenessIssue] {
        check(report).filter(\.blocking)
    }

    public static func canSubmit(_ report: FeedbackReport) -> Bool {
        blocking(report).isEmpty
    }
}

// MARK: - The advisory pass

/// One question the on-device pass wants to put back to the reporter.
public struct CompletenessQuestion: Sendable, Equatable, Identifiable, Codable {
    public var id: String { field.rawValue + ":" + question }
    public var field: ReportField
    /// Asked as a question, in the reporter's language.
    public var question: String
    /// Why it is being asked, so the reporter can judge whether it matters.
    public var reason: String

    public init(field: ReportField, question: String, reason: String) {
        self.field = field
        self.question = question
        self.reason = reason
    }

    private enum CodingKeys: String, CodingKey { case field, question, reason }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try c.decode(String.self, forKey: .field)
        field = ReportField(rawValue: raw) ?? .whatHappened
        question = try c.decode(String.self, forKey: .question)
        reason = try c.decodeIfPresent(String.self, forKey: .reason) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(field.rawValue, forKey: .field)
        try c.encode(question, forKey: .question)
        try c.encode(reason, forKey: .reason)
    }
}

/// The result of the advisory pass.
public struct CompletenessReview: Sendable, Equatable, Codable {
    /// The model's read: is there anything worth going back for?
    public var readsAsComplete: Bool
    public var questions: [CompletenessQuestion]
    /// How the review was produced — recorded on the report so that a
    /// thin report can be told apart from one nothing checked.
    public var source: ReviewSource

    public init(readsAsComplete: Bool, questions: [CompletenessQuestion] = [],
                source: ReviewSource) {
        self.readsAsComplete = readsAsComplete
        self.questions = questions
        self.source = source
    }

    public enum ReviewSource: String, Sendable, Codable {
        /// Apple's on-device model looked at it.
        case onDevice = "on-device"
        /// No on-device model here, so nothing beyond the rules ran. The
        /// report says so rather than implying it was reviewed.
        case unavailable
        /// The reporter declined to wait, or the pass errored out.
        case skipped
    }

    public static let notReviewed = CompletenessReview(
        readsAsComplete: true, questions: [], source: .unavailable)
}
