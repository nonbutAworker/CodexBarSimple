import SwiftUI

// Geometry from TRAE Copy.zip/assets/icons/bell.svg, in its original 24 × 24 view box.
struct TraeBell: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 6, y: 8))
        path.addArc(
            center: CGPoint(x: 12, y: 8), radius: 6,
            startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        path.addCurve(
            to: CGPoint(x: 21, y: 16),
            control1: CGPoint(x: 18, y: 15), control2: CGPoint(x: 21, y: 16))
        path.addLine(to: CGPoint(x: 3, y: 16))
        path.addCurve(
            to: CGPoint(x: 6, y: 8),
            control1: CGPoint(x: 3, y: 16), control2: CGPoint(x: 6, y: 15))
        path.closeSubpath()
        path.move(to: CGPoint(x: 10, y: 21))
        path.addArc(
            center: CGPoint(x: 12, y: 21), radius: 2,
            startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true)
        return path.applying(
            CGAffineTransform(a: rect.width / 24, b: 0, c: 0, d: rect.height / 24, tx: rect.minX, ty: rect.minY))
    }
}

enum ResetBellMotion {
    static let duration: TimeInterval = 60

    static func rotation(at elapsed: TimeInterval) -> Double {
        guard elapsed >= 0, elapsed < self.duration else { return 0 }
        let envelope = min(1, elapsed / 0.2, (self.duration - elapsed) / 0.2)
        return 18 * envelope * sin(elapsed * 2 * .pi / 0.8)
    }
}
