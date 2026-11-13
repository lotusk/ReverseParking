import SceneKit
import UIKit

// Body shell of a 4.75 x 1.92 m crossover, lofted from cross-sections along the car.
// Local +x is forward, +y is up, +z is the car's right side. Only the right half is described; the left is mirrored.
enum CarMesh {
    static let half = 2.375
    static let axles = [1.495, -1.395]
    static let wheelRadius = 0.36
    static let track = 0.80
    private static let archRadius = 0.43

    enum Part: Int, CaseIterable {
        case paint, glass, trim, headlight, taillight, reverseLight, under
    }

    static let body = build()

    private typealias Point = (z: Double, y: Double)

    private struct Station {
        let x, w, y0, yd, h, lo, squeeze: Double
        let arch: Bool
    }

    // Hermite curve through the keys, with slopes taken from the neighbours.
    private static func curve(_ keys: [(Double, Double)]) -> (Double) -> Double {
        func slope(_ k: Int) -> Double {
            let a = keys[max(k - 1, 0)], b = keys[min(k + 1, keys.count - 1)]
            return (b.1 - a.1) / (b.0 - a.0)
        }
        return { t in
            guard let i = keys.lastIndex(where: { $0.0 <= t }) else { return keys[0].1 }
            guard i + 1 < keys.count else { return keys[i].1 }
            let (t0, v0) = keys[i], (t1, v1) = keys[i + 1]
            let span = t1 - t0, u = (t - t0) / span
            let m0 = slope(i) * span, m1 = slope(i + 1) * span
            let u2 = u * u, u3 = u2 * u
            return (2 * u3 - 3 * u2 + 1) * v0 + (u3 - 2 * u2 + u) * m0 + (3 * u2 - 2 * u3) * v1 + (u3 - u2) * m1
        }
    }

    // Height of the hood, belt line and tail, and of the roof above them.
    private static let deck = curve([(-2.375, 0.98), (-2.2, 1.04), (-1.6, 1.06), (-0.5, 1.03), (0.95, 1.02),
                                     (1.5, 0.94), (2.0, 0.82), (2.3, 0.72), (2.375, 0.68)])
    private static let roof = curve([(-2.2, 1.05), (-2.0, 1.17), (-1.5, 1.40), (-0.9, 1.55), (-0.3, 1.60),
                                     (0.2, 1.54), (0.6, 1.30), (0.95, 1.02)])

    private static func station(_ x: Double) -> Station {
        let u = min(1, abs(x) / half)
        let yd = deck(x)
        var lo = 0.19 + 0.13 * pow(u, 8), arch = false
        let y0 = lo
        for a in axles where abs(x - a) <= archRadius + 1e-9 {
            lo = wheelRadius + max(0, archRadius * archRadius - (x - a) * (x - a)).squareRoot()
            arch = true
        }
        return Station(x: x, w: 0.96 * pow(max(0, 1 - pow(u, 5)), 0.2), y0: y0, yd: yd,
                       h: x > -2.2 && x < 0.95 ? max(0, roof(x) - yd) : 0, lo: lo,
                       squeeze: pow(max(0, 1 - pow(u, 16)), 1.0 / 3), arch: arch)
    }

    private static let stations: [Station] = {
        var xs = (0...72).map { -half * cos(.pi * Double($0) / 72) }
        for a in axles {
            xs += (0...24).map { a + archRadius * cos(.pi * Double($0) / 24) }
            xs += [a - archRadius - 0.006, a + archRadius + 0.006]
        }
        // Edges of the lamps, windows and trim, so they come out straight.
        xs += [-2.36, -2.33, -2.25, -2.12, -2.0, -1.75, -1.15, -1.05, 0.12, 0.22, 0.55, 0.9, 1.95, 2.30, 2.32]
        xs.sort()
        var kept: [Double] = []
        for x in xs where kept.isEmpty || x - kept[kept.count - 1] > 1e-4 { kept.append(x) }
        return kept.map(station)
    }()

