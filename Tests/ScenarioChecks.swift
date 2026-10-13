struct Key: Hashable { let x: Int, y: Int, h: Int }
func key(_ p: Pose) -> Key {
    var h = p.heading.truncatingRemainder(dividingBy: 2 * .pi); if h < 0 { h += 2 * .pi }
    return Key(x: Int((p.x * 5).rounded()), y: Int((p.y * 5).rounded()), h: Int((h * 180 / .pi / 3).rounded()) % 120)
}
let steers = [-1.0, -0.5, 0, 0.5, 1]
func explore(_ starts: [Pose], dir: Double, edge: Double, right: Double) -> [Pose] {
    var seen = Set(starts.map(key)), out: [Pose] = [], queue = starts
    while let p = queue.popLast() {
        out.append(p)
        for s in steers {
            var q = p, ok = true
            for _ in 0..<3 {
                q = ParkingModel.advanced(q, steering: s, travel: dir * 0.1)
                if ParkingModel.blocked(q, aisleEdge: edge, rightEdge: right) { ok = false; break }
            }
            if ok && seen.insert(key(q)).inserted { queue.append(q) }
        }
    }
    return out
}
let expectForward = ["停过头了", "车位在右，停太近"]
for s in Scenario.all {
    precondition(!ParkingModel.blocked(s.start, aisleEdge: s.aisleEdge, rightEdge: s.rightEdge), "\(s.name): start blocked")
    let reverseOnly = explore([s.start], dir: -1, edge: s.aisleEdge, right: s.rightEdge).contains(where: ParkingModel.parked)
    let withForward = reverseOnly || explore(explore([s.start], dir: 1, edge: s.aisleEdge, right: s.rightEdge), dir: -1, edge: s.aisleEdge, right: s.rightEdge)
        .contains(where: ParkingModel.parked)
    precondition(withForward, "\(s.name): cannot be parked")
    if expectForward.contains(s.name) { precondition(!reverseOnly, "\(s.name): should need a forward fix") }
    print("\(s.name): ok, \(reverseOnly ? "reverse only" : "needs forward first")")
}
