import SceneKit
import UIKit

// World (x, y) maps to scene (x, 0, y). Car local +x is forward, +z is the car's right side.
final class DriverWorld {
    let scene = SCNScene()
    let driverCam: SCNNode
    let rearCam: SCNNode
    let leftMirror: SCNNode
    let rightMirror: SCNNode
    private let car = SCNNode()
    private let bodyMaterial = SCNMaterial()
    private let staticRoot = SCNNode()
    private var trackNodes: [SCNNode] = []
    private var builtLayout: Layout?

    private static let guideMask = 2
    private static let rearMarkMask = 4

    init() {
        scene.background.contents = UIColor(red: 0.62, green: 0.72, blue: 0.82, alpha: 1)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 550
        scene.rootNode.addChildNode(ambient)
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 750
        sun.eulerAngles = SCNVector3(-1.0, 0.6, 0)
        scene.rootNode.addChildNode(sun)
        scene.rootNode.addChildNode(staticRoot)

        bodyMaterial.diffuse.contents = UIColor.systemCyan
        let body = SCNNode(geometry: SCNBox(width: 4.2, height: 0.8, length: 1.8, chamferRadius: 0.12))
        body.geometry?.materials = [bodyMaterial]
        body.position = SCNVector3(0, 0.5, 0)
        car.addChildNode(body)
        car.addChildNode(Self.box(2.2, 0.5, 1.6, UIColor(white: 0.12, alpha: 1), at: SCNVector3(-0.2, 1.15, 0)))
        car.addChildNode(Self.box(0.6, 0.1, 1.7, UIColor(white: 0.2, alpha: 1), at: SCNVector3(0.65, 0.93, 0)))
        scene.rootNode.addChildNode(car)

        driverCam = Self.camera(on: car, at: SCNVector3(0.1, 1.25, -0.4), yaw: -.pi / 2, pitch: -0.1,
                                fov: 75, mask: 1 | Self.guideMask)
        rearCam = Self.camera(on: car, at: SCNVector3(-2.15, 1.0, 0), yaw: .pi / 2, pitch: -0.6,
                              fov: 100, mask: 1 | Self.guideMask | Self.rearMarkMask)
        leftMirror = Self.camera(on: car, at: SCNVector3(0.9, 1.05, -1.2), yaw: .pi / 2 - 0.22, pitch: -0.08,
                                 fov: 34, mask: 1)
        rightMirror = Self.camera(on: car, at: SCNVector3(0.9, 1.05, 1.2), yaw: .pi / 2 + 0.22, pitch: -0.08,
                                  fov: 34, mask: 1)

        for (distance, color) in [(0.5, UIColor.systemRed), (1.0, .systemYellow), (2.0, .systemGreen)] {
            let mark = Self.box(0.06, 0.01, 1.8, color, at: SCNVector3(-2.1 - distance, 0.02, 0))
            mark.categoryBitMask = Self.rearMarkMask
            car.addChildNode(mark)
        }
        for z in [-0.9, 0.9] {
            let side = Self.box(2.0, 0.01, 0.05, UIColor.white.withAlphaComponent(0.8), at: SCNVector3(-3.1, 0.02, z))
            side.categoryBitMask = Self.rearMarkMask
            car.addChildNode(side)
        }

        for _ in 0..<120 {
            let node = Self.box(1, 0.01, 0.07, .systemYellow, at: SCNVector3(0, 0.025, 0))
            node.categoryBitMask = Self.guideMask
            scene.rootNode.addChildNode(node)
            trackNodes.append(node)
        }
    }

