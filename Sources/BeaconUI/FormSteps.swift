// The three forms, the attachments block, the review screen and the
// on-device questions.
//
// The bug form is the one with rules. Its three required fields are laid
// out in the order a person actually thinks in — what should have happened,
// what did, and how you get there — and the Next button explains what is
// missing rather than just staying grey. A disabled button with no reason
// is the single most common way a report never gets filed.

import SwiftUI
import UniformTypeIdentifiers
import BeaconCore
#if os(iOS)
import PhotosUI
#endif

struct FormStepView: View {
    @Bindable var session: FeedbackSession

    var body: some View {
        StepScaffold(title: session.kind.title, subtitle: session.kind.blurb) {
            VStack(alignment: .leading, spacing: 20) {
                switch session.kind {
                case .bug: BugFormView(session: session)
                case .featureRequest: FeatureFormView(session: session)
                case .feedback: FeedbackFormView(session: session)
                }

                ImpactPicker(impact: $session.impact)
                AttachmentsView(session: session)

                if !session.blockingIssues.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Before this can go").font(.headline)
                            ForEach(session.blockingIssues) { issue in
                                Text("\u{2022} \(issue.message)")
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                    }
                }
            }
        }
    }
}

// MARK: - Bug

struct BugFormView: View {
    @Bindable var session: FeedbackSession

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FieldBlock(label: "What did you expect to happen?",
                       hint: "This is the one that tells us whether the app is "
                            + "broken or just confusing. Both are worth fixing.") {
                TextEditor(text: $session.bug.expected)
                    .frame(minHeight: 60).textEditorStyle(.plain)
            }

            FieldBlock(label: "What actually happened?",
                       hint: "Say what you saw on screen.") {
                TextEditor(text: $session.bug.whatHappened)
                    .frame(minHeight: 60).textEditorStyle(.plain)
            }

            FieldBlock(label: "What did you do to get there?",
                       hint: "One action per line, starting from where you were.") {
                StepsEditor(steps: $session.bug.steps)
            }

            FieldBlock(label: "Does it happen again?", hint: nil) {
                Picker("", selection: $session.bug.reproducibility) {
                    ForEach(Reproducibility.allCases, id: \.self) {
                        Text($0.question).tag($0)
                    }
                }
                .labelsHidden()
                .exclusiveChoiceStyle()
            }

            AreaPicker(title: "Where in the app did you see it?",
                       index: session.index,
                       selection: $session.areaID,
                       allowsSomethingNew: false)
        }
    }
}

/// The numbered steps. A list that grows as you type in the last row, so
/// nobody has to find an add button — the thing people abandon a form over.
struct StepsEditor: View {
    @Binding var steps: [String]
    @FocusState private var focused: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(steps.indices, id: \.self) { index in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(index + 1).").monospacedDigit()
                        .foregroundStyle(.secondary).frame(width: 22, alignment: .trailing)
                    TextField("", text: binding(index), axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .focused($focused, equals: index)
                    Button {
                        steps.remove(at: index)
                        if steps.isEmpty { steps = [""] }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .disabled(steps.count == 1)
                    .help("Remove this step")
                }
            }
            Button("Add a step") {
                steps.append("")
                focused = steps.count - 1
            }
            // A link-styled button is the Mac's quiet inline action; iOS
            // has no such style and its borderless button is the same idea.
            #if os(macOS)
            .buttonStyle(.link)
            #else
            .buttonStyle(.borderless)
            #endif
        }
    }

    func binding(_ index: Int) -> Binding<String> {
        Binding(get: { index < steps.count ? steps[index] : "" },
                set: { newValue in
                    guard index < steps.count else { return }
                    steps[index] = newValue
                    // Typing in the last row opens the next one.
                    if index == steps.count - 1,
                       !newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                        steps.append("")
                    }
                })
    }
}

// MARK: - Feature

struct FeatureFormView: View {
    @Bindable var session: FeedbackSession

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FieldBlock(label: "What do you want to be able to do?",
                       hint: "Describe the thing you're trying to get done, "
                            + "rather than the button you think it needs.") {
                TextEditor(text: $session.feature.whatIWant)
                    .frame(minHeight: 70).textEditorStyle(.plain)
            }

            FieldBlock(label: "What makes that hard today?",
                       hint: "Knowing this often turns up a better answer than "
                            + "the one you asked for.") {
                TextEditor(text: $session.feature.why)
                    .frame(minHeight: 60).textEditorStyle(.plain)
            }

            AreaPicker(title: "Which part of the app is this about?",
                       index: session.index,
                       selection: $session.feature.areaID,
                       allowsSomethingNew: true,
                       isNewArea: $session.feature.isNewArea)
        }
    }
}

