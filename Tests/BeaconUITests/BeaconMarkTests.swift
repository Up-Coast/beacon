import Testing
import SwiftUI
@testable import BeaconUI

@Suite struct BeaconMarkTests {
    @Test func bubbleFillsTheGridTheWebButtonUses() {
        let box = BeaconBubbleShape().path(in: CGRect(x: 0, y: 0, width: 32, height: 32)).boundingRect
        #expect(abs(box.minX - 3) < 0.01)
        #expect(abs(box.maxX - 29) < 0.01)
        #expect(abs(box.minY - 5) < 0.01)
        #expect(abs(box.maxY - 28) < 0.01)
    }

    @Test func towerSitsInsideTheBubble() {
        let rect = CGRect(x: 0, y: 0, width: 32, height: 32)
        let bubble = BeaconBubbleShape().path(in: rect).boundingRect
        let tower = BeaconTowerShape().path(in: rect).boundingRect
        #expect(bubble.contains(tower))
    }

    @Test func markScalesWithItsFrame() {
        let small = BeaconBubbleShape().path(in: CGRect(x: 0, y: 0, width: 16, height: 16)).boundingRect
        #expect(abs(small.maxX - 14.5) < 0.01)
    }
}
