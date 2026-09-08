// Every report is written to disk before it is sent.
//
// The reason is narrow and worth stating: somebody has just spent ten
// minutes writing down what they saw, and the network is the one part of
// this system nobody controls. Saving first means a failed send is an
// inconvenience instead of a lost report — and it means the reporter can
// be told, truthfully, that their words are safe on their own machine.
//
// The archive is also what makes the offline transport possible at all: a
// saved report is a complete, self-contained folder somebody can hand over.

import Foundation
import BeaconCore

public struct ReportArchive: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// One report's folder: the JSON, the rendered issue, and every
    /// attachment as a real file with its real name.
    public struct SavedReport: Sendable, Equatable {
        public var folder: URL
        public var reportJSON: URL
        public var issueMarkdown: URL
        public var attachments: [URL]
    }

    @discardableResult
    public func save(_ submission: ReportSubmission) throws -> SavedReport {
        let fm = FileManager.default
        let stamp = Self.stamp(submission.report.startedAt)
        let folder = directory.appendingPathComponent(
            "\(stamp)-\(submission.report.reference)", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        // The report JSON carries no attachment bytes — those are written
        // beside it as files, so the JSON stays readable and the folder
        // stays something a person can open and understand.
        var slim = submission.report
        slim.attachments = slim.attachments.map {
            var stripped = $0
            stripped.data = Data()
            return stripped
        }
        let reportURL = folder.appendingPathComponent("report.json")
        try encoder.encode(slim).write(to: reportURL)

        let issueURL = folder.appendingPathComponent("issue.md")
        let issueText = "# \(submission.issue.title)\n\n"
            + "Labels: \(submission.issue.labels.joined(separator: ", "))\n\n"
            + submission.issue.body + "\n"
        try Data(issueText.utf8).write(to: issueURL)

        var attachmentURLs: [URL] = []
        if !submission.attachments.isEmpty {
            let attachmentsFolder = folder.appendingPathComponent("attachments", isDirectory: true)
            try fm.createDirectory(at: attachmentsFolder, withIntermediateDirectories: true)
            for attachment in submission.attachments {
                let url = attachmentsFolder.appendingPathComponent(
                    Self.safeFilename(attachment.filename))
                try attachment.data.write(to: url)
                attachmentURLs.append(url)
            }
        }

        return SavedReport(folder: folder, reportJSON: reportURL,
                           issueMarkdown: issueURL, attachments: attachmentURLs)
    }

    /// Reports still on disk, newest first. The host can offer these for a
    /// retry after a failed send.
    public func saved() -> [URL] {
        let fm = FileManager.default
        let folders = (try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles])) ?? []
        return folders.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: date)
    }

    /// Filenames come partly from the reporter, so they get flattened
    /// before they ever reach the file system.
    static func safeFilename(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._- "))
        let cleaned = String(name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
        let trimmed = cleaned.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "attachment" : String(trimmed.prefix(120))
    }
}
