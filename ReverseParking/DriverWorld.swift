import SceneKit
import SceneKit.ModelIO
import ModelIO
import UIKit

// World (x, y) maps to scene (x, 0, y). Car local +x is forward, +z is the car's right side.
final class DriverWorld {
    let scene = SCNScene()
    let driverCam: SCNNode
    let rearCam: SCNNode
    let leftMirror: SCNNode
    let rightMirror: SCNNode
    private let own: Sedan
    private let car: SCNNode
    private let staticRoot = SCNNode()
    private var trackNodes: [SCNNode] = []
    private var builtLayout: Layout?

    private static let guideMask = 2
    private static let rearMarkMask = 4

    init() {
        let sedan = Sedan(paint: CarPaint.pearl.uiColor, interior: true, lit: true)
        own = sedan
        car = sedan.node
        Self.light(scene)
        scene.rootNode.addChildNode(staticRoot)
        scene.rootNode.addChildNode(car)

        let half = Float(ParkingModel.length / 2), side = Float(ParkingModel.width / 2)
        driverCam = Self.camera(on: car, at: SCNVector3(0.42, 1.3, -0.4), yaw: -.pi / 2, pitch: -0.06,
                                fov: 72, mask: 1 | Self.guideMask, occlusion: true)
        rearCam = Self.camera(on: car, at: SCNVector3(-half - 0.03, 1.0, 0), yaw: .pi / 2, pitch: -0.55,
                              fov: 100, mask: 1 | Self.guideMask | Self.rearMarkMask, occlusion: true)
        leftMirror = Self.camera(on: car, at: SCNVector3(0.72, 1.12, -side - 0.12), yaw: .pi / 2 - 0.2, pitch: -0.08,
                                 fov: 34, mask: 1)
        rightMirror = Self.camera(on: car, at: SCNVector3(0.72, 1.12, side + 0.12), yaw: .pi / 2 + 0.2, pitch: -0.08,
                                  fov: 34, mask: 1)

        for (distance, color) in [(0.5, UIColor.systemRed), (1.0, .systemYellow), (2.0, .systemGreen)] {
            let mark = Self.overlay(0.07, ParkingModel.width, color, at: SCNVector3(-half - Float(distance), 0.03, 0))
            mark.categoryBitMask = Self.rearMarkMask
            car.addChildNode(mark)
        }
        for z in [-side, side] {
            let line = Self.overlay(2.0, 0.05, UIColor.white.withAlphaComponent(0.85), at: SCNVector3(-half - 1, 0.03, z))
            line.categoryBitMask = Self.rearMarkMask
            car.addChildNode(line)
        }

        for i in 0..<120 {
            let node = Self.overlay(1, 0.08, .systemYellow, at: SCNVector3(0, 0.035, 0))
            node.categoryBitMask = Self.guideMask
            node.opacity = CGFloat(1 - 0.75 * Double(i % 60) / 60)
            scene.rootNode.addChildNode(node)
            trackNodes.append(node)
        }
    }

    // Sky, image-based light from it, and a sun that casts soft shadows over `span` metres around `center`.
    static func light(_ scene: SCNScene, center: SCNVector3 = SCNVector3(12, 0, 7), span: CGFloat = 24) {
        scene.background.contents = sky
        scene.lightingEnvironment.contents = sky
        scene.lightingEnvironment.intensity = 1.15

        let sun = SCNNode()
        let light = SCNLight()
        light.type = .directional
        light.intensity = 2400
        light.color = UIColor(red: 1, green: 0.96, blue: 0.9, alpha: 1)
        light.castsShadow = true
        light.automaticallyAdjustsShadowProjection = false
        light.orthographicScale = span
        light.zNear = 1
        light.zFar = 120
        light.shadowMapSize = CGSize(width: 2048, height: 2048)
        light.shadowSampleCount = 12
        light.shadowRadius = 3
        light.shadowBias = 2
        light.shadowColor = UIColor(white: 0, alpha: 0.85)
        sun.light = light
        sun.position = SCNVector3(center.x - 34, 40, center.z - 26)
        sun.look(at: center)
        scene.rootNode.addChildNode(sun)
    }

