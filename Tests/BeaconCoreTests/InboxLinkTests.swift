import Testing
import Foundation
@testable import BeaconCore

struct InboxLinkTests {
    let inbox = BeaconInbox(page: URL(string: "https://example.com/inbox")!,
                           repository: "your-org/harbour")
    let app = AppIdentity(name: "Harbour", bundleIdentifier: "ca.upcoast.harbour",
                          version: "1.4.2", build: "318", commit: "abc123")
    let environment = EnvironmentSnapshot(operatingSystem: "macOS", osVersion: "26.1",
                                          deviceModel: "Mac15,3", architecture: "arm64",
                                          locale: "en_CA", timeZone: "America/Vancouver")

    func items(_ url: URL) -> [String: String] {
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        return Dictionary(uniqueKeysWithValues: (comps.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    }

    @Test func carriesTheMachineHalfOfTheReport() {
        let url = inbox.url(for: app, environment: environment,
                            reporter: Reporter(accountID: "sam@example.com", displayName: "Sam"),
                            area: "Settings")
        let q = items(url)
        #expect(url.absoluteString.hasPrefix("https://example.com/inbox?"))
        #expect(q["app"] == "Harbour")
        #expect(q["version"] == "1.4.2")
        #expect(q["build"] == "318")
        #expect(q["commit"] == "abc123")
        #expect(q["repo"] == "your-org/harbour")
        #expect(q["os"] == "macOS")
        #expect(q["osVersion"] == "26.1")
        #expect(q["device"] == "Mac15,3")
        #expect(q["reporter"] == "Sam <sam@example.com>")
        #expect(q["area"] == "Settings")
    }

    @Test func leavesUnknownsOutRatherThanSendingBlanks() {
        let url = inbox.url(for: AppIdentity(name: "Harbour"), environment: EnvironmentSnapshot())
        let q = items(url)
        #expect(q["app"] == "Harbour")
        #expect(q["commit"] == nil)
        #expect(q["reporter"] == nil)
        #expect(q["appearance"] == nil)
        #expect(!url.absoluteString.contains("="+"&"))
    }

    @Test func keepsQueryThePageAlreadyHad() {
        let sticky = BeaconInbox(page: URL(string: "https://example.com/inbox?theme=dark")!,
                                repository: "your-org/harbour")
        let q = items(sticky.url(for: app, environment: environment))
        #expect(q["theme"] == "dark")
        #expect(q["app"] == "Harbour")
    }

    @Test func everyKeyIsOneThePageReads() {
        // The page's contract, copied from Inbox/index.html's `ctx` block.
        let pageReads: Set<String> = ["app","bundle","version","build","commit","repo","os",
                                      "osVersion","device","arch","locale","tz","appearance",
                                      "textSize","reporter","area"]
        #expect(Set(BeaconInbox.Key.allCases.map(\.rawValue)) == pageReads)
    }
}
