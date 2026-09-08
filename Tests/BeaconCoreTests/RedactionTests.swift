// The last thing that runs before a report becomes a public-ish artefact.

import Testing
import Foundation
@testable import BeaconCore

@Suite("Secrets never reach the issue")
struct RedactionTests {

    /// The prefixes are split from their bodies so this file never contains
    /// a literal that looks like a real credential. These are invented, but
    /// a repository's own push protection cannot tell that, and a test file
    /// that trips it blocks every push.
    @Test("Known credential shapes are caught", arguments: [
        "sk-" + "ant-api03-AAAABBBBCCCCDDDDEEEEFFFFGGGG",
        "ghp" + "_ABCDEFGHIJKLMNOPQRSTUVWXYZ012345",
        "github" + "_pat_11ABCDEFG0abcdefghijklmnop",
        "AKI" + "AIOSFODNN7EXAMPLE",
        "xoxb" + "-123456789012-abcdefghijklmno",
        "sk_" + "live_ABCDEFGHIJKLMNOPQRSTUVWX",
    ])
    func credentialShapesAreMasked(_ secret: String) {
        let result = Redactor().sweep("my key is \(secret) ok", location: "your log")
        #expect(!result.text.contains(secret))
        #expect(result.text.contains(Redactor.mask))
        #expect(!result.findings.isEmpty)
    }

    @Test func hostSuppliedSecretsAreCaughtEvenWhenTheyLookLikeNothing() {
        let redactor = Redactor(hostSecrets: ["hunter2-correct-horse"])
        let result = redactor.sweep("password was hunter2-correct-horse",
                                    location: "your settings")
        #expect(!result.text.contains("hunter2-correct-horse"))
        #expect(result.findings.count == 1)
    }

    /// A short host "secret" would fire inside ordinary words and make the
    /// whole screen look broken.
    @Test func veryShortHostSecretsAreIgnored() {
        let redactor = Redactor(hostSecrets: ["cat"])
        let result = redactor.sweep("the catalogue is fine", location: "your log")
        #expect(result.text == "the catalogue is fine")
        #expect(result.findings.isEmpty)
    }

    @Test func ordinaryProseIsLeftAlone() {
        let text = "I clicked Save and the window went white. My project is called Harbour."
        let result = Redactor().sweep(text, location: "your report")
        #expect(result.text == text)
        #expect(result.findings.isEmpty)
    }

    @Test func passwordsInSettingLinesAreCaught() {
        let result = Redactor().sweep("api_key = 8f3a9c2e5b7d1f4a", location: "your settings")
        #expect(result.text.contains(Redactor.mask))
    }

    @Test func urlsCarryingCredentialsAreCaught() {
        let result = Redactor().sweep("https://sam:s3cretpass@example.com/repo.git",
                                      location: "your log")
        #expect(!result.text.contains("s3cretpass"))
    }

    @Test func textAttachmentsAreSweptAndBinariesAreLeftAlone() {
        let redactor = Redactor()
        let text = Attachment(kind: .userFile, filename: "config.json",
                              data: Data(("{\"token\":\"ghp" + "_ABCDEFGHIJKLMNOPQRSTUVWXYZ012345\"}").utf8))
        let sweptText = redactor.sweep(text)
        #expect(!sweptText.findings.isEmpty)
        #expect(!String(data: sweptText.attachment.data, encoding: .utf8)!.contains("ghp_"))

        let binary = Attachment(kind: .screenshot, filename: "shot.png",
                                data: Data([0x89, 0x50, 0x4E, 0x47]))
        let sweptBinary = redactor.sweep(binary)
        #expect(sweptBinary.attachment.data == binary.data)
        #expect(sweptBinary.findings.isEmpty)
    }

    @Test func theHomeDirectoryBecomesATilde() {
        let path = Redactor.redactHome("/Users/sam/Documents/Harbour", home: "/Users/sam")
        #expect(path == "~/Documents/Harbour")
        #expect(Redactor.redactHome("/Users/sam", home: "/Users/sam") == "~")
        #expect(Redactor.redactHome("/opt/tools", home: "/Users/sam") == "/opt/tools")
    }
}

@Suite("Which files we accept, and why")
struct AcceptedFormatTests {

