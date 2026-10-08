// Beacon's own mark: a blue speech bubble, tail at the bottom right, with a
// lighthouse drawn in line.
//
// The same artwork, on the same 64-unit grid, as the web button
// (Brand/beacon-mark.svg, the one source), so a report button looks the same
// in a Mac app, an iPhone app and a website. It is drawn here rather than
// taken from SF Symbols so nothing about it depends on the host app.

import SwiftUI

/// Maps the 64 x 64 drawing grid onto a rect.
private struct MarkGrid {
    let rect: CGRect
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + x / 64 * rect.width, y: rect.minY + y / 64 * rect.height)
    }
    func length(_ units: CGFloat) -> CGFloat { units / 64 * min(rect.width, rect.height) }
}

/// The bubble, filled: a rounded body and a small tail at the bottom right.
struct BeaconBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let g = MarkGrid(rect: rect)
        let body = CGRect(x: g.point(2, 2).x, y: g.point(2, 2).y,
                          width: g.point(62, 2).x - g.point(2, 2).x,
                          height: g.point(2, 50).y - g.point(2, 2).y)
        var path = Path(roundedRect: body, cornerRadius: g.length(14), style: .continuous)
        var tail = Path()
        tail.move(to: g.point(40, 49))
        tail.addLine(to: g.point(54, 62))
        tail.addLine(to: g.point(52, 49))
        tail.closeSubpath()
        path.addPath(tail)
        return path
    }
}

/// The lighthouse, as strokes: a roof cap, an open lantern room wider than the
/// tower, a gallery line, the tower (two sides, one stripe, a base line) and
/// four short rays. Stroke it with round caps and joins.
struct BeaconTowerShape: Shape {
    /// Stroke width on the 64-unit grid.
    static let lineWidth: CGFloat = 1.75

    func path(in rect: CGRect) -> Path {
        let g = MarkGrid(rect: rect)
        var p = Path()
        func line(_ a: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat)) {
            p.move(to: g.point(a.0, a.1))
            p.addLine(to: g.point(b.0, b.1))
        }
        p.move(to: g.point(26, 13))
        p.addLine(to: g.point(32, 7.5))
        p.addLine(to: g.point(38, 13))
        p.closeSubpath()
        p.addRect(CGRect(x: g.point(27, 16).x, y: g.point(27, 16).y,
                         width: g.point(37, 16).x - g.point(27, 16).x,
                         height: g.point(27, 24).y - g.point(27, 16).y))
        line((24.5, 27.5), (39.5, 27.5))
        line((29.5, 27.5), (25.5, 44))
        line((34.5, 27.5), (38.5, 44))
        line((26.2, 36.5), (37.8, 36.5))
        line((22.5, 44), (41.5, 44))
        line((24.5, 18), (20.5, 15.5)); line((39.5, 18), (43.5, 15.5))
        line((24.5, 22.5), (20.5, 21)); line((39.5, 22.5), (43.5, 21))
        return p
    }
}

/// The light inside the lantern room: a small solid dot.
struct BeaconLightShape: Shape {
    func path(in rect: CGRect) -> Path {
        let g = MarkGrid(rect: rect)
        let r = g.length(2.4)
        let c = g.point(32, 20)
        return Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }
}

/// Beacon's mark at whatever size the host gives it.
public struct BeaconMark: View {
    static let blue = Color(red: 47 / 255, green: 111 / 255, blue: 237 / 255)

    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                BeaconBubbleShape().fill(Self.blue)
                BeaconTowerShape().stroke(
                    .white,
                    style: StrokeStyle(lineWidth: BeaconTowerShape.lineWidth * side / 64, lineCap: .round, lineJoin: .round))
                BeaconLightShape().fill(.white)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
