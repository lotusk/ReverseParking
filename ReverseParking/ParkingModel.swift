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

struct Box: Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var corners: [Vector] {
        [Vector(x: x, y: y), Vector(x: x + width, y: y),
         Vector(x: x + width, y: y + height), Vector(x: x, y: y + height)]
    }
}

// The lot is 24 x 16 m. The aisle is above y = 9, stalls are below it.
// Entrances open the aisle beyond x = 0.3 or x = 23.7.
struct Layout: Equatable {
    var stalls: [Box]
    var target: Box
    var cars: [Box]
    var pillars: [Box] = []
    var aisleEdge = 0.3
    var leftEdge = 0.3
    var rightEdge = 23.7
    var backEdge = 15.7

    var obstacles: [Box] { cars + pillars }
    var parallel: Bool { target.width > target.height }

    static let standard = Layout(
        stalls: [Box(x: 6, y: 9, width: 4, height: 6), Box(x: 10, y: 9, width: 3.2, height: 6),
                 Box(x: 13.2, y: 9, width: 4, height: 6)],
        target: Box(x: 10, y: 9, width: 3.2, height: 6),
        cars: [Box(x: 6.5, y: 10, width: 1.8, height: 4.2), Box(x: 15, y: 10, width: 1.8, height: 4.2)])

    func with(_ change: (inout Layout) -> Void) -> Layout {
        var copy = self
        change(&copy)
        return copy
    }
}

struct ParkingModel {
    static let length = 4.2
    static let width = 1.8
    static let wheelbase = 2.6
    var pose = Pose()
    var layout = Layout.standard
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

    static func outside(_ v: Vector, _ l: Layout) -> Bool {
        v.x < l.leftEdge || v.x > l.rightEdge || v.y < l.aisleEdge || v.y > l.backEdge
            || ((v.x < 0.3 || v.x > 23.7) && v.y > 9)
    }

    static func blocked(_ p: Pose, in l: Layout = .standard) -> Bool {
        let points = corners(p)
        return points.contains { outside($0, l) } || l.obstacles.contains { overlaps(points, $0.corners) }
    }

