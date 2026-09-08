// What screenshots and recordings have in common on every platform.
//
// The platform-specific halves — ScreenCaptureKit on the Mac, ReplayKit and
// the view hierarchy on iOS — live in their own files and present the same
// three names to the sheet: `ScreenPermission`, `ScreenCapturer` and
// `ScreenRecording`. Everything that does not depend on how the pixels were
// obtained lives here, once: the errors and their sentences, PNG encoding,
// the filenames, the scratch folder, and pulling still frames out of a
// video so the assistant doing triage — which cannot watch one — can see
// what the reporter recorded.

import Foundation
import AVFoundation
import CoreGraphics
import CoreMedia
import ImageIO
import UniformTypeIdentifiers
import BeaconCore

public enum CaptureError: Error, LocalizedError {
    case permissionDenied
    case noWindow
    case unavailable
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            #if os(macOS)
            "macOS hasn't given this app permission to record the screen yet. "
                + "Open System Settings \u{203A} Privacy & Security \u{203A} Screen & System "
                + "Audio Recording and switch it on, then try again."
            #else
            "Recording was declined when iOS asked. Press record again and "
                + "choose Record Screen when it asks."
            #endif
        case .noWindow:
            "There was no app \(PlatformWording.appSurface) to capture. Make sure "
                + "the \(PlatformWording.appSurface) you want is showing, then try again."
        case .unavailable:
            "Screen recording isn't available on \(PlatformWording.thisDevice) right now "
                + "\u{2014} a screenshot of the moment it goes wrong works just as well."
        case .failed(let detail):
            "The capture didn't work: \(detail)"
        }
    }
}

/// The shared mechanics. Static and stateless: nothing here knows which
/// platform produced the pixels.
enum CaptureSupport {

    /// PNG bytes for a CGImage, through ImageIO — the same encoder on
    /// every platform, so a frame from a Mac and a frame from an iPhone are
    /// the same kind of file.
    static func pngData(from image: CGImage) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    /// The same picture with every piece of metadata left behind: no
    /// location, no camera, no timestamp. Decoded to pixels and written
    /// back in the same format, so a PNG stays a PNG and a JPEG a JPEG;
    /// nil when the bytes aren't an image ImageIO can read.
    static func pixelsOnly(_ data: Data, type: UTType) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, type.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    /// A time-of-day stamp for filenames: a reporter who takes three
    /// screenshots should end up with three files whose names say which
    /// came first.
    static func stamp(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HHmmss"
        return formatter.string(from: date)
    }

    /// Where a recording is written while it is in progress. Temporary on
    /// purpose: the bytes move into the attachment and the file is removed.
    static func scratchFile(extension ext: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("beacon-recordings", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("recording-\(UUID().uuidString).\(ext)")
    }

    /// Waits for the system's writer to finish closing a file after a
    /// capture stops. Polled rather than slept blindly so it costs nothing
    /// when the file is already there.
    static func settle(_ url: URL) async {
        for _ in 0..<20 {
            if let size = try? FileManager.default
                .attributesOfItem(atPath: url.path)[.size] as? Int, size > 0 { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    /// The finished recording as attachments: the video first, then the
    /// frames in time order. The file is removed once it has been read.
    static func attachments(forRecordingAt url: URL, frameCount: Int) async throws -> [Attachment] {
        await settle(url)
        guard let videoData = try? Data(contentsOf: url), !videoData.isEmpty else {
            throw CaptureError.failed("the recording came back empty")
        }
        var attachments = [Attachment(
            kind: .screenRecording,
            filename: "recording-\(stamp()).\(url.pathExtension)",
            data: videoData,
            note: "Recorded inside the app \u{2014} only this app's "
                + "\(PlatformWording.appSurface) is in it.")]
        attachments += await RecordingFrames.extract(from: url, count: frameCount)
        try? FileManager.default.removeItem(at: url)
        return attachments
    }
}

/// Stills from a video, evenly spaced, plus the last moment — which is
/// usually where the problem is. These exist so the assistant doing triage
/// can see the recording; it cannot play one.
public enum RecordingFrames {

    /// The default number of frames pulled from a recording.
    public static let defaultCount = 6

    /// Frames are for reading, not for archiving — the long edge is capped
    /// so six of them don't outweigh the video they came from.
    static let maximumEdge: CGFloat = 1600

    public static func extract(from url: URL, count: Int = defaultCount) async -> [Attachment] {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration),
              duration.seconds > 0.2 else { return [] }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.3, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.3, preferredTimescale: 600)
        generator.maximumSize = CGSize(width: maximumEdge, height: maximumEdge)

        var attachments: [Attachment] = []
        for (index, offset) in offsets(duration: duration.seconds, count: count).enumerated() {
            let time = CMTime(seconds: offset, preferredTimescale: 600)
            guard let result = try? await generator.image(at: time),
                  let data = CaptureSupport.pngData(from: result.image) else { continue }
            attachments.append(Attachment(
                kind: .recordingFrame,
                filename: String(format: "recording-frame-%02d.png", index + 1),
                data: data,
                note: nil,
                timeOffsetSeconds: offset))
        }
        return attachments
    }

    /// Where in the video to look. Starts a beat in and ends a beat before
    /// the very end: the first and last frames of a capture are often blank.
    static func offsets(duration: Double, count: Int) -> [Double] {
        let wanted = max(2, count)
        return (0..<wanted).map { index in
            let fraction = Double(index) / Double(wanted - 1)
            return min(duration - 0.05, max(0.05, fraction * duration))
        }
    }
}

/// A picture or video the reporter picked from their photo library. iOS
/// testers take screenshots and screen recordings with the buttons they
/// already know, and those land in Photos — so the picker is the native way
/// to attach one. A video always travels with frames pulled out of it, the
/// same as one Beacon recorded, because triage can't watch it.
public enum PickedMedia {

    /// The attachments for one picked item, or nothing when the format is
    /// one nobody downstream could read.
    public static func attachments(data: Data, type: UTType) async -> [Attachment] {
        guard let ext = type.preferredFilenameExtension else { return [] }
        let isVideo = type.conforms(to: .movie) || type.conforms(to: .video)
        let filename = "\(isVideo ? "video" : "photo")-\(CaptureSupport.stamp()).\(ext)"
        guard AcceptedFormats.accepts(URL(fileURLWithPath: filename)) else { return [] }

        // A photo from the library carries where and when it was taken. A
        // bug report needs the pixels and nothing else, so the picture is
        // re-encoded from its pixels alone before it becomes an attachment.
        let payload = isVideo ? data : (CaptureSupport.pixelsOnly(data, type: type) ?? data)
        var produced = [Attachment(kind: isVideo ? .screenRecording : .screenshot,
                                   filename: filename, data: payload)]
        if isVideo, let scratch = try? CaptureSupport.scratchFile(extension: ext),
           (try? data.write(to: scratch)) != nil {
            produced += await RecordingFrames.extract(from: scratch)
            try? FileManager.default.removeItem(at: scratch)
        }
        return produced
    }
}
