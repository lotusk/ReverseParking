struct Key: Hashable { let x: Int, y: Int, h: Int }
func key(_ p: Pose) -> Key {
    var h = p.heading.truncatingRemainder(dividingBy: 2 * .pi); if h < 0 { h += 2 * .pi }
    return Key(x: Int((p.x * 5).rounded()), y: Int((p.y * 5).rounded()), h: Int((h * 180 / .pi / 3).rounded()) % 120)
}
let steers = [-1.0, -0.5, 0, 0.5, 1]
func explore(_ starts: [Pose], dir: Double, in l: Layout) -> [Pose] {
    var seen = Set(starts.map(key)), out: [Pose] = [], queue = starts
    while let p = queue.popLast() {
        out.append(p)
        for s in steers {
            var q = p, ok = true
            for _ in 0..<3 {
                q = ParkingModel.advanced(q, steering: s, travel: dir * 0.1)
                if ParkingModel.blocked(q, in: l) { ok = false; break }
            }
            if ok && seen.insert(key(q)).inserted { queue.append(q) }
        }
    }
    return out
}
// Fewest straight-gear segments to park, trying R first, then D-R, R-D-R, D-R-D-R.
func segments(_ s: Scenario) -> Int? {
    let l = s.layout
    var reverseSide = explore([s.start], dir: -1, in: l)
    if reverseSide.contains(where: { ParkingModel.parked($0, in: l) }) { return 1 }
    var forwardSide = explore([s.start], dir: 1, in: l)
    for n in 2...4 {
        if n % 2 == 0 {
            forwardSide = explore(forwardSide, dir: -1, in: l)
            if forwardSide.contains(where: { ParkingModel.parked($0, in: l) }) { return n }
            reverseSide = explore(reverseSide, dir: 1, in: l)
        } else {
            reverseSide = explore(reverseSide, dir: -1, in: l)
            if reverseSide.contains(where: { ParkingModel.parked($0, in: l) }) { return n }
            forwardSide = explore(forwardSide, dir: 1, in: l)
        }
    }
    return nil
}
let needsFix = ["停过头了", "车位在右，停太近"]
for s in Scenario.all {
    precondition(!ParkingModel.blocked(s.start, in: s.layout), "\(s.name): start blocked")
    let n = segments(s)
    print("\(s.group) / \(s.name): \(n.map { "\($0) segment(s)" } ?? "NOT SOLVABLE")")
    precondition(n != nil, "\(s.name): cannot be parked")
    if needsFix.contains(s.name) { precondition(n! >= 2, "\(s.name): should need a forward fix") }
}
print("All \(Scenario.all.count) scenarios can be parked.")
