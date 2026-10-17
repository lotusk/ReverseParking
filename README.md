# ReverseParking

iPhone app for practicing reverse parking. SwiftUI + Core Motion, iOS 17+.

## Install on your iPhone

1. Open `ReverseParking.xcodeproj` in Xcode.
2. Target ReverseParking → Signing & Capabilities → pick your Team. Change the bundle ID if it clashes.
3. Plug in the iPhone, trust the Mac, turn on Developer Mode (Settings → Privacy & Security).
4. Pick the phone as run target and press Run.

With a free Apple ID the app expires after 7 days. Run it again from Xcode to renew.

## Two modes

The home screen has two modes. They share scenarios, gears, pedal and wheel.

- 俯视练习: the original top-down view of the whole lot.
- 驾驶视角: first-person 3D (SceneKit). Side mirrors at the top, a 360 heading-up minimap at the bottom right, and the nearest-obstacle distance at the bottom left.
  - In R the main view switches to a backup camera, mirrored like a real one, with 0.5 / 1 / 2 m lines and the predicted path.
  - In R both mirrors tilt down to show the bay lines.

## How to play

- Portrait. Pick R, P or D.
- Hold mode, like a Tesla: the car only moves while you hold the pedal (left). Let go and it stops.
- Turn the wheel (right) by dragging around it or swiping across it. 3/4 turn each way is full lock.
- The wheel does not center itself. Tap 回正 to center it.
- Park fully inside the green bay, within 8° of straight, then let go.
- Yellow dashed lines show where the two rear corners will go (front corners in D).

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
| 挑战 | 两边车压线 | Neighbours over the lines, 0.6 m each side |
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