// MARK: - Feedback

struct FeedbackFormView: View {
    @Bindable var session: FeedbackSession

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FieldBlock(label: "What's on your mind?", hint: nil) {
                TextEditor(text: $session.feedback.message)
                    .frame(minHeight: 120).textEditorStyle(.plain)
            }
            AreaPicker(title: "Is this about a particular part of the app?",
                       index: session.index,
                       selection: $session.feedback.areaID,
                       allowsSomethingNew: false)
        }
    }
}

// MARK: - Shared fields

struct FieldBlock<Content: View>: View {
    let label: String
    let hint: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.headline)
            if let hint {
                Text(hint).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.4)))
        }
    }
}

struct ImpactPicker: View {
    @Binding var impact: Impact

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How much is this affecting you?").font(.headline)
            Text("This is what decides the order things get looked at, so an "
                + "honest answer helps more than a dramatic one.")
                .font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Picker("", selection: $impact) {
                ForEach(Impact.allCases, id: \.self) { Text($0.question).tag($0) }
            }
            .labelsHidden()
            .exclusiveChoiceStyle()
        }
    }
}

extension View {
    /// The native shape for a short exclusive list of sentences: a radio
    /// group on the Mac; on iOS, where no radio group exists and an inline
    /// picker outside a Form becomes a wheel, a menu that shows the chosen
    /// answer and opens to the rest.
    func exclusiveChoiceStyle() -> some View {
        #if os(macOS)
        pickerStyle(.radioGroup)
        #else
        pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
        #endif
    }
}

/// The picker the generated app map feeds. Always offers "not sure",
/// because a forced guess produces a confidently wrong label, and a wrong
/// label routes the report to the wrong place.
struct AreaPicker: View {
    let title: String
    let index: BeaconIndex?
    @Binding var selection: String?
    var allowsSomethingNew: Bool
    var isNewArea: Binding<Bool>? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            if let index, !index.reporterAreas.isEmpty {
                Picker("", selection: pickerBinding) {
                    Text("Not sure").tag(BeaconIndex.unsureAreaID)
                    if allowsSomethingNew {
                        Text("Something new \u{2014} the app doesn't do this at all")
                            .tag(BeaconIndex.newAreaID)
                    }
                    Divider()
                    ForEach(index.reporterAreas) { area in
                        Text(area.name).tag(area.id)
                    }
                }
                .labelsHidden()
                if let id = selection, let area = index.area(id: id), let blurb = area.blurb {
                    Text(blurb).font(.subheadline).foregroundStyle(.secondary)
                }
            } else {
                // No map: say so rather than showing an empty picker, and
                // let the report go without one.
                Text("This app hasn't been mapped yet, so there's nothing to "
                    + "pick from. Say where you were in the steps instead \u{2014} "
                    + "that works just as well.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    var pickerBinding: Binding<String> {
        Binding(get: { selection ?? BeaconIndex.unsureAreaID },
                set: { newValue in
                    isNewArea?.wrappedValue = newValue == BeaconIndex.newAreaID
                    selection = newValue == BeaconIndex.newAreaID ? nil : newValue
                })
    }
}

// MARK: - Attachments

struct AttachmentsView: View {
    @Bindable var session: FeedbackSession
    @State private var importing = false
    @State private var problem: String?
    #if os(iOS)
    @State private var picked: [PhotosPickerItem] = []
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Anything to show us?").font(.headline)
            Text("A picture of what you're looking at is usually worth more "
                + "than another paragraph. If you can make the problem happen "
                + "on demand, record it \u{2014} we only record this app's "
                + "\(PlatformWording.appSurface), never anything else on "
                + "\(PlatformWording.yourDevice).")
                .font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Wrapped rather than a fixed row: five buttons don't fit across a
            // phone, and a row that clips its last button hides the one that
            // matters most.
            FlowingButtons {
                Button {
                    Task { problem = await session.takeScreenshot() }
                } label: { Label("Take a screenshot", systemImage: "camera") }

                if session.configuration.allowsScreenRecording {
                    if session.isRecording {
                        Button {
                            Task { await session.stopRecording() }
                        } label: { Label("Stop recording", systemImage: "stop.circle.fill") }
                            .tint(.red)
                        Button("Throw it away") { Task { await session.cancelRecording() } }
                            .buttonStyle(.borderless)
                    } else {
                        Button {
                            Task { problem = await session.startRecording() }
                        } label: { Label("Record what happens", systemImage: "record.circle") }
                    }
                }
                #if os(iOS)
                // Screenshots and recordings taken with the buttons every
                // iOS user knows land in Photos, so that is where to look.
                PhotosPicker(selection: $picked, maxSelectionCount: 6,
                             matching: .any(of: [.images, .videos])) {
                    Label("Choose from Photos", systemImage: "photo.on.rectangle")
                }
                #endif
                Button {
                    importing = true
                } label: { Label("Add a file", systemImage: "paperclip") }
            }
            .buttonStyle(.bordered)