    static func clearance(_ p: Pose, in l: Layout) -> Double {
        let c = corners(p)
        let samples = c.indices.flatMap { i -> [Vector] in
            let a = c[i], b = c[(i + 1) % c.count]
            return (0..<6).map { k in
                let t = Double(k) / 6
                return Vector(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            }
        }
        return samples.map { v in
            var d = min(v.x - l.leftEdge, v.y - l.aisleEdge, l.backEdge - v.y, l.rightEdge - v.x)
            if v.y > 9 { d = min(d, 23.7 - v.x, v.x - 0.3) }
            for b in l.obstacles {
                let dx = max(b.x - v.x, 0, v.x - b.x - b.width)
                let dy = max(b.y - v.y, 0, v.y - b.y - b.height)
                d = min(d, hypot(dx, dy))
            }
            return d
        }.min() ?? 0
    }

    // Perpendicular stalls only count when backed in, nose toward the aisle.
    static func parked(_ p: Pose, in l: Layout = .standard) -> Bool {
        let t = l.target
        let limit = 8 * Double.pi / 180
        let aligned = l.parallel ? abs(sin(p.heading)) < sin(limit) : -sin(p.heading) > cos(limit)
        return aligned && corners(p).allSatisfy {
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
            won = Self.parked(pose, in: layout)
            return
        }
        let travel = gear * 1.0 * max(0, min(dt, 0.04))
        let candidate = Self.advanced(pose, steering: steering, travel: travel)
        collision = Self.blocked(candidate, in: layout)
        if collision { driving = false; return }
        pose = candidate
        distance += abs(travel)
    }

    var onLine: Bool {
        let t = layout.target
        return Self.corners(pose).contains {
            $0.y > t.y && ($0.x < t.x || $0.x > t.x + t.width)
        } && pose.x > t.x - 1 && pose.x < t.x + t.width + 1
    }

    var noseIn: Bool {
        guard !driving, !layout.parallel else { return false }
        let t = layout.target
        return sin(pose.heading) > 0.9 && Self.corners(pose).allSatisfy {
            $0.x > t.x && $0.x < t.x + t.width && $0.y > t.y && $0.y < t.y + t.height
        }
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
    let group: String
    let name: String
    let hint: String
    let start: Pose
    let layout: Layout
    var id: String { name }

    static func == (a: Scenario, b: Scenario) -> Bool { a.name == b.name }
    func hash(into hasher: inout Hasher) { hasher.combine(name) }

    static let groups = ["入门", "进阶", "挑战", "侧方停车"]

    static let all: [Scenario] = {
        let std = Layout.standard
        let narrow = std.with { $0.aisleEdge = 3 }
        return [
            Scenario(group: "入门", name: "从右侧开进来", hint: "车位在左手边，开过车位找好位置停下再倒",
                     start: Pose(x: 26, y: 6, heading: .pi), layout: narrow.with { $0.rightEdge = 31 }),
            Scenario(group: "入门", name: "从左侧开进来", hint: "车位在右手边，开过车位找好位置停下再倒",
                     start: Pose(x: -2, y: 6, heading: 0), layout: narrow.with { $0.leftEdge = -7 }),
            Scenario(group: "入门", name: "标准：停在车位旁", hint: "打满方向直接倒进去",
                     start: Pose(x: 17, y: 6, heading: 0), layout: std),
            Scenario(group: "入门", name: "只有一边有车", hint: "右边没车，空间大，先找感觉",
                     start: Pose(x: 17, y: 6, heading: 0), layout: std.with { $0.cars = [$0.cars[0]] }),
            Scenario(group: "进阶", name: "窄通道标准位", hint: "通道窄，倒车时注意车头别碰对面",
                     start: Pose(x: 16, y: 6, heading: 0), layout: narrow),
            Scenario(group: "进阶", name: "停过头了", hint: "直接倒进不去，先往前打方向摆一下车头",
                     start: Pose(x: 10, y: 6.7, heading: .pi), layout: narrow),
            Scenario(group: "进阶", name: "车位在右，停太近", hint: "直接倒进不去，先往前修一下",
                     start: Pose(x: 13, y: 6.2, heading: 0), layout: narrow),
            Scenario(group: "进阶", name: "车头歪着", hint: "起步车身是斜的，先想好往哪边打",
                     start: Pose(x: 17, y: 6.5, heading: -0.35), layout: narrow),
            Scenario(group: "进阶", name: "车位后面是墙", hint: "车位短，倒到底会撞墙，看好距离",
                     start: Pose(x: 17, y: 6, heading: 0), layout: std.with {
                         $0.stalls = $0.stalls.map { Box(x: $0.x, y: 9, width: $0.width, height: 5.3) }
                         $0.target.height = 5.3
                         $0.cars = $0.cars.map { Box(x: $0.x, y: 9.6, width: $0.width, height: $0.height) }
                         $0.backEdge = 14.5
                     }),
            Scenario(group: "挑战", name: "两边车压线", hint: "邻车都压着线停，两边只剩 0.6 米",
                     start: Pose(x: 17, y: 6, heading: 0), layout: std.with {
                         $0.cars = [Box(x: 8.3, y: 10, width: 1.8, height: 4.2), Box(x: 13.1, y: 10, width: 1.8, height: 4.2)]
                         $0.aisleEdge = 3
                     }),
            Scenario(group: "挑战", name: "窄车位", hint: "车位只有 2.5 米宽",
                     start: Pose(x: 16, y: 6, heading: 0), layout: std.with {
                         $0.stalls = [Box(x: 7.5, y: 9, width: 2.5, height: 6), Box(x: 10, y: 9, width: 2.5, height: 6),
                                      Box(x: 12.5, y: 9, width: 2.5, height: 6)]
                         $0.target = Box(x: 10, y: 9, width: 2.5, height: 6)
                         $0.cars = [Box(x: 7.85, y: 10, width: 1.8, height: 4.2), Box(x: 12.85, y: 10, width: 1.8, height: 4.2)]
                         $0.aisleEdge = 3
                     }),
            Scenario(group: "挑战", name: "地库柱子", hint: "车位口右边有根柱子，车身别刮到",
                     start: Pose(x: 17, y: 6, heading: 0), layout: std.with {
                         $0.pillars = [Box(x: 13.0, y: 8.3, width: 0.7, height: 0.7)]
                         $0.aisleEdge = 3
                     }),
            Scenario(group: "侧方停车", name: "侧方停车", hint: "和前车并排停好，先打右倒进去，再回左摆正",
                     start: Pose(x: 17.4, y: 7.5, heading: 0), layout: Layout(
                         stalls: [Box(x: 8.3, y: 9.3, width: 6.8, height: 2.3)],
                         target: Box(x: 8.3, y: 9.3, width: 6.8, height: 2.3),
                         cars: [Box(x: 3.9, y: 9.6, width: 4.2, height: 1.8), Box(x: 15.3, y: 9.6, width: 4.2, height: 1.8)],
                         aisleEdge: 3, backEdge: 11.8)),
        ]
    }()
}

extension ParkingModel {
    init(scenario: Scenario) {
        self.init()
        pose = scenario.start
        layout = scenario.layout
    }
}
