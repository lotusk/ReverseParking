import SwiftUI
import SceneKit

@main
struct ReverseParkingApp: App {
    var body: some Scene {
        WindowGroup { HomeView().preferredColorScheme(.dark) }
    }
}

struct HomeView: View {
    @AppStorage("paint") private var paint = CarPaint.pearl

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("倒车练习").font(.largeTitle.bold())
                Showroom(paint: paint)
                    .frame(height: 230)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                HStack(spacing: 14) {
                    ForEach(CarPaint.allCases) { item in
                        Button { paint = item } label: {
                            Circle()
                                .fill(item.color)
                                .frame(width: 30, height: 30)
                                .overlay(Circle().stroke(.white.opacity(item == paint ? 1 : 0.25), lineWidth: item == paint ? 3 : 1))
                        }
                        .accessibilityLabel(item.name)
                    }
                    Spacer()
                    Text(paint.name).font(.subheadline).foregroundStyle(.secondary)
                }
                card(.driver, icon: "car.rear.and.tire.marks", title: "驾驶视角",
                     detail: "第一人称 · 后视镜 · 倒车影像 · 360 俯视小图")
                card(.topDown, icon: "map", title: "俯视练习",
                     detail: "从上往下看整个车场，适合先理解路线")
                Spacer()
            }
            .padding(20)
            .navigationDestination(for: PracticeMode.self) { ParkingView(mode: $0) }
        }
    }

    private func card(_ mode: PracticeMode, icon: String, title: String, detail: String) -> some View {
        NavigationLink(value: mode) {
            HStack(spacing: 16) {
                Image(systemName: icon).font(.system(size: 30)).frame(width: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title3.bold())
                    Text(detail).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(18)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}

// The car on a slow turntable, in the chosen paint.
struct Showroom: UIViewRepresentable {
    let paint: CarPaint

    final class Stage {
        let scene = SCNScene()
        let car = Sedan(paint: CarPaint.pearl.uiColor, lit: true)
        let camera = SCNNode()

        init() {
            DriverWorld.light(scene, center: SCNVector3(0, 0, 0), span: 6)
            let floor = SCNFloor()
            floor.reflectivity = 0.25
            floor.materials = [Sedan.surface(UIColor(white: 0.12, alpha: 1), roughness: 0.5)]
            scene.rootNode.addChildNode(SCNNode(geometry: floor))
            scene.rootNode.addChildNode(car.node)
            car.node.runAction(.repeatForever(.rotateBy(x: 0, y: 2 * .pi, z: 0, duration: 30)))
            camera.camera = DriverWorld.lens(fov: 30, occlusion: true)
            camera.position = SCNVector3(6.2, 2.1, 5.4)
            camera.look(at: SCNVector3(0, 0.7, 0))
            scene.rootNode.addChildNode(camera)
        }
    }

    func makeCoordinator() -> Stage { Stage() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = context.coordinator.scene
        view.pointOfView = context.coordinator.camera
        view.antialiasingMode = .multisampling4X
        view.isUserInteractionEnabled = false
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.car.paint.diffuse.contents = paint.uiColor
        context.coordinator.car.paint.metalness.contents = paint.metalness
    }
}
