// Beacon's own mark: a blue chat bubble with a tower drawn in line.
//
// The same artwork, on the same 32-unit grid, as the web button
// (Web/src/icon.ts), so a report button looks the same in a Mac app, an
// iPhone app and a website. It is drawn here rather than taken from
// SF Symbols so nothing about it depends on the host app.

import SwiftUI

/// The bubble, filled.
struct BeaconBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 32
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }
        var path = Path()
        path.move(to: p(6, 5))
        path.addLine(to: p(26, 5))
        path.addArc(tangent1End: p(29, 5), tangent2End: p(29, 8), radius: 3 * s)
        path.addLine(to: p(29, 20))
        path.addArc(tangent1End: p(29, 23), tangent2End: p(26, 23), radius: 3 * s)
        path.addLine(to: p(15, 23))
        path.addLine(to: p(9, 28))
        path.addLine(to: p(9, 23))
        path.addLine(to: p(6, 23))
        path.addArc(tangent1End: p(3, 23), tangent2End: p(3, 20), radius: 3 * s)
        path.addLine(to: p(3, 8))
        path.addArc(tangent1End: p(3, 5), tangent2End: p(6, 5), radius: 3 * s)
        path.closeSubpath()
        return path
    }
}

/// The tower, as strokes.
struct BeaconTowerShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 32
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }
        var path = Path()
        path.move(to: p(13, 21))
        path.addLine(to: p(14.8, 12))
        path.addLine(to: p(17.2, 12))
        path.addLine(to: p(19, 21))
        path.move(to: p(14.2, 16.5))
        path.addLine(to: p(17.8, 16.5))
        path.move(to: p(15, 12))
        path.addLine(to: p(15, 10.4))
        path.addLine(to: p(17, 10.4))
        path.addLine(to: p(17, 12))
        path.move(to: p(16, 8.6))
        path.addLine(to: p(16, 7))
        path.move(to: p(12.6, 9.4))
        path.addLine(to: p(11.4, 8.4))
        path.move(to: p(19.4, 9.4))
        path.addLine(to: p(20.6, 8.4))
        return path
    }
}

/// Beacon's mark at whatever size the host gives it.
public struct BeaconMark: View {
    static let blue = Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255)

    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                BeaconBubbleShape().fill(Self.blue)
                BeaconTowerShape().stroke(
                    .white,
                    style: StrokeStyle(lineWidth: 1.6 * side / 32, lineCap: .round, lineJoin: .round))
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
