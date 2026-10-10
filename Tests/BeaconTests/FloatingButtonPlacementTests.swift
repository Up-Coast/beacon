import CoreGraphics
import Testing
@testable import Beacon

@Suite("Where the floating button rests")
@MainActor
struct FloatingButtonPlacementTests {

    @Test func withNoOffsetTheButtonRestsAtTheMarginFromTheCorner() {
        let inset = FloatingReportButton.restingInset(bottomOffset: 0)
        #expect(inset == CGSize(width: FloatingReportButton.margin, height: FloatingReportButton.margin))
    }

    /// The point of the option: a host with a bar along the bottom of its
    /// window lifts the button clear of it, and only upward.
    @Test func theBottomOffsetRaisesTheButtonAndLeavesItsSideAlone() {
        let inset = FloatingReportButton.restingInset(bottomOffset: 30)
        #expect(inset.width == FloatingReportButton.margin)
        #expect(inset.height == FloatingReportButton.margin + 30)
    }

    @Test func aNegativeOffsetNeverPushesTheButtonBelowItsUsualSpot() {
        #expect(FloatingReportButton.restingInset(bottomOffset: -50).height == FloatingReportButton.margin)
    }
}