    private static func side(_ s: Station, _ y: Double) -> Double {
        let tuck = max(0, 1 - (y - s.y0) / 0.3)
        let lean = max(0, (y - s.y0 - 0.45) / max(0.1, s.yd - s.y0 - 0.45))
        return s.w * (1 - 0.10 * tuck * tuck - 0.05 * lean * lean)
    }

    private static func squeezed(_ s: Station, _ ring: [Point]) -> [Point] {
        ring.map { ($0.z, 0.56 + ($0.y - 0.56) * s.squeeze) }
    }

    // From the arch lip (or sill) up the side, over the window and across the roof to the centre line.
    private static func skin(_ s: Station) -> [Point] {
        var ring: [Point] = [0, 0.1, 0.25, 0.45, 0.65, 0.82, 0.94, 1].map { f in
            let y = s.lo + (s.yd - s.lo) * f
            return (side(s, y), y)
        }
        let t = min(1, s.h / 0.12), cab = t * t * (3 - 2 * t)
        let rail = s.w * 0.74
        func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * cab }
        ring += [
            (mix(0.88 * s.w, 0.925 * s.w), s.yd + mix(0.014, 0.03)),
            (mix(0.78 * s.w, (0.925 * s.w + rail) / 2), s.yd + mix(0.03, 0.5 * s.h)),
            (mix(0.64 * s.w, rail + 0.012), s.yd + mix(0.044, s.h - 0.07)),
            (mix(0.48 * s.w, 0.92 * rail), s.yd + mix(0.054, s.h - 0.02)),
            (mix(0.32 * s.w, 0.6 * rail), s.yd + mix(0.061, s.h + 0.02)),
            (mix(0.16 * s.w, 0.3 * rail), s.yd + mix(0.065, s.h + 0.035)),
            (0, s.yd + mix(0.066, s.h + 0.04)),
        ]
        return squeezed(s, ring)
    }

    // Floor, and inside an arch the wheel well.
    private static func under(_ s: Station) -> [Point] {
        let lip = side(s, s.lo)
        let wall = s.arch ? max(0, s.w - 0.42) : lip * 0.9
        return squeezed(s, [(0, s.y0), (wall, s.y0), (wall, s.lo), (lip, s.lo)])
    }

    private static func part(_ x: Double, _ k: Int) -> Part {
        switch k {
        case 0: return .trim
        case 1: if x > 2.30 || x < -2.25 { return .trim }
        case 2: if x > 2.30 { return .trim }
        case 4: if x < -2.33 { return .reverseLight }
        case 5, 6:
            if x > 1.95 && x < 2.32 { return .headlight }
            if x < -2.12 { return .taillight }
        case 8, 9: if x > -1.75 && x < 0.55 { return .glass }
        case 11...13:
            if (x > 0.22 && x < 0.9) || (x > -1.05 && x < 0.12) || (x > -2.0 && x < -1.15) { return .glass }
        default: break
        }
        return .paint
    }

    private static func build() -> SCNGeometry {
        var positions: [SCNVector3] = [], normals: [SCNVector3] = []
        var indices = [[UInt32]](repeating: [], count: Part.allCases.count)

        func grid(_ rings: [[Point]], part: (Double, Int) -> Part) {
            let rows = rings.count, columns = rings[0].count
            let points = rings.enumerated().map { i, ring in
                ring.map { SIMD3(stations[i].x, $0.y, $0.z) }
            }
            var sums = [[SIMD3<Double>]](repeating: [SIMD3<Double>](repeating: .zero, count: columns), count: rows)
            for i in 0..<rows - 1 {
                for k in 0..<columns - 1 {
                    let face = cross(points[i + 1][k + 1] - points[i][k], points[i][k + 1] - points[i + 1][k])
                    for (a, b) in [(i, k), (i + 1, k), (i + 1, k + 1), (i, k + 1)] { sums[a][b] += face }
                }
            }
            for mirror in [1.0, -1.0] {
                let base = UInt32(positions.count)
                for i in 0..<rows {
                    for k in 0..<columns {
                        let p = points[i][k]
                        var n = sums[i][k]
                        if p.z == 0 { n.z = 0 }
                        n = simd_length(n) > 1e-12 ? simd_normalize(n) : SIMD3(0, 1, 0)
                        positions.append(SCNVector3(Float(p.x), Float(p.y), Float(p.z * mirror)))
                        normals.append(SCNVector3(Float(n.x), Float(n.y), Float(n.z * mirror)))
                    }
                }
                for i in 0..<rows - 1 {
                    let x = (stations[i].x + stations[i + 1].x) / 2
                    for k in 0..<columns - 1 {
                        let a = base + UInt32(i * columns + k), b = a + UInt32(columns)
                        let quad = mirror > 0 ? [a, b, b + 1, a, b + 1, a + 1] : [a, b + 1, b, a, a + 1, b + 1]
                        indices[part(x, k).rawValue] += quad
                    }
                }
            }
        }

        grid(stations.map(skin), part: part)
        grid(stations.map(under)) { _, _ in .under }

        return SCNGeometry(sources: [SCNGeometrySource(vertices: positions), SCNGeometrySource(normals: normals)],
                           elements: indices.map { SCNGeometryElement(indices: $0, primitiveType: .triangles) })
    }
}

