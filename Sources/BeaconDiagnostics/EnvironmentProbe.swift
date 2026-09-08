// What machine this is.
//
// Everything here is read from the system at report time and none of it
// identifies the person — model, OS, architecture, language, and the
// display settings that change what the app looks like. That last group is
// there because a surprising share of "it looked wrong" reports are a
// large-text or high-contrast setting doing exactly what it was asked to.

import Foundation
import BeaconCore
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FoundationModels)
import FoundationModels
#endif

public enum EnvironmentProbe {

    /// Main-actor because the appearance and text-size readings come from
    /// UIKit and AppKit, which answer only there. Everything else here
    /// could run anywhere; one isolation for the whole snapshot is simpler
    /// than two paths through it.
    @MainActor
    public static func snapshot() -> EnvironmentSnapshot {
        let process = ProcessInfo.processInfo
        var snapshot = EnvironmentSnapshot(
            operatingSystem: osName(),
            osVersion: process.operatingSystemVersionString,
            deviceModel: model(),
            architecture: architecture(),
            locale: Locale.current.identifier,
            timeZone: TimeZone.current.identifier,
            onDeviceModel: onDeviceModelDescription(),
            memoryGB: Double(process.physicalMemory) / 1_073_741_824,
            freeDiskGB: freeDiskGB())
        applyAppearance(to: &snapshot)
        return snapshot
    }

    static func osName() -> String {
        #if os(macOS)
        "macOS"
        #elseif os(iOS)
        "iOS"
        #else
        "unknown"
        #endif
    }

    /// The hardware identifier — `Mac15,3`, `iPhone17,1` and the like — the
    /// same value Apple's own reports carry. The Mac keeps it under
    /// `hw.model`; iOS keeps the board name there and the device under
    /// `hw.machine`. In the simulator `hw.machine` is the Mac's architecture,
    /// and the simulated device is in the environment instead.
    static func model(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        #if os(macOS)
        return sysctlString("hw.model")
        #else
        if let simulated = environment["SIMULATOR_MODEL_IDENTIFIER"], !simulated.isEmpty {
            return simulated + " (Simulator)"
        }
        return sysctlString("hw.machine")
        #endif
    }

    static func sysctlString(_ key: String) -> String {
        var size = 0
        guard sysctlbyname(key, nil, &size, nil, 0) == 0, size > 0 else { return "unknown" }
        var bytes = [UInt8](repeating: 0, count: size)
        guard sysctlbyname(key, &bytes, &size, nil, 0) == 0 else { return "unknown" }
        return String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
    }

    static func architecture() -> String {
        #if arch(arm64)
        "arm64"
        #elseif arch(x86_64)
        "x86_64"
        #else
        "unknown"
        #endif
    }

    static func freeDiskGB() -> Double? {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? home.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let free = values.volumeAvailableCapacityForImportantUsage
        else { return nil }
        return Double(free) / 1_073_741_824
    }

    /// Whether Apple's on-device model can run here, and if not, why. Read
    /// as state — this asks the framework a question, it never starts a
    /// session or generates anything.
    public static func onDeviceModelDescription() -> String {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            return "available"
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return "\(PlatformWording.thisDevice) can't run it"
            case .appleIntelligenceNotEnabled: return "Apple Intelligence is switched off"
            case .modelNotReady: return "still downloading"
            @unknown default: return "unavailable"
            }
        @unknown default:
            return "unknown"
        }
        #else
        return "not built into this app"
        #endif
    }

    @MainActor
    static func applyAppearance(to snapshot: inout EnvironmentSnapshot) {
        #if os(macOS)
        let appearance = NSApp?.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
        snapshot.appearance = appearance == .darkAqua ? "dark" : "light"
        snapshot.reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        // macOS has no single text-size setting the way iOS does; the
        // honest answer is to leave it unset rather than invent one.
        #elseif os(iOS)
        snapshot.appearance = UITraitCollection.current.userInterfaceStyle == .dark ? "dark" : "light"
        snapshot.textSize = UIApplication.shared.preferredContentSizeCategory.rawValue
        snapshot.reducedMotion = UIAccessibility.isReduceMotionEnabled
        #endif
    }
}
