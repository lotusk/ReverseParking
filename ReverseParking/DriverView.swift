import SwiftUI
import SceneKit

struct SceneViewport: UIViewRepresentable {
    let world: DriverWorld
    let camera: SCNNode
    var fps = 60

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = world.scene
        view.pointOfView = camera
        view.antialiasingMode = .multisampling4X
        view.rendersContinuously = true
        view.preferredFramesPerSecond = fps
        view.isUserInteractionEnabled = false
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

    private var reversing: Bool { model.gear < 0 }

    private var clearance: Double {
        ParkingModel.clearance(model.pose, aisleEdge: model.aisleEdge, rightEdge: model.rightEdge)
    }

    var body: some View {
        ZStack {
            // Backup cameras show a mirrored image so left stays left, like the mirrors.
            SceneViewport(world: world, camera: reversing ? world.rearCam : world.driverCam)
                .scaleEffect(x: reversing ? -1 : 1, y: 1)

            VStack {
                HStack {
                    mirror(world.leftMirror)
                    Spacer()
                    mirror(world.rightMirror)
                }
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(reversing ? "倒车影像" : "前方")
                            .font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.black.opacity(0.55), in: Capsule())
                        radar
                    }
                    Spacer()
                    ParkingCanvas(model: model, showGuide: showGuide, carView: true)
                        .frame(width: 128, height: 128)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.5), lineWidth: 1))
                }
            }
            .padding(8)
        }
    }

    private var radar: some View {
        let d = clearance
        let color: Color = d < 0.3 ? .red : d < 0.8 ? .orange : d < 1.5 ? .yellow : .green
        return HStack(spacing: 6) {
            Image(systemName: "dot.radiowaves.left.and.right")
            Text(d > 3 ? "周围安全" : String(format: "最近 %.1f 米", max(0, d)))
                .monospacedDigit()
        }
        .font(.subheadline.bold())
        .foregroundStyle(color)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.black.opacity(0.6), in: Capsule())
    }

    private func mirror(_ camera: SCNNode) -> some View {
        SceneViewport(world: world, camera: camera, fps: 30)
            .scaleEffect(x: -1, y: 1)
            .frame(width: 124, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.black, lineWidth: 3))
    }
}