    @Test("Formats the triaging assistant can read are accepted",
          arguments: ["notes.txt", "log.log", "state.json", "shot.png", "scan.pdf", "clip.mov"])
    func accepted(_ name: String) {
        #expect(AcceptedFormats.accepts(URL(fileURLWithPath: "/tmp/\(name)")))
    }

    @Test("Formats nobody downstream can read are refused",
          arguments: ["archive.zip", "app.dmg", "sheet.xlsx", "binary.bin", "noextension"])
    func refused(_ name: String) {
        let url = URL(fileURLWithPath: "/tmp/\(name)")
        #expect(!AcceptedFormats.accepts(url))
        // A refusal always says what to do instead.
        #expect(AcceptedFormats.refusal(for: url).contains("screenshot"))
    }
}

@Suite("Consent")
struct ConsentTests {

    @Test func acceptanceIsPerVersionSoRewordingAsksAgain() {
        let defaults = UserDefaults(suiteName: "beacon.tests.\(UUID().uuidString)")!
        let store = UserDefaultsConsentStore(defaults: defaults)
        let notice = ConsentNotice.current

        #expect(store.needsAcceptance(accountID: "sam", notice: notice))
        store.save(ConsentRecord(acceptedVersion: notice.version,
                                 acceptedAt: Date(), accountID: "sam"))
        #expect(!store.needsAcceptance(accountID: "sam", notice: notice))

        let reworded = ConsentNotice(version: "2099-01-01.1", headline: notice.headline,
                                     points: notice.points, acceptButton: notice.acceptButton)
        #expect(store.needsAcceptance(accountID: "sam", notice: reworded))
    }

    @Test func acceptanceIsPerPerson() {
        let defaults = UserDefaults(suiteName: "beacon.tests.\(UUID().uuidString)")!
        let store = UserDefaultsConsentStore(defaults: defaults)
        store.save(ConsentRecord(acceptedVersion: ConsentNotice.current.version,
                                 acceptedAt: Date(), accountID: "sam"))
        #expect(store.needsAcceptance(accountID: "alex"))
    }

    @Test func theNoticeNamesTheOrganisationAndSaysItIsNotAnonymous() {
        let notice = ConsentNotice.current.naming("the Harbour team")
        #expect(notice.points.contains { $0.contains("the Harbour team") })
        #expect(notice.points.contains { $0.contains("not anonymous") })
        #expect(notice.points.contains { $0.contains("GitHub") })
        #expect(!notice.points.contains { $0.contains("$ORG") })
    }
}

@Suite("The app map")
struct BeaconIndexTests {

    @Test func roundTripsThroughJSON() throws {
        let index = BeaconIndex(appName: "Harbour", commit: "abc123", areas: [
            IndexedArea(id: "settings", name: "Settings", paths: ["Sources/Settings"],
                        screens: [IndexedScreen(id: "general", name: "General",
                                                symbol: "GeneralView",
                                                path: "Sources/Settings/GeneralView.swift")]),
        ])
        let decoded = try BeaconIndex.decode(index.encoded())
        #expect(decoded.appName == "Harbour")
        #expect(decoded.areas.first?.screens.first?.symbol == "GeneralView")
    }

    @Test func aMapFromANewerBeaconIsRefusedRatherThanMisread() throws {
        let json = #"{"schemaVersion":99,"generatedAt":"2026-08-23T00:00:00Z","appName":"X","areas":[]}"#
        #expect(throws: BeaconIndex.LoadError.self) {
            try BeaconIndex.decode(Data(json.utf8))
        }
    }

    @Test func hiddenAreasAreRoutableButNotOffered() {
        let index = BeaconIndex(areas: [
            IndexedArea(id: "plumbing", name: "Plumbing", hiddenFromReporters: true),
            IndexedArea(id: "settings", name: "Settings"),
        ])
        #expect(index.reporterAreas.map(\.id) == ["settings"])
        #expect(index.area(id: "plumbing") != nil)
    }

    @Test func theSentinelsAlwaysRenderAName() {
        let index = BeaconIndex(areas: [])
        #expect(index.displayName(forAreaID: BeaconIndex.unsureAreaID) == "Not sure")
        #expect(index.displayName(forAreaID: BeaconIndex.newAreaID) == "Something new")
        #expect(index.displayName(forAreaID: nil) == "Not said")
    }
}
