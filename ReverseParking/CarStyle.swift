import SwiftUI

enum CarPaint: String, CaseIterable, Identifiable {
    case pearl, silver, blue, red, black
    var id: String { rawValue }

    var name: String {
        switch self {
        case .pearl: "珍珠白"
        case .silver: "冷光银"
        case .blue: "深海蓝"
        case .red: "烈焰红"
        case .black: "曜石黑"
        }
    }

    var uiColor: UIColor {
        switch self {
        case .pearl: UIColor(red: 0.93, green: 0.93, blue: 0.91, alpha: 1)
        case .silver: UIColor(red: 0.66, green: 0.68, blue: 0.70, alpha: 1)
        case .blue: UIColor(red: 0.10, green: 0.22, blue: 0.48, alpha: 1)
        case .red: UIColor(red: 0.70, green: 0.06, blue: 0.08, alpha: 1)
        case .black: UIColor(white: 0.08, alpha: 1)
        }
    }

    var color: Color { Color(uiColor: uiColor) }

    var metalness: Double {
        switch self {
        case .pearl: 0.05
        case .silver: 0.85
        case .blue: 0.6
        case .red: 0.4
        case .black: 0.5
        }
    }
}

// Shared by the top view and the 3D view so each parked car has the same colour in both.
enum ParkedPaint {
    static let all: [UIColor] = [
        UIColor(white: 0.55, alpha: 1), UIColor(red: 0.45, green: 0.32, blue: 0.22, alpha: 1), UIColor(white: 0.95, alpha: 1),
        UIColor(white: 0.25, alpha: 1), UIColor(red: 0.2, green: 0.35, blue: 0.6, alpha: 1), UIColor(white: 0.75, alpha: 1),
        UIColor(white: 0.1, alpha: 1), UIColor(red: 0.6, green: 0.1, blue: 0.1, alpha: 1),
    ]
    static func bay(_ i: Int) -> UIColor { all[i % all.count] }
    static func row(_ i: Int) -> UIColor { all[(i + 2) % all.count] }
}

// Top view of the car, drawn in metres around the car centre.
// Car-local x points forward, y points to the car's right.
func drawSedan(_ context: GraphicsContext, at center: CGPoint, heading: Double, scale: CGFloat,
               paint: Color, steering: Double = 0, reversing: Bool = false, outline: Color? = nil,
               length: Double = ParkingModel.length, width: Double = ParkingModel.width) {
    var c = context
    c.translateBy(x: center.x, y: center.y)
    c.rotate(by: .radians(heading))
    c.scaleBy(x: length / 4.2, y: width / 1.8)
    func rect(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> CGRect {
        CGRect(x: x0 * scale, y: y0 * scale, width: (x1 - x0) * scale, height: (y1 - y0) * scale)
    }

    for (x, steers) in [(1.3, true), (-1.3, false)] {
        for y in [-0.84, 0.84] {
            var tire = c
            tire.translateBy(x: x * scale, y: y * scale)
            if steers { tire.rotate(by: .radians(steering * .pi / 5)) }
            tire.fill(Path(roundedRect: rect(-0.34, -0.12, 0.34, 0.12), cornerRadius: 0.06 * scale),
                      with: .color(Color(white: 0.06)))
        }
    }

    let body = UnevenRoundedRectangle(topLeadingRadius: 0.45 * scale, bottomLeadingRadius: 0.45 * scale,
                                      bottomTrailingRadius: 0.75 * scale, topTrailingRadius: 0.75 * scale)
        .path(in: rect(-2.1, -0.9, 2.1, 0.9))
    c.fill(body, with: .color(paint))
    c.fill(body, with: .linearGradient(Gradient(colors: [.white.opacity(0.18), .clear, .black.opacity(0.18)]),
                                       startPoint: CGPoint(x: 0, y: -0.9 * scale), endPoint: CGPoint(x: 0, y: 0.9 * scale)))
    c.stroke(body, with: .color(outline ?? .black.opacity(0.35)), lineWidth: outline == nil ? 1 : 3)

    for y in [-1.0, 0.86] {
        c.fill(Path(roundedRect: rect(0.62, y, 0.86, y + 0.14), cornerRadius: 0.05 * scale), with: .color(paint))
    }

    let roof = Path(roundedRect: rect(-1.38, -0.7, 0.98, 0.7), cornerRadius: 0.42 * scale)
    c.fill(roof, with: .linearGradient(Gradient(colors: [Color(white: 0.04), Color(red: 0.12, green: 0.16, blue: 0.22)]),
                                       startPoint: CGPoint(x: -1.38 * scale, y: 0), endPoint: CGPoint(x: 0.98 * scale, y: 0)))
    c.stroke(Path(CGRect(x: -0.1 * scale, y: -0.7 * scale, width: 0.06 * scale, height: 1.4 * scale)),
             with: .color(paint.opacity(0.5)), lineWidth: 0.5)

    for y in [-0.74, 0.54] {
        c.fill(Path(roundedRect: rect(1.82, y, 2.02, y + 0.2), cornerRadius: 0.06 * scale), with: .color(.white.opacity(0.9)))
    }
    c.fill(Path(roundedRect: rect(-2.09, -0.76, -1.99, 0.76), cornerRadius: 0.04 * scale), with: .color(Color(red: 0.85, green: 0.05, blue: 0.08)))
    if reversing {
        for y in [-0.5, 0.35] {
            c.fill(Path(rect(-2.09, y, -1.99, y + 0.15)), with: .color(.white))
        }
    }
}
