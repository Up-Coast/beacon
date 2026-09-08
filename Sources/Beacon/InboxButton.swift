// The in-app way into the shared inbox, for hosts that report there.

import SwiftUI
import BeaconCore
import BeaconDiagnostics

public extension BeaconInbox {
    /// The link for this host, right now: the configured app identity,
    /// the machine as it is at this moment, and whoever is signed in.
    @MainActor
    func url(area: String? = nil) -> URL {
        let configuration = Beacon.configuration
        return url(for: configuration.app,
                   environment: EnvironmentProbe.snapshot(),
                   reporter: configuration.currentReporter(),
                   area: area)
    }
}

/// A button that opens the inbox page in the system browser, with the
/// machine's half of the report already in the link. Same view on macOS
/// and iOS.
public struct BeaconInboxButton: View {
    @Environment(\.openURL) private var openURL
    var inbox: BeaconInbox
    var title: LocalizedStringKey
    var area: String?

    public init(_ inbox: BeaconInbox, title: LocalizedStringKey = "Report a problem",
                area: String? = nil) {
        self.inbox = inbox
        self.title = title
        self.area = area
    }

    public var body: some View {
        Button {
            openURL(inbox.url(area: area))
        } label: {
            Label(title, systemImage: "exclamationmark.bubble")
        }
    }
}
