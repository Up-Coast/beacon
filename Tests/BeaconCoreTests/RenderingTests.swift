// What triage receives has to be found in the same place every time.

import Testing
import Foundation
@testable import BeaconCore

private let index = BeaconIndex(appName: "Harbour", areas: [
    IndexedArea(id: "settings", name: "Settings", paths: ["Sources/Settings"]),
    IndexedArea(id: "projects", name: "Projects", paths: ["Sources/Projects"]),
])

private func report(_ body: ReportBody, impact: Impact = .blocked,
                    area: String? = "settings") -> FeedbackReport {
    FeedbackReport(reporter: Reporter(accountID: "tester@example.com",
                                      displayName: "Sam Tester"),
                   body: body, impact: impact, areaID: area)
}

private let bug = BugBody(
    whatHappened: "The window went white.",
    expected: "It should have saved.",
    steps: ["Open Harbour", "Click Save"],
    reproducibility: .everyTime)

@Suite("Issue rendering")
struct RenderingTests {

    @Test func theFixedHeadingsAreAlwaysThere() {
        let draft = IssueRenderer.render(report(.bug(bug)), index: index)
        #expect(draft.body.contains("## What they expected"))
        #expect(draft.body.contains("## What actually happened"))
        #expect(draft.body.contains("## Steps to see it"))
        #expect(draft.body.contains("## Does it happen again?"))
    }

    @Test func theReportersWordsAreQuotedVerbatim() {
        let draft = IssueRenderer.render(report(.bug(bug)), index: index)
        #expect(draft.body.contains("> The window went white."))
        #expect(draft.body.contains("> It should have saved."))
    }

    @Test func multiLineAnswersStayInsideTheQuote() {
        var multiline = bug
        multiline.whatHappened = "First line.\nSecond line."
        let draft = IssueRenderer.render(report(.bug(multiline)), index: index)
        #expect(draft.body.contains("> First line.\n> Second line."))
    }

    @Test func stepsAreNumberedInOrder() {
        let draft = IssueRenderer.render(report(.bug(bug)), index: index)
        #expect(draft.body.contains("1. Open Harbour"))
        #expect(draft.body.contains("2. Click Save"))
    }

    @Test func labelsCarryKindImpactAndArea() {
        let draft = IssueRenderer.render(report(.bug(bug)), index: index)
        #expect(draft.labels.contains("beacon"))
        #expect(draft.labels.contains("type:bug"))
        #expect(draft.labels.contains("impact:blocked"))
        #expect(draft.labels.contains("area:settings"))
    }

    /// Severity is an engineering judgement made during triage. If the app
    /// ever starts setting it, the two halves of the system stop agreeing
    /// about who decides.
    @Test func severityIsNeverSetByTheApp() {
        let draft = IssueRenderer.render(report(.bug(bug)), index: index)
        #expect(!draft.labels.contains { $0.hasPrefix("severity:") })
    }

    @Test func anUnsureAreaProducesNoAreaLabel() {
        let draft = IssueRenderer.render(
            report(.bug(bug), area: BeaconIndex.unsureAreaID), index: index)
        #expect(!draft.labels.contains { $0.hasPrefix("area:") })
    }

    @Test func theTitleIsPrefixedWithTheArea() {
        var withTitle = report(.bug(bug))
        withTitle.title = "Saving hangs"
        let draft = IssueRenderer.render(withTitle, index: index)
        #expect(draft.title == "[Settings] Saving hangs")
    }

    @Test func aMissingTitleIsDerivedAndNotCutMidWord() {
        var long = bug
        long.whatHappened = String(repeating: "wordy ", count: 40)
        let draft = IssueRenderer.render(report(.bug(long)), index: index)
        #expect(draft.title.hasSuffix("\u{2026}"))
        #expect(draft.title.count < 100)
    }

    @Test func theMetadataBlockIsParseableAndHidden() throws {
        let draft = IssueRenderer.render(report(.bug(bug)), index: index)
        let marker = "<!-- beacon-metadata"
        let start = try #require(draft.body.range(of: marker))
        let end = try #require(draft.body.range(of: "-->", range: start.upperBound..<draft.body.endIndex))
        let json = String(draft.body[start.upperBound..<end.lowerBound])
        let parsed = try #require(
            try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: String])
        #expect(parsed["kind"] == "bug")
        #expect(parsed["impact"] == "blocked")
        #expect(parsed["reproducibility"] == "every-time")
        #expect(parsed["step_count"] == "2")
        #expect(parsed["account"] == "tester@example.com")
    }

    @Test func featureRequestsCarryTheAreasSourcePathsForTriage() {
        let feature = FeatureBody(whatIWant: "Rename a project", why: "I typo names",
                                  areaID: "projects")
        let draft = IssueRenderer.render(report(.feature(feature), area: "projects"),
                                         index: index)
        #expect(draft.body.contains("`Sources/Projects`"))
    }

    @Test func somethingNewIsSaidPlainly() {
        let feature = FeatureBody(whatIWant: "Share a project", isNewArea: true)
        let report = FeedbackReport(reporter: Reporter(accountID: "a@b.c"),
                                    body: .feature(feature),
                                    areaID: BeaconIndex.newAreaID)
        let draft = IssueRenderer.render(report, index: index)
        #expect(draft.body.contains("Something new"))
    }

    @Test func theReportIsMarkedAsNotAnonymous() {
        let draft = IssueRenderer.render(report(.bug(bug)), index: index)
        #expect(draft.body.contains("tester@example.com"))
        #expect(draft.body.contains("agreed to be contacted"))
    }
}
