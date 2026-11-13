# ReverseParking

iPhone app for practicing reverse parking. SwiftUI + SceneKit, iOS 17+.

## Install on your iPhone

1. Open `ReverseParking.xcodeproj` in Xcode.
2. Target ReverseParking → Signing & Capabilities → pick your Team. Change the bundle ID if it clashes.
3. Plug in the iPhone, trust the Mac, turn on Developer Mode (Settings → Privacy & Security).
4. Pick the phone as run target and press Run.

With a free Apple ID the app expires after 7 days. Run it again from Xcode to renew.

## Two modes

The home screen shows the car on a turntable, the paint picker, and two modes.
Both modes share scenarios, gears, pedal and wheel.

- 俯视练习: top-down view of the whole lot.
- 驾驶视角: first-person 3D. Side mirrors at the top, gear and speed between them,
  a 360 heading-up minimap at the bottom right, and the nearest-obstacle distance at the bottom left.
  - In R the main view switches to a backup camera with 0.5 / 1 / 2 m lines and the predicted path.
  - The backup camera is mirrored like a real one (left of the screen is the left of the car).
    The ? sheet has a switch to show it unmirrored instead.
  - In R both mirrors tilt down to show the bay lines.

All cars are 4.75 x 1.92 m with a 2.89 m wheelbase (about a Model Y).
No logos or brand names are used.

## 3D scene

- The car body is a mesh built in code (`CarMesh.swift`): cross-sections along the car, with wheel arches,
  windows, glass roof, lamps and black trim as separate materials. Wheels roll and the front ones steer.
- Physically based materials, light from a sky image, and one sun with soft shadows.
- Brake lights come on when you let go of the pedal; reverse lights in R.
- The lot has textured asphalt and concrete, wheel stops, hedges, trees, lamp posts and far buildings.

## How to play

- Portrait. Gears R, P, D are in the column between the pedal and the wheel.
- Hold mode, like a Tesla: the car only moves while you touch the pedal (left). Let go and it brakes to a stop.
- The pedal is analog. Touch low to creep, slide up to go faster. Speed changes smoothly, top speed is about 8 km/h
  (a bit less in R).
- Turn the wheel (right) by dragging around its rim. One turn each way is full lock.
  A light tick when you pass the center or hit full lock. Let go within 4° of center and it snaps straight.
- The wheel does not center itself. Tap 回正 to center it. Touches near the hub are ignored.
- Park fully inside the green bay, then let go. It only counts when the car is within 3° of straight
  and within 0.3 m of the middle of the bay. Within 1.5° and 0.15 m is 完美.
- As soon as a corner is inside the bay, a chip shows the tilt and offset live. Green means good enough.
- Bars around the car in the top view are parking sensors: yellow under 1 m, orange under 0.6 m, red under 0.3 m.
- Yellow dashed lines show where the two rear corners will go (front corners in D). The curve button at the top turns them off.

The model runs once per screen refresh with the real frame time (`Game.swift`), so motion stays even.

## Scenarios

13 scenarios in 4 groups. Pick one from the menu at the top. Reset starts the same one again.

| Group | Scenario | What it trains |
|---|---|---|
| 入门 | 从右侧开进来 | Come in from the right entrance, bay on your left, pick your own stop point |
| 入门 | 从左侧开进来 | Same, from the left, bay on your right |
| 入门 | 标准：停在车位旁 | Full lock, reverse straight in |
| 入门 | 只有一边有车 | Lots of room, get a feel for it |
| 进阶 | 窄通道标准位 | 6 m aisle, watch the nose |
| 进阶 | 停过头了 | Too far forward in a narrow aisle, pull forward first |
| 进阶 | 车位在右，停太近 | Too close to the row, pull forward first |
| 进阶 | 车头歪着 | Start at an angle |
| 进阶 | 车位后面是墙 | Short bay with a wall, stop in time |
| 挑战 | 两边车压线 | Neighbours over the lines, about 0.5 m each side |
| 挑战 | 窄车位 | 2.5 m bay |
| 挑战 | 地库柱子 | Pillar at the bay mouth |
| 侧方停车 | 侧方停车 | Parallel park between two cars |

Each scenario has its own layout (stalls, cars, pillars, aisle width, back wall, entrances).
Perpendicular bays only count when backed in, nose out.

`Tests/ScenarioChecks.swift` searches every scenario (up to 4 back-and-forth segments) to prove it can be parked,
and that the two "pull forward first" ones can't be done in reverse only.

## Checks

```sh
cat ReverseParking/ParkingModel.swift Tests/ModelChecks.swift > /tmp/checks.swift && swift /tmp/checks.swift
cat ReverseParking/ParkingModel.swift Tests/ScenarioChecks.swift > /tmp/sc.swift && swiftc -O /tmp/sc.swift -o /tmp/sc && /tmp/sc
```
