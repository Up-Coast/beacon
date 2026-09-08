// The map of the host app, generated from its own source.
//
// This is what turns "which part of the app?" from a text box into a
// picker, and it is why adopting Beacon has an indexing step. Two very
// different readers use the same file: the reporter, who picks the area
// they were in, and the triaging agent, which turns that pick back into a
// set of real paths to go and read. Hand-maintained lists rot; a generated
// one is re-derived from the code on every build.

import Foundation

/// One pickable part of the app.
public struct IndexedArea: Codable, Sendable, Equatable, Identifiable, Hashable {
    /// Stable, lowercase, hyphenated. Written onto reports and used as the
    /// GitHub label, so it must not change when a display name is reworded.
    public var id: String
    /// What the reporter reads on the picker.
    public var name: String
    public var kind: AreaKind
    /// Source paths that make up this area, relative to the repository
    /// root. This is the half triage uses: an issue labelled `area:settings`
    /// tells an agent exactly which directories to open.
    public var paths: [String]
    /// Screens or entry points inside this area, when the indexer found
    /// them — the second level of the picker.
    public var screens: [IndexedScreen]
    /// A sentence explaining the area, when the source carried one.
    public var blurb: String?
    /// Set by a maintainer, not the indexer: areas nobody should be asked
    /// to pick (internal plumbing) stay out of the reporter's list while
    /// remaining available for routing.
    public var hiddenFromReporters: Bool

    public init(id: String, name: String, kind: AreaKind = .module,
                paths: [String] = [], screens: [IndexedScreen] = [],
                blurb: String? = nil, hiddenFromReporters: Bool = false) {
        self.id = id
        self.name = name
        self.kind = kind
        self.paths = paths
        self.screens = screens
        self.blurb = blurb
        self.hiddenFromReporters = hiddenFromReporters
    }
}

public enum AreaKind: String, Codable, Sendable {
    /// A build unit — a SwiftPM target, an Xcode target, a top-level folder.
    case module
    /// A grouping a maintainer declared by hand in the overrides file.
    case feature
}

/// One screen inside an area.
public struct IndexedScreen: Codable, Sendable, Equatable, Identifiable, Hashable {
    public var id: String
    /// The reporter-facing name. The indexer un-camel-cases the type name
    /// and drops a trailing "View", so `ProjectSettingsView` reads as
    /// "Project Settings" — good enough to recognise, and overridable.
    public var name: String
    /// The type it came from, kept so triage can jump straight to it.
    public var symbol: String
    public var path: String

    public init(id: String, name: String, symbol: String, path: String) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.path = path
    }
}

/// The whole map.
public struct BeaconIndex: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1
    /// The filename hosts bundle as a resource, and the indexer writes.
    public static let filename = "BeaconIndex.json"

    public var schemaVersion: Int
    public var generatedAt: Date
    public var appName: String
    /// The commit the index was generated from. When this doesn't match the
    /// build a report came from, triage knows the map may be stale.
    public var commit: String?
    public var areas: [IndexedArea]

    public init(schemaVersion: Int = BeaconIndex.currentSchemaVersion,
                generatedAt: Date = Date(), appName: String = "",
                commit: String? = nil, areas: [IndexedArea] = []) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.appName = appName
        self.commit = commit
        self.areas = areas
    }

    /// The id meaning "it's everywhere, or I don't know where". Always
    /// offered: forcing a guess produces a confidently wrong label, which
    /// is worse for routing than an honest blank.
    public static let unsureAreaID = "not-sure"
    /// The id meaning "this isn't part of anything that exists yet".
    public static let newAreaID = "something-new"

    /// The areas a reporter is actually offered, in reading order.
    public var reporterAreas: [IndexedArea] {
        areas.filter { !$0.hiddenFromReporters }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public func area(id: String) -> IndexedArea? { areas.first { $0.id == id } }

    /// The display name for an area id, including the two sentinels — so
    /// every surface renders a label without special-casing.
    public func displayName(forAreaID id: String?) -> String {
        switch id {
        case nil, "": "Not said"
        case BeaconIndex.unsureAreaID: "Not sure"
        case BeaconIndex.newAreaID: "Something new"
        default: area(id: id!)?.name ?? id!
        }
    }

    // MARK: Loading

    public enum LoadError: Error, LocalizedError {
        case notFound
        case unreadable(String)
        case futureSchema(Int)

        public var errorDescription: String? {
            switch self {
            case .notFound:
                "No app map was found. Run beacon-index over the app's source "
                    + "and bundle the result, or hand areas in through the configuration."
            case .unreadable(let detail):
                "The app map couldn't be read: \(detail)"
            case .futureSchema(let version):
                "The app map is version \(version), which this build of Beacon "
                    + "doesn't understand yet. Regenerate it with the matching beacon-index."
            }
        }
    }

    public static func load(from url: URL) throws -> BeaconIndex {
        guard let data = try? Data(contentsOf: url) else { throw LoadError.notFound }
        return try decode(data)
    }

    public static func decode(_ data: Data) throws -> BeaconIndex {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let index = try decoder.decode(BeaconIndex.self, from: data)
            guard index.schemaVersion <= currentSchemaVersion else {
                throw LoadError.futureSchema(index.schemaVersion)
            }
            return index
        } catch let error as LoadError {
            throw error
        } catch {
            throw LoadError.unreadable(error.localizedDescription)
        }
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Read from a bundle. This is the path a shipped app takes, and the
    /// reason the file has a fixed name.
    public static func loadFromBundle(_ bundle: Bundle) -> BeaconIndex? {
        guard let url = bundle.url(forResource: "BeaconIndex", withExtension: "json")
        else { return nil }
        return try? load(from: url)
    }
}
