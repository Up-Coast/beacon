// What rides along with a report.
//
// Two audiences read attachments and they want different things. A person
// wants the screen recording. An agent doing triage cannot watch a video at
// all — so anything visual also arrives as still frames, and anything
// structured also arrives as text. The accepted-format list below is chosen
// on exactly that basis: a format is allowed when the triaging agent can
// actually read it, because an attachment nobody can read is a file that
// only makes the report look thorough.

import Foundation

public enum AttachmentKind: String, Codable, Sendable {
    /// A still the reporter took, or one Beacon took for them.
    case screenshot
    /// The video itself — for human eyes.
    case screenRecording = "screen-recording"
    /// Stills pulled out of that video so triage can see it too.
    case recordingFrame = "recording-frame"
    /// A file the reporter chose to add.
    case userFile = "user-file"
    /// Something Beacon collected: the log tail, the environment, the
    /// settings snapshot, the file-tree listing.
    case diagnostic
}

/// The formats Beacon will accept from a reporter, and the reason the list
/// stops where it does: each of these is a format the triaging agent can
/// read directly. Anything else is refused at the picker with a plain
/// sentence, rather than accepted and quietly ignored later.
public enum AcceptedFormats {
    /// Text-shaped files, read as text.
    public static let textExtensions: Set<String> = [
        "txt", "md", "markdown", "log", "json", "yaml", "yml", "toml", "csv",
        "tsv", "xml", "html", "htm", "plist", "diff", "patch", "rtf",
        // Source files, because a reporter who is technical often has the
        // most useful thing right there.
        "swift", "js", "ts", "tsx", "jsx", "py", "rb", "go", "rs", "java",
        "kt", "c", "h", "cpp", "hpp", "m", "mm", "sh", "sql", "conf", "ini",
    ]
    /// Images, read as images.
    public static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "heic", "heif", "gif", "webp", "tiff", "bmp",
    ]
    /// Documents that carry their own text layer.
    public static let documentExtensions: Set<String> = ["pdf"]
    /// Video, accepted only because Beacon itself produces it; a reporter
    /// can attach one too, and it always travels with extracted frames.
    public static let videoExtensions: Set<String> = ["mov", "mp4", "m4v"]

    public static var all: Set<String> {
        textExtensions.union(imageExtensions).union(documentExtensions).union(videoExtensions)
    }

    public static func accepts(_ url: URL) -> Bool {
        all.contains(url.pathExtension.lowercased())
    }

    /// The sentence shown when a file is turned away. It says why, and it
    /// says what to do instead — a refusal with no road out is a dead end.
    public static func refusal(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        let named = ext.isEmpty ? "That file" : "A .\(ext) file"
        return "\(named) can't be read by the person or the assistant who will "
            + "look at this report, so adding it wouldn't help. Text, images, "
            + "PDFs and screen recordings all work — a screenshot of what "
            + "you're looking at is usually the most useful thing you can add."
    }

    /// The largest single file Beacon will carry. Past this the reporter is
    /// asked to trim rather than being told "upload failed" at the end.
    public static let maximumFileBytes = 25 * 1024 * 1024
    /// The largest a whole report's attachments may total.
    public static let maximumTotalBytes = 60 * 1024 * 1024
}

/// One attached file. The bytes travel with the report so a submission is
/// a single self-contained thing; the original location is kept only as a
/// label, and never re-read after staging.
public struct Attachment: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var kind: AttachmentKind
    /// The name shown to the reporter and used inside the bundle.
    public var filename: String
    public var data: Data
    /// What the reporter said this is — optional, and worth a lot during
    /// triage ("this is the screen right before it froze").
    public var note: String?
    /// For a frame pulled out of a recording: where in the video it came
    /// from, so the issue can say "at 0:14".
    public var timeOffsetSeconds: Double?

    public init(id: UUID = UUID(), kind: AttachmentKind, filename: String,
                data: Data, note: String? = nil, timeOffsetSeconds: Double? = nil) {
        self.id = id
        self.kind = kind
        self.filename = filename
        self.data = data
        self.note = note
        self.timeOffsetSeconds = timeOffsetSeconds
    }

    public var byteCount: Int { data.count }

    /// A human size for the review screen — the reporter should be able to
    /// see what they are about to send.
    public var displaySize: String {
        let bytes = Double(byteCount)
        if bytes < 1024 { return "\(byteCount) bytes" }
        if bytes < 1024 * 1024 { return String(format: "%.0f KB", bytes / 1024) }
        return String(format: "%.1f MB", bytes / (1024 * 1024))
    }
}
