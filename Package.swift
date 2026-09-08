// swift-tools-version: 6.2
// Beacon — a drop-in bug / feature / feedback reporting system for any app.
//
// The whole point is that a host app adopts this without knowing anything
// about it beyond one call. So Beacon assumes NOTHING about its host: it
// brings its own logger, its own diagnostics capture, its own UI, and its
// own path to GitHub. A host app that has none of those still gets a
// complete reporting system; a host app that has its own can hand its own
// in through the seams instead.
//
// Layering (each target may import only the ones above it):
//   BeaconCore          values, rules, rendering — no UI, no platform APIs
//   BeaconDiagnostics   the logger + what gets attached to a report
//   BeaconIntelligence  the on-device completeness check
//   BeaconCapture       screenshots and screen recording (ScreenCaptureKit on
//                       macOS, ReplayKit and the view hierarchy on iOS)
//   BeaconGitHub        the ways a finished report reaches GitHub
//   BeaconUI            the SwiftUI flow the reporter actually sees
//   Beacon              the one-call façade a host app adopts

import PackageDescription

let package = Package(
    name: "Beacon",
    platforms: [
        // 26 is the floor on both because the on-device completeness check
        // (FoundationModels) and the modern capture paths land there. Every
        // target builds for both; the capture layer has a file per platform.
        .macOS(.v26), .iOS(.v26),
    ],
    products: [
        .library(name: "Beacon", targets: ["Beacon"]),
        .library(name: "BeaconCore", targets: ["BeaconCore"]),
        .executable(name: "beacon-index", targets: ["beacon-index"]),
    ],
    targets: [
        .target(name: "BeaconCore"),
        .target(name: "BeaconDiagnostics", dependencies: ["BeaconCore"]),
        .target(name: "BeaconIntelligence", dependencies: ["BeaconCore"]),
        .target(name: "BeaconCapture", dependencies: ["BeaconCore"]),
        .target(name: "BeaconGitHub", dependencies: ["BeaconCore"]),
        .target(name: "BeaconUI", dependencies: [
            "BeaconCore", "BeaconDiagnostics", "BeaconIntelligence",
            "BeaconCapture", "BeaconGitHub",
        ]),
        // The façade: what a host app imports and calls.
        .target(name: "Beacon", dependencies: ["BeaconUI"]),

        // The indexer a host app runs once at adoption (and again in CI):
        // reads the host's own source tree and writes BeaconIndex.json, which
        // is what makes the module/area pickers real instead of hand-typed.
        .executableTarget(name: "beacon-index", dependencies: ["BeaconCore"]),

        .testTarget(name: "BeaconCoreTests", dependencies: ["BeaconCore"]),
        .testTarget(name: "BeaconDiagnosticsTests", dependencies: ["BeaconDiagnostics"]),
        .testTarget(name: "BeaconIntelligenceTests", dependencies: ["BeaconIntelligence"]),
        .testTarget(name: "BeaconCaptureTests", dependencies: ["BeaconCapture"]),
        .testTarget(name: "BeaconGitHubTests", dependencies: ["BeaconGitHub"]),
    ]
)