    func update(_ model: ParkingModel, showGuide: Bool) {
        if model.layout != builtLayout {
            builtLayout = model.layout
            buildLot(model.layout)
        }

        let p = model.pose
        car.position = SCNVector3(Float(p.x), 0, Float(p.y))
        car.eulerAngles.y = Float(-p.heading)
        bodyMaterial.diffuse.contents = model.won ? UIColor.systemGreen : model.collision ? UIColor.systemRed : UIColor.systemCyan

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
                node.position = SCNVector3(Float((a.x + b.x) / 2), 0.025, Float((a.y + b.y) / 2))
                node.scale = SCNVector3(Float(hypot(b.x - a.x, b.y - a.y)), 1, 1)
                node.eulerAngles.y = Float(-atan2(b.y - a.y, b.x - a.x))
            }
        }
    }

    private func buildLot(_ l: Layout) {
        staticRoot.childNodes.forEach { $0.removeFromParentNode() }
        let add = { (node: SCNNode) in self.staticRoot.addChildNode(node) }
        let concrete = UIColor(white: 0.62, alpha: 1)
        let asphalt = UIColor(white: 0.24, alpha: 1)
        let line = UIColor(white: 0.95, alpha: 1)
        let low = l.aisleEdge > 1 ? l.aisleEdge : 0.3
        let back = l.backEdge
        let wallHeight = 1.2

        add(Self.box(160, 0.02, 160, UIColor(red: 0.36, green: 0.42, blue: 0.34, alpha: 1), at: SCNVector3(12, -0.02, 8)))
        add(Self.box(23.4, 0.01, 15.4, asphalt, at: SCNVector3(12, 0, 8)))

        for b in l.stalls {
            for x in [b.x, b.x + b.width] {
                add(Self.box(0.12, 0.01, b.height, line, at: SCNVector3(Float(x), 0.008, Float(b.y + b.height / 2))))
            }
            add(Self.box(b.width + 0.12, 0.01, 0.12, line, at: SCNVector3(Float(b.x + b.width / 2), 0.008, Float(b.y + b.height))))
        }
        let t = l.target
        add(Self.box(t.width - 0.2, 0.005, t.height - 0.2, UIColor.systemGreen.withAlphaComponent(0.35),
                     at: SCNVector3(Float(t.x + t.width / 2), 0.006, Float(t.y + t.height / 2))))

        let colors: [UIColor] = [.systemGray, .systemBrown, .white, .darkGray, .systemBlue, .systemGray2, .black, .systemRed]
        for (i, b) in l.cars.enumerated() {
            add(Self.parkedCar(b, color: colors[i % colors.count]))
        }
        for b in l.pillars {
            let c = SCNVector3(Float(b.x + b.width / 2), 0, Float(b.y + b.height / 2))
            add(Self.box(b.width, 3, b.height, concrete, at: SCNVector3(c.x, 1.5, c.z)))
            add(Self.box(b.width + 0.02, 0.5, b.height + 0.02, .systemOrange, at: SCNVector3(c.x, 0.5, c.z)))
        }

        if l.aisleEdge > 1 {
            add(Self.box(24, 0.18, 0.2, .systemYellow, at: SCNVector3(12, 0.09, Float(l.aisleEdge - 0.1))))
            for (i, x) in stride(from: 1.0, through: 21.0, by: 3.2).enumerated() {
                add(Self.parkedCar(Box(x: x + 0.7, y: l.aisleEdge - 4.4, width: 1.8, height: 4.0),
                                   color: colors[(i + 2) % colors.count]))
            }
        } else {
            add(Self.box(24, wallHeight, 0.2, concrete, at: SCNVector3(12, 0.6, 0.2)))
        }

        if l.parallel {
            add(Self.box(24, 0.18, 0.2, .systemYellow, at: SCNVector3(12, 0.09, Float(back + 0.1))))
            add(Self.box(24, 0.15, 3, concrete, at: SCNVector3(12, 0.075, Float(back + 1.7))))
        } else {
            add(Self.box(24, wallHeight, 0.2, concrete, at: SCNVector3(12, 0.6, Float(back + 0.1))))
        }

        // Side walls run the full depth, or only along the stall row when that side is an entrance.
        for (open, x, road) in [(l.leftEdge < 0, 0.2, -14.7), (l.rightEdge > 24, 23.8, 38.7)] {
            if open {
                add(Self.box(0.2, wallHeight, back - 9, concrete, at: SCNVector3(Float(x), 0.6, Float((9 + back) / 2))))
                add(Self.box(30, 0.01, 9 - low, asphalt, at: SCNVector3(Float(road), 0, Float((low + 9) / 2))))
                add(Self.box(30, 0.18, 0.2, .systemYellow, at: SCNVector3(Float(road), 0.09, 9.1)))
                if l.aisleEdge > 1 {
                    add(Self.box(30, 0.18, 0.2, .systemYellow, at: SCNVector3(Float(road), 0.09, Float(l.aisleEdge - 0.1))))
                }
            } else {
                add(Self.box(0.2, wallHeight, back - 0.3, concrete, at: SCNVector3(Float(x), 0.6, Float((0.3 + back) / 2))))
            }
        }
    }

    private static func box(_ w: Double, _ h: Double, _ l: Double, _ color: UIColor, at position: SCNVector3) -> SCNNode {
        let material = SCNMaterial()
        material.diffuse.contents = color
        let geometry = SCNBox(width: w, height: h, length: l, chamferRadius: 0)
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry)
        node.position = position
        return node
    }

    private static func parkedCar(_ b: Box, color: UIColor) -> SCNNode {
        let node = SCNNode()
        node.position = SCNVector3(Float(b.x + b.width / 2), 0, Float(b.y + b.height / 2))
        let along = b.width > b.height
        node.addChildNode(box(b.width, 0.8, b.height, color, at: SCNVector3(0, 0.5, 0)))
        node.addChildNode(box(along ? b.width * 0.5 : b.width - 0.2, 0.5, along ? b.height - 0.2 : b.height * 0.5,
                              UIColor(white: 0.15, alpha: 1), at: SCNVector3(0, 1.15, 0)))
        return node
    }

    private static func camera(on car: SCNNode, at position: SCNVector3, yaw: Float, pitch: Float,
                               fov: CGFloat, mask: Int) -> SCNNode {
        let mount = SCNNode()
        mount.position = position
        mount.eulerAngles.y = yaw
        car.addChildNode(mount)
        let node = SCNNode()
        node.camera = SCNCamera()
        node.camera?.fieldOfView = fov
        node.camera?.zNear = 0.05
        node.camera?.zFar = 200
        node.camera?.categoryBitMask = mask
        node.eulerAngles.x = pitch
        mount.addChildNode(node)
        return node
    }
}
