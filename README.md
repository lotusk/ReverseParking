# ReverseParking

iPhone app for practicing reverse parking. SwiftUI + Core Motion, iOS 17+.

## Install on your iPhone

1. Open `ReverseParking.xcodeproj` in Xcode.
2. Target ReverseParking → Signing & Capabilities → pick your Team. Change the bundle ID if it clashes.
3. Plug in the iPhone, trust the Mac, turn on Developer Mode (Settings → Privacy & Security).
4. Pick the phone as run target and press Run.

With a free Apple ID the app expires after 7 days. Run it again from Xcode to renew.

## How to play

- Portrait. Pick R, P or D.
- Hold mode, like a Tesla: the car only moves while you hold the pedal (left). Let go and it stops.
- Turn the wheel (right) by dragging around it or swiping across it. 3/4 turn each way is full lock.
- The wheel does not center itself. Tap 回正 to center it.
- Park fully inside the green bay, within 8° of straight, then let go.
- Yellow dashed lines show where the two rear corners will go (front corners in D).

## Scenarios

Pick one from the menu at the top. Reset starts the same one again.

- 从右侧开进来: come in from the right entrance, bay on your left, pick your own stop point.
- 标准：停在车位旁: full lock and reverse straight in.
- 停过头了: bay on your left, too far forward in a narrow aisle. Pull forward and swing the nose first.
- 车位在右，停太近: narrow aisle, needs a forward fix first.
- 窄通道标准位: narrow aisle, reverse only.

`Tests/ScenarioChecks.swift` searches every scenario to prove it can be parked, and that the two "fix first" ones can't be done in reverse only.

## Checks

```sh
cat ReverseParking/ParkingModel.swift Tests/ModelChecks.swift > /tmp/checks.swift && swift /tmp/checks.swift
cat ReverseParking/ParkingModel.swift Tests/ScenarioChecks.swift > /tmp/sc.swift && swiftc -O /tmp/sc.swift -o /tmp/sc && /tmp/sc
```
