import Testing
import Foundation
@testable import BeaconCore

@Suite("Seeding a reproduction run")
struct SeedTests {

    func makeSeed() throws -> URL {
        let seed = FileManager.default.temporaryDirectory
            .appendingPathComponent("beacon-seed-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: seed, withIntermediateDirectories: true)
        try Data("seeded".utf8).write(to: seed.appendingPathComponent("marker.txt"))
        return seed
    }

    func makeDestination() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("beacon-dest-\(UUID().uuidString)", isDirectory: true)
    }

    @Test func itCopiesTheSeedInWhenBothSwitchesAreSet() throws {
        let seed = try makeSeed(), destination = makeDestination()
        defer { try? FileManager.default.removeItem(at: seed)
                try? FileManager.default.removeItem(at: destination) }

        let result = BeaconSeed.applyIfRequested(into: destination, environment: [
            BeaconSeed.directoryVariable: seed.path,
            BeaconSeed.enableVariable: "1",
        ])
        #expect(result.applied)
        #expect(FileManager.default.fileExists(
            atPath: destination.appendingPathComponent("marker.txt").path))
    }

    /// The whole safety story: one variable on its own does nothing. A
    /// seed that fired on somebody's real machine would replace their data.
    @Test func oneSwitchOnItsOwnDoesNothing() throws {
        let seed = try makeSeed(), destination = makeDestination()
        defer { try? FileManager.default.removeItem(at: seed) }

        let named = BeaconSeed.applyIfRequested(into: destination, environment: [
            BeaconSeed.directoryVariable: seed.path,
        ])
        #expect(!named.applied)
        #expect(!FileManager.default.fileExists(atPath: destination.path))

        let enabledOnly = BeaconSeed.applyIfRequested(into: destination, environment: [
            BeaconSeed.enableVariable: "1",
        ])
        #expect(!enabledOnly.applied)
    }

    @Test func aMissingSeedFolderLeavesTheDestinationAlone() {
        let destination = makeDestination()
        let result = BeaconSeed.applyIfRequested(into: destination, environment: [
            BeaconSeed.directoryVariable: "/nowhere/at/all",
            BeaconSeed.enableVariable: "1",
        ])
        #expect(!result.applied)
        #expect(result.explanation.contains("isn't there"))
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    @Test func everyOutcomeExplainsItselfForTheRunLog() {
        let result = BeaconSeed.applyIfRequested(into: makeDestination(), environment: [:])
        #expect(!result.explanation.isEmpty)
    }

    @Test func aRunKnowsWhetherItIsAReproduction() {
        #expect(BeaconSeed.isReproductionRun(environment: [BeaconSeed.enableVariable: "1"]))
        #expect(!BeaconSeed.isReproductionRun(environment: [:]))
    }
}
