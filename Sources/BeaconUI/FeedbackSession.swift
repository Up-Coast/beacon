// The state behind one report, from "something's wrong" to "it's filed".
//
// One object owns the whole session because the steps are not independent:
// what the reporter typed on the form decides what the review screen shows,
// which decides whether the on-device pass has anything to ask, which
// decides whether they see a questions step at all. Splitting that across
// screens is how a flow ends up able to submit an empty report.
//
// The order is fixed and short, because somebody in this flow is already
// annoyed: agree once, pick a kind, fill it in, read what's being sent,
// answer at most three questions, done.

import Foundation
import SwiftUI
import BeaconCore
import BeaconDiagnostics
import BeaconIntelligence
import BeaconCapture
import UniformTypeIdentifiers

@MainActor
@Observable
public final class FeedbackSession {

    public enum Step: Equatable {
        case consent
        case pickKind
        case form
        case review
        /// Only reached when the on-device pass came back with questions.
        case questions
        case sending
        case done
        /// Nobody is signed in, so there is nobody to follow up with.
        case noReporter
    }

    // MARK: What the reporter is doing

    public private(set) var step: Step = .pickKind
    public var kind: FeedbackKind = .bug

    public var bug = BugBody(steps: [""])
    public var feature = FeatureBody()
    public var feedback = FeedbackBody()
    public var title = ""
    public var impact: Impact = .slowed
    public var areaID: String?
    public var attachments: [Attachment] = []

    /// Answers typed into the on-device pass's questions. Appended to the
    /// relevant field rather than replacing it — the reporter's first words
    /// are never overwritten by their second.
    public var answers: [String: String] = [:]

    // MARK: What the machine is doing

    public private(set) var blockingIssues: [CompletenessIssue] = []
    public private(set) var advisoryIssues: [CompletenessIssue] = []
    public private(set) var review: CompletenessReview?
    public private(set) var context: ReportContext?
    public private(set) var redactionFindings: [RedactionFinding] = []
    public private(set) var receipt: SubmissionReceipt?
    public private(set) var failure: String?
    public private(set) var isWorking = false
    public private(set) var workingMessage = ""

    public private(set) var recording: ScreenRecording?
    public var isRecording: Bool { recording != nil }
    /// Stops a recording the reporter forgot about at `maximumRecordingSeconds`.
    private var recordingLimit: Task<Void, Never>?

    // MARK: Wiring

    public let configuration: BeaconConfiguration
    let reviewer: any CompletenessReviewing
    let log: BeaconLog
    let archive: ReportArchive
    /// Set once at the start and kept, so the session's reporter can't
    /// change under it if the host signs somebody else in mid-report.
    public let reporter: Reporter?
    let startedAt = Date()

    public init(configuration: BeaconConfiguration,
                reviewer: any CompletenessReviewing = CompletenessReviewers.standard(),
                log: BeaconLog = .shared) {
        self.configuration = configuration
        self.reviewer = reviewer
        self.log = log
        self.archive = ReportArchive(directory: configuration.reportArchiveDirectory)
        self.reporter = configuration.currentReporter()

        if reporter == nil {
            step = .noReporter
        } else if configuration.consentStore.needsAcceptance(
            accountID: reporter!.accountID, notice: configuration.consentNotice) {
            step = .consent
        } else {
            step = .pickKind
        }
    }

    /// Called once the sheet is on screen. SwiftUI may construct a view's
    /// initial state more than once while deciding what to show; the log
    /// line belongs to the session the reporter actually sees.
    public func noteShown() {
        log.info("feedback session started", category: "beacon")
    }

    public var index: BeaconIndex? { configuration.index }
    public var notice: ConsentNotice { configuration.consentNotice }

    /// Whether the on-device pass can run here, for the line the review
    /// screen shows. Read as state; no model call.
    public var reviewAvailability: ReviewAvailability { reviewer.availability() }

    // MARK: Moving through the steps

    public func acceptConsent() {
        guard let reporter else { return }
        configuration.consentStore.save(ConsentRecord(
            acceptedVersion: notice.version,
            acceptedAt: Date(),
            accountID: reporter.accountID))
        step = .pickKind
    }

    public func choose(_ kind: FeedbackKind) {
        self.kind = kind
        step = .form
    }

    public func backToKinds() {
        step = .pickKind
    }

    /// Leaving the form: check the hard rules, collect the machine's half,
    /// and show the reporter everything that is about to be sent. The
    /// collection happens here rather than at send so the review screen can
    /// show real values instead of promising them.
    public func continueToReview() async {
        blockingIssues = CompletenessRules.blocking(draftReport())
        guard blockingIssues.isEmpty else { return }
        advisoryIssues = CompletenessRules.check(draftReport()).filter { !$0.blocking }

        isWorking = true
        workingMessage = "Collecting what's on \(PlatformWording.thisDevice)\u{2026}"
        context = await ContextCollector(configuration: configuration, log: log).collect()
        isWorking = false
        step = .review
    }

