// The first-run walkthrough.
//
// Testers who have never filed a bug report do two things: they write "it
// doesn't work" and they don't attach anything. Both are fixable, and both
// are fixed by showing somebody once what a good report looks like — which
// is what this is. It is four cards, it takes under a minute, and it can
// always be opened again from wherever the host puts it.
//
// The example on the third card is doing the most work. It shows a weak
// report and a strong one side by side, because "be specific" means
// nothing and "say the window went white instead of saying it broke"
// means something.

import SwiftUI
import BeaconCore

public struct BeaconWalkthrough: View {
    @State private var page = 0
    @Environment(\.dismiss) private var dismiss
    let appName: String
    let allowsRecording: Bool
    /// Called when they finish, so the host can remember not to show it
    /// again. Also called on skip: somebody who skipped it once should not
    /// be shown it every launch.
    let onFinish: () -> Void

    public init(appName: String, allowsRecording: Bool = true,
                onFinish: @escaping () -> Void = {}) {
        self.appName = appName
        self.allowsRecording = allowsRecording
        self.onFinish = onFinish
    }

    public var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    WalkthroughPage(page: page).tag(index)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page)
            #endif

            Divider()
            HStack {
                Button("Skip") { onFinish(); dismiss() }
                Spacer()
                Text("\(page + 1) of \(pages.count)")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if page < pages.count - 1 {
                    Button("Next") { withAnimation { page += 1 } }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Got it") { onFinish(); dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
        }
        #if os(macOS)
        .frame(minWidth: 560, idealWidth: 600, minHeight: 460, idealHeight: 520)
        #endif
    }

    var pages: [WalkthroughContent] {
        var all: [WalkthroughContent] = [
            WalkthroughContent(
                symbol: "ladybug",
                title: "Found something wrong? Tell us from inside \(appName)",
                body: "There's a report button right in the app. It picks up your "
                    + "version, your settings and what the app was doing, so you "
                    + "don't have to describe any of that. You write the part only "
                    + "you know.",
                points: []),

            WalkthroughContent(
                symbol: "list.number",
                title: "Three things make a report fixable",
                body: "You'll be asked for these every time, and you can't send a "
                    + "bug report without them. They're not paperwork \u{2014} they're "
                    + "the difference between a fix today and a conversation next week.",
                points: [
                    "What you expected to happen",
                    "What actually happened instead",
                    "The steps that get you there",
                ]),

            WalkthroughContent(
                symbol: "text.magnifyingglass",
                title: "Be plain, not brief",
                body: "You don't need technical words. You do need specifics \u{2014} "
                    + "here's the same report written both ways.",
                points: [],
                weakExample: "It broke when I tried to save.",
                strongExample: "I clicked Save on a project called Harbour. The "
                    + "spinner ran for about ten seconds, then the window went "
                    + "white and stayed white. I expected it to save and go back "
                    + "to the project list."),
        ]

        var showing = WalkthroughContent(
            symbol: "camera",
            title: "Show us, don't just tell us",
            body: "A picture of what you're looking at beats another paragraph "
                + "nearly every time.",
            points: [
                "Take a screenshot \u{2014} one button, it grabs \(appName)'s \(PlatformWording.appSurface)",
                "Add a file \u{2014} anything text, an image, or a PDF",
            ])
        if allowsRecording {
            showing.points.insert(
                "Record it \u{2014} if you can make it happen on demand, press record, "
                    + "do it, press stop. Only \(appName)'s own \(PlatformWording.appSurface) "
                    + "is recorded, never anything else on \(PlatformWording.yourDevice).", at: 0)
        }
        all.append(showing)
        return all
    }
}

struct WalkthroughContent {
    var symbol: String
    var title: String
    var body: String
    var points: [String]
    var weakExample: String?
    var strongExample: String?
}

struct WalkthroughPage: View {
    let page: WalkthroughContent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: page.symbol)
                    .font(.system(size: 40)).foregroundStyle(.tint)
                Text(page.title).font(.title2).bold()
                    .fixedSize(horizontal: false, vertical: true)
                Text(page.body).fixedSize(horizontal: false, vertical: true)

                ForEach(Array(page.points.enumerated()), id: \.offset) { _, point in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "checkmark").foregroundStyle(.tint)
                        Text(point).fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let weak = page.weakExample, let strong = page.strongExample {
                    VStack(alignment: .leading, spacing: 10) {
                        ExampleBox(label: "Hard to act on", text: weak,
                                   symbol: "xmark.circle", tint: .secondary)
                        ExampleBox(label: "Fixable", text: strong,
                                   symbol: "checkmark.circle", tint: .green)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(28)
        }
    }
}

struct ExampleBox: View {
    let label: String
    let text: String
    let symbol: String
    let tint: Color

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Label(label, systemImage: symbol)
                    .font(.caption).foregroundStyle(tint)
                Text(text).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        }
    }
}
