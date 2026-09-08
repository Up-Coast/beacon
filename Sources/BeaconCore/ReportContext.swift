// What the machine collects on its own, so the reporter doesn't have to.
//
// The rule that shapes all of this: Beacon reads *about* the person's files,
// never *inside* them. It lists the shape of a folder — names, nesting,
// sizes, dates — because that is what tells you "the project has no
// settings file" or "there are 4,000 items in here". It never opens one.
// The one exception is a file the reporter deliberately attaches, which is
// their choice, made file by file.

import Foundation

/// The machine's half of a report.
public struct ReportContext: Codable, Sendable, Equatable {
    public var app: AppIdentity
    public var environment: EnvironmentSnapshot
    /// The host app's settings, as the host chose to describe them.
    public var settings: [SettingEntry]
    /// Folder shape — names and structure only.
    public var fileTrees: [FileTreeSnapshot]
    /// The tail of Beacon's own log, newest last.
    public var log: [LogLine]
    /// Anything the host app added for itself through the extra-context
    /// seam — the escape hatch that keeps Beacon from needing to know
    /// anything about its host.
    public var hostNotes: [SettingEntry]

    public init(app: AppIdentity = AppIdentity(),
                environment: EnvironmentSnapshot = EnvironmentSnapshot(),
                settings: [SettingEntry] = [],
                fileTrees: [FileTreeSnapshot] = [],
                log: [LogLine] = [],
                hostNotes: [SettingEntry] = []) {
        self.app = app
        self.environment = environment
        self.settings = settings
        self.fileTrees = fileTrees
        self.log = log
        self.hostNotes = hostNotes
    }
}

/// Which app, which build. Without the build there is no way to tell a
/// fixed bug from a live one, so this is never optional.
public struct AppIdentity: Codable, Sendable, Equatable {
    public var name: String
    public var bundleIdentifier: String
    public var version: String
    public var build: String
    /// The commit the build came from, when the host can supply it. This is
    /// what lets triage check out the exact code the reporter was running.
    public var commit: String?

    public init(name: String = "", bundleIdentifier: String = "",
                version: String = "", build: String = "", commit: String? = nil) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.build = build
        self.commit = commit
    }
}

/// The machine the report came from.
public struct EnvironmentSnapshot: Codable, Sendable, Equatable {
    public var operatingSystem: String
    public var osVersion: String
    public var deviceModel: String
    public var architecture: String
    public var locale: String
    public var timeZone: String
    /// Whether the on-device model could run here — recorded because it
    /// changes what Beacon itself was able to do before submitting.
    public var onDeviceModel: String
    public var memoryGB: Double?
    public var freeDiskGB: Double?
    /// Accessibility and display settings that change what the app looks
    /// like, and therefore change what "it looked wrong" means.
    public var appearance: String?
    public var textSize: String?
    public var reducedMotion: Bool?

    public init(operatingSystem: String = "", osVersion: String = "",
                deviceModel: String = "", architecture: String = "",
                locale: String = "", timeZone: String = "",
                onDeviceModel: String = "unknown",
                memoryGB: Double? = nil, freeDiskGB: Double? = nil,
                appearance: String? = nil, textSize: String? = nil,
                reducedMotion: Bool? = nil) {
        self.operatingSystem = operatingSystem
        self.osVersion = osVersion
        self.deviceModel = deviceModel
        self.architecture = architecture
        self.locale = locale
        self.timeZone = timeZone
        self.onDeviceModel = onDeviceModel
        self.memoryGB = memoryGB
        self.freeDiskGB = freeDiskGB
        self.appearance = appearance
        self.textSize = textSize
        self.reducedMotion = reducedMotion
    }
}

/// One named setting and its value, as the host app describes it. A plain
/// pair rather than a typed model, because Beacon must not need to know what
/// its host's settings are.
public struct SettingEntry: Codable, Sendable, Equatable, Identifiable {
    public var id: String { name }
    public var name: String
    public var value: String
    /// Set when the value is a secret the host wants counted but not shown.
    /// Beacon then records that the setting exists and is set, and nothing
    /// more — "API key: set (not shown)".
    public var isRedacted: Bool

    public init(name: String, value: String, isRedacted: Bool = false) {
        self.name = name
        self.value = isRedacted ? "set (not shown)" : value
        self.isRedacted = isRedacted
    }
}

/// The shape of one folder. Names and structure — never contents.
public struct FileTreeSnapshot: Codable, Sendable, Equatable {
    /// What this folder is, in the host's words ("your project folder").
    public var label: String
    /// The root path, already redacted (home directory becomes `~`).
    public var rootPath: String
    public var entries: [FileTreeEntry]
    /// True when the walk stopped early. A truncated listing that doesn't
    /// say so reads as a complete one, which is worse than no listing.
    public var truncated: Bool
    public var totalEntriesSeen: Int

    public init(label: String, rootPath: String, entries: [FileTreeEntry],
                truncated: Bool = false, totalEntriesSeen: Int = 0) {
        self.label = label
        self.rootPath = rootPath
        self.entries = entries
        self.truncated = truncated
        self.totalEntriesSeen = totalEntriesSeen
    }
}

public struct FileTreeEntry: Codable, Sendable, Equatable {
    /// Path relative to the snapshot root.
    public var path: String
    public var isDirectory: Bool
    /// Size in bytes. Knowing a file is 0 bytes has solved a lot of bugs;
    /// knowing what is inside it has solved none that this wouldn't.
    public var byteCount: Int64?
    public var modifiedAt: Date?

    public init(path: String, isDirectory: Bool,
                byteCount: Int64? = nil, modifiedAt: Date? = nil) {
        self.path = path
        self.isDirectory = isDirectory
        self.byteCount = byteCount
        self.modifiedAt = modifiedAt
    }
}

/// One line of Beacon's own log.
public struct LogLine: Codable, Sendable, Equatable {
    public var at: Date
    public var level: LogLevel
    /// A coarse grouping the host picks — usually the module name, which
    /// is what lets triage line a log line up against the index.
    public var category: String
    public var message: String

    public init(at: Date, level: LogLevel, category: String, message: String) {
        self.at = at
        self.level = level
        self.category = category
        self.message = message
    }
}

public enum LogLevel: String, Codable, Sendable, Comparable, CaseIterable {
    case debug, info, notice, warning, error, fault

    var order: Int {
        switch self {
        case .debug: 0; case .info: 1; case .notice: 2
        case .warning: 3; case .error: 4; case .fault: 5
        }
    }

    public static func < (a: LogLevel, b: LogLevel) -> Bool { a.order < b.order }
}
