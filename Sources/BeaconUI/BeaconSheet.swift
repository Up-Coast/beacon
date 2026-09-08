// The sheet the reporter sees, and the steps inside it.
//
// Built out of native controls throughout — a Form, a List, a sheet, a
// file importer. Nothing here hand-rolls navigation or a modal: the flow
// is short enough to be a switch over one step value, and a person in the
// middle of reporting a bug should not have to learn a second app's
// conventions to do it.

import SwiftUI
import BeaconCore
import BeaconDiagnostics

public struct BeaconSheet: View {
    @State private var session: FeedbackSession
    @Environment(\.dismiss) private var dismiss
    #if os(iOS)
    /// On iOS the sheet collapses to a strip while recording, so the
    /// reporter can work the app behind it and come back to press stop.
    @State private var detent: PresentationDetent = .large
    static let recordingDetent = PresentationDetent.height(112)
    #endif

    public init(configuration: BeaconConfiguration) {
        _session = State(initialValue: FeedbackSession(configuration: configuration))
    }

    public var body: some View {
        VStack(spacing: 0) {
            #if os(iOS)
            if session.isRecording {
                RecordingStrip(session: session)
            } else {
                content
                Divider()
                footer
            }
            #else
            content
            Divider()
            footer
            #endif
        }
        // Sized for a Mac sheet. On iOS the sheet owns its own size and a
        // fixed frame would fight the presentation.
        #if os(macOS)
        .frame(minWidth: 560, idealWidth: 620, minHeight: 520, idealHeight: 660)
        #else
        // While recording, the sheet becomes a strip the app stays usable
        // behind — the native way to keep the form alive while the
        // reporter goes and makes the problem happen. It cannot be swiped
        // away mid-recording, which would lose the recording and the form.
        .presentationDetents(session.isRecording ? [Self.recordingDetent] : [.large],
                             selection: $detent)
        .presentationBackgroundInteraction(session.isRecording ? .enabled : .automatic)
        .interactiveDismissDisabled(session.isRecording)
        .onChange(of: session.isRecording) { _, recording in
            detent = recording ? Self.recordingDetent : .large
        }
        #endif
        .overlay { if session.isWorking { WorkingOverlay(message: session.workingMessage) } }
        .onAppear { session.noteShown() }
    }

    @ViewBuilder
    private var content: some View {
        switch session.step {
        case .noReporter: NoReporterView()
        case .consent: ConsentView(session: session)
        case .pickKind: KindPickerView(session: session)
        case .form: FormStepView(session: session)
        case .review: ReviewStepView(session: session)
        case .questions: QuestionsStepView(session: session)
        case .sending: WorkingOverlay(message: "Sending\u{2026}")
        case .done: DoneView(session: session, dismiss: { dismiss() })
        }
    }

    @ViewBuilder
    private var footer: some View {
        HStack {
            switch session.step {
            case .form:
                Button("Back") { session.backToKinds() }
                Spacer()
                Button("Next") { Task { await session.continueToReview() } }
                    .keyboardShortcut(.defaultAction)
            case .review:
                Button("Back") { session.backToForm() }
                Spacer()
                Button(sendButtonTitle) { Task { await session.submit() } }
                    .keyboardShortcut(.defaultAction)
            case .questions:
                Button("Back") { session.backToForm() }
                Spacer()
                Button("Send it") { Task { await session.sendAnyway() } }
                    .keyboardShortcut(.defaultAction)
            case .consent, .pickKind, .noReporter:
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            case .sending, .done:
                EmptyView()
            }
        }
        .padding(16)
    }

    private var sendButtonTitle: String {
        session.reviewAvailability.isAvailable ? "Check and send" : "Send"
    }
}

// MARK: - Steps

struct NoReporterView: View {
    var body: some View {
        StepScaffold(title: "You'll need to be signed in first",
                     subtitle: "Reports aren't anonymous \u{2014} they go out with your "
                        + "account so we can come back to you about them. Sign in "
                        + "and the report button will work.") {
            EmptyView()
        }
    }
}