struct Sedan {
    let node = SCNNode()
    let paint = Sedan.surface(.white, roughness: 0.4, metalness: 0.2)
    private let tail = SCNMaterial()
    private let reverse = SCNMaterial()
    private var steered: [SCNNode] = []
    private var rolling: [SCNNode] = []

    private static let glass = surface(UIColor(red: 0.03, green: 0.04, blue: 0.05, alpha: 1), roughness: 0.03, metalness: 0.6)
    private static let trim = surface(UIColor(white: 0.03, alpha: 1), roughness: 0.6)
    private static let dark = surface(UIColor(white: 0.015, alpha: 1), roughness: 1)
    private static let rubber = surface(UIColor(white: 0.025, alpha: 1), roughness: 0.9)
    private static let alloy = surface(UIColor(white: 0.62, alpha: 1), roughness: 0.28, metalness: 1)
    private static let headlight = lamp(UIColor(white: 0.9, alpha: 1), glow: UIColor(white: 1, alpha: 1), intensity: 1.2)
    private static let lens = surface(UIColor(white: 0.75, alpha: 1), roughness: 0.12, metalness: 0.4)

    private static let tire: SCNGeometry = {
        let tube = SCNTube(innerRadius: 0.235, outerRadius: CGFloat(CarMesh.wheelRadius), height: 0.255)
        tube.radialSegmentCount = 40
        tube.materials = [rubber]
        return tube
    }()

