// The one thing a host app fills in.
//
// Everything Beacon needs to know about its host arrives here, and nothing
// arrives any other way. That is what keeps the promise on the tin: Beacon
// has no idea what app it is inside, so the same build drops into any of
// them. Every field that can have a sensible default has one; the four
// that cannot — who the app is, who is reporting, who to name in the
// privacy notice, and where reports go — are required, because guessing
// any of them would produce a report nobody can act on.

import Foundation

/// A folder Beacon may list the shape of. Names and structure only.
public struct FileTreeRoot: Sendable, Equatable {
    /// What this folder is, in the reporter's words.
    public var label: String
    public var url: URL
    /// How deep to walk. Deep enough to see the layout, shallow enough
    /// that a report doesn't become a directory dump.
    public var maximumDepth: Int
    /// A hard stop on how many entries are listed. Hit it and the snapshot
    /// says so instead of pretending it saw everything.
    public var maximumEntries: Int
    /// Folder names skipped wholesale — build output and package caches
    /// say nothing about a bug and drown everything that does.
    public var skippedDirectoryNames: Set<String>

    public init(label: String, url: URL, maximumDepth: Int = 4,
                maximumEntries: Int = 800,
                skippedDirectoryNames: Set<String> = FileTreeRoot.defaultSkips) {
        self.label = label
        self.url = url
        self.maximumDepth = maximumDepth
        self.maximumEntries = maximumEntries
        self.skippedDirectoryNames = skippedDirectoryNames
    }

    public static let defaultSkips: Set<String> = [
        ".git", ".build", "build", "DerivedData", "node_modules", ".venv",
        "venv", "__pycache__", ".next", "dist", "Pods", ".gradle",
        ".swiftpm", "Carthage", ".DS_Store", ".cache",
    ]
}

public struct BeaconConfiguration: Sendable {
    /// Which app and build this is. Without it a report can't be told
    /// apart from one filed against a version fixed three weeks ago.
    public var app: AppIdentity

    /// Named in the privacy notice, so it says who can read the report
    /// rather than "the team".
    public var organizationName: String

    /// Who is reporting. Returns nil when nobody is signed in, and Beacon
    /// then says so and stops — an anonymous report can't be followed up,
    /// and following up is the point.
    public var currentReporter: @Sendable () -> Reporter?

    /// Where reports go.
    public var transport: any ReportTransport

    /// The app map. Nil is allowed and honest: the pickers then offer only
    /// "not sure" and "something new", and the adoption docs say to run
    /// beacon-index.
    public var index: BeaconIndex?

    /// The host's settings, as it wants them described. Anything secret
    /// should be handed in with `isRedacted: true` rather than left out —
    /// knowing a key is set is often the whole answer.
    public var settings: @Sendable () -> [SettingEntry]

    /// Anything else the host wants on the report.
    public var hostNotes: @Sendable () -> [SettingEntry]

    /// Folders whose shape may be listed.
    public var fileTreeRoots: [FileTreeRoot]

    /// Strings the host knows are secret, for the final sweep. Read these
    /// from the keychain at call time rather than holding them.
    public var hostSecrets: @Sendable () -> [String]

    /// How many log lines ride along.
    public var logTailLineCount: Int

    /// Whether the recording button is offered. Off is a legitimate
    /// setting for an app that shows other people's private data.
    public var allowsScreenRecording: Bool

    /// The longest recording Beacon will make. A reporter who forgets to
    /// stop should not produce a 900 MB attachment.
    public var maximumRecordingSeconds: Int

    /// Where consent is remembered.
    public var consentStore: any ConsentStoring

    /// Where reports are kept on disk — always written before sending, so
    /// a failed send never loses someone's work.
    public var reportArchiveDirectory: URL

    public init(app: AppIdentity,
                organizationName: String,
                currentReporter: @escaping @Sendable () -> Reporter?,
                transport: any ReportTransport,
                index: BeaconIndex? = nil,
                settings: @escaping @Sendable () -> [SettingEntry] = { [] },
                hostNotes: @escaping @Sendable () -> [SettingEntry] = { [] },
                fileTreeRoots: [FileTreeRoot] = [],
                hostSecrets: @escaping @Sendable () -> [String] = { [] },
                logTailLineCount: Int = 400,
                allowsScreenRecording: Bool = true,
                maximumRecordingSeconds: Int = 180,
                consentStore: any ConsentStoring = UserDefaultsConsentStore(),
                reportArchiveDirectory: URL? = nil) {
        self.app = app
        self.organizationName = organizationName
        self.currentReporter = currentReporter
        self.transport = transport
        self.index = index
        self.settings = settings
        self.hostNotes = hostNotes
        self.fileTreeRoots = fileTreeRoots
        self.hostSecrets = hostSecrets
        self.logTailLineCount = logTailLineCount
        self.allowsScreenRecording = allowsScreenRecording
        self.maximumRecordingSeconds = maximumRecordingSeconds
        self.consentStore = consentStore
        self.reportArchiveDirectory = reportArchiveDirectory
            ?? BeaconConfiguration.defaultArchiveDirectory(appName: app.name)
    }

    public static func defaultArchiveDirectory(appName: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        return base.appendingPathComponent(appName.isEmpty ? "Beacon" : appName,
                                           isDirectory: true)
            .appendingPathComponent("Beacon/reports", isDirectory: true)
    }

    /// The privacy notice with this host's organisation named in it.
    public var consentNotice: ConsentNotice {
        ConsentNotice.current.naming(organizationName)
    }
}
