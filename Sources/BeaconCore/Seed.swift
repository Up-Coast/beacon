// Starting the app with data already in it.
//
// This exists for one job: letting a machine that is not the founder's Mac
// reproduce a bug. A reproduction is worthless against an empty app —
// almost every real report starts "I opened the project called Harbour" —
// so the reproducing machine has to be able to start the app with a known
// set of data in place.
//
// The mechanism is deliberately dumb, because it has to work in a CI job
// with no UI and no person: an environment variable names a folder, and at
// launch the app copies that folder over its own data directory. Nothing
// is inferred and nothing is downloaded.
//
// It is also gated hard. Seeding replaces real data, so it refuses to run
// unless BOTH the variable is set AND the host passed a directory that is
// not the one it ships to people. A seed that fires on a customer's Mac
// would be the worst bug this whole system could have.

import Foundation

public enum BeaconSeed {

    /// Set to the path of a folder to copy in at launch.
    public static let directoryVariable = "BEACON_SEED_DIRECTORY"
    /// Must be `1` as well. Two switches, because one environment variable
    /// is one typo away from wiping somebody's data.
    public static let enableVariable = "BEACON_SEED_ENABLE"

    public struct Result: Sendable, Equatable {
        public var applied: Bool
        /// Said out loud in the log either way, so a reproduction run's
        /// output shows whether it started from the data it meant to.
        public var explanation: String
    }

    /// Copy the seed folder over `destination`, when asked to.
    ///
    /// `destination` is the host's own data directory — it is passed in
    /// rather than guessed, because this function is not allowed to decide
    /// what to overwrite.
    @discardableResult
    public static func applyIfRequested(
        into destination: URL,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default) -> Result {

        guard let seedPath = environment[directoryVariable], !seedPath.isEmpty else {
            return Result(applied: false, explanation: "No seed asked for; starting with real data.")
        }
        guard environment[enableVariable] == "1" else {
            return Result(applied: false,
                          explanation: "A seed folder was named but \(enableVariable) is not 1, "
                            + "so nothing was replaced. Both are required.")
        }
        let seed = URL(fileURLWithPath: seedPath)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: seed.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return Result(applied: false,
                          explanation: "The seed folder \(seed.path) isn't there, so nothing was replaced.")
        }

        do {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
            try fileManager.copyItem(at: seed, to: destination)
            return Result(applied: true,
                          explanation: "Started from the seed at \(seed.path).")
        } catch {
            return Result(applied: false,
                          explanation: "The seed couldn't be copied in (\(error.localizedDescription)); "
                            + "the run is NOT starting from the data it meant to.")
        }
    }

    /// Whether this process was started as a reproduction run. Hosts use it
    /// to skip onboarding, sign-in walls and anything else that would stop
    /// an unattended run before it reached the steps.
    public static func isReproductionRun(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        environment[enableVariable] == "1"
    }
}
