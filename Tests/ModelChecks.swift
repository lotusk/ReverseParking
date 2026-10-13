
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
print("All 11 model checks passed, including a collision-free parking route.")
