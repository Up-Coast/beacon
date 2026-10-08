import Testing
import SwiftUI
@testable import BeaconUI

@Suite struct BeaconMarkTests {
    @Test func bubbleFillsTheGridTheWebButtonUses() {
        let box = BeaconBubbleShape().path(in: CGRect(x: 0, y: 0, width: 64, height: 64)).boundingRect
        #expect(abs(box.minX - 2) < 0.01)
        #expect(abs(box.maxX - 62) < 0.01)
        #expect(abs(box.minY - 2) < 0.01)
        #expect(abs(box.maxY - 62) < 0.01)
    }

    @Test func tailIsAtTheBottomRight() {
        let rect = CGRect(x: 0, y: 0, width: 64, height: 64)
        let tail = BeaconBubbleShape().path(in: rect)
        #expect(tail.contains(CGPoint(x: 52, y: 55)))
        #expect(!tail.contains(CGPoint(x: 12, y: 55)))
    }

    @Test func lighthouseSitsInsideTheBubble() {
        let rect = CGRect(x: 0, y: 0, width: 64, height: 64)
        let bubble = BeaconBubbleShape().path(in: rect).boundingRect
        let tower = BeaconTowerShape().path(in: rect).boundingRect
        #expect(bubble.contains(tower))
    }

    @Test func markScalesWithItsFrame() {
        let small = BeaconBubbleShape().path(in: CGRect(x: 0, y: 0, width: 32, height: 32)).boundingRect
        #expect(abs(small.maxX - 31) < 0.01)
    }
}
