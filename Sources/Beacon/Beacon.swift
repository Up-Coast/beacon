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

    /// Call once, at launch, before anything can open the sheet.
    public static func configure(_ configuration: BeaconConfiguration) {
        stored = configuration
        BeaconLog.shared.info(
            "Beacon ready for \(configuration.app.name) \(configuration.app.version) "
            + "(\(configuration.app.build)) \u{2014} reports go to "
            + configuration.transport.destinationDescription,
            category: "beacon")
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
            BeaconSheet(configuration: Beacon.configuration)
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
            .task {
                guard Beacon.isConfigured, !Beacon.hasSeenWalkthrough() else { return }
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
        Button {
            reporting = true
        } label: {
            Label(title, systemImage: "exclamationmark.bubble")
        }
        .beaconReportSheet(isPresented: $reporting)
    }
}
