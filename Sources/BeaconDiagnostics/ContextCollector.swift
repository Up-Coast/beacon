// Assembling the machine's half of a report.
//
// Runs off the main actor because the folder walk can take a moment on a
// large project, and a reporting tool that beachballs the app it is
// reporting on has already lost the argument.

import Foundation
import BeaconCore

public struct ContextCollector: Sendable {
    let configuration: BeaconConfiguration
    let log: BeaconLog

    public init(configuration: BeaconConfiguration, log: BeaconLog = .shared) {
        self.configuration = configuration
        self.log = log
    }

    public func collect() async -> ReportContext {
        let settings = configuration.settings()
        let hostNotes = configuration.hostNotes()
        let logTail = log.tail(configuration.logTailLineCount)
        let roots = configuration.fileTreeRoots
        let app = configuration.app

        let trees: [FileTreeSnapshot] = await Task.detached(priority: .userInitiated) {
            roots.map(FileTreeScanner.scan)
        }.value

        let environment = await MainActor.run { EnvironmentProbe.snapshot() }
        return ReportContext(
            app: app,
            environment: environment,
            settings: settings,
            fileTrees: trees,
            log: logTail,
            hostNotes: hostNotes)
    }
}
