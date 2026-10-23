
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
}
let straight = ParkingModel.advanced(Pose(), steering: 0, travel: -1)
check(abs(straight.x - 16) < 0.0001 && straight.y == 6, "Reverse straight")
let forward = ParkingModel.advanced(Pose(), steering: 1, travel: 1)
let reverse = ParkingModel.advanced(Pose(), steering: 1, travel: -1)
check(forward.heading > 0 && reverse.heading < 0, "Steering reverses yaw in reverse gear")
check(!ParkingModel.blocked(Pose()), "Start is clear")
check(ParkingModel.blocked(Pose(x: 7.4, y: 12, heading: .pi / 2)), "Parked car collision")
check(ParkingModel.blocked(Pose(x: 0, y: 6, heading: 0)), "World boundary")
check(ParkingModel.parked(Pose(x: 11.6, y: 12, heading: -.pi / 2)), "Valid bay parking")
check(!ParkingModel.parked(Pose(x: 11.6, y: 12, heading: 0)), "Reject sideways parking")
check(!ParkingModel.parked(Pose(x: 10.2, y: 12, heading: -.pi / 2)), "Reject partial parking")
var game = ParkingModel()
game.pose = Pose(x: 11.6, y: 12, heading: -.pi / 2)
game.driving = true
game.step(1.0 / 60)
check(!game.won, "Must stop before success")
game.driving = false
game.step(1.0 / 60)
check(game.won, "Stopped parking succeeds")
// A feasible reverse arc from the starting lane, then a straight finish.
var p = Pose()
let radius = ParkingModel.wheelbase / tan(Double.pi / 5)
let startX = 11.6 + radius
p.x = startX
for _ in 0..<1000 { p = ParkingModel.advanced(p, steering: 1, travel: -radius * .pi / 2 / 1000); check(!ParkingModel.blocked(p), "Entry arc clear") }
for _ in 0..<400 { p = ParkingModel.advanced(p, steering: 0, travel: -0.006); check(!ParkingModel.blocked(p), "Straight finish clear") }
check(ParkingModel.parked(p), "Scenario can be completed")
let l = Layout.standard
let straight90 = -Double.pi / 2
check(ParkingModel.fit(Pose(x: 11.6, y: 12, heading: straight90), in: l)!.perfect, "Centered and straight is perfect")
let tilted = ParkingModel.fit(Pose(x: 11.6, y: 12, heading: straight90 + 5 * .pi / 180), in: l)!
check(!tilted.good && abs(tilted.angle - 5) < 0.01, "5 degrees off is not good enough")
let shifted = ParkingModel.fit(Pose(x: 12.0, y: 12, heading: straight90), in: l)!
check(!shifted.good && abs(shifted.offset - 0.4) < 0.01, "0.4 m to the right is not good enough")
check(ParkingModel.fit(Pose(x: 11.8, y: 12, heading: straight90 + 2 * .pi / 180), in: l)!.good, "2 degrees and 0.2 m is good")
print("All 15 model checks passed, including a collision-free parking route.")
