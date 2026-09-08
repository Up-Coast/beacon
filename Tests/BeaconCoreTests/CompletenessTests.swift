// The gate that decides whether a report can be filed at all.

import Testing
import Foundation
@testable import BeaconCore

private func bugReport(_ bug: BugBody) -> FeedbackReport {
    FeedbackReport(reporter: Reporter(accountID: "tester@example.com"), body: .bug(bug))
}

private let goodBug = BugBody(
    whatHappened: "The window went white and stayed white for a minute.",
    expected: "I expected it to save and go back to the project list.",
    steps: ["Open the project called Harbour", "Click Save in the toolbar"],
    reproducibility: .everyTime)

@Suite("A bug can't be filed without the three things")
struct BugCompletenessTests {

    @Test func aCompleteBugPasses() {
        #expect(CompletenessRules.canSubmit(bugReport(goodBug)))
    }

    @Test func missingExpectedBlocks() {
        var bug = goodBug
        bug.expected = ""
        let issues = CompletenessRules.blocking(bugReport(bug))
        #expect(issues.contains { $0.field == .expected })
        #expect(!CompletenessRules.canSubmit(bugReport(bug)))
    }

    @Test func missingWhatHappenedBlocks() {
        var bug = goodBug
        bug.whatHappened = "   "
        #expect(CompletenessRules.blocking(bugReport(bug)).contains { $0.field == .whatHappened })
    }

    @Test func noStepsBlocks() {
        var bug = goodBug
        bug.steps = ["", "   "]
        #expect(CompletenessRules.blocking(bugReport(bug)).contains { $0.field == .steps })
    }

    /// The point of the placeholder list: these all pass a "field is not
    /// empty" test and tell nobody anything.
    @Test("Filled-in-but-empty answers are refused",
          arguments: ["n/a", "idk", "it broke", "asdf", "?", "TBD", "doesn't work"])
    func placeholdersAreRefused(_ placeholder: String) {
        var bug = goodBug
        bug.expected = placeholder
        #expect(!CompletenessRules.canSubmit(bugReport(bug)),
                "\(placeholder) should not count as an answer")
    }

    @Test func aSingleWordIsTooShort() {
        var bug = goodBug
        bug.whatHappened = "crashed"
        #expect(!CompletenessRules.canSubmit(bugReport(bug)))
    }

    /// "I haven't tried again" is a true answer and must never be blocked —
    /// blocking it only teaches people to pick a different one.
    @Test func notHavingTriedAgainWarnsButDoesNotBlock() {
        var bug = goodBug
        bug.reproducibility = .unknown
        let all = CompletenessRules.check(bugReport(bug))
        #expect(all.contains { $0.field == .reproducibility && !$0.blocking })
        #expect(CompletenessRules.canSubmit(bugReport(bug)))
    }

    @Test func blankStepRowsAreDroppedNotCounted() {
        var bug = goodBug
        bug.steps = ["Open the project called Harbour", "", "  ", "Click Save"]
        #expect(bug.cleanSteps.count == 2)
    }
}

@Suite("Feature requests must land somewhere")
struct FeatureCompletenessTests {

    @Test func mustPickAnAreaOrSayItIsNew() {
        let feature = FeatureBody(whatIWant: "I want to rename a project after making it")
        let report = FeedbackReport(reporter: Reporter(accountID: "a@b.c"), body: .feature(feature))
        #expect(CompletenessRules.blocking(report).contains { $0.field == .area })
    }

    @Test func sayingItIsNewIsAValidAnswer() {
        let feature = FeatureBody(whatIWant: "I want to rename a project after making it",
                                  isNewArea: true)
        let report = FeedbackReport(reporter: Reporter(accountID: "a@b.c"), body: .feature(feature))
        #expect(CompletenessRules.canSubmit(report))
    }

    @Test func theWhyIsAskedForButNotRequired() {
        let feature = FeatureBody(whatIWant: "I want to rename a project after making it",
                                  areaID: "projects")
        let report = FeedbackReport(reporter: Reporter(accountID: "a@b.c"), body: .feature(feature))
        #expect(CompletenessRules.canSubmit(report))
        #expect(CompletenessRules.check(report).contains { $0.field == .why && !$0.blocking })
    }
}