            if session.isRecording {
                Label("Recording this app's \(PlatformWording.appSurface). Go and make "
                    + "it happen, then come back and press stop.", systemImage: "record.circle")
                    .font(.subheadline).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let problem = problem ?? session.recordingProblem {
                Text(problem).font(.subheadline).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(session.attachments) { attachment in
                HStack {
                    Image(systemName: symbol(attachment.kind))
                    Text(attachment.filename).lineLimit(1).truncationMode(.middle)
                    Text(attachment.displaySize).foregroundStyle(.secondary)
                    Spacer()
                    Button { session.remove(attachment) } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.borderless).help("Remove")
                }
                .font(.callout)
            }
        }
        .fileImporter(isPresented: $importing,
                      allowedContentTypes: [.item],
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                problem = nil
                for url in urls {
                    // A file chosen through the importer is reachable only
                    // inside this scope when the app is sandboxed.
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    if let refusal = session.addFile(at: url) { problem = refusal }
                }
            case .failure(let error):
                problem = error.localizedDescription
            }
        }
        #if os(iOS)
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            Task {
                problem = nil
                for item in items {
                    guard let type = item.supportedContentTypes.first,
                          let data = try? await item.loadTransferable(type: Data.self) else {
                        problem = "That item couldn't be read from Photos."
                        continue
                    }
                    if let refusal = await session.addMedia(data, type: type) { problem = refusal }
                }
                picked = []
            }
        }
        #endif
    }

    func symbol(_ kind: AttachmentKind) -> String {
        switch kind {
        case .screenshot, .recordingFrame: "photo"
        case .screenRecording: "video"
        case .userFile: "doc"
        case .diagnostic: "gearshape"
        }
    }
}

// MARK: - Review

struct ReviewStepView: View {
    let session: FeedbackSession
    @State private var showingFullIssue = false

    var body: some View {
        StepScaffold(title: "Here's what we'll send",
                     subtitle: "Read it over. Nothing has left \(PlatformWording.yourDevice) yet.") {
            VStack(alignment: .leading, spacing: 16) {
                LabeledContent("Going to") {
                    Text(session.configuration.transport.destinationDescription)
                }
                LabeledContent("From") {
                    Text(session.reporter?.accountID ?? "\u{2014}")
                }

                if !session.advisoryIssues.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(session.advisoryIssues) { issue in
                                Text(issue.message)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(6)
                    }
                }

                DisclosureGroup("Everything being sent", isExpanded: $showingFullIssue) {
                    ScrollView {
                        Text(session.previewIssue().body)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(height: 260)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.4)))
                }

                Text(reviewLine).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Says plainly whether anything will look this over before it goes.
    /// A reporter on a device without the on-device model is told that, rather
    /// than being left to assume a check happened.
    var reviewLine: String {
        switch session.reviewAvailability {
        case .available:
            "When you press send, \(PlatformWording.thisDevice) reads your report over first and may "
                + "ask you a question or two. That check happens here \u{2014} nothing "
                + "is sent to do it."
        case .unavailable(let why):
            why
        }
    }
}

// MARK: - The on-device questions

struct QuestionsStepView: View {
    @Bindable var session: FeedbackSession

    var body: some View {
        StepScaffold(title: "A couple of things would help",
                     subtitle: "\(PlatformWording.yourDeviceCapitalized) read the report over and thought these were "
                        + "worth asking. Answer what you can \u{2014} or send it as it is.") {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(session.review?.questions ?? []) { question in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(question.question).font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        if !question.reason.isEmpty {
                            Text(question.reason).font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        TextEditor(text: answerBinding(question.field.rawValue))
                            .frame(minHeight: 54).textEditorStyle(.plain)
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 6)
                                .fill(.quaternary.opacity(0.4)))
                    }
                }
                Text("Anything you write here gets added to your report \u{2014} "
                    + "nothing you already wrote is changed or replaced.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    func answerBinding(_ key: String) -> Binding<String> {
        Binding(get: { session.answers[key] ?? "" },
                set: { session.answers[key] = $0 })
    }
}

/// A row of buttons that wraps onto further rows when the width runs out.
/// On the Mac's wide sheet it is one row; on a phone it is two or three.
struct FlowingButtons<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        #if os(macOS)
        HStack(spacing: 8) { content }
        #else
        // A grid of flexible columns is the native way to let a small set
        // of controls share a narrow width without measuring anything.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)],
                  alignment: .leading, spacing: 8) { content }
        #endif
    }
}
