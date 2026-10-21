// The whole public surface a host app touches.
//
// Adopting Beacon is meant to be three things: configure it once at launch,
// put a button somewhere, and run the indexer in your build. Everything
// else in this package is reachable, but nothing else is required — and
// that constraint is the product. A reporting system people have to
// integrate carefully is a reporting system that doesn't get integrated.

import SwiftUI
import BeaconCore
import BeaconDiagnostics
import BeaconGitHub
import BeaconUI

// One import in the host: the types the configuration call needs — the
// report values, the log, and the transports — all arrive with `Beacon`.
@_exported import BeaconCore
@_exported import BeaconDiagnostics
@_exported import BeaconGitHub

@MainActor
public enum Beacon {

    private static var stored: BeaconConfiguration?

    /// The account reporters sign in to from inside the sheet, on the
    /// GitHub route.
    public private(set) static var gitHubAccount: GitHubAccount?

    /// Call once, at launch, before anything can open the sheet.
    ///
    /// - Parameters:
    ///   - gitHubAccount: pass one when reports go to GitHub as whoever is
    ///     signed in, and the sheet offers GitHub sign-in to anyone who
    ///     isn't yet. Leave it out when the host signs people in itself.
    ///   - audience: who is offered the report button and the walkthrough.
    ///     `.testBuilds` keeps both out of App Store builds.
    public static func configure(_ configuration: BeaconConfiguration,
                                 gitHubAccount: GitHubAccount? = nil,
                                 audience: BeaconAudience = .everyone) {
        stored = configuration
        self.gitHubAccount = gitHubAccount
        BeaconLog.shared.info(
            "Beacon ready for \(configuration.app.name) \(configuration.app.version) "
            + "(\(configuration.app.build)) \u{2014} reports go to "
            + configuration.transport.destinationDescription,
            category: "beacon")
        if let gitHubAccount, !gitHubAccount.canKeepASignIn {
            BeaconLog.shared.warning(
                "this build cannot keep a GitHub sign-in, so nobody can report from it: "
                + GitHubTokenStore.explain(gitHubAccount.keychainStatus),
                category: "beacon")
        }
        Task {
            await BeaconAvailability.shared.resolve(for: audience)
            if isOffered && configuration.showsFloatingButton {
                FloatingReportButton.shared.show()
            } else {
                FloatingReportButton.shared.hide()
            }
        }
    }

    /// Whether this build offers reporting at all. Views that read it are
    /// redrawn when it's settled, which on `.testBuilds` takes a moment at
    /// launch. False until then, so nothing flashes up in an App Store
    /// build.
    public static var isOffered: Bool {
        isConfigured && BeaconAvailability.shared.isOffered
    }

    /// The live configuration. Reaching this before `configure` is a
    /// programming mistake in the host, and it fails loudly here rather
    /// than showing an empty sheet at the moment somebody needed it.
    public static var configuration: BeaconConfiguration {
        guard let stored else {
            preconditionFailure(
                "Beacon.configure(_:) has not been called. Call it at launch, "
                + "before any view can present the report sheet.")
        }
        return stored
    }

    public static var isConfigured: Bool { stored != nil }

    /// Sends `fields` privately: swept for secrets, sealed on this device to
    /// the owner's public key, and stored away from GitHub, where only the
    /// owner can read them. Use it for details the app sends on its own that
    /// must never become an issue. Returns the message's id, which a public
    /// report may cite; pass your own `id` (a UUID) to make a retry land on
    /// the same message instead of a second one.
    ///
    /// Throws `PrivateDelivery.Failure.notEnabled` unless the app turned
    /// private delivery on, and `.notConsented` until the person accepted the
    /// notice that says this happens (when that is what covers it). Nothing
    /// leaves the device in either case.
    @discardableResult
    public static func sendPrivately(_ fields: [String: String],
                                     id: String = UUID().uuidString) async throws -> String {
        let configuration = configuration
        guard let delivery = configuration.privateDelivery else { throw PrivateDelivery.Failure.notEnabled }
        guard let uuid = UUID(uuidString: id) else { throw PrivateDelivery.Failure.invalidID }
        let id = uuid.uuidString.lowercased()
        let noticeVersion = try configuration.privateDeliveryNoticeVersion()
        let details = try delivery.details(
            id: id, fields: fields, app: configuration.app, hostSecrets: configuration.hostSecrets(),
            noticeVersion: noticeVersion)
        let sealed = try PrivateSealing.seal(details, to: delivery.ownerPublicKey)
        try await delivery.send(sealed, id: id, app: configuration.app.bundleIdentifier)
        BeaconLog.shared.info("sent details privately (\(details.fields.count) fields)", category: "beacon")
        return id
    }

    /// The log the host writes to. Its last few hundred lines ride on
    /// every report automatically.
    public nonisolated static var log: BeaconLog { .shared }

    /// Whether this person has been shown the walkthrough.
    public static func hasSeenWalkthrough(
        defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: walkthroughKey)
    }

    public static func markWalkthroughSeen(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: walkthroughKey)
    }

    static let walkthroughKey = "beacon.walkthrough.seen"
}

// MARK: - What a host puts in its views

public extension View {
    /// Present the report flow.
    ///
    ///     .beaconReportSheet(isPresented: $reporting)
    func beaconReportSheet(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            BeaconSheet(configuration: Beacon.configuration,
                        gitHubAccount: Beacon.gitHubAccount)
        }
    }

    /// Present the walkthrough, and remember that it was shown.
    func beaconWalkthroughSheet(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            BeaconWalkthrough(appName: Beacon.configuration.app.name,
                             allowsRecording: Beacon.configuration.allowsScreenRecording) {
                Beacon.markWalkthroughSeen()
            }
        }
    }

    /// Show the walkthrough once, the first time this view appears. Put it
    /// on the app's main view and new testers get shown how to report
    /// before they need to.
    func beaconWalkthroughOnFirstRun() -> some View {
        modifier(FirstRunWalkthrough())
    }
}

struct FirstRunWalkthrough: ViewModifier {
    @State private var showing = false

    func body(content: Content) -> some View {
        content
            .beaconWalkthroughSheet(isPresented: $showing)
            // Keyed on availability, so a test build that settles after
            // this view appears still shows the walkthrough once.
            .task(id: Beacon.isOffered) {
                guard Beacon.isOffered, !Beacon.hasSeenWalkthrough() else { return }
                showing = true
            }
    }
}

/// A ready-made button, for hosts that just want one somewhere.
public struct BeaconReportButton: View {
    @State private var reporting = false
    var title: String

    public init(title: String = "Report a problem") {
        self.title = title
    }

    public var body: some View {
        if Beacon.isOffered {
            Button {
                reporting = true
            } label: {
                Label { Text(title) } icon: { BeaconMark() }
            }
            .beaconReportSheet(isPresented: $reporting)
        }
    }
}
