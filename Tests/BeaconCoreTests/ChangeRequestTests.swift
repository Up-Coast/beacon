// Ideas on feature requests, the change request kind, and the first-screen intro line.

import Testing
import Foundation
@testable import BeaconCore

private let index = BeaconIndex(appName: "Harbour", areas: [
    IndexedArea(id: "settings", name: "Settings", paths: ["Sources/Settings"]),
])

private func filed(_ body: ReportBody, area: String? = nil) -> FeedbackReport {
    FeedbackReport(reporter: Reporter(accountID: "a@b.c"), body: body, areaID: area)
}

private let goodChange = ChangeBody(
    whatToChange: "The toolbar icons are hard to tell apart",
    instead: "Use labelled icons with the words underneath")

@Suite("An idea on a feature request")
struct IdeaTests {
    private let want = "I want to rename a project after making it"

    @Test func theIdeaHasItsOwnHeading() {
        let feature = FeatureBody(whatIWant: want, areaID: "settings",
                                  idea: "A rename field in the title bar")
        let body = IssueRenderer.render(filed(.feature(feature), area: "settings"), index: index).body
        #expect(body.contains("## Their idea"))
        #expect(body.contains("> A rename field in the title bar"))
    }

    @Test func noIdeaMeansNoHeading() {
        let feature = FeatureBody(whatIWant: want, areaID: "settings", idea: "  \n")
        let body = IssueRenderer.render(filed(.feature(feature), area: "settings"), index: index).body
        #expect(!body.contains("## Their idea"))
    }

    @Test func theIdeaNeverBlocksASend() {
        let feature = FeatureBody(whatIWant: want, areaID: "settings")
        let report = filed(.feature(feature), area: "settings")
        #expect(CompletenessRules.canSubmit(report))
        #expect(CompletenessRules.check(report).filter { $0.blocking }.isEmpty)
    }

    @Test func aSavedReportWithoutAnIdeaStillDecodes() throws {
        let old = #"{"whatIWant":"x","why":"","isNewArea":false}"#
        let decoded = try JSONDecoder().decode(FeatureBody.self, from: Data(old.utf8))
        #expect(decoded.idea.isEmpty)
    }
}

@Suite("A change request")
struct ChangeRequestTests {

    @Test func theCardIsCalledChangeRequest() {
        #expect(FeedbackKind.changeRequest.title == "Change request")
        #expect(FeedbackKind.allCases.count == 4)
    }

    @Test func bothRequiredFieldsBlock() {
        let blocking = CompletenessRules.blocking(filed(.change(ChangeBody())))
        #expect(Set(blocking.map(\.field)) == [.whatToChange, .instead])
        let onlyFirst = CompletenessRules.blocking(
            filed(.change(ChangeBody(whatToChange: goodChange.whatToChange))))
        #expect(onlyFirst.map(\.field) == [.instead])
        let placeholder = CompletenessRules.blocking(
            filed(.change(ChangeBody(whatToChange: goodChange.whatToChange, instead: "idk"))))
        #expect(placeholder.map(\.field) == [.instead])
    }

    @Test func theOptionalFieldsDoNotBlockOrNag() {
        let report = filed(.change(goodChange))
        #expect(CompletenessRules.check(report).isEmpty)
        #expect(CompletenessRules.canSubmit(report))
    }

    @Test func noAreaIsNeverRequired() {
        #expect(CompletenessRules.canSubmit(filed(.change(goodChange)), offersAreas: true))
        #expect(CompletenessRules.canSubmit(filed(.change(goodChange)), offersAreas: false))
    }

    @Test func itFilesWithItsOwnLabel() {
        let draft = IssueRenderer.render(filed(.change(goodChange)), index: index)
        #expect(draft.labels.contains("type:change-request"))
        #expect(!draft.labels.contains("type:feature-request"))
        #expect(draft.title == "The toolbar icons are hard to tell apart")
    }

    @Test func itRendersEachAnswerUnderItsHeading() {
        var change = goodChange
        change.why = "I use it all day"
        let body = IssueRenderer.render(filed(.change(change), area: "settings"), index: index).body
        #expect(body.contains("## What they would like changed\n\n> The toolbar icons"))
        #expect(body.contains("## What they would like instead\n\n> Use labelled icons"))
        #expect(body.contains("## Why it matters to them\n\n> I use it all day"))
        #expect(body.contains("## Where it is\n\n**Settings**"))
        #expect(body.contains("\"kind\": \"change-request\""))
    }

    @Test func emptyOptionalAnswersLeaveNoHeadings() {
        let body = IssueRenderer.render(filed(.change(goodChange)), index: index).body
        #expect(!body.contains("## Why it matters to them"))
        #expect(!body.contains("## Where it is"))
    }

    @Test func theLabelScriptCreatesEveryKindsLabel() throws {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Scripts/beacon-labels.sh")
        let script = try String(contentsOf: path, encoding: .utf8)
        for kind in FeedbackKind.allCases {
            #expect(script.contains("label \"\(IssueRenderer.Labels.kind(kind))\""))
        }
    }
}

@Suite("The line at the top of the first screen")
struct IntroLineTests {
    private let words = ReporterWords(destination: .team)

    @Test func itNamesTheOrganisation() {
        #expect(words.introLine(organizationName: "Up Coast")
            == "We use Up Coast\u{2019}s free tool Beacon for user feedback and bug reports.")
    }

    @Test func withoutAnOrganisationItStillReadsWell() {
        let expected = "We use the free tool Beacon for user feedback and bug reports."
        #expect(words.introLine(organizationName: "") == expected)
        #expect(words.introLine(organizationName: "  ") == expected)
    }

    @Test func beaconIsTheLink() {
        let text = words.introText(organizationName: "Up Coast")
        let linked = text.runs.filter { $0.link != nil }
        #expect(linked.count == 1)
        #expect(String(text[linked[0].range].characters) == "Beacon")
        #expect(linked[0].link == URL(string: "https://github.com/Up-Coast/beacon"))
    }
}
