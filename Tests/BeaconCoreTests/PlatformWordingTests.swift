// The device is named once, and every sentence that names it asks there.

import Testing
@testable import BeaconCore

@Suite("Naming the reporter's device")
struct PlatformWordingTests {

    @Test func theNounMatchesThePlatformThisWasBuiltFor() {
        #if os(macOS)
        #expect(PlatformWording.thisDevice == "this Mac")
        #expect(PlatformWording.appSurface == "window")
        #else
        #expect(PlatformWording.thisDevice == "this device")
        #expect(PlatformWording.appSurface == "screen")
        #endif
    }

    @Test func theCapitalisedFormsOnlyChangeTheFirstLetter() {
        #expect(PlatformWording.thisDeviceCapitalized.dropFirst() == PlatformWording.thisDevice.dropFirst())
        #expect(PlatformWording.thisDeviceCapitalized.first?.isUppercase == true)
        #expect(PlatformWording.yourDeviceCapitalized.dropFirst() == PlatformWording.yourDevice.dropFirst())
        #expect(PlatformWording.yourDeviceCapitalized.first?.isUppercase == true)
    }

    /// The one sentence in Core that names the device goes through the
    /// same home, so an iPhone is never told its report is "on this Mac".
    @Test func theNetworkFailureSentenceNamesThisDevice() {
        let sentence = TransportError.network("offline").errorDescription ?? ""
        #expect(sentence.contains("saved on \(PlatformWording.thisDevice)"))
    }
}