    public func backToForm() {
        step = .form
    }

    /// The send button. Runs the on-device pass first; if it has questions
    /// the reporter sees them, once. Answering is optional either way.
    public func submit() async {
        guard blockingIssues.isEmpty else { step = .form; return }

        if review == nil, reviewAvailability.isAvailable {
            isWorking = true
            workingMessage = "Checking your report on \(PlatformWording.thisDevice)\u{2026}"
            let result = await reviewer.review(draftReport())
            review = result
            isWorking = false
            if !result.questions.isEmpty {
                step = .questions
                return
            }
        }
        await send()
    }

    /// From the questions screen: fold any answers in and send. Available
    /// whether or not they answered anything — the check asks, it never
    /// blocks.
    public func sendAnyway() async {
        applyAnswers()
        await send()
    }

    func applyAnswers() {
        for (key, value) in answers {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let field = ReportField(rawValue: key) else { continue }
            switch field {
            case .whatHappened: bug.whatHappened += "\n\n\(trimmed)"
            case .expected: bug.expected += "\n\n\(trimmed)"
            case .steps: bug.steps.append(trimmed)
            case .whatIWant: feature.whatIWant += "\n\n\(trimmed)"
            case .why: feature.why += "\n\n\(trimmed)"
            case .message: feedback.message += "\n\n\(trimmed)"
            default: break
            }
        }
        answers.removeAll()
    }

    func send() async {
        step = .sending
        isWorking = true
        workingMessage = "Sending\u{2026}"
        failure = nil

        var report = draftReport()
        report.review = review

        // The sweep runs last, over the finished text and every
        // attachment — after this point nothing is added, so nothing can
        // slip past it.
        let redactor = Redactor(hostSecrets: configuration.hostSecrets())
        var findings: [RedactionFinding] = []
        var sweptAttachments: [Attachment] = []
        for attachment in report.attachments {
            let result = redactor.sweep(attachment)
            sweptAttachments.append(result.attachment)
            findings += result.findings
        }
        report.attachments = sweptAttachments

        var draft = IssueRenderer.render(report, index: index, review: review)
        let sweptBody = redactor.sweep(draft.body, location: "your report")
        draft.body = sweptBody.text
        findings += sweptBody.findings
        redactionFindings = findings
        if !findings.isEmpty {
            log.warning("redaction removed \(findings.count) value(s) before sending",
                        category: "beacon")
        }

        let submission = ReportSubmission(report: report, issue: draft,
                                          attachments: report.attachments)

        // Saved before sent, always: the network is the part nobody
        // controls, and losing somebody's ten minutes of writing is not
        // an acceptable failure mode.
        var savedFolder: URL?
        do {
            savedFolder = try archive.save(submission).folder
        } catch {
            log.error("couldn't save the report locally: \(error.localizedDescription)",
                      category: "beacon")
        }

        do {
            receipt = try await configuration.transport.submit(submission)
            log.info("report \(report.reference) filed", category: "beacon")
        } catch {
            let detail = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            failure = detail
            receipt = SubmissionReceipt(
                summary: "\(detail)\n\nYour report is saved on \(PlatformWording.thisDevice)"
                    + (savedFolder.map { " at \(Redactor.redactHome($0.path))" } ?? "")
                    + ", so nothing you wrote is lost.",
                url: savedFolder,
                isFiled: false)
            log.error("report \(report.reference) could not be sent: \(detail)",
                      category: "beacon")
        }

        isWorking = false
        step = .done
    }

    // MARK: The draft

    public func draftReport() -> FeedbackReport {
        let body: ReportBody = switch kind {
        case .bug: .bug(bug)
        case .featureRequest: .feature(feature)
        case .feedback: .feedback(feedback)
        }
        var resolvedArea = areaID
        if kind == .featureRequest {
            resolvedArea = feature.isNewArea ? BeaconIndex.newAreaID : feature.areaID
        }
        return FeedbackReport(
            id: reportID,
            startedAt: startedAt,
            reporter: reporter ?? Reporter(accountID: "unknown"),
            title: title,
            body: body,
            impact: impact,
            areaID: resolvedArea,
            attachments: attachments,
            context: context ?? ReportContext(app: configuration.app),
            consentVersion: notice.version,
            review: review)
    }

    /// Stable for the whole session, so the reference the reporter is shown
    /// is the one on the issue.
    let reportID = UUID()

