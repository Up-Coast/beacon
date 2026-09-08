// Screenshots and screen recordings on iOS, taken of the app itself.
//
// The Mac asks ScreenCaptureKit for the app's own windows. iOS has no
// windows to choose between and no API for capturing another app, so the
// same promise — only this app, never anything else — is kept by two
// different means:
//
//   A screenshot is drawn from the app's own view hierarchy, not read from
//   the display. It cannot contain another app because it never looks at
//   the display at all. It is drawn from the view underneath the report
//   sheet, so the picture is of what the reporter was looking at when they
//   pressed the button, not of the form they are filling in.
//
//   A recording goes through ReplayKit, which records this app's screen
//   only, only while it is in the foreground, and asks the person for
//   permission itself each time. No audio: the microphone is switched off
//   before recording starts.
//
// Both hand back the same `Attachment`s the Mac path does, so the sheet,
// the renderer and the transports never know which platform produced them.

#if os(iOS)

import Foundation
import UIKit
import ReplayKit
import BeaconCore

public enum ScreenPermission {
    /// iOS has no preflight for screen recording: the system asks the
    /// person the moment a recording starts, and asks again in a later
    /// session. So the only thing to check ahead of time is whether the
    /// recorder exists on this device at all.
    public static func ensure() -> Bool { RPScreenRecorder.shared().isAvailable }
}

public struct ScreenCapturer: Sendable {

    public init() {}

    /// The window the reporter is looking at — the key window of the
    /// foreground scene.
    @MainActor
    static func keyWindow() throws -> UIWindow {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .sorted { $0.activationState.rawValue < $1.activationState.rawValue }
        guard let window = scenes.compactMap(\.keyWindow).first else {
            throw CaptureError.noWindow
        }
        return window
    }

    /// A PNG of the app's screen, drawn from the view hierarchy beneath
    /// the sheet. The root view controller's view is what the app shows;
    /// a presented sheet lives beside it in the window, not inside it, so
    /// drawing the root view leaves the report form out of the picture.
    @MainActor
    public func screenshot() async throws -> Attachment {
        let window = try Self.keyWindow()
        guard let view = window.rootViewController?.view else { throw CaptureError.noWindow }
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        let data = renderer.pngData { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
        }
        guard !data.isEmpty else { throw CaptureError.failed("the picture couldn't be encoded") }
        return Attachment(kind: .screenshot,
                          filename: "screenshot-\(CaptureSupport.stamp()).png",
                          data: data)
    }
}

// MARK: - Recording

/// A recording in progress. Held by the sheet while the reporter
/// reproduces the problem; `finish()` stops it and hands back the video
/// plus the frames pulled out of it.
@MainActor
public final class ScreenRecording {

    private let recorder: RPScreenRecorder
    private let fileURL: URL
    private let startedAt: Date
    private var finished = false

    init(recorder: RPScreenRecorder, fileURL: URL) {
        self.recorder = recorder
        self.fileURL = fileURL
        self.startedAt = Date()
    }

    public var elapsedSeconds: Double { Date().timeIntervalSince(startedAt) }

    /// Start recording the app's screen. iOS shows its own permission
    /// sheet here; declining it is reported as `permissionDenied`, with a
    /// sentence that says what to press next time.
    public static func start(maximumSeconds: Int = 180) async throws -> ScreenRecording {
        let recorder = RPScreenRecorder.shared()
        guard recorder.isAvailable else { throw CaptureError.unavailable }
        // Nobody consented to having their room recorded, and a silent
        // capture removes the question entirely.
        recorder.isMicrophoneEnabled = false
        recorder.isCameraEnabled = false

        let fileURL = try CaptureSupport.scratchFile(extension: "mov")
        try await Self.call { recorder.startRecording(handler: $0) }
        return ScreenRecording(recorder: recorder, fileURL: fileURL)
    }

    /// Stop, and produce the attachments. The video comes back first, then
    /// the frames in time order.
    public func finish(frameCount: Int = RecordingFrames.defaultCount) async throws -> [Attachment] {
        guard !finished else { return [] }
        finished = true
        try await Self.call { recorder.stopRecording(withOutput: fileURL, completionHandler: $0) }
        return try await CaptureSupport.attachments(forRecordingAt: fileURL, frameCount: frameCount)
    }

    /// Give up without producing anything.
    public func cancel() async {
        finished = true
        try? await Self.call { recorder.stopRecording(withOutput: fileURL, completionHandler: $0) }
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// ReplayKit answers through completion blocks; this turns one into a
    /// throwing call so the flow above reads top to bottom.
    static func call(_ operation: (@escaping @Sendable (Error?) -> Void) -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            operation { error in
                if let error { continuation.resume(throwing: explain(error)) }
                else { continuation.resume() }
            }
        }
    }

    /// ReplayKit's errors, in the reporter's terms. Declining the system
    /// prompt is the one that happens; everything else is a real failure.
    nonisolated static func explain(_ error: any Error) -> CaptureError {
        let nsError = error as NSError
        if nsError.domain == RPRecordingErrorDomain,
           nsError.code == RPRecordingErrorCode.userDeclined.rawValue {
            return .permissionDenied
        }
        return .failed(error.localizedDescription)
    }
}

#endif
