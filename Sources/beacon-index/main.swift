// beacon-index — read an app's source and write the map Beacon's pickers use.
//
// This runs once when a team adopts Beacon, and then in CI on every build,
// because a hand-kept list of "parts of the app" is wrong within a month
// and nobody notices until a reporter picks an area that no longer exists.
//
// What it does, in order:
//   1. Work out the app's build units. SwiftPM targets if there is a
//      Package.swift; otherwise the top-level folders under the source
//      root, which is what an Xcode project looks like from out here.
//   2. Find the screens inside each — SwiftUI views, view controllers, and
//      anything a maintainer marked with a `// beacon:screen` comment.
//   3. Apply the overrides file, so a human can rename, describe, hide, or
//      group anything without editing generated output.
//   4. Write BeaconIndex.json.
//
// Usage:
//   beacon-index --source <dir> --output <file> [--app-name <name>]
//               [--overrides <file>] [--commit <sha>]

import Foundation
import BeaconCore

// MARK: - Arguments

struct Arguments {
    var source = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    var output: URL?
    var appName = ""
    var overrides: URL?
    var commit: String?
    var quiet = false
}

func parseArguments() -> Arguments {
    var arguments = Arguments()
    var iterator = CommandLine.arguments.dropFirst().makeIterator()
    while let flag = iterator.next() {
        switch flag {
        case "--source", "-s":
            if let value = iterator.next() { arguments.source = URL(fileURLWithPath: value) }
        case "--output", "-o":
            if let value = iterator.next() { arguments.output = URL(fileURLWithPath: value) }
        case "--app-name":
            if let value = iterator.next() { arguments.appName = value }
        case "--overrides":
            if let value = iterator.next() { arguments.overrides = URL(fileURLWithPath: value) }
        case "--commit":
            if let value = iterator.next() { arguments.commit = value }
        case "--quiet", "-q":
            arguments.quiet = true
        case "--help", "-h":
            print("""
                beacon-index — build the app map Beacon's pickers read.

                  --source <dir>      where the app's source lives (default: here)
                  --output <file>     where to write BeaconIndex.json
                                      (default: <source>/BeaconIndex.json)
                  --app-name <name>   the app's name, for the map's header
                  --overrides <file>  hand edits: renames, blurbs, hidden areas
                  --commit <sha>      the commit this map describes
                  --quiet             only print the summary line
                """)
            exit(0)
        default:
            FileHandle.standardError.write(Data("beacon-index: unknown option \(flag)\n".utf8))
            exit(2)
        }
    }
    return arguments
}

// MARK: - Overrides

/// The hand-edited half. Generated output is never edited in place — it is
/// regenerated — so anything a person wants to say about an area lives
/// here and is re-applied on every run.
struct Overrides: Codable {
    struct AreaOverride: Codable {
        var name: String?
        var blurb: String?
        var hidden: Bool?
        /// Merge these generated areas into this one, so "the four
        /// networking targets" can be one thing a reporter picks.
        var absorbs: [String]?
    }
    /// Keyed by generated area id.
    var areas: [String: AreaOverride]?
    /// Areas that exist only in the overrides file — a feature that spans
    /// several modules and has no folder of its own.
    var extraAreas: [IndexedArea]?
    /// Folder names to ignore entirely.
    var ignore: [String]?
}

// MARK: - Walking

let ignoredDirectories: Set<String> = [
    ".git", ".build", "build", "DerivedData", "node_modules", ".venv",
    "Pods", "Carthage", ".swiftpm", "vendor", "third_party", "Tests",
    "tests", "__pycache__", ".next", "dist", "out",
]

func swiftFiles(under directory: URL, ignoring extra: Set<String>) -> [URL] {
    let fm = FileManager.default
    var found: [URL] = []
    guard let walker = fm.enumerator(at: directory,
                                     includingPropertiesForKeys: [.isDirectoryKey],
                                     options: [.skipsHiddenFiles]) else { return [] }
    for case let url as URL in walker {
        let name = url.lastPathComponent
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
            if ignoredDirectories.contains(name) || extra.contains(name) {
                walker.skipDescendants()
            }
            continue
        }
        if ["swift", "m", "mm"].contains(url.pathExtension.lowercased()) { found.append(url) }
    }
    return found
}

