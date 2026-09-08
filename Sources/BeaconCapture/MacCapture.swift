// Screenshots and screen recordings on macOS, taken of the app itself.
//
// Beacon captures the HOST APP'S OWN WINDOWS and nothing else. It asks the
// system for `SCShareableContent.currentProcess`, which returns only this
// process's windows — so a recording cannot pick up the email behind the
// app, and the reporter does not have to trust that it won't. It also
// means the reporter never has to choose a window correctly, which is the
// step people get wrong when they are already frustrated.
//
// The shared half — errors, PNG encoding, filenames, and pulling frames
// out of a recording — is in Capture.swift, and the iOS path in
// IOSCapture.swift presents the same three names to the sheet.

#if os(macOS)

import Foundation
import ScreenCaptureKit
import CoreGraphics
import CoreMedia
import AppKit
import BeaconCore

public enum ScreenPermission {
    /// Whether permission is already granted. Reading this does not prompt,
    /// so the UI can show the right button before committing the reporter
    /// to a system dialog.
    public static var isGranted: Bool { CGPreflightScreenCaptureAccess() }

    /// Ask for it. The system shows its own dialog; the first call is the
    /// only one that does, after which the person has to go to Settings —
    /// which is why `CaptureError.permissionDenied` spells out the path.
    @discardableResult
    public static func request() -> Bool { CGRequestScreenCaptureAccess() }

    /// Granted already, or granted just now. The one call the sheet makes.
    public static func ensure() -> Bool { isGranted || request() }
}

public struct ScreenCapturer: Sendable {

    public init() {}

    /// This app's own windows, largest first — the frontmost real window is
    /// almost always the biggest, and the biggest is what somebody means
    /// when they say "the app".
    static func ownWindows() async throws -> [SCWindow] {
        guard ScreenPermission.isGranted else { throw CaptureError.permissionDenied }
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.currentProcess
        } catch {
            throw CaptureError.failed(error.localizedDescription)
        }
        let windows = content.windows
            .filter { $0.frame.width > 80 && $0.frame.height > 80 && $0.isOnScreen }
            .sorted { $0.frame.width * $0.frame.height > $1.frame.width * $1.frame.height }
        guard !windows.isEmpty else { throw CaptureError.noWindow }
        return windows
    }

    /// A stream configuration sized to the window's pixels, cursor shown.
    static func streamConfiguration(for filter: SCContentFilter) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        configuration.width = Int(filter.contentRect.width * CGFloat(filter.pointPixelScale))
        configuration.height = Int(filter.contentRect.height * CGFloat(filter.pointPixelScale))
        configuration.showsCursor = true
        return configuration
    }

    // MARK: Screenshot

    /// A PNG of the app's main window.
    public func screenshot() async throws -> Attachment {
        let window = try await Self.ownWindows()[0]
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let image: CGImage
        do {
            image = try await SCScreenshotManager.captureImage(
                contentFilter: filter, configuration: Self.streamConfiguration(for: filter))
        } catch {
            throw CaptureError.failed(error.localizedDescription)
        }
        guard let data = CaptureSupport.pngData(from: image) else {
            throw CaptureError.failed("the picture couldn't be encoded")
        }
        return Attachment(kind: .screenshot,
                          filename: "screenshot-\(CaptureSupport.stamp()).png",
                          data: data)
    }
}

// MARK: - Recording

/// A recording in progress. Held by the UI while the reporter reproduces
/// the problem; `finish()` stops it and hands back the video plus the
/// frames pulled out of it.
///
/// Main-actor isolated, because that is where it is driven from and it
/// removes every lock from the class itself. The one thing that genuinely
/// arrives from another thread — a failure from the system's recording
/// delegate — lands in `FailureBox`, which is the only synchronised thing
/// here.
@MainActor
public final class ScreenRecording {

    private let stream: SCStream
    private let output: SCRecordingOutput
    private let fileURL: URL
    private let startedAt: Date
    private let failures: FailureBox
    private var finished = false

    init(stream: SCStream, output: SCRecordingOutput, fileURL: URL, failures: FailureBox) {
        self.stream = stream
        self.output = output
        self.fileURL = fileURL
        self.failures = failures
        self.startedAt = Date()
    }

    public var elapsedSeconds: Double { Date().timeIntervalSince(startedAt) }

    /// Start recording the app's own main window.
    public static func start(maximumSeconds: Int = 180) async throws -> ScreenRecording {
        let window = try await ScreenCapturer.ownWindows()[0]
        let filter = SCContentFilter(desktopIndependentWindow: window)

        let configuration = ScreenCapturer.streamConfiguration(for: filter)
        // 12 fps: enough to see what somebody did, small enough that a
        // three-minute recording is still an attachment and not a download.
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 12)
        // No audio. Nobody consented to having their room recorded, and a
        // silent capture removes the question entirely.
        configuration.capturesAudio = false

        let fileURL = try CaptureSupport.scratchFile(extension: "mp4")
        let recordingConfiguration = SCRecordingOutputConfiguration()
        recordingConfiguration.outputURL = fileURL

        let failures = FailureBox()
        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        let delegate = RecordingDelegateBox(failures: failures)
        let output = SCRecordingOutput(configuration: recordingConfiguration, delegate: delegate)
        // The delegate is held weakly by ScreenCaptureKit, so the recording
        // keeps it alive for as long as the capture runs.
        objc_setAssociatedObject(output, &RecordingDelegateBox.associationKey,
                                 delegate, .OBJC_ASSOCIATION_RETAIN)
        do {
            try stream.addRecordingOutput(output)
            try await stream.startCapture()
        } catch {
            throw CaptureError.failed(error.localizedDescription)
        }

        return ScreenRecording(stream: stream, output: output,
                               fileURL: fileURL, failures: failures)
    }

    /// Stop, and produce the attachments. The video comes back first, then
    /// the frames in time order.
    public func finish(frameCount: Int = RecordingFrames.defaultCount) async throws -> [Attachment] {
        guard !finished else { return [] }
        finished = true

        try? await stream.stopCapture()
        if let failure = failures.value() { throw CaptureError.failed(failure) }
        return try await CaptureSupport.attachments(forRecordingAt: fileURL, frameCount: frameCount)
    }

    /// Give up without producing anything.
    public func cancel() async {
        finished = true
        try? await stream.stopCapture()
        try? FileManager.default.removeItem(at: fileURL)
    }
}

/// Carries a failure from the system's delegate thread back to the main
/// actor. Small on purpose: it is the only shared mutable state in this
/// file, so it is the only thing that needs a lock.
final class FailureBox: @unchecked Sendable {
    private let lock = NSLock()
    private var message: String?

    func set(_ newValue: String) {
        lock.lock()
        defer { lock.unlock() }
        if message == nil { message = newValue }
    }

    func value() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return message
    }
}

/// The delegate ScreenCaptureKit requires. It exists only to notice
/// failures — a recording that dies silently and hands back a valid-looking
/// empty file is the worst outcome available here.
final class RecordingDelegateBox: NSObject, SCRecordingOutputDelegate, @unchecked Sendable {
    nonisolated(unsafe) static var associationKey: UInt8 = 0
    private let failures: FailureBox

    init(failures: FailureBox) {
        self.failures = failures
    }

    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: any Error) {
        failures.set(error.localizedDescription)
    }
}

#endif
