// Beacon's own mark: a blue chat bubble with a lighthouse drawn in line.
//
// The same artwork, on the same 32-unit grid, as the web button
// (Brand/beacon-mark.svg, the one source), so a report button looks the same in a Mac app, an
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
        path.move(to: p(6, 4))
        path.addLine(to: p(26, 4))
        path.addArc(tangent1End: p(29, 4), tangent2End: p(29, 7), radius: 3 * s)
        path.addLine(to: p(29, 20))
        path.addArc(tangent1End: p(29, 23), tangent2End: p(26, 23), radius: 3 * s)
        path.addLine(to: p(15.5, 23))
        path.addLine(to: p(9, 28.5))
        path.addLine(to: p(9, 23))
        path.addLine(to: p(6, 23))
        path.addArc(tangent1End: p(3, 23), tangent2End: p(3, 20), radius: 3 * s)
        path.addLine(to: p(3, 7))
        path.addArc(tangent1End: p(3, 4), tangent2End: p(6, 4), radius: 3 * s)
        path.closeSubpath()
        return path
    }
}

/// The lighthouse, as strokes.
struct BeaconTowerShape: Shape {
    static let lineWidth: CGFloat = 1.4

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 32
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }
        var path = Path()
        func line(_ points: (CGFloat, CGFloat)...) {
            path.move(to: p(points[0].0, points[0].1))
            for point in points.dropFirst() { path.addLine(to: p(point.0, point.1)) }
        }
        line((12.8, 20), (14.3, 12.6), (17.7, 12.6), (19.2, 20))
        line((13.6, 16.2), (18.4, 16.2))
        line((13.6, 12.6), (13.6, 9.9), (18.4, 9.9), (18.4, 12.6))
        line((13.2, 9.9), (16, 7.4), (18.8, 9.9))
        line((10, 10.4), (11.9, 10.4))
        line((20.1, 10.4), (22, 10.4))
        line((10.8, 7.8), (12.3, 8.8))
        line((21.2, 7.8), (19.7, 8.8))
        line((11.8, 20), (20.2, 20))
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
                    style: StrokeStyle(lineWidth: BeaconTowerShape.lineWidth * side / 32, lineCap: .round, lineJoin: .round))
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
