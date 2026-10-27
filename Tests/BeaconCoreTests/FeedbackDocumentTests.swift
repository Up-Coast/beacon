// The feedback-document kind: a file is the report, and triage splits it.

import Testing
import Foundation
@testable import BeaconCore

private func document(note: String = "", files: [String] = ["review.docx"]) -> FeedbackReport {
    FeedbackReport(
        reporter: Reporter(accountID: "a@b.c"),
        body: .document(DocumentBody(note: note)),
        attachments: files.map {
            Attachment(kind: .userFile, filename: $0, data: Data("x".utf8))
        })
}

@Suite("A feedback document")
struct FeedbackDocumentTests {

    @Test func theKindHasItsOwnCardAndLabel() {
        #expect(FeedbackKind.feedbackDocument.title == "I have a feedback document")
        #expect(IssueRenderer.Labels.kind(.feedbackDocument) == "type:feedback-document")
    }

    @Test func withoutAFileItCannotBeSent() {
        let report = document(files: [])
        #expect(!CompletenessRules.canSubmit(report))
    }

    @Test func aScreenshotAloneIsNotTheDocument() {
        var report = document(files: [])
        report.attachments = [Attachment(kind: .screenshot, filename: "s.png", data: Data())]
        #expect(!CompletenessRules.canSubmit(report))
    }

    @Test func anAttachedFileIsEnoughAndANoteIsOptional() {
        #expect(CompletenessRules.canSubmit(document()))
    }

    @Test func theIssueSaysToSplitItAndCarriesNoImpact() {
        let draft = IssueRenderer.render(document(note: "From the March beta"), index: nil)
        #expect(draft.labels == ["beacon", "type:feedback-document"])
        #expect(draft.body.contains("## The document"))
        #expect(draft.body.contains("as its own"))
        #expect(draft.body.contains("## Their note"))
        #expect(draft.body.contains("> From the March beta"))
        #expect(draft.body.contains("`review.docx`"))
        #expect(!draft.body.contains("How much this affects them"))
    }

    @Test func noNoteMeansNoNoteHeading() {
        let draft = IssueRenderer.render(document(note: "  "), index: nil)
        #expect(!draft.body.contains("## Their note"))
    }

    @Test func theTitleNamesTheFile() {
        let draft = IssueRenderer.render(document(), index: nil)
        #expect(draft.title == "Feedback document: review.docx")
    }

    @Test func officeFilesAreAccepted() {
        for name in ["a.docx", "a.odt", "a.pptx", "a.xlsx", "a.pdf", "a.md"] {
            #expect(AcceptedFormats.accepts(URL(fileURLWithPath: "/tmp/\(name)")))
        }
        #expect(!AcceptedFormats.accepts(URL(fileURLWithPath: "/tmp/a.key")))
    }

    @Test func aSavedDocumentReportRoundTrips() throws {
        let data = try JSONEncoder().encode(document(note: "n"))
        let back = try JSONDecoder().decode(FeedbackReport.self, from: data)
        #expect(back.kind == .feedbackDocument)
    }
}
