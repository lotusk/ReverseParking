import SwiftUI
import SceneKit

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
}

// Top view of a sedan in the style of a Model 3, drawn in metres around the car centre.
// Car-local x points forward, y points to the car's right.
func drawSedan(_ context: GraphicsContext, at center: CGPoint, heading: Double, scale: CGFloat,
               paint: Color, steering: Double = 0, reversing: Bool = false, outline: Color? = nil) {
    var c = context
    c.translateBy(x: center.x, y: center.y)
    c.rotate(by: .radians(heading))
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

struct Sedan {
    let node = SCNNode()
    let bodyMaterial = SCNMaterial()
    private(set) var frontWheels: [SCNNode] = []

    private static let bodyShape: SCNShape = {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: -2.04, y: 0.26))
        p.addLine(to: CGPoint(x: -2.1, y: 0.55))
        p.addQuadCurve(to: CGPoint(x: -1.92, y: 0.93), controlPoint: CGPoint(x: -2.12, y: 0.88))
        p.addLine(to: CGPoint(x: -1.5, y: 0.97))
        p.addLine(to: CGPoint(x: 1.15, y: 0.92))
        p.addQuadCurve(to: CGPoint(x: 2.06, y: 0.6), controlPoint: CGPoint(x: 1.88, y: 0.9))
        p.addQuadCurve(to: CGPoint(x: 1.98, y: 0.26), controlPoint: CGPoint(x: 2.14, y: 0.4))
        p.close()
        p.flatness = 0.01
        let shape = SCNShape(path: p, extrusionDepth: 1.8)
        shape.chamferRadius = 0.12
        return shape
    }()

    private static let glassShape: SCNShape = {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: -1.52, y: 0.93))
        p.addQuadCurve(to: CGPoint(x: -0.55, y: 1.42), controlPoint: CGPoint(x: -1.05, y: 1.32))
        p.addQuadCurve(to: CGPoint(x: 0.35, y: 1.43), controlPoint: CGPoint(x: -0.1, y: 1.49))
        p.addLine(to: CGPoint(x: 1.2, y: 0.92))
        p.close()
        p.flatness = 0.01
        let shape = SCNShape(path: p, extrusionDepth: 1.5)
        shape.chamferRadius = 0.14
        return shape
    }()

    init(paint: UIColor, interior: Bool = false) {
        bodyMaterial.diffuse.contents = paint
        bodyMaterial.specular.contents = UIColor(white: 0.7, alpha: 1)
        bodyMaterial.shininess = 0.5
        let body = SCNNode(geometry: Self.bodyShape.copy() as? SCNGeometry)
        body.geometry?.materials = [bodyMaterial]
        node.addChildNode(body)

        let glass = SCNMaterial()
        glass.diffuse.contents = UIColor(red: 0.04, green: 0.05, blue: 0.07, alpha: 1)
        glass.specular.contents = UIColor(white: 0.9, alpha: 1)
        glass.shininess = 0.8
        let roof = SCNNode(geometry: Self.glassShape.copy() as? SCNGeometry)
        roof.geometry?.materials = [glass]
        node.addChildNode(roof)

        let tire = SCNMaterial()
        tire.diffuse.contents = UIColor(white: 0.06, alpha: 1)
        let rim = SCNMaterial()
        rim.diffuse.contents = UIColor(white: 0.55, alpha: 1)
        rim.specular.contents = UIColor.white
        for x in [1.3, -1.3] {
            for z in [-0.8, 0.8] {
                let pivot = SCNNode()
                pivot.position = SCNVector3(Float(x), 0.34, Float(z))
                let wheel = SCNNode(geometry: SCNCylinder(radius: 0.34, height: 0.24))
                wheel.geometry?.materials = [tire]
                wheel.eulerAngles.x = .pi / 2
                let cap = SCNNode(geometry: SCNCylinder(radius: 0.24, height: 0.25))
                cap.geometry?.materials = [rim]
                wheel.addChildNode(cap)
                pivot.addChildNode(wheel)
                node.addChildNode(pivot)
                if x > 0 { frontWheels.append(pivot) }
            }
        }

        let head = Self.material(.white, glow: true)
        for z in [-0.58, 0.58] {
            let lamp = SCNNode(geometry: SCNBox(width: 0.06, height: 0.05, length: 0.36, chamferRadius: 0.02))
            lamp.geometry?.materials = [head]
            lamp.position = SCNVector3(2.0, 0.68, Float(z))
            lamp.eulerAngles.y = Float(z > 0 ? 0.35 : -0.35)
            node.addChildNode(lamp)
        }
        let tail = SCNNode(geometry: SCNBox(width: 0.05, height: 0.06, length: 1.55, chamferRadius: 0.02))
        tail.geometry?.materials = [Self.material(UIColor(red: 0.9, green: 0.05, blue: 0.08, alpha: 1), glow: true)]
        tail.position = SCNVector3(-2.08, 0.8, 0)
        node.addChildNode(tail)

        if interior {
            let dash = SCNNode(geometry: SCNBox(width: 0.55, height: 0.06, length: 1.6, chamferRadius: 0.03))
            dash.geometry?.materials = [Self.material(UIColor(white: 0.12, alpha: 1))]
            dash.position = SCNVector3(0.68, 0.97, 0)
            node.addChildNode(dash)
            let screen = SCNNode(geometry: SCNBox(width: 0.02, height: 0.19, length: 0.32, chamferRadius: 0.01))
            screen.geometry?.materials = [Self.material(UIColor(red: 0.12, green: 0.17, blue: 0.24, alpha: 1), glow: true)]
            screen.position = SCNVector3(0.72, 1.06, 0.05)
            screen.eulerAngles.z = 0.25
            node.addChildNode(screen)
        }
    }

    func steer(_ steering: Double) {
        for wheel in frontWheels { wheel.eulerAngles.y = Float(-steering * .pi / 5) }
    }

    private static func material(_ color: UIColor, glow: Bool = false) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        if glow { m.emission.contents = color }
        return m
    }
}
