// The one place the reporter's machine is named.
//
// Beacon's sentences talk about "this Mac" because that is where it was
// written first. The same sentences are read on an iPhone and an iPad, and
// a report sheet that calls a phone a Mac reads as broken before the
// reporter has typed a word. So the noun is chosen once, here, from the
// platform the package was compiled for, and every sentence that needs it
// asks here — never spelling it out at the use site.

import Foundation

public enum PlatformWording {
    /// "this Mac" / "this device" — mid-sentence.
    public static let thisDevice: String = {
        #if os(macOS)
        "this Mac"
        #else
        "this device"
        #endif
    }()

    /// "This Mac" / "This device" — at the start of a sentence.
    public static let thisDeviceCapitalized: String =
        thisDevice.prefix(1).uppercased() + thisDevice.dropFirst()

    /// "your Mac" / "your device" — when the sentence is addressed to the
    /// reporter.
    public static let yourDevice: String = {
        #if os(macOS)
        "your Mac"
        #else
        "your device"
        #endif
    }()

    /// "Your Mac" / "Your device" — at the start of a sentence.
    public static let yourDeviceCapitalized: String =
        yourDevice.prefix(1).uppercased() + yourDevice.dropFirst()

    /// What a capture is of: a Mac app has a window, an iOS app has the
    /// whole screen.
    public static let appSurface: String = {
        #if os(macOS)
        "window"
        #else
        "screen"
        #endif
    }()
}