struct ConsentView: View {
    let session: FeedbackSession

    var body: some View {
        StepScaffold(title: session.notice.headline,
                     subtitle: "You'll only see this once, unless it changes.") {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(session.notice.points.enumerated()), id: \.offset) { _, point in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "circle.fill").font(.system(size: 5))
                            .foregroundStyle(.secondary).padding(.top, 6)
                        Text(point).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Button(session.notice.acceptButton) { session.acceptConsent() }
                    .keyboardShortcut(.defaultAction)
                    .padding(.top, 8)
            }
        }
    }
}

struct KindPickerView: View {
    let session: FeedbackSession

    var body: some View {
        StepScaffold(title: "What would you like to tell us?",
                     subtitle: nil) {
            VStack(spacing: 10) {
                ForEach(FeedbackKind.allCases, id: \.self) { kind in
                    Button { session.choose(kind) } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: icon(kind))
                                .font(.title2).frame(width: 28)
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(kind.title).font(.headline)
                                Text(kind.blurb).font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    func icon(_ kind: FeedbackKind) -> String {
        switch kind {
        case .bug: "ladybug"
        case .featureRequest: "lightbulb"
        case .feedback: "bubble.left.and.text.bubble.right"
        }
    }
}

struct DoneView: View {
    let session: FeedbackSession
    let dismiss: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        StepScaffold(title: session.receipt?.isFiled == true ? "Sent \u{2014} thank you"
                        : "Saved on \(PlatformWording.thisDevice)",
                     subtitle: nil) {
            VStack(alignment: .leading, spacing: 16) {
                Text(session.receipt?.summary ?? "")
                    .fixedSize(horizontal: false, vertical: true)

                LabeledContent("Your reference") {
                    Text(session.draftReport().reference).monospaced().textSelection(.enabled)
                }

                if !session.redactionFindings.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("We removed some things before sending")
                                .font(.headline)
                            Text("These looked like passwords or keys, so they were "
                                + "taken out of your report. Nothing else was changed.")
                                .font(.subheadline).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            ForEach(session.redactionFindings) { finding in
                                Text("\u{2022} \(finding.label) \u{2014} in \(finding.location)")
                                    .font(.callout)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                    }
                }

                HStack {
                    if let url = session.receipt?.url, !url.isFileURL {
                        Button("Open the issue") { openURL(url) }
                    }
                    #if os(macOS)
                    // A folder can be shown in the Finder; iOS has nowhere
                    // to show one, so the button exists only on the Mac.
                    if let url = session.receipt?.url, url.isFileURL {
                        Button("Show the folder") {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                    }
                    #endif
                    Spacer()
                    Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
                }
                .padding(.top, 6)
            }
        }
    }
}

#if os(iOS)
/// What the sheet shows while a recording runs on iOS: one line saying
/// what is happening, stop, and throw away. Everything else waits
/// underneath until the recording ends.
struct RecordingStrip: View {
    let session: FeedbackSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Recording this app's screen. Make it happen, then press stop.",
                  systemImage: "record.circle")
                .font(.subheadline).foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Button {
                    Task { await session.stopRecording() }
                } label: { Label("Stop recording", systemImage: "stop.circle.fill") }
                    .buttonStyle(.borderedProminent).tint(.red)
                Button("Throw it away") { Task { await session.cancelRecording() } }
                    .buttonStyle(.borderless)
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif

// MARK: - Shared furniture

/// Every step is a title, an optional sentence under it, and a scrolling
/// body. Keeping that in one place is what makes the flow feel like one
/// thing rather than five screens somebody wrote on different days.
struct StepScaffold<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.title2).bold()
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        Text(subtitle).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
    }
}

struct WorkingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Rectangle().fill(.regularMaterial)
            VStack(spacing: 12) {
                ProgressView()
                Text(message).foregroundStyle(.secondary)
            }
        }
        .transition(.opacity)
    }
}