    // Equirectangular sky: blue above, pale at the horizon, a few soft clouds, grass colour below.
    private static let sky: UIImage = {
        let size = CGSize(width: 1024, height: 512)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext, space = CGColorSpaceCreateDeviceRGB()
            let stops: [(CGFloat, [CGFloat])] = [
                (0, [0.16, 0.38, 0.8, 1]), (0.4, [0.42, 0.65, 0.95, 1]), (0.495, [0.8, 0.89, 0.98, 1]),
                (0.505, [0.33, 0.4, 0.27, 1]), (1, [0.24, 0.3, 0.2, 1]),
            ]
            let gradient = CGGradient(colorSpace: space, colorComponents: stops.flatMap { $0.1 },
                                      locations: stops.map { $0.0 }, count: stops.count)!
            cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            let cloud = CGGradient(colorSpace: space, colorComponents: [1, 1, 1, 0.75, 1, 1, 1, 0], locations: [0, 1], count: 2)!
            for i in 0..<16 {
                let x = CGFloat((i * 397) % 1024), y = 120 + CGFloat((i * 53) % 110), r = 22 + CGFloat((i * 31) % 26)
                // Drawn three times so clouds wrap around the seam of the image.
                for shift in [-size.width, 0, size.width] {
                    cg.saveGState()
                    cg.translateBy(x: x + shift, y: y)
                    cg.scaleBy(x: 3.2, y: 1)
                    cg.drawRadialGradient(cloud, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: r, options: [])
                    cg.restoreGState()
                }
            }
        }
    }()

    func update(_ model: ParkingModel, showGuide: Bool, paint: CarPaint) {
        if model.layout != builtLayout {
            builtLayout = model.layout
            buildLot(model.layout)
        }

        let p = model.pose
        car.position = SCNVector3(Float(p.x), 0, Float(p.y))
        car.eulerAngles.y = Float(-p.heading)
        own.paint.diffuse.contents = paint.uiColor
        own.paint.metalness.contents = paint.metalness
        own.paint.emission.contents = model.won ? UIColor.systemGreen.withAlphaComponent(0.35)
            : model.collision ? UIColor.systemRed.withAlphaComponent(0.45) : UIColor.black
        own.steer(model.steering)
        own.roll(model.travelled)
        own.lights(braking: model.throttle == 0 || model.gear == 0, reversing: model.gear < 0)

        let dip: Float = model.gear < 0 ? -0.24 : -0.08
        leftMirror.eulerAngles.x = dip
        rightMirror.eulerAngles.x = dip

        let direction = model.gear == 0 ? -1.0 : model.gear
        let show = showGuide && !model.won
        let lx = direction < 0 ? -ParkingModel.length / 2 : ParkingModel.length / 2
        let poses = [p] + model.trajectory(direction: direction)
        for (side, ly) in [-ParkingModel.width / 2, ParkingModel.width / 2].enumerated() {
            let points = poses.map { q in
                Vector(x: q.x + lx * cos(q.heading) - ly * sin(q.heading),
                       y: q.y + lx * sin(q.heading) + ly * cos(q.heading))
            }
            for j in 0..<60 {
                let node = trackNodes[side * 60 + j]
                node.isHidden = !show || j % 2 == 1
                guard show else { continue }
                let a = points[j], b = points[j + 1]
                node.position = SCNVector3(Float((a.x + b.x) / 2), 0.035, Float((a.y + b.y) / 2))
                node.scale = SCNVector3(Float(hypot(b.x - a.x, b.y - a.y)), 1, 1)
                node.eulerAngles.y = Float(-atan2(b.y - a.y, b.x - a.x))
            }
        }
    }

    private func buildLot(_ l: Layout) {
        staticRoot.childNodes.forEach { $0.removeFromParentNode() }
        let add = { (node: SCNNode) in self.staticRoot.addChildNode(node) }
        let concrete = Self.concrete, asphalt = Self.asphalt, paint = Self.linePaint, curb = Self.curb
        let narrow = l.aisleEdge > 1
        let low = narrow ? l.aisleEdge : 0.3
        let back = l.backEdge
        let wallHeight = 1.1

        // Kept to 220 m: a much larger ground plane made the sun's shadows disappear. The sky image continues it.
        let grass = Self.box(220, 0.02, 220, Self.grass, at: SCNVector3(12, -0.03, 8))
        grass.castsShadow = false
        add(grass)
        add(Self.ground(23.4, 15.4, asphalt, at: SCNVector3(12, 0, 8)))

        for b in l.stalls {
            for x in [b.x, b.x + b.width] {
                add(Self.marking(0.12, b.height, paint, at: SCNVector3(Float(x), 0, Float(b.y + b.height / 2))))
            }
            add(Self.marking(b.width + 0.12, 0.12, paint, at: SCNVector3(Float(b.x + b.width / 2), 0, Float(b.y + b.height))))
            if !l.parallel {
                add(Self.box(1.7, 0.1, 0.16, concrete, at: SCNVector3(Float(b.x + b.width / 2), 0.05, Float(b.y + b.height - 0.42)),
                             chamfer: 0.03))
            }
        }
        let t = l.target
        add(Self.overlay(t.width - 0.3, t.height - 0.3, UIColor.systemGreen.withAlphaComponent(0.3),
                         at: SCNVector3(Float(t.x + t.width / 2), 0.012, Float(t.y + t.height / 2))))

        for (i, b) in l.cars.enumerated() {
            add(Self.parkedCar(b, color: ParkedPaint.bay(i)))
        }
        for b in l.pillars {
            let c = SCNVector3(Float(b.x + b.width / 2), 0, Float(b.y + b.height / 2))
            add(Self.box(b.width, 3, b.height, concrete, at: SCNVector3(c.x, 1.5, c.z), chamfer: 0.03))
            add(Self.box(b.width + 0.02, 0.6, b.height + 0.02, Self.hazard, at: SCNVector3(c.x, 0.55, c.z), chamfer: 0.03))
        }

        if narrow {
            // The row across the aisle is another line of bays, all taken.
            add(Self.ground(23.4, 6.2, asphalt, at: SCNVector3(12, 0, Float(l.aisleEdge - 2.8))))
            add(Self.marking(22.4, 0.12, paint, at: SCNVector3(12.2, 0, Float(l.aisleEdge))))
            for k in 0...7 {
                add(Self.marking(0.12, 5.4, paint, at: SCNVector3(Float(1 + 3.2 * Double(k)), 0, Float(l.aisleEdge - 2.7))))
            }
            for (i, x) in stride(from: 1.0, through: 21.0, by: 3.2).enumerated() {
                add(Self.parkedCar(Box(x: x + 0.64, y: l.aisleEdge - 5.0, width: 1.92, height: 4.6),
                                   color: ParkedPaint.row(i), noseDown: true))
            }
            add(Self.box(24, 0.9, 0.5, Self.hedge, at: SCNVector3(12, 0.45, Float(l.aisleEdge - 6.3)), chamfer: 0.1))
        } else {
            add(Self.box(24, wallHeight, 0.2, concrete, at: SCNVector3(12, Float(wallHeight / 2), 0.2)))
        }

        if l.parallel {
            add(Self.box(24, 0.16, 0.2, curb, at: SCNVector3(12, 0.08, Float(back + 0.1)), chamfer: 0.03))
            add(Self.box(24, 0.14, 3, concrete, at: SCNVector3(12, 0.07, Float(back + 1.7))))
        } else {
            add(Self.box(24, wallHeight, 0.2, concrete, at: SCNVector3(12, Float(wallHeight / 2), Float(back + 0.1))))
            add(Self.box(24, 1.3, 0.7, Self.hedge, at: SCNVector3(12, 0.65, Float(back + 0.75)), chamfer: 0.15))
        }

        // Side walls run the full depth, or only along the stall row when that side is an entrance.
        for (open, x, road) in [(l.leftEdge < 0, 0.2, -14.7), (l.rightEdge > 24, 23.8, 38.7)] {
            if open {
                add(Self.box(0.2, wallHeight, back - 9, concrete, at: SCNVector3(Float(x), Float(wallHeight / 2), Float((9 + back) / 2))))
                add(Self.ground(30, 9 - low, asphalt, at: SCNVector3(Float(road), 0, Float((low + 9) / 2))))
                add(Self.box(30, 0.16, 0.2, curb, at: SCNVector3(Float(road), 0.08, 9.1), chamfer: 0.03))
                if narrow {
                    add(Self.box(30, 0.16, 0.2, curb, at: SCNVector3(Float(road), 0.08, Float(l.aisleEdge - 0.1)), chamfer: 0.03))
                }
            } else {
                add(Self.box(0.2, wallHeight, back - 0.3, concrete, at: SCNVector3(Float(x), Float(wallHeight / 2), Float((0.3 + back) / 2))))
            }
        }

        let behind = back + (l.parallel ? 3.6 : 1.6)
        for x in [5.0, 19.0] { add(Self.lamp(at: SCNVector3(Float(x), 0, Float(behind)))) }
        let far = narrow ? l.aisleEdge - 9 : -3.5
        for (i, x) in stride(from: -9.0, through: 33.0, by: 6).enumerated() {
            add(Self.tree(at: SCNVector3(Float(x), 0, Float(behind + 3 + Double(i % 2))), size: 1 + 0.25 * Double(i % 3)))
            add(Self.tree(at: SCNVector3(Float(x + 3), 0, Float(far - Double(i % 2))), size: 1.15 - 0.2 * Double(i % 3)))
        }
        for (i, x) in [-14.0, 3.0, 21.0, 38.0].enumerated() {
            add(Self.building(16, [14.0, 22.0, 17.0, 26.0][i], 12, at: SCNVector3(Float(x), 0, Float(behind + 26))))
            add(Self.building(15, [20.0, 12.0, 24.0, 16.0][i], 12, at: SCNVector3(Float(x + 5), 0, Float(far - 26))))
        }
    }

    private static let grass = Sedan.surface(UIColor(red: 0.23, green: 0.33, blue: 0.16, alpha: 1), roughness: 1)
    private static let hedge = Sedan.surface(UIColor(red: 0.1, green: 0.22, blue: 0.09, alpha: 1), roughness: 1)
    private static let leaves = Sedan.surface(UIColor(red: 0.14, green: 0.3, blue: 0.11, alpha: 1), roughness: 1)
    private static let bark = Sedan.surface(UIColor(red: 0.2, green: 0.14, blue: 0.1, alpha: 1), roughness: 1)
    private static let linePaint = Sedan.surface(UIColor(white: 0.85, alpha: 1), roughness: 0.6)
    private static let curb = Sedan.surface(UIColor(red: 0.85, green: 0.65, blue: 0.05, alpha: 1), roughness: 0.7)
    private static let hazard = Sedan.surface(UIColor(red: 0.9, green: 0.45, blue: 0.05, alpha: 1), roughness: 0.6)
    private static let steel = Sedan.surface(UIColor(white: 0.3, alpha: 1), roughness: 0.4, metalness: 1)

    private static let concrete: SCNMaterial = {
        let m = Sedan.surface(.white, roughness: 0.9)
        m.diffuse.contents = speckled(base: 0.6, spread: 0.07, count: 5000)
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        m.diffuse.mipFilter = .linear
        return m
    }()

    private static let asphalt: SCNMaterial = {
        let m = Sedan.surface(.white, roughness: 0.92)
        m.diffuse.contents = speckled(base: 0.17, spread: 0.1, count: 14000)
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        m.diffuse.mipFilter = .linear
        m.diffuse.maxAnisotropy = 8
        return m
    }()

    private static let facade: SCNMaterial = {
        let size = CGSize(width: 64, height: 64)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 0.62, green: 0.6, blue: 0.57, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.2, green: 0.28, blue: 0.36, alpha: 1).setFill()
            context.fill(CGRect(x: 10, y: 14, width: 44, height: 36))
        }
        let m = Sedan.surface(.white, roughness: 0.7)
        m.diffuse.contents = image
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        m.diffuse.mipFilter = .linear
        return m
    }()

    // Grey noise tile for ground and concrete.
    private static func speckled(base: CGFloat, spread: CGFloat, count: Int) -> UIImage {
        let size = CGSize(width: 256, height: 256)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        var seed: UInt64 = 88172645463325252
        func random() -> CGFloat {
            seed ^= seed << 13
            seed ^= seed >> 7
            seed ^= seed << 17
            return CGFloat(seed % 10000) / 10000
        }
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(white: base, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            for _ in 0..<count {
                UIColor(white: base + (random() - 0.5) * 2 * spread, alpha: 1).setFill()
                let side = 1 + random() * 2
                context.fill(CGRect(x: random() * 256, y: random() * 256, width: side, height: side))
            }
        }
    }

    private static func box(_ w: Double, _ h: Double, _ l: Double, _ material: SCNMaterial, at position: SCNVector3,
                            chamfer: Double = 0) -> SCNNode {
        let geometry = SCNBox(width: w, height: h, length: l, chamferRadius: chamfer)
        if material === concrete, max(w, l) > 3 {
            let tiled = material.copy() as! SCNMaterial
            tiled.diffuse.contentsTransform = SCNMatrix4MakeScale(Float(max(w, l) / 2), Float(max(h, 1) / 2), 1)
            geometry.materials = [tiled]
        } else {
            geometry.materials = [material]
        }
        let node = SCNNode(geometry: geometry)
        node.position = position
        return node
    }

    // Flat slab of ground, with the noise tile repeated so it stays sharp up close.
    private static func ground(_ w: Double, _ l: Double, _ material: SCNMaterial, at position: SCNVector3) -> SCNNode {
        let tiled = material.copy() as! SCNMaterial
        tiled.diffuse.contentsTransform = SCNMatrix4MakeScale(Float(w / 1.2), Float(l / 1.2), 1)
        let node = box(w, 0.01, l, tiled, at: position)
        node.castsShadow = false
        return node
    }

    private static func marking(_ w: Double, _ l: Double, _ material: SCNMaterial, at position: SCNVector3) -> SCNNode {
        let node = box(w, 0.01, l, material, at: SCNVector3(position.x, 0.008, position.z))
        node.castsShadow = false
        return node
    }

    // Unlit helper drawn on the ground: guide lines, distance marks, the target bay.
    private static func overlay(_ w: Double, _ l: Double, _ color: UIColor, at position: SCNVector3) -> SCNNode {
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = color
        material.writesToDepthBuffer = false
        let node = box(w, 0.005, l, material, at: position)
        node.castsShadow = false
        node.renderingOrder = 10
        return node
    }

    private static func lamp(at position: SCNVector3) -> SCNNode {
        let node = SCNNode()
        node.position = position
        let pole = SCNNode(geometry: SCNCylinder(radius: 0.07, height: 5.5))
        pole.geometry?.materials = [steel]
        pole.position.y = 2.75
        node.addChildNode(pole)
        node.addChildNode(box(0.25, 0.08, 1.4, steel, at: SCNVector3(0, 5.5, -0.6)))
        let glow = SCNMaterial()
        glow.lightingModel = .constant
        glow.diffuse.contents = UIColor(white: 0.95, alpha: 1)
        node.addChildNode(box(0.2, 0.03, 0.5, glow, at: SCNVector3(0, 5.45, -1.0)))
        return node
    }

    private static func tree(at position: SCNVector3, size: Double) -> SCNNode {
        let node = SCNNode()
        node.position = position
        node.scale = SCNVector3(Float(size), Float(size), Float(size))
        let trunk = SCNNode(geometry: SCNCylinder(radius: 0.14, height: 2.4))
        trunk.geometry?.materials = [bark]
        trunk.position.y = 1.2
        node.addChildNode(trunk)
        for (x, y, z, r) in [(0.0, 3.2, 0.0, 1.5), (0.8, 2.7, 0.3, 1.0), (-0.7, 2.8, -0.4, 1.1), (0.1, 4.1, 0.2, 1.0)] {
            let sphere = SCNSphere(radius: r)
            sphere.segmentCount = 14
            sphere.materials = [leaves]
            let blob = SCNNode(geometry: sphere)
            blob.position = SCNVector3(Float(x), Float(y), Float(z))
            node.addChildNode(blob)
        }
        return node
    }

    private static func building(_ w: Double, _ h: Double, _ l: Double, at position: SCNVector3) -> SCNNode {
        let wall = facade.copy() as! SCNMaterial
        wall.diffuse.contentsTransform = SCNMatrix4MakeScale(Float(w / 3), Float(h / 3), 1)
        let node = box(w, h, l, wall, at: SCNVector3(position.x, Float(h / 2), position.z))
        node.castsShadow = false
        return node
    }

    // Perpendicular cars face the aisle; cars in a parallel row face +x.
    private static func parkedCar(_ b: Box, color: UIColor, noseDown: Bool = false) -> SCNNode {
        let car = Sedan(paint: color, length: max(b.width, b.height), width: min(b.width, b.height)).node
        car.position = SCNVector3(Float(b.x + b.width / 2), 0, Float(b.y + b.height / 2))
        if b.height > b.width { car.eulerAngles.y = noseDown ? -.pi / 2 : .pi / 2 }
        return car
    }

    private static func camera(on car: SCNNode, at position: SCNVector3, yaw: Float, pitch: Float,
                               fov: CGFloat, mask: Int, occlusion: Bool = false) -> SCNNode {
        let mount = SCNNode()
        mount.position = position
        mount.eulerAngles.y = yaw
        car.addChildNode(mount)
        let node = SCNNode()
        node.camera = lens(fov: fov, occlusion: occlusion)
        node.camera?.categoryBitMask = mask
        node.eulerAngles.x = pitch
        mount.addChildNode(node)
        return node
    }

    static func lens(fov: CGFloat, occlusion: Bool) -> SCNCamera {
        let camera = SCNCamera()
        camera.fieldOfView = fov
        camera.zNear = 0.1
        camera.zFar = 400
        camera.wantsHDR = true
        camera.wantsExposureAdaptation = false
        camera.exposureOffset = -0.2
        camera.bloomIntensity = 0.3
        camera.bloomThreshold = 1
        if occlusion {
            camera.screenSpaceAmbientOcclusionIntensity = 0.7
            camera.screenSpaceAmbientOcclusionRadius = 0.5
        }
        return camera
    }
}
