import Testing
import Foundation
@testable import BeaconCore
@testable import BeaconIntelligence

@Suite("The advisory pass")
struct ReviewerTests {

    /// Where there is no model, the report must say "nothing checked this"
    /// rather than passing silently — the two look identical otherwise, and
    /// only one of them means the report was read.
    @Test func noReviewerIsHonestRatherThanSilentlyApproving() async {
        let reviewer = NoReviewer()
        #expect(!reviewer.availability().isAvailable)
        let review = await reviewer.review(FeedbackReport(
            reporter: Reporter(accountID: "a@b.c"), body: .feedback(FeedbackBody(message: "hi"))))
        #expect(review.source == .unavailable)
        #expect(review.questions.isEmpty)
    }

    @Test func unavailabilityAlwaysCarriesAReason() {
        guard case .unavailable(let why) = NoReviewer().availability() else {
            Issue.record("expected unavailable"); return
        }
        #expect(!why.isEmpty)
    }

    /// Reading availability must not start a session, so it is safe to call
    /// on every render of the review screen.
    @Test func availabilityIsCheapAndAlwaysAnswerable() {
        let reviewer = CompletenessReviewers.standard()
        _ = reviewer.availability()
        _ = reviewer.availability()
    }

    #if canImport(FoundationModels)
    /// The prompt has to carry the fields the instructions talk about, or
    /// the model is being asked to judge something it cannot see.
    @Test func thePromptCarriesEveryFieldTheInstructionsReferTo() {
        let report = FeedbackReport(
            reporter: Reporter(accountID: "a@b.c"),
            body: .bug(BugBody(whatHappened: "went white", expected: "should save",
                               steps: ["Click Save"], reproducibility: .everyTime)),
            impact: .blocked)
        let prompt = OnDeviceCompletenessReviewer.prompt(for: report)
        #expect(prompt.contains("WHAT THEY EXPECTED: should save"))
        #expect(prompt.contains("WHAT HAPPENED: went white"))
        #expect(prompt.contains("1. Click Save"))
        #expect(prompt.contains("ATTACHMENTS: none"))
    }

    /// A model that says "complete" and then asks three questions is
    /// contradicting itself; the questions are the part with content.
    @Test func questionsOverrideTheModelsOwnCompletenessFlag() {
        let verdict = OnDeviceCompletenessReviewer.Verdict(
            readsAsComplete: true,
            questions: [.init(field: "steps", question: "Which project was it?",
                              reason: "there may be more than one")])
        let review = verdict.asReview()
        #expect(!review.readsAsComplete)
        #expect(review.questions.count == 1)
        #expect(review.source == .onDevice)
    }

    @Test func emptyQuestionsAreDroppedRatherThanShownBlank() {
        let verdict = OnDeviceCompletenessReviewer.Verdict(
            readsAsComplete: false,
            questions: [.init(field: "steps", question: "   ", reason: "")])
        #expect(verdict.asReview().questions.isEmpty)
        #expect(verdict.asReview().readsAsComplete)
    }

    @Test func anUnknownFieldNameFallsBackInsteadOfCrashing() {
        let verdict = OnDeviceCompletenessReviewer.Verdict(
            readsAsComplete: false,
            questions: [.init(field: "not-a-real-field", question: "What happened next?",
                              reason: "")])
        #expect(verdict.asReview().questions.first?.field == .whatHappened)
    }
    #endif
}
