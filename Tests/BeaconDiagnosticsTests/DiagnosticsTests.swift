import Testing
import Foundation
@testable import BeaconCore
@testable import BeaconDiagnostics

@Suite("The log Beacon brings with it")
struct BeaconLogTests {

    @Test func itKeepsTheMostRecentLinesAndDropsTheOldest() {
        let log = BeaconLog(capacity: 60, minimumLevel: .debug)
        for index in 1...200 { log.info("line \(index)") }
        let lines = log.lines()
        #expect(lines.count == 60)
        #expect(lines.first?.message == "line 141")
        #expect(lines.last?.message == "line 200")
    }

    @Test func theTailIsOldestFirstSoAReportReadsForwards() {
        let log = BeaconLog(capacity: 100, minimumLevel: .debug)
        for index in 1...10 { log.info("line \(index)") }
        let tail = log.tail(3)
        #expect(tail.map(\.message) == ["line 8", "line 9", "line 10"])
    }

    @Test func linesBelowTheMinimumAreDropped() {
        let log = BeaconLog(capacity: 50, minimumLevel: .warning)
        log.debug("noise")
        log.info("noise")
        log.error("real")
        #expect(log.lines().map(\.message) == ["real"])
    }

    @Test func categoriesRideOnEachLine() {
        let log = BeaconLog(capacity: 50, minimumLevel: .debug)
        log.category("settings").warning("something odd")
        #expect(log.lines().first?.category == "settings")
        #expect(log.lines().first?.level == .warning)
    }

    @Test func clearingEmptiesItCompletely() {
        let log = BeaconLog(capacity: 10, minimumLevel: .debug)
        for index in 1...25 { log.info("line \(index)") }
        log.clear()
        #expect(log.lines().isEmpty)
        log.info("after")
        #expect(log.lines().map(\.message) == ["after"])
    }
}

@Suite("Listing a folder without opening anything in it")
struct FileTreeScannerTests {

    /// Builds a small tree with a file whose CONTENTS must never appear in
    /// the snapshot — the whole promise of this feature in one check.
    func makeTree() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("beacon-tree-\(UUID().uuidString)", isDirectory: true)
        let fm = FileManager.default
        try fm.createDirectory(at: root.appendingPathComponent("Sources/Deep/Deeper/Deepest",
                                                              isDirectory: true),
                               withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent(".build", isDirectory: true),
                               withIntermediateDirectories: true)
        try Data("SECRET-CONTENTS-abcdef".utf8)
            .write(to: root.appendingPathComponent("notes.txt"))
        try Data().write(to: root.appendingPathComponent("empty.log"))
        try Data("x".utf8).write(to: root.appendingPathComponent(".build/artifact.o"))
        return root
    }

    @Test func itRecordsNamesAndSizesAndNeverContents() throws {
        let root = try makeTree()
        defer { try? FileManager.default.removeItem(at: root) }

        let snapshot = FileTreeScanner.scan(FileTreeRoot(label: "Your project", url: root))
        let paths = snapshot.entries.map(\.path)
        #expect(paths.contains("notes.txt"))
        #expect(paths.contains("empty.log"))

        // A zero-byte file is worth knowing about; its contents never are.
        let empty = snapshot.entries.first { $0.path == "empty.log" }
        #expect(empty?.byteCount == 0)

        let everything = snapshot.entries.map { "\($0.path)\($0.byteCount ?? 0)" }.joined()
        #expect(!everything.contains("SECRET-CONTENTS"))
    }

    @Test func buildOutputIsMarkedSkippedRatherThanWalked() throws {
        let root = try makeTree()
        defer { try? FileManager.default.removeItem(at: root) }
        let snapshot = FileTreeScanner.scan(FileTreeRoot(label: "Your project", url: root))
        #expect(snapshot.entries.contains { $0.path == ".build (skipped)" })
        #expect(!snapshot.entries.contains { $0.path.hasPrefix(".build/") })
    }

    @Test func depthIsBounded() throws {
        let root = try makeTree()
        defer { try? FileManager.default.removeItem(at: root) }
        let snapshot = FileTreeScanner.scan(
            FileTreeRoot(label: "Your project", url: root, maximumDepth: 1))
        #expect(!snapshot.entries.contains { $0.path.contains("Deeper") })
    }

    /// A truncated listing that doesn't say so reads as a complete one,
    /// which is worse than no listing at all.
    @Test func hittingTheEntryLimitIsSaidOutLoud() throws {
        let root = try makeTree()
        defer { try? FileManager.default.removeItem(at: root) }
        let snapshot = FileTreeScanner.scan(
            FileTreeRoot(label: "Your project", url: root, maximumEntries: 2))
        #expect(snapshot.truncated)
        #expect(snapshot.totalEntriesSeen > snapshot.entries.count)
    }

    @Test func theRootPathIsRedacted() throws {
        let snapshot = FileTreeScanner.scan(FileTreeRoot(
            label: "Home", url: URL(fileURLWithPath: NSHomeDirectory()), maximumDepth: 0,
            maximumEntries: 1))
        #expect(snapshot.rootPath == "~")
    }
}

