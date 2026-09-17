// Signing a reporter in to GitHub, inside the sheet.
//
// Shown in place of "you'll need to be signed in" when the host is on the
// GitHub route. GitHub's device flow, as GitHub designed it: show a short
// code, send the person to github.com to enter it, wait. The code is copied
// for them as it appears, because on a phone they are about to switch apps
// and typing eight characters from memory is where this goes wrong.

import SwiftUI
import BeaconCore
import BeaconGitHub
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct GitHubSignInView: View {
    let account: GitHubAccount
    let onSignedIn: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var phase: Phase = .ready

    enum Phase: Equatable {
        case ready
        case starting
        case waiting(GitHubDeviceFlow.Challenge)
        case failed(String)
    }

    var body: some View {
        StepScaffold(title: "Sign in to GitHub to send reports",
                     subtitle: "Reports are filed on GitHub under your own account, so the "
                        + "team can reply to you there. You only do this once on "
                        + "\(PlatformWording.thisDevice).") {
            VStack(alignment: .leading, spacing: 16) {
                switch phase {
                case .ready:
                    Button("Sign in with GitHub") { start() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                case .starting:
                    ProgressView("Asking GitHub for a code\u{2026}")
                case .waiting(let challenge):
                    waiting(challenge)
                case .failed(let message):
                    Text(message).fixedSize(horizontal: false, vertical: true)
                    Button("Try again") { start() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    @ViewBuilder
    private func waiting(_ challenge: GitHubDeviceFlow.Challenge) -> some View {
        Text("Enter this code on GitHub. It's already copied, so you can paste it.")
            .fixedSize(horizontal: false, vertical: true)
        Text(challenge.userCode)
            .font(.largeTitle.monospaced()).bold()
            .textSelection(.enabled)
            .accessibilityLabel("Code \(challenge.userCode)")
        HStack(spacing: 12) {
            Button("Open GitHub") { openURL(challenge.verificationURL) }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            Button("Copy the code again") { Self.copy(challenge.userCode) }
                .buttonStyle(.bordered)
        }
        ProgressView("Waiting for GitHub\u{2026}")
            .padding(.top, 4)
    }

    private func start() {
        phase = .starting
        Task {
            do {
                let flow = account.deviceFlow
                let challenge = try await flow.begin()
                Self.copy(challenge.userCode)
                phase = .waiting(challenge)
                let token = try await flow.awaitToken(challenge)
                try await account.connect(token: token)
                onSignedIn()
            } catch {
                phase = .failed((error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription)
            }
        }
    }

    static func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
