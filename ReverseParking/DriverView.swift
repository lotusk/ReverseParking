import SwiftUI
import SceneKit

struct SceneViewport: UIViewRepresentable {
    let scene: SCNScene
    let camera: SCNNode
    var fps = 60
    var smooth = true

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = scene
        view.pointOfView = camera
        view.antialiasingMode = smooth ? .multisampling4X : .multisampling2X
        view.rendersContinuously = true
        view.preferredFramesPerSecond = fps
        view.isUserInteractionEnabled = false
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        if view.pointOfView !== camera { view.pointOfView = camera }
    }
}

struct DriverPanel: View {
    let world: DriverWorld
    let model: ParkingModel
    let showGuide: Bool
    let paint: CarPaint
    @AppStorage("rawRearView") private var rawRearView = false

    private var reversing: Bool { model.gear < 0 }

    var body: some View {
        ZStack {
            // Backup cameras show a mirrored image so left stays left, like the mirrors.
            SceneViewport(scene: world.scene, camera: reversing ? world.rearCam : world.driverCam)
                .scaleEffect(x: reversing && !rawRearView ? -1 : 1, y: 1)

            VStack {
                HStack(alignment: .top) {
                    mirror(world.leftMirror)
                    Spacer(minLength: 4)
                    GearSpeed(model: model)
                    Spacer(minLength: 4)
                    mirror(world.rightMirror)
                }
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(reversing ? (rawRearView ? "倒车影像 · 回头看" : "倒车影像") : "前方")
                            .font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.black.opacity(0.55), in: Capsule())
                        AlignChip(model: model)
                        RadarChip(model: model)
                    }
                    Spacer()
                    ParkingCanvas(model: model, showGuide: showGuide, paint: paint, carView: true)
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.5), lineWidth: 1))
                }
            }
            .padding(8)
        }
    }

    private func mirror(_ camera: SCNNode) -> some View {
        SceneViewport(scene: world.scene, camera: camera, fps: 30, smooth: false)
            .scaleEffect(x: -1, y: 1)
            .frame(width: 132, height: 76)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.black, lineWidth: 3))
    }
}

struct GearSpeed: View {
    let model: ParkingModel

    var body: some View {
        let gear = model.gear < 0 ? "R" : model.gear > 0 ? "D" : "P"
        let color: Color = model.gear < 0 ? .orange : model.gear > 0 ? .blue : .gray
        VStack(spacing: 0) {
            Text(gear).font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundStyle(color)
            Text(String(format: "%.0f", abs(model.speed) * 3.6))
                .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
            Text("km/h").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
        }
        .frame(width: 58)
        .padding(.vertical, 5)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    }
}

// Live tilt and offset once any corner is inside the bay.
struct AlignChip: View {
    let model: ParkingModel

    var body: some View {
        if !model.won && ParkingModel.entering(model.pose, in: model.layout) {
            let a = ParkingModel.alignment(model.pose, in: model.layout)
            let straight = abs(a.angle) <= 3, centered = abs(a.offset) <= 0.3
            let side = model.layout.parallel ? (a.offset > 0 ? "靠边" : "靠外") : (a.offset > 0 ? "偏右" : "偏左")
            HStack(spacing: 8) {
                Label(String(format: "%.1f°", abs(a.angle)), systemImage: "angle")
                    .foregroundStyle(straight ? .green : .yellow)
                Text(String(format: "%@ %.2f", side, abs(a.offset)))
                    .foregroundStyle(centered ? .green : .yellow)
            }
            .font(.subheadline.bold().monospacedDigit())
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.black.opacity(0.6), in: Capsule())
        }
    }
}

struct RadarChip: View {
    let model: ParkingModel

    var body: some View {
        let d = ParkingModel.clearance(model.pose, in: model.layout)
        let color: Color = d < 0.3 ? .red : d < 0.6 ? .orange : d < 1.0 ? .yellow : .green
        HStack(spacing: 6) {
            Image(systemName: "dot.radiowaves.left.and.right")
            Text(d > 3 ? "周围安全" : String(format: "最近 %.1f 米", max(0, d)))
                .monospacedDigit()
        }
        .font(.subheadline.bold())
        .foregroundStyle(color)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.black.opacity(0.6), in: Capsule())
    }
}
