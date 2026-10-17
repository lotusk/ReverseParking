import SwiftUI
import Combine

enum PracticeMode: String, Hashable {
    case topDown, driver
}

struct ParkingView: View {
    let mode: PracticeMode
    @State private var world = DriverWorld()
    @State private var scenario = Scenario.all[0]
    @State private var model = ParkingModel(scenario: Scenario.all[0])
    @State private var wheelAngle = 0.0
    @State private var pressing = false
    @State private var showGuide = true
    @State private var showHelp = false
    @Environment(\.scenePhase) private var phase
    @Environment(\.dismiss) private var dismiss
    private let timer = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()
    static let maxWheel = 270.0

    private var status: String {
        if model.won { return "入库成功！" }
        if model.collision { return "碰到了 · 换挡驶离" }
        if model.noseIn { return "车头朝里了，要倒进去才算" }
        if model.onLine { return "压线了，调整方向" }
        if model.gear == 0 { return scenario.hint }
        if !pressing { return model.gear < 0 ? "R · 按住电门倒车" : "D · 按住电门前进" }
        return model.gear < 0 ? "R 倒车中" : "D 前进中"
    }

    var body: some View {
        VStack(spacing: 12) {
            topBar
            Group {
                if mode == .driver {
                    DriverPanel(world: world, model: model, showGuide: showGuide)
                } else {
                    ParkingCanvas(model: model, showGuide: showGuide)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            gearBar
            HStack(spacing: 14) {
                pedal
                SteeringWheel(angle: $wheelAngle, maxAngle: Self.maxWheel)
            }
            .frame(height: mode == .driver ? 200 : 230)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(Color(red: 0.03, green: 0.05, blue: 0.08))
        .sensoryFeedback(.error, trigger: model.collision) { _, hit in hit }
        .sensoryFeedback(.success, trigger: model.won) { _, won in won }
        .sheet(isPresented: $showHelp) { help }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            if mode == .driver { world.update(model, showGuide: showGuide) }
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: scenario) { restart() }
        .onChange(of: phase) { _, value in if value != .active { model.gear = 0 } }
        .onReceive(timer) { _ in
            guard phase == .active else { return }
            model.steering = wheelAngle / Self.maxWheel
            model.driving = model.gear != 0 && pressing && !showHelp
            model.step(1.0 / 60)
            if mode == .driver { world.update(model, showGuide: showGuide) }
        }
    }

    private func restart() {
        model = ParkingModel(scenario: scenario)
        wheelAngle = 0
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 6) {
        HStack {
            Button { dismiss() } label: { Image(systemName: "chevron.left") }
                .padding(.trailing, 6)
            Menu {
                ForEach(Scenario.groups, id: \.self) { group in
                    Section(group) {
                        ForEach(Scenario.all.filter { $0.group == group }) { item in
                            Button { scenario = item } label: {
                                if item == scenario { Label(item.name, systemImage: "checkmark") } else { Text(item.name) }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(scenario.name).font(.headline)
                    Image(systemName: "chevron.down").font(.caption.bold())
                }
            }
            Spacer()
            Button(action: restart) { Image(systemName: "arrow.counterclockwise") }
            Button { showHelp = true } label: { Image(systemName: "questionmark.circle") }
                .padding(.leading, 12)
        }
        Text(status)
            .font(.subheadline)
            .foregroundStyle(model.won ? .green : model.collision ? .red : model.onLine ? .yellow : .secondary)
            .lineLimit(1)
        }
        .font(.title3)
        .padding(.top, 4)
    }

    private var gearBar: some View {
        HStack(spacing: 8) {
            gearButton("R", value: -1, color: .orange)
            gearButton("P", value: 0, color: .gray)
            gearButton("D", value: 1, color: .blue)
            Toggle(isOn: $showGuide) { Image(systemName: "point.topleft.down.to.point.bottomright.curvepath") }
                .toggleStyle(.button)
                .frame(width: 56)
        }
        .frame(height: 50)
    }

    private func gearButton(_ title: String, value: Double, color: Color) -> some View {
        let selected = model.gear == value
        return Button { model.gear = value } label: {
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(selected ? color : Color.white.opacity(0.08))
                .foregroundStyle(selected ? .white : .gray)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var pedal: some View {
        VStack(spacing: 8) {
            Image(systemName: pressing ? "pedal.accelerator.fill" : "pedal.accelerator").font(.system(size: 34))
            Text(pressing ? "松开停车" : "按住走").font(.subheadline.bold())
        }
        .frame(width: 92)
        .frame(maxHeight: .infinity)
        .background(pressing ? Color.green.opacity(0.85) : Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in pressing = true }
            .onEnded { _ in pressing = false })
        .accessibilityLabel("按住电门走，松开停车")
    }

    private var help: some View {
        NavigationStack {
            List {
                Text("Hold 模式：按住左边电门车才走，松开立即停住。")
                Text("左手拇指管电门，右手拇指转方向盘。")
                Text("手指按住方向盘转圈，或在上面左右划。左右各转 3/4 圈打满。")
                Text("方向盘松手不会自己回正，和真车一样。点「回正」一键回正。")
                Text("黄线是车尾两角会走的路线（D 挡时是车头）。")
                Text("驾驶视角：挂 R 自动切倒车影像，红黄绿线分别是 0.5、1、2 米。后视镜在 R 挡会自动下压。")
                Text("右下角小图以车为中心、车头朝上，左下角是离障碍物最近的距离。")
                Text("车完全进绿色车位、车身摆正后停车，就算成功。")
            }
            .navigationTitle("怎么练")
            .toolbar { Button("知道了") { showHelp = false } }
        }
        .presentationDetents([.medium])
    }
}

struct SteeringWheel: View {
    @Binding var angle: Double
    let maxAngle: Double
    @State private var lastTouch: Double?

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                wheel(side: side)
                    .rotationEffect(.degrees(angle))
                    .position(center)
                VStack {
                    Spacer()
                    HStack {
                        Text(label).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Spacer()
                        Button("回正") { withAnimation(.easeOut(duration: 0.25)) { angle = 0 } }
                            .font(.caption.bold())
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let touch = atan2(value.location.y - center.y, value.location.x - center.x) * 180 / .pi
                    if let last = lastTouch {
                        var delta = touch - last
                        if delta > 180 { delta -= 360 }
                        if delta < -180 { delta += 360 }
                        angle = max(-maxAngle, min(maxAngle, angle + delta))
                    }
                    lastTouch = touch
                }
                .onEnded { _ in lastTouch = nil })
        }
        .accessibilityLabel("方向盘")
        .accessibilityValue(label)
    }

    private var label: String {
        let turns = abs(angle) / 360
        if abs(angle) < 5 { return "方向正" }
        return String(format: "%@ %.2f 圈", angle < 0 ? "左" : "右", turns)
    }

    private func wheel(side: CGFloat) -> some View {
        let d = side * 0.92
        return ZStack {
            Circle().stroke(Color(white: 0.75), lineWidth: d * 0.09)
            ForEach([90.0, 210.0, 330.0], id: \.self) { a in
                Capsule()
                    .fill(Color(white: 0.55))
                    .frame(width: d * 0.42, height: d * 0.07)
                    .offset(x: d * 0.21)
                    .rotationEffect(.degrees(a))
            }
            Circle().fill(Color(white: 0.3)).frame(width: d * 0.28)
            Capsule()
                .fill(Color.red)
                .frame(width: d * 0.04, height: d * 0.1)
                .offset(y: -d / 2)
        }
        .frame(width: d, height: d)
        .opacity(abs(angle) >= maxAngle ? 0.75 : 1)
    }
}

struct ParkingCanvas: View {
    let model: ParkingModel
    let showGuide: Bool
    var carView = false
    static let home = Vector(x: 12, y: 9)
    static let visibleWidth = 19.0

    var body: some View {
        Canvas { context, size in
            let scale = carView ? size.width / 11 : min(size.width / Self.visibleWidth, size.height / 16.5)
            let halfW = size.width / scale / 2, halfH = size.height / scale / 2
            func follow(_ value: Double, _ home: Double, _ half: Double) -> Double {
                let margin = half - 2.8
                return home + max(0, abs(value - home) - margin) * (value < home ? -1 : 1)
            }
            let camera = carView ? Vector(x: model.pose.x, y: model.pose.y)
                : Vector(x: follow(model.pose.x, Self.home.x, halfW), y: follow(model.pose.y, Self.home.y, halfH))
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            func point(_ p: Vector) -> CGPoint {
                CGPoint(x: center.x + (p.x - camera.x) * scale,
                        y: center.y + (p.y - camera.y) * scale)
            }
            func polygon(_ points: [Vector]) -> Path {
                Path { path in
                    path.addLines(points.map(point))
                    path.closeSubpath()
                }
            }
            func rect(_ b: Box) -> CGRect {
                let o = point(Vector(x: b.x, y: b.y))
                return CGRect(x: o.x, y: o.y, width: b.width * scale, height: b.height * scale)
            }
            func line(_ a: Vector, _ b: Vector) -> Path {
                Path { path in
                    path.move(to: point(a))
                    path.addLine(to: point(b))
                }
            }

            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.16, green: 0.19, blue: 0.17)))
            if carView {
                context.translateBy(x: center.x, y: center.y)
                context.rotate(by: .radians(-.pi / 2 - model.pose.heading))
                context.translateBy(x: -center.x, y: -center.y)
            }
            let l = model.layout
            let asphalt = Color(red: 0.11, green: 0.12, blue: 0.14)
            let paint = Color.white.opacity(0.85)
            let lot = rect(Box(x: 0, y: 0, width: 24, height: 16))
            context.fill(Path(lot), with: .color(asphalt))
            context.stroke(Path(lot), with: .color(.yellow.opacity(0.6)), lineWidth: 3)
            if l.rightEdge > 24 {
                context.fill(Path(rect(Box(x: 22, y: l.aisleEdge, width: l.rightEdge - 22, height: 9 - l.aisleEdge))),
                             with: .color(asphalt))
                context.draw(Text("入口").font(.caption).foregroundColor(.gray), at: point(Vector(x: 25.5, y: 8.3)))
            }
            if l.leftEdge < 0 {
                context.fill(Path(rect(Box(x: l.leftEdge, y: l.aisleEdge, width: 2 - l.leftEdge, height: 9 - l.aisleEdge))),
                             with: .color(asphalt))
                context.draw(Text("入口").font(.caption).foregroundColor(.gray), at: point(Vector(x: -1.5, y: 8.3)))
            }
            if l.backEdge < 15.7 {
                context.fill(Path(rect(Box(x: 0, y: l.backEdge, width: 24, height: 16 - l.backEdge))),
                             with: .color(Color(white: 0.32)))
                context.stroke(line(Vector(x: 0, y: l.backEdge), Vector(x: 24, y: l.backEdge)),
                               with: .color(.yellow.opacity(0.8)), lineWidth: 3)
            }

            context.fill(Path(rect(l.target)), with: .color(.green.opacity(0.22)))
            for b in l.stalls {
                var outline = Path()
                outline.move(to: point(Vector(x: b.x, y: b.y)))
                outline.addLine(to: point(Vector(x: b.x, y: b.y + b.height)))
                outline.addLine(to: point(Vector(x: b.x + b.width, y: b.y + b.height)))
                outline.addLine(to: point(Vector(x: b.x + b.width, y: b.y)))
                context.stroke(outline, with: .color(paint), lineWidth: 2)
            }
            if l.aisleEdge > 1 {
                let edge = l.aisleEdge
                context.fill(Path(rect(Box(x: min(0, l.leftEdge), y: 0, width: max(24, l.rightEdge) - min(0, l.leftEdge), height: edge))),
                             with: .color(Color(red: 0.2, green: 0.21, blue: 0.24)))
                context.stroke(line(Vector(x: min(0, l.leftEdge), y: edge), Vector(x: max(24, l.rightEdge), y: edge)),
                               with: .color(paint), lineWidth: 2)
                for x in stride(from: 1.0, through: 21.0, by: 3.2) {
                    context.fill(Path(roundedRect: rect(Box(x: x + 0.7, y: edge - 2.9, width: 1.8, height: 2.6)),
                                      cornerRadius: scale * 0.4),
                                 with: .color(Color(white: 0.45)))
                }
            } else {
                context.stroke(line(Vector(x: 1, y: 3.5), Vector(x: 23, y: 3.5)),
                               with: .color(.white.opacity(0.25)),
                               style: StrokeStyle(lineWidth: 2, dash: [14, 12]))
            }

            for b in l.cars {
                context.fill(Path(roundedRect: rect(b), cornerRadius: scale * 0.4), with: .color(Color(white: 0.45)))
            }
            for b in l.pillars {
                context.fill(Path(rect(b)), with: .color(Color(white: 0.75)))
                context.stroke(Path(rect(b)), with: .color(.orange), lineWidth: 2)
            }

            if showGuide && !model.won {
                let direction = model.gear == 0 ? -1.0 : model.gear
                let lx = direction < 0 ? -ParkingModel.length / 2 : ParkingModel.length / 2
                for ly in [-ParkingModel.width / 2, ParkingModel.width / 2] {
                    var track = Path()
                    for (i, p) in ([model.pose] + model.trajectory(direction: direction)).enumerated() {
                        let v = Vector(x: p.x + lx * cos(p.heading) - ly * sin(p.heading),
                                       y: p.y + lx * sin(p.heading) + ly * cos(p.heading))
                        if i == 0 { track.move(to: point(v)) } else { track.addLine(to: point(v)) }
                    }
                    context.stroke(track, with: .color(.yellow.opacity(0.85)),
                                   style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                }
            }

            let p = model.pose
            let body = model.won ? Color.green : model.collision ? Color.red : Color.cyan
            context.fill(polygon(ParkingModel.corners(p)), with: .color(body))
            var car = context
            let c = point(Vector(x: p.x, y: p.y))
            car.translateBy(x: c.x, y: c.y)
            car.rotate(by: .radians(p.heading))
            car.fill(Path(roundedRect: CGRect(x: 0.2 * scale, y: -0.66 * scale,
                                              width: 0.8 * scale, height: 1.32 * scale), cornerRadius: 3),
                     with: .color(.black.opacity(0.6)))
            car.fill(Path(roundedRect: CGRect(x: -1.6 * scale, y: -0.6 * scale,
                                              width: 0.5 * scale, height: 1.2 * scale), cornerRadius: 3),
                     with: .color(.black.opacity(0.4)))
            for y in [-0.75, 0.6] {
                car.fill(Path(CGRect(x: -2.1 * scale, y: y * scale, width: 0.15 * scale, height: 0.15 * scale)),
                         with: .color(model.gear < 0 ? .white : .red))
            }
            for y in [-1.0, 1.0] {
                var wheel = car
                wheel.translateBy(x: 1.2 * scale, y: y * scale)
                wheel.rotate(by: .radians(model.steering * .pi / 5))
                wheel.fill(Path(CGRect(x: -0.35 * scale, y: -0.12 * scale,
                                       width: 0.7 * scale, height: 0.24 * scale)), with: .color(.white))
            }
        }
        .accessibilityLabel("倒车入库俯视练习场")
    }
}