    private static let rim: SCNGeometry = {
        let path = UIBezierPath(arcCenter: .zero, radius: 0.24, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        let step = 2 * CGFloat.pi / 5
        for i in 0..<5 {
            let a = CGFloat(i) * step
            let hole = UIBezierPath()
            hole.addArc(withCenter: .zero, radius: 0.205, startAngle: a + 0.2, endAngle: a + step - 0.2, clockwise: true)
            hole.addArc(withCenter: .zero, radius: 0.085, startAngle: a + step - 0.45, endAngle: a + 0.45, clockwise: false)
            hole.close()
            path.append(hole)
        }
        path.usesEvenOddFillRule = true
        path.flatness = 0.004
        let shape = SCNShape(path: path, extrusionDepth: 0.03)
        shape.materials = [alloy]
        return shape
    }()

    private static let hub: SCNGeometry = {
        let disc = SCNCylinder(radius: 0.236, height: 0.02)
        disc.materials = [surface(UIColor(white: 0.12, alpha: 1), roughness: 0.5, metalness: 0.8)]
        return disc
    }()

    init(paint color: UIColor, length: Double = ParkingModel.length, width: Double = ParkingModel.width,
         metalness: Double = 0.2, interior: Bool = false, lit: Bool = false) {
        let shell = SCNNode()
        shell.scale = SCNVector3(Float(length / 4.75), 1, Float(width / 1.92))
        node.addChildNode(shell)

        paint.diffuse.contents = color
        paint.metalness.contents = metalness
        paint.clearCoat.contents = 0.3
        paint.clearCoatRoughness.contents = 0.08
        Self.setLamp(tail, UIColor(red: 0.3, green: 0.01, blue: 0.02, alpha: 1), glow: UIColor(red: 1, green: 0.05, blue: 0.05, alpha: 1),
                     intensity: lit ? 0.6 : 0)
        Self.setLamp(reverse, UIColor(white: 0.2, alpha: 1), glow: .black, intensity: 1.5)

        let body = SCNNode(geometry: CarMesh.body.copy() as? SCNGeometry)
        body.geometry?.materials = [paint, Self.glass, Self.trim, lit ? Self.headlight : Self.lens, tail, reverse, Self.dark]
        shell.addChildNode(body)

        for (index, x) in CarMesh.axles.enumerated() {
            for side in [-1.0, 1.0] {
                let pivot = SCNNode()
                pivot.position = SCNVector3(Float(x), Float(CarMesh.wheelRadius), Float(side * CarMesh.track))
                let spin = SCNNode()
                let tire = SCNNode(geometry: Self.tire)
                tire.eulerAngles.x = .pi / 2
                let rim = SCNNode(geometry: Self.rim)
                rim.position.z = Float(side * 0.095)
                let hub = SCNNode(geometry: Self.hub)
                hub.eulerAngles.x = .pi / 2
                hub.position.z = Float(side * 0.06)
                for part in [tire, rim, hub] { spin.addChildNode(part) }
                pivot.addChildNode(spin)
                shell.addChildNode(pivot)
                rolling.append(spin)
                if index == 0 { steered.append(pivot) }
            }
        }

        for side in [-1.0, 1.0] {
            let housing = SCNNode(geometry: SCNBox(width: 0.1, height: 0.15, length: 0.26, chamferRadius: 0.04))
            housing.geometry?.materials = [paint]
            housing.position = SCNVector3(0.8, 1.12, Float(side * 0.99))
            shell.addChildNode(housing)
        }

        if interior {
            let dash = SCNNode(geometry: SCNBox(width: 0.95, height: 0.3, length: 1.7, chamferRadius: 0.04))
            dash.geometry?.materials = [Self.surface(UIColor(white: 0.05, alpha: 1), roughness: 0.85)]
            dash.position = SCNVector3(0.545, 0.95, 0)
            dash.castsShadow = false
            shell.addChildNode(dash)
        }
    }

    func steer(_ steering: Double) {
        for wheel in steered { wheel.eulerAngles.y = Float(-steering * .pi / 5) }
    }

    func roll(_ travelled: Double) {
        let angle = Float(-travelled / CarMesh.wheelRadius)
        for wheel in rolling { wheel.eulerAngles.z = angle }
    }

    func lights(braking: Bool, reversing: Bool) {
        tail.emission.intensity = braking ? 2.4 : 0.6
        reverse.emission.contents = reversing ? UIColor.white : UIColor.black
    }

    static func surface(_ color: UIColor, roughness: Double, metalness: Double = 0) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = color
        m.roughness.contents = roughness
        m.metalness.contents = metalness
        return m
    }

    private static func lamp(_ color: UIColor, glow: UIColor, intensity: CGFloat) -> SCNMaterial {
        let m = SCNMaterial()
        setLamp(m, color, glow: glow, intensity: intensity)
        return m
    }

    private static func setLamp(_ m: SCNMaterial, _ color: UIColor, glow: UIColor, intensity: CGFloat) {
        m.lightingModel = .physicallyBased
        m.diffuse.contents = color
        m.roughness.contents = 0.15
        m.emission.contents = glow
        m.emission.intensity = intensity
    }
}
