import Foundation

struct Vector: Equatable {
    var x: Double
    var y: Double
}

struct Pose {
    var x = 17.0
    var y = 6.0
    var heading = 0.0 // Screen coordinates: positive rotation is clockwise.
}

struct Box {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var corners: [Vector] {
        [Vector(x: x, y: y), Vector(x: x + width, y: y),
         Vector(x: x + width, y: y + height), Vector(x: x, y: y + height)]
    }
}

struct ParkingModel {
    static let length = 4.2
    static let width = 1.8
    static let wheelbase = 2.6
    static let target = Box(x: 10, y: 9, width: 3.2, height: 6)
    static let obstacles = [Box(x: 6.5, y: 10, width: 1.8, height: 4.2),
                            Box(x: 15, y: 10, width: 1.8, height: 4.2)]
    var pose = Pose()
    var aisleEdge = 0.3
    var rightEdge = 23.7
    var steering = 0.0
    var gear = 0.0
    var driving = false
    var collision = false
    var won = false
    var distance = 0.0

    static func corners(_ p: Pose) -> [Vector] {
        [(-length / 2, -width / 2), (length / 2, -width / 2),
         (length / 2, width / 2), (-length / 2, width / 2)].map { a, b in
            Vector(x: p.x + a * cos(p.heading) - b * sin(p.heading),
                   y: p.y + a * sin(p.heading) + b * cos(p.heading))
        }
    }

    static func overlaps(_ a: [Vector], _ b: [Vector]) -> Bool {
        for polygon in [a, b] {
            for i in polygon.indices {
                let p = polygon[i], q = polygon[(i + 1) % polygon.count]
                let axis = Vector(x: -(q.y - p.y), y: q.x - p.x)
                let pa = a.map { $0.x * axis.x + $0.y * axis.y }
                let pb = b.map { $0.x * axis.x + $0.y * axis.y }
                if pa.max()! < pb.min()! || pb.max()! < pa.min()! { return false }
            }
        }
        return true
    }

    static func blocked(_ p: Pose, aisleEdge: Double = 0.3, rightEdge: Double = 23.7) -> Bool {
        let points = corners(p)
        return points.contains { $0.x < 0.3 || $0.x > rightEdge || ($0.x > 23.7 && $0.y > 9) || $0.y < aisleEdge || $0.y > 15.7 }
            || obstacles.contains { overlaps(points, $0.corners) }
    }

    static func parked(_ p: Pose) -> Bool {
        let t = target
        let alignment = abs(cos(p.heading)) < sin(8 * Double.pi / 180)
        return alignment && corners(p).allSatisfy {
            $0.x > t.x + 0.1 && $0.x < t.x + t.width - 0.1 &&
            $0.y > t.y + 0.1 && $0.y < t.y + t.height - 0.1
        }
    }

    static func advanced(_ p: Pose, steering: Double, travel: Double) -> Pose {
        let turn = travel / wheelbase * tan(max(-1, min(1, steering)) * .pi / 5)
        return Pose(x: p.x + travel * cos(p.heading + turn / 2),
                    y: p.y + travel * sin(p.heading + turn / 2), heading: p.heading + turn)
    }

    mutating func step(_ dt: Double) {
        guard !won else { driving = false; return }
        guard driving else {
            won = Self.parked(pose)
            return
        }
        let travel = gear * 1.0 * max(0, min(dt, 0.04))
        let candidate = Self.advanced(pose, steering: steering, travel: travel)
        collision = Self.blocked(candidate, aisleEdge: aisleEdge, rightEdge: rightEdge)
        if collision { driving = false; return }
        pose = candidate
        distance += abs(travel)
    }

    var onLine: Bool {
        let t = Self.target
        return Self.corners(pose).contains {
            $0.y > t.y && ($0.x < t.x || $0.x > t.x + t.width)
        } && pose.x > t.x - 1 && pose.x < t.x + t.width + 1
    }

    func trajectory(direction: Double) -> [Pose] {
        var p = pose
        return (0..<60).map { _ in
            p = Self.advanced(p, steering: steering, travel: direction * 0.10)
            return p
        }
    }
}

struct Scenario: Identifiable, Hashable {
    let name: String
    let hint: String
    let start: Pose
    let aisleEdge: Double
    var rightEdge = 23.7
    var id: String { name }

    static func == (a: Scenario, b: Scenario) -> Bool { a.name == b.name }
    func hash(into hasher: inout Hasher) { hasher.combine(name) }

    static let all = [
        Scenario(name: "从右侧开进来", hint: "车位在左手边，开过车位找好位置停下再倒",
                 start: Pose(x: 26, y: 6, heading: .pi), aisleEdge: 3.0, rightEdge: 31),
        Scenario(name: "标准：停在车位旁", hint: "打满方向直接倒进去",
                 start: Pose(x: 17, y: 6, heading: 0), aisleEdge: 0.3),
        Scenario(name: "停过头了", hint: "直接倒进不去，先往前打方向摆一下车头",
                 start: Pose(x: 10, y: 6.7, heading: .pi), aisleEdge: 3.0),
        Scenario(name: "车位在右，停太近", hint: "直接倒进不去，先往前修一下",
                 start: Pose(x: 13, y: 6.2, heading: 0), aisleEdge: 3.0),
        Scenario(name: "窄通道标准位", hint: "通道窄，倒车时注意车头别碰对面",
                 start: Pose(x: 16, y: 6, heading: 0), aisleEdge: 3.0),
    ]
}

extension ParkingModel {
    init(scenario: Scenario) {
        self.init()
        pose = scenario.start
        aisleEdge = scenario.aisleEdge
        rightEdge = scenario.rightEdge
    }
}
