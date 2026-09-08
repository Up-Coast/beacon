// The smallest app Beacon can be walked in.
//
// It exists to be run, not shipped: two screens, a settings page with the
// report button, and a button that writes to the log so a report has
// something in its tail. Reports go to the local bundle transport, so
// nothing leaves the device — the saved folder is printed to the log.

import SwiftUI
import Beacon

@main
struct BeaconExampleApp: App {
    init() {
        Beacon.configure(BeaconConfiguration(
            app: AppIdentity(
                name: "Beacon Example",
                bundleIdentifier: Bundle.main.bundleIdentifier ?? "",
                version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
                build: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""),
            organizationName: "the Beacon example team",
            currentReporter: { Reporter(accountID: "tester@example.com", displayName: "Sam Tester") },
            transport: LocalBundleTransport(folderProvider: { nil }),
            settings: { [SettingEntry(name: "Example setting", value: "on")] }))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .beaconWalkthroughOnFirstRun()
        }
    }
}

struct ContentView: View {
    @State private var count = 0

    var body: some View {
        NavigationStack {
            List {
                Section("Something to report about") {
                    Stepper("Counter: \(count)", value: $count)
                        .onChange(of: count) { _, new in
                            Beacon.log.info("counter changed to \(new)", category: "example")
                        }
                    Button("Do something that logs a warning") {
                        Beacon.log.warning("the example warning fired", category: "example")
                    }
                }
                Section("Report") {
                    BeaconReportButton()
                }
            }
            .navigationTitle("Beacon Example")
        }
    }
}
