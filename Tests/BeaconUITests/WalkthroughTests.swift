import Testing
import BeaconCore
@testable import BeaconUI

/// The first card is where a new tester learns how to report at all, so it
/// shows the button itself and says to press it.
@Suite struct WalkthroughTests {
    @Test func theFirstCardShowsTheReportButtonAndSaysToPressIt() throws {
        let first = try #require(BeaconWalkthrough(appName: "Neori").pages.first)
        #expect(first.symbol == nil, "nil draws Beacon's own mark, the button testers press")
        #expect(first.title.contains("\(PlatformWording.press) this button"))
        #expect(first.body.contains("corner"))
    }

    @Test func withoutTheFloatingButtonItPointsAtTheHostsOwnButton() throws {
        let first = try #require(
            BeaconWalkthrough(appName: "Neori", showsFloatingButton: false).pages.first)
        #expect(first.symbol == nil)
        #expect(!first.body.contains("corner"))
        #expect(first.body.contains("Report a problem"))
    }
}
