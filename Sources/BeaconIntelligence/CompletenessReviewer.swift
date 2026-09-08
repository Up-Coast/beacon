// The check that runs when the reporter hits send.
//
// The deterministic rules in BeaconCore already refused a report with a
// missing field. What they cannot do is read. "It crashed" passes every
// rule and is still useless; steps that stop two screens before the thing
// that broke pass every rule too. That reading is what this does, on the
// reporter's own machine, using Apple's on-device model.
//
// Three rules govern it, and they are the reason it is safe to put a model
// in front of somebody trying to file a bug:
//
//   It never blocks. It asks at most one round of questions, and "send it
//   anyway" is always right there. A model's opinion about prose must not
//   be able to stop a person from reporting something real.
//
//   It never rewrites. Everything the reporter typed is filed word for
//   word. The model produces questions, not text.
//
//   It never leaves the machine. This is Apple's on-device model only —
//   never Private Cloud Compute, never a server. A bug report is somebody's
//   unredacted description of their own work, and it is checked where it
//   was written or not at all. Where there is no on-device model, the pass
//   is honestly absent and the report says so.

import Foundation
import BeaconCore
#if canImport(FoundationModels)
import FoundationModels
#endif

/// The seam. Hosts can hand in their own; tests hand in a scripted one.
public protocol CompletenessReviewing: Sendable {
    /// Whether a review can actually run right now — read as state, with
    /// no model call, so the UI can decide what to show before it commits.
    func availability() -> ReviewAvailability
    func review(_ report: FeedbackReport) async -> CompletenessReview
}

public enum ReviewAvailability: Equatable, Sendable {
    case available
    /// Not available, with a sentence saying why in the reporter's terms.
    case unavailable(String)

    public var isAvailable: Bool { self == .available }
}

/// Used where there is no model at all. It says so rather than passing
/// everything silently, which would look identical to a clean review.
public struct NoReviewer: CompletenessReviewing {
    public init() {}
    public func availability() -> ReviewAvailability {
        .unavailable("This app isn't set up to check reports before sending.")
    }
    public func review(_ report: FeedbackReport) async -> CompletenessReview {
        .notReviewed
    }
}

#if canImport(FoundationModels)

public struct OnDeviceCompletenessReviewer: CompletenessReviewing {

    /// How long the reporter is made to wait. Past this the pass is
    /// abandoned and the report goes as written — waiting on a model is
    /// never allowed to become the reason a report doesn't get filed.
    public var timeout: Duration

    public init(timeout: Duration = .seconds(20)) {
        self.timeout = timeout
    }