@Suite("A report is saved before it is sent")
struct ReportArchiveTests {

    @Test func itWritesTheReportTheIssueAndEveryAttachment() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("beacon-archive-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let report = FeedbackReport(
            reporter: Reporter(accountID: "sam@example.com"),
            body: .bug(BugBody(whatHappened: "It went white", expected: "It should save",
                               steps: ["Click Save"], reproducibility: .everyTime)),
            attachments: [Attachment(kind: .screenshot, filename: "shot.png",
                                     data: Data([1, 2, 3, 4]))])
        let submission = ReportSubmission(
            report: report,
            issue: IssueRenderer.render(report, index: nil),
            attachments: report.attachments)

        let saved = try ReportArchive(directory: directory).save(submission)
        #expect(FileManager.default.fileExists(atPath: saved.reportJSON.path))
        #expect(FileManager.default.fileExists(atPath: saved.issueMarkdown.path))
        #expect(saved.attachments.count == 1)
        #expect(try Data(contentsOf: saved.attachments[0]) == Data([1, 2, 3, 4]))

        // The JSON stays readable: bytes live beside it as real files.
        let json = try String(contentsOf: saved.reportJSON, encoding: .utf8)
        #expect(json.contains("shot.png"))
        #expect(!json.contains("AQIDBA"))
    }

    @Test func awkwardFilenamesAreFlattenedBeforeTheyReachDisk() {
        #expect(ReportArchive.safeFilename("../../etc/passwd") == ".._.._etc_passwd")
        #expect(ReportArchive.safeFilename("") == "attachment")
        #expect(ReportArchive.safeFilename("fine name.png") == "fine name.png")
    }
}

@Suite("What machine this is")
@MainActor
struct EnvironmentProbeTests {

    @Test func itFillsInTheThingsATriageNeeds() {
        let snapshot = EnvironmentProbe.snapshot()
        #expect(!snapshot.osVersion.isEmpty)
        #expect(!snapshot.deviceModel.isEmpty)
        #expect(snapshot.deviceModel != "unknown")
        #expect(!snapshot.locale.isEmpty)
        #expect(["arm64", "x86_64"].contains(snapshot.architecture))
        #if os(macOS)
        #expect(snapshot.operatingSystem == "macOS")
        #expect(snapshot.deviceModel.hasPrefix("Mac"))
        #else
        #expect(snapshot.operatingSystem == "iOS")
        // The device, never the architecture the simulator would otherwise
        // report, and never the board name iOS keeps under hw.model.
        #expect(snapshot.deviceModel.hasPrefix("iPhone") || snapshot.deviceModel.hasPrefix("iPad"))
        #expect(snapshot.textSize != nil)
        #expect(snapshot.appearance != nil)
        #endif
    }

    #if os(iOS)
    @Test func theSimulatedDeviceIsReadFromTheEnvironment() {
        #expect(EnvironmentProbe.model(environment: ["SIMULATOR_MODEL_IDENTIFIER": "iPhone17,1"])
                == "iPhone17,1 (Simulator)")
    }
    #endif

    /// Reading availability must never be a model call — this is asked on
    /// every report, including on machines that can't run the model.
    @Test func onDeviceAvailabilityIsAlwaysAnswerable() {
        #expect(!EnvironmentProbe.onDeviceModelDescription().isEmpty)
    }
}