    /// The rendered issue, for the review screen's "see exactly what's
    /// being sent" — the same renderer that files it, so what they read is
    /// what goes.
    public func previewIssue() -> IssueDraft {
        IssueRenderer.render(draftReport(), index: index, review: review)
    }

    // MARK: Attachments

    public func canAcceptMore(_ additionalBytes: Int) -> Bool {
        attachments.reduce(0, { $0 + $1.byteCount }) + additionalBytes
            <= AcceptedFormats.maximumTotalBytes
    }

    /// Add a file the reporter chose. Refuses what nobody downstream could
    /// read, and says why.
    @discardableResult
    public func addFile(at url: URL) -> String? {
        guard AcceptedFormats.accepts(url) else { return AcceptedFormats.refusal(for: url) }
        guard let data = try? Data(contentsOf: url) else {
            return "That file couldn't be read from disk."
        }
        return admit([Attachment(kind: .userFile, filename: url.lastPathComponent, data: data)])
    }

    /// The one place the size limits are applied, whatever produced the
    /// attachments — a chosen file, a picked photo, a finished recording.
    /// Returns the sentence to show when they don't fit, nil when they do.
    func admit(_ produced: [Attachment]) -> String? {
        if let oversized = produced.first(where: { $0.byteCount > AcceptedFormats.maximumFileBytes }) {
            return "\(oversized.filename) is \(oversized.byteCount / 1024 / 1024) MB, over the "
                + "\(AcceptedFormats.maximumFileBytes / 1024 / 1024) MB limit for one file."
        }
        guard canAcceptMore(produced.reduce(0) { $0 + $1.byteCount }) else {
            return "That would take the report over "
                + "\(AcceptedFormats.maximumTotalBytes / 1024 / 1024) MB in total. "
                + "Removing something else first will make room."
        }
        attachments += produced
        return nil
    }

    public func remove(_ attachment: Attachment) {
        attachments.removeAll { $0.id == attachment.id }
    }

    // MARK: Capture

    public func takeScreenshot() async -> String? {
        do {
            return admit([try await ScreenCapturer().screenshot()])
        } catch {
            log.warning("screenshot failed: \(Self.sentence(for: error))", category: "beacon")
            return Self.sentence(for: error)
        }
    }

    public func startRecording() async -> String? {
        guard configuration.allowsScreenRecording else {
            return "Recording is switched off in this app."
        }
        guard ScreenPermission.ensure() else {
            return CaptureError.permissionDenied.errorDescription
        }
        recordingProblem = nil
        do {
            recording = try await ScreenRecording.start(
                maximumSeconds: configuration.maximumRecordingSeconds)
            // A reporter who forgets to press stop should not produce a
            // 900 MB attachment: the recording stops itself at the limit
            // and what it captured is kept.
            recordingLimit = Task { [weak self, seconds = configuration.maximumRecordingSeconds] in
                try? await Task.sleep(for: .seconds(seconds))
                guard !Task.isCancelled, let self, self.isRecording else { return }
                await self.stopRecording()
            }
            return nil
        } catch {
            return Self.sentence(for: error)
        }
    }

    /// What went wrong with the last recording, kept on the session rather
    /// than on whichever view pressed stop: on iOS that view is the strip
    /// the sheet collapses to, and it is gone by the time the answer comes
    /// back. The attachments block shows it once the form is back.
    public private(set) var recordingProblem: String?

    @discardableResult
    public func stopRecording() async -> String? {
        guard let recording else { return nil }
        self.recording = nil
        recordingLimit?.cancel()
        recordingLimit = nil
        isWorking = true
        workingMessage = "Getting the recording ready\u{2026}"
        defer { isWorking = false }
        do {
            recordingProblem = admit(try await recording.finish())
        } catch {
            recordingProblem = Self.sentence(for: error)
        }
        if let recordingProblem {
            log.warning("recording not attached: \(recordingProblem)", category: "beacon")
        }
        return recordingProblem
    }

    /// The reporter's sentence for a capture failure, and one place that
    /// unwraps the error for it.
    static func sentence(for error: any Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    public func cancelRecording() async {
        guard let recording else { return }
        self.recording = nil
        recordingLimit?.cancel()
        recordingLimit = nil
        await recording.cancel()
    }

    /// Add a picture or video the reporter picked from their library — on
    /// iOS the screenshots and screen recordings people already know how to
    /// take land there.
    public func addMedia(_ data: Data, type: UTType) async -> String? {
        let produced = await PickedMedia.attachments(data: data, type: type)
        guard !produced.isEmpty else {
            return AcceptedFormats.refusal(for: URL(
                fileURLWithPath: "picked." + (type.preferredFilenameExtension ?? "")))
        }
        return admit(produced)
    }
}
