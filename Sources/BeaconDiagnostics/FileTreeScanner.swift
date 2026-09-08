// Listing the shape of a folder without opening anything in it.
//
// This is the collection step people are most right to be nervous about,
// so the rule is drawn tight and enforced in code rather than promised in
// a document: this file calls `contentsOfDirectory` and `resourceValues`,
// and never once opens a file handle. It cannot read a file's contents
// because it never asks for them.
//
// Bounded three ways — depth, entry count, and a skip list — because an
// unbounded walk over a developer's home folder is both a privacy problem
// and a twenty-minute hang.

import Foundation
import BeaconCore

public enum FileTreeScanner {

    public static func scan(_ root: FileTreeRoot) -> FileTreeSnapshot {
        let fm = FileManager.default
        var entries: [FileTreeEntry] = []
        var seen = 0
        var truncated = false

        // Breadth-first, so hitting the entry limit leaves a wide shallow
        // picture rather than one very deep branch. Shape is what this is
        // for, and shape reads better wide.
        var queue: [(url: URL, depth: Int)] = [(root.url, 0)]
        while !queue.isEmpty {
            let (directory, depth) = queue.removeFirst()
            guard depth <= root.maximumDepth else { continue }

            let contents = (try? fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey,
                                             .contentModificationDateKey],
                options: [])) ?? []

            for url in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                seen += 1
                if entries.count >= root.maximumEntries {
                    truncated = true
                    continue
                }
                let values = try? url.resourceValues(forKeys: [
                    .isDirectoryKey, .fileSizeKey, .contentModificationDateKey,
                ])
                let isDirectory = values?.isDirectory ?? false
                let name = url.lastPathComponent

                if isDirectory && root.skippedDirectoryNames.contains(name) {
                    entries.append(FileTreeEntry(
                        path: relative(url, to: root.url) + " (skipped)",
                        isDirectory: true))
                    continue
                }

                entries.append(FileTreeEntry(
                    path: relative(url, to: root.url),
                    isDirectory: isDirectory,
                    byteCount: isDirectory ? nil : values?.fileSize.map(Int64.init),
                    modifiedAt: values?.contentModificationDate))

                if isDirectory && depth < root.maximumDepth {
                    queue.append((url, depth + 1))
                }
            }
        }

        return FileTreeSnapshot(
            label: root.label,
            rootPath: Redactor.redactHome(root.url.path),
            entries: entries.sorted { $0.path < $1.path },
            truncated: truncated,
            totalEntriesSeen: seen)
    }

    static func relative(_ url: URL, to root: URL) -> String {
        let path = url.path
        let base = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard path.hasPrefix(base) else { return url.lastPathComponent }
        return String(path.dropFirst(base.count))
    }
}