    public func availability() -> ReviewAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .unavailable("\(PlatformWording.thisDeviceCapitalized) can't run the on-device check, "
                    + "so your report goes exactly as you wrote it.")
            case .appleIntelligenceNotEnabled:
                return .unavailable("Apple Intelligence is switched off on "
                    + "\(PlatformWording.thisDevice), so nothing checks your report before it goes. "
                    + "You can turn it on in Settings.")
            case .modelNotReady:
                return .unavailable("The on-device model is still downloading. "
                    + "Your report goes exactly as you wrote it.")
            @unknown default:
                return .unavailable("The on-device check isn't available right now.")
            }
        @unknown default:
            return .unavailable("The on-device check isn't available right now.")
        }
    }

    public func review(_ report: FeedbackReport) async -> CompletenessReview {
        guard availability().isAvailable else { return .notReviewed }
        do {
            return try await withThrowingTaskGroup(of: CompletenessReview.self) { group in
                group.addTask { try await runReview(report) }
                group.addTask {
                    try await Task.sleep(for: timeout)
                    return CompletenessReview(readsAsComplete: true, source: .skipped)
                }
                let first = try await group.next() ?? .notReviewed
                group.cancelAll()
                return first
            }
        } catch {
            // Every failure mode ends the same way: the report goes as
            // written. A checker that can block on its own error is worse
            // than no checker.
            return CompletenessReview(readsAsComplete: true, source: .skipped)
        }
    }

    func runReview(_ report: FeedbackReport) async throws -> CompletenessReview {
        let session = LanguageModelSession(instructions: Self.instructions)
        let response = try await session.respond(
            to: Self.prompt(for: report),
            generating: Verdict.self,
            options: GenerationOptions(sampling: .greedy))
        return response.content.asReview()
    }

    // MARK: The prompt

    static let instructions = """
        You read bug reports and feature requests written by ordinary people \
        and decide whether an engineer could act on them without going back \
        to ask a question.

        You are not an editor. Never rewrite, never summarise, never \
        correct spelling. Your only output is a short list of questions to \
        put back to the person who wrote it.

        Ask a question only when the answer would genuinely change what an \
        engineer does first. In particular, ask when:
          - the steps stop before the moment the problem happens, or skip a \
            step somebody unfamiliar with the app could not guess
          - what happened is a judgement ("it broke", "it was wrong") with \
            no description of what was actually on screen
          - what they expected is the same sentence as what happened, so \
            there is no way to tell what the difference was
          - a number, name or place is referred to but never given ("the \
            second project", "that button")

        Do NOT ask when:
          - the answer is already somewhere in the report, including in the \
            attachments list or the app details
          - you are only asking for more detail because more is usually nicer
          - the person has plainly said they do not know

        Ask at most three questions. Ask none at all when the report is \
        good — that is the common case and the right answer. Write each \
        question the way a helpful colleague would say it out loud, in one \
        sentence, addressed to the person directly.
        """

    static func prompt(for report: FeedbackReport) -> String {
        var lines: [String] = ["Here is the report.", ""]
        switch report.body {
        case .bug(let bug):
            lines.append("KIND: bug")
            lines.append("WHAT THEY EXPECTED: \(bug.expected)")
            lines.append("WHAT HAPPENED: \(bug.whatHappened)")
            lines.append("STEPS:")
            for (offset, step) in bug.cleanSteps.enumerated() {
                lines.append("  \(offset + 1). \(step)")
            }
            lines.append("HAPPENS AGAIN: \(bug.reproducibility.question)")
        case .feature(let feature):
            lines.append("KIND: feature request")
            lines.append("WHAT THEY WANT: \(feature.whatIWant)")
            lines.append("WHY: \(feature.why.isEmpty ? "(not said)" : feature.why)")
        case .feedback(let feedback):
            lines.append("KIND: general feedback")
            lines.append("MESSAGE: \(feedback.message)")
        }
        lines.append("HOW MUCH IT AFFECTS THEM: \(report.impact.question)")
        if report.attachments.isEmpty {
            lines.append("ATTACHMENTS: none")
        } else {
            lines.append("ATTACHMENTS: " + report.attachments.map(\.filename)
                .joined(separator: ", "))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: The shape the model must answer in

    @Generable
    struct Verdict {
        @Guide(description: "true when an engineer could start work on this report without asking the reporter anything")
        var readsAsComplete: Bool

        @Guide(description: "questions to put back to the reporter; empty when the report is good", .maximumCount(3))
        var questions: [Question]

        func asReview() -> CompletenessReview {
            let mapped = questions.compactMap { question -> CompletenessQuestion? in
                let text = question.question.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                return CompletenessQuestion(
                    field: ReportField(rawValue: question.field) ?? .whatHappened,
                    question: text,
                    reason: question.reason.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            // The model's own flag is not trusted against its own output:
            // "complete" plus three questions is a contradiction, and the
            // questions are the part with content, so they decide.
            return CompletenessReview(readsAsComplete: mapped.isEmpty,
                                      questions: mapped, source: .onDevice)
        }
    }

    @Generable
    struct Question {
        @Guide(description: "which part of the report the question is about",
               .anyOf(["what-happened", "expected", "steps", "reproducibility",
                       "what-i-want", "why", "area", "attachments", "message"]))
        var field: String

        @Guide(description: "one sentence, addressed to the reporter, asking for the missing thing")
        var question: String

        @Guide(description: "a few words on why it matters, so they can judge whether to bother")
        var reason: String
    }
}

#endif

/// Picks the right reviewer for wherever this is running. Hosts call this
/// rather than choosing, so an app built for a device that can't run the
/// model still behaves correctly.
public enum CompletenessReviewers {
    public static func standard() -> any CompletenessReviewing {
        #if canImport(FoundationModels)
        return OnDeviceCompletenessReviewer()
        #else
        return NoReviewer()
        #endif
    }
}