/// The screens in one file. Three signals, in order of trust:
///
///   an explicit `// beacon:screen Name` comment — a maintainer said so
///   a type declaring `: View` — SwiftUI's own marker
///   a subclass of a view controller — the AppKit/UIKit equivalent
///
/// Nothing here parses Swift properly, and it does not need to: the cost
/// of a false positive is one extra row in a picker that a maintainer can
/// hide in the overrides file, and the cost of missing one is the same row
/// missing. Both are cheap, and a real parser is not.
func screens(in file: URL, relativeTo root: URL) -> [IndexedScreen] {
    guard let text = try? String(contentsOf: file, encoding: .utf8) else { return [] }
    let path = relativePath(file, to: root)
    var found: [IndexedScreen] = []
    var seen = Set<String>()

    func add(symbol: String, name: String) {
        let id = slug(symbol)
        guard !id.isEmpty, seen.insert(id).inserted else { return }
        found.append(IndexedScreen(id: id, name: name, symbol: symbol, path: path))
    }

    for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if let range = trimmed.range(of: "beacon:screen") {
            let label = trimmed[range.upperBound...].trimmingCharacters(in: .whitespaces)
            if !label.isEmpty { add(symbol: label, name: label) }
            continue
        }
        // `// beacon:ignore` on a type's line keeps it out of the map.
        if trimmed.contains("beacon:ignore") { continue }

        guard let symbol = declaredViewType(in: trimmed) else { continue }
        add(symbol: symbol, name: readableName(symbol))
    }
    return found
}

/// The declared type name when this line declares a screen, else nil.
func declaredViewType(in line: String) -> String? {
    let keywords = ["struct ", "final class ", "class ", "public struct ",
                    "public final class ", "public class "]
    guard let keyword = keywords.first(where: { line.hasPrefix($0) }) else { return nil }
    let rest = line.dropFirst(keyword.count)
    guard let colon = rest.firstIndex(of: ":") else { return nil }
    let name = rest[..<colon].trimmingCharacters(in: .whitespaces)
    guard !name.isEmpty, !name.contains(" ") else { return nil }

    let conformances = rest[rest.index(after: colon)...]
    let markers = ["View", "NSViewController", "UIViewController",
                   "NSWindowController", "Scene"]
    let parts = conformances.split(whereSeparator: { ",{ ".contains($0) })
        .map { $0.trimmingCharacters(in: .whitespaces) }
    guard parts.contains(where: { markers.contains($0) }) else { return nil }
    return name
}

/// `ProjectSettingsView` → "Project Settings". Good enough to recognise on
/// a picker, and overridable when it isn't.
///
/// Runs of capitals are kept together, so `GitHubAPIView` reads as
/// "GitHub API" rather than "Git Hub A P I" — the naive split makes every
/// acronym in a codebase look like a typo on the picker.
func readableName(_ symbol: String) -> String {
    var base = symbol
    for suffix in ["ViewController", "WindowController", "View", "Screen", "Scene"]
    where base.hasSuffix(suffix) && base.count > suffix.count {
        base = String(base.dropLast(suffix.count))
        break
    }
    return splitCamelCase(base).joined(separator: " ")
}

/// Split on the two real boundaries: lower-to-upper (`fooBar`) and the end
/// of an acronym run (`APIKey` → `API`, `Key`).
func splitCamelCase(_ text: String) -> [String] {
    let characters = Array(text)
    guard !characters.isEmpty else { return [] }
    var words: [String] = []
    var current = String(characters[0])

    for index in 1..<characters.count {
        let character = characters[index]
        let previous = characters[index - 1]
        let next = index + 1 < characters.count ? characters[index + 1] : nil

        let startsWord =
            (character.isUppercase && !previous.isUppercase) ||
            (character.isUppercase && previous.isUppercase &&
             (next.map { $0.isLowercase } ?? false)) ||
            (character.isNumber && !previous.isNumber) ||
            (!character.isLetter && !character.isNumber)

        if startsWord && !current.isEmpty {
            words.append(current)
            current = ""
        }
        if character.isLetter || character.isNumber { current.append(character) }
    }
    if !current.isEmpty { words.append(current) }
    return words.filter { !$0.isEmpty }
}

func slug(_ text: String) -> String {
    splitCamelCase(text).map { $0.lowercased() }.joined(separator: "-")
}

