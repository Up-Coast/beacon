// The parts of capture that don't need a screen: frames out of a video,
// picked media becoming attachments, and the sentences naming the right
// device. These run on the Mac and on the iOS Simulator alike.

import Testing
import Foundation
import AVFoundation
import CoreGraphics
import CoreVideo
import ImageIO
import UniformTypeIdentifiers
@testable import BeaconCore
@testable import BeaconCapture

/// A short, real video written with AVAssetWriter, so frame extraction is
/// tested against the same decoder path a recording goes through.
private func makeVideo(seconds: Double = 1.5, fps: Int32 = 10) async throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("beacon-capture-test-\(UUID().uuidString).mov")
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    let width = 64, height = 48
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width, AVVideoHeightKey: height,
    ])
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: input,
        sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
    writer.add(input)
    guard writer.startWriting() else { throw writer.error ?? CaptureError.failed("startWriting") }
    writer.startSession(atSourceTime: .zero)

    let frameCount = Int(seconds * Double(fps))
    for index in 0..<frameCount {
        while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
        let pixelBuffer = try #require(buffer)
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        // A different shade per frame, so frames are distinguishable.
        memset(CVPixelBufferGetBaseAddress(pixelBuffer), Int32(index * 15 % 255),
               CVPixelBufferGetDataSize(pixelBuffer))
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: CMTimeValue(index), timescale: fps))
    }
    input.markAsFinished()
    await writer.finishWriting()
    return url
}

@Suite("Frames out of a recording")
struct RecordingFrameTests {

    @Test func offsetsStartABeatInAndEndABeatBeforeTheEnd() {
        let offsets = RecordingFrames.offsets(duration: 10, count: 4)
        #expect(offsets.count == 4)
        #expect(offsets.first == 0.05)
        #expect(offsets.last == 9.95)
        #expect(offsets == offsets.sorted())
    }

    @Test func atLeastTwoFramesAreAlwaysAsked_for() {
        #expect(RecordingFrames.offsets(duration: 3, count: 0).count == 2)
    }

    @Test func framesComeOutAsPNGsInTimeOrder() async throws {
        let url = try await makeVideo()
        defer { try? FileManager.default.removeItem(at: url) }

        let frames = await RecordingFrames.extract(from: url, count: 4)
        #expect(frames.count == 4)
        #expect(frames.allSatisfy { $0.kind == .recordingFrame })
        #expect(frames.map(\.filename) == ["recording-frame-01.png", "recording-frame-02.png",
                                           "recording-frame-03.png", "recording-frame-04.png"])
        let offsets = frames.compactMap(\.timeOffsetSeconds)
        #expect(offsets == offsets.sorted())
        // The PNG signature — these are pictures, not empty files.
        for frame in frames {
            #expect(frame.data.prefix(4) == Data([0x89, 0x50, 0x4E, 0x47]))
        }
    }

    @Test func aFileThatIsNotAVideoYieldsNoFrames() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("not-a-video-\(UUID().uuidString).mov")
        try Data("hello".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(await RecordingFrames.extract(from: url).isEmpty)
    }
}

@Suite("Media picked from the library")
struct PickedMediaTests {

    @Test func aPictureBecomesOneScreenshotAttachment() async {
        let produced = await PickedMedia.attachments(data: Data([1, 2, 3]), type: .png)
        #expect(produced.count == 1)
        #expect(produced[0].kind == .screenshot)
        #expect(produced[0].filename.hasSuffix(".png"))
        #expect(produced[0].data == Data([1, 2, 3]))
    }

    /// The promise that matters for triage: a video never travels alone.
    @Test func aVideoTravelsWithItsFrames() async throws {
        let url = try await makeVideo()
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try Data(contentsOf: url)

        let produced = await PickedMedia.attachments(data: data, type: .quickTimeMovie)
        #expect(produced.first?.kind == .screenRecording)
        #expect(produced.first?.filename.hasSuffix(".mov") == true)
        #expect(produced.filter { $0.kind == .recordingFrame }.count == RecordingFrames.defaultCount)
    }

    /// A photo from the library says where it was taken. The attachment
    /// must not.
    @Test func locationAndCameraMetadataAreLeftBehind() async throws {
        let tagged = try #require(makeJPEGWithLocation())
        let before = try #require(CGImageSourceCreateWithData(tagged as CFData, nil))
        let beforeProperties = CGImageSourceCopyPropertiesAtIndex(before, 0, nil) as? [CFString: Any]
        #expect(beforeProperties?[kCGImagePropertyGPSDictionary] != nil)

        let produced = await PickedMedia.attachments(data: tagged, type: .jpeg)
        let attachment = try #require(produced.first)
        #expect(attachment.filename.hasSuffix(".jpeg"))
        let after = try #require(CGImageSourceCreateWithData(attachment.data as CFData, nil))
        let properties = CGImageSourceCopyPropertiesAtIndex(after, 0, nil) as? [CFString: Any]
        #expect(properties?[kCGImagePropertyGPSDictionary] == nil)
        // The encoder writes a bare EXIF block of its own (pixel sizes);
        // what must not survive is anything that came from the camera.
        let exif = properties?[kCGImagePropertyExifDictionary] as? [CFString: Any]
        #expect(exif?[kCGImagePropertyExifLensModel] == nil)
        #expect(properties?[kCGImagePropertyPixelWidth] as? Int == 8)
    }

    func makeJPEGWithLocation() -> Data? {
        let space = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
              let image = context.makeImage() else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        let properties: [CFString: Any] = [
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 49.28,
                                            kCGImagePropertyGPSLongitude: 123.12],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifLensModel: "test lens"],
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    @Test func aFormatNobodyDownstreamCanReadIsTurnedAway() async {
        #expect(await PickedMedia.attachments(data: Data([0]), type: .zip).isEmpty)
    }
}

@Suite("Capture sentences")
struct CaptureWordingTests {

    /// The sentence has to name the device the reporter is holding.
    @Test func unavailabilityNamesThisDevice() {
        let sentence = CaptureError.unavailable.errorDescription ?? ""
        #expect(sentence.contains(PlatformWording.thisDevice))
        #if os(iOS)
        #expect(!sentence.contains("Mac"))
        #endif
    }

    @Test func permissionAdviceIsForThePlatformItRunsOn() {
        let sentence = CaptureError.permissionDenied.errorDescription ?? ""
        #if os(macOS)
        #expect(sentence.contains("System Settings"))
        #else
        #expect(sentence.contains("Record Screen"))
        #endif
    }
}
