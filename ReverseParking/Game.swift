import SwiftUI
import QuartzCore

// Runs the model once per screen refresh with the real frame time.
@Observable
final class Game {
    static let maxWheel = 360.0

    private(set) var model: ParkingModel
    var scenario: Scenario { didSet { restart() } }
    var wheelAngle = 0.0
    var pedal = 0.0
    var showGuide = true
    var paused = false
    @ObservationIgnored var paint = CarPaint.pearl
    @ObservationIgnored let world: DriverWorld?
    @ObservationIgnored private let ticker = Ticker()
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var last: CFTimeInterval = 0
    @ObservationIgnored private var drawn: Drawn?

    private struct Drawn: Equatable {
        let model: ParkingModel
        let showGuide: Bool
        let paint: CarPaint
    }

    init(driver: Bool) {
        let first = Scenario.all[0]
        scenario = first
        model = ParkingModel(scenario: first)
        world = driver ? DriverWorld() : nil
        ticker.fire = { [weak self] time in self?.tick(time) }
    }

    func start() {
        guard link == nil else { return }
        last = 0
        link = CADisplayLink(target: ticker, selector: #selector(Ticker.step))
        link?.add(to: .main, forMode: .common)
        draw()
    }

    func stop() {
        link?.invalidate()
        link = nil
        pedal = 0
    }

    func restart() {
        model = ParkingModel(scenario: scenario)
        wheelAngle = 0
        pedal = 0
    }

    func shift(_ gear: Double) {
        guard model.gear != gear else { return }
        model.gear = gear
    }

    private func tick(_ time: CFTimeInterval) {
        let dt = last == 0 ? 1.0 / 60 : time - last
        last = time
        var next = model
        next.steering = wheelAngle / Self.maxWheel
        next.throttle = paused ? 0 : pedal
        next.step(dt)
        if next != model { model = next }
        draw()
    }

    private func draw() {
        let state = Drawn(model: model, showGuide: showGuide, paint: paint)
        guard let world, state != drawn else { return }
        drawn = state
        world.update(model, showGuide: showGuide, paint: paint)
    }

    deinit { link?.invalidate() }
}

private final class Ticker: NSObject {
    var fire: ((CFTimeInterval) -> Void)?

    @objc func step(_ link: CADisplayLink) {
        fire?(link.timestamp)
    }
}