func relativePath(_ url: URL, to root: URL) -> String {
    let path = url.path
    let base = root.path.hasSuffix("/") ? root.path : root.path + "/"
    return path.hasPrefix(base) ? String(path.dropFirst(base.count)) : path
}

// MARK: - Build units

/// The app's build units, as directories. SwiftPM's layout first, because
/// when it is there it is exactly right; otherwise the top-level folders,
/// which is the best available answer for an Xcode project.
func buildUnits(source: URL, ignoring extra: Set<String>) -> [(name: String, url: URL)] {
    let fm = FileManager.default
    let packageSources = source.appendingPathComponent("Sources", isDirectory: true)
    let root = fm.fileExists(atPath: packageSources.path) ? packageSources : source

    let entries = (try? fm.contentsOfDirectory(
        at: root, includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles])) ?? []

    var units = entries.filter { url in
        guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        else { return false }
        let name = url.lastPathComponent
        return !ignoredDirectories.contains(name) && !extra.contains(name)
    }.map { (name: $0.lastPathComponent, url: $0) }

    // A flat project with sources sitting loose at the root still deserves
    // one area rather than none.
    if units.isEmpty && !swiftFiles(under: root, ignoring: extra).isEmpty {
        units = [(name: source.lastPathComponent, url: root)]
    }
    return units.sorted { $0.name < $1.name }
}

// MARK: - Run

let arguments = parseArguments()
let source = arguments.source.standardizedFileURL

var overrides = Overrides()
if let overridesURL = arguments.overrides,
   let data = try? Data(contentsOf: overridesURL) {
    do {
        overrides = try JSONDecoder().decode(Overrides.self, from: data)
    } catch {
        FileHandle.standardError.write(Data(
            "beacon-index: the overrides file couldn't be read — \(error.localizedDescription)\n".utf8))
        exit(1)
    }
}
let extraIgnores = Set(overrides.ignore ?? [])

var areas: [IndexedArea] = []
for unit in buildUnits(source: source, ignoring: extraIgnores) {
    let files = swiftFiles(under: unit.url, ignoring: extraIgnores)
    guard !files.isEmpty else { continue }
    let found = files.flatMap { screens(in: $0, relativeTo: source) }
        .sorted { $0.name < $1.name }
    areas.append(IndexedArea(
        id: slug(unit.name),
        name: readableName(unit.name),
        kind: .module,
        paths: [relativePath(unit.url, to: source)],
        screens: found))
}

// Absorb first, so a merged area keeps every screen and path it gained.
for (id, override) in overrides.areas ?? [:] {
    guard let absorbs = override.absorbs, !absorbs.isEmpty,
          let target = areas.firstIndex(where: { $0.id == id }) else { continue }
    for absorbedID in absorbs {
        guard let index = areas.firstIndex(where: { $0.id == absorbedID }) else { continue }
        areas[target].paths += areas[index].paths
        areas[target].screens += areas[index].screens
        areas.remove(at: index)
    }
}

areas = areas.map { area in
    guard let override = overrides.areas?[area.id] else { return area }
    var updated = area
    if let name = override.name { updated.name = name }
    if let blurb = override.blurb { updated.blurb = blurb }
    if let hidden = override.hidden { updated.hiddenFromReporters = hidden }
    return updated
}
areas += overrides.extraAreas ?? []
areas.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

let index = BeaconIndex(
    generatedAt: Date(),
    appName: arguments.appName.isEmpty ? source.lastPathComponent : arguments.appName,
    commit: arguments.commit,
    areas: areas)

let output = arguments.output ?? source.appendingPathComponent(BeaconIndex.filename)
do {
    try index.encoded().write(to: output)
} catch {
    FileHandle.standardError.write(Data(
        "beacon-index: couldn't write \(output.path) — \(error.localizedDescription)\n".utf8))
    exit(1)
}

if !arguments.quiet {
    for area in areas {
        print("  \(area.name) (\(area.id)) — \(area.screens.count) screens, "
            + "\(area.paths.count) path\(area.paths.count == 1 ? "" : "s")")
    }
}
print("beacon-index: \(areas.count) areas, "
    + "\(areas.reduce(0) { $0 + $1.screens.count }) screens → \(output.path)")
