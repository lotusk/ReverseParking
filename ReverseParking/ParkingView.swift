import SwiftUI

enum PracticeMode: String, Hashable {
    case topDown, driver
}

struct ParkingView: View {
    let mode: PracticeMode
    @State private var game: Game
    @AppStorage("paint") private var paint = CarPaint.pearl
    @AppStorage("rawRearView") private var rawRearView = false
    @State private var showHelp = false
    @Environment(\.scenePhase) private var phase
    @Environment(\.dismiss) private var dismiss

    init(mode: PracticeMode) {
        self.mode = mode
        _game = State(initialValue: Game(driver: mode == .driver))
    }

    var body: some View {
        @Bindable var game = game
        VStack(spacing: 10) {
            topBar
            StatusLine(game: game)
            Viewport(game: game, paint: paint)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            HStack(spacing: 12) {
                Pedal(value: $game.pedal)
                GearColumn(game: game)
                SteeringWheel(angle: $game.wheelAngle, maxAngle: Game.maxWheel)
            }
            .frame(height: 214)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(Color(red: 0.03, green: 0.05, blue: 0.08))
        .sheet(isPresented: $showHelp) { help }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            game.paint = paint
            game.start()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            game.stop()
        }
        .onChange(of: paint) { game.paint = paint }
        .onChange(of: showHelp) { game.paused = showHelp }
        .onChange(of: phase) { _, value in
            if value == .active { game.start() } else { game.stop(); game.shift(0) }
        }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: { Image(systemName: "chevron.left") }
            Menu {
                ForEach(Scenario.groups, id: \.self) { group in
                    Section(group) {
                        ForEach(Scenario.all.filter { $0.group == group }) { item in
                            Button { game.scenario = item } label: {
                                if item == game.scenario { Label(item.name, systemImage: "checkmark") } else { Text(item.name) }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(game.scenario.name).font(.headline)
                    Image(systemName: "chevron.down").font(.caption.bold())
                }
            }
            Spacer()
            Button { game.showGuide.toggle() } label: {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    .foregroundStyle(game.showGuide ? Color.accentColor : .gray)
            }
            Button { game.restart() } label: { Image(systemName: "arrow.counterclockwise") }
            Button { showHelp = true } label: { Image(systemName: "questionmark.circle") }
        }
        .font(.title3)
        .padding(.top, 4)
    }

    private var help: some View {
        NavigationStack {
            List {
                Section("车漆") {
                    Picker("车漆", selection: $paint) {
                        ForEach(CarPaint.allCases) { item in
                            Label { Text(item.name) } icon: {
                                Image(systemName: "circle.fill").foregroundStyle(item.color)
                            }
                            .tag(item)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                if mode == .driver {
                    Section {
                        Picker("倒车影像", selection: $rawRearView) {
                            Text("镜像（和真车一样）").tag(false)
                            Text("回头看（不镜像）").tag(true)
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    } header: {
                        Text("倒车影像")
                    } footer: {
                        Text("真车的倒车影像是镜像的：画面左边就是车的左边，和后视镜一致。「回头看」是你转头从后窗看出去的样子，左右相反。")
                    }
                }
                Section("怎么练") {
                    Text("Hold 模式：按住左边电门车才走，松开自动刹停。")
                    Text("电门能控制快慢：按在下面慢慢挪，手指往上滑更快。起步和停车都是平顺的。")
                    Text("中间一列是挡位。左手拇指管电门，右手拇指转方向盘。")
                    Text("手指按住方向盘外圈转。左右各转 1 圈打满。回到正中会轻震一下，松手时离正中很近会自动对正。")
                    Text("方向盘松手不会自己回正，和真车一样。点「回正」一键回正。")
                    Text("黄线是车尾两角会走的路线（D 挡时是车头）。右上角的曲线按钮可以关掉。")
                    Text("驾驶视角：挂 R 自动切倒车影像，红黄绿线分别是 0.5、1、2 米。后视镜在 R 挡会自动下压。")
                    Text("小图以车为中心、车头朝上。车身周围的色条是雷达：黄 1 米内，橙 0.6 米内，红 0.3 米内。")
                    Text("车一进车位，左下角会实时显示歪了几度、偏了多少，变绿就是合格。")
                    Text("车完全进绿色车位，车身歪不超过 3°、左右偏不超过 0.3 米，停下才算成功。1.5° 和 0.15 米以内算完美。")
                }
            }
            .navigationTitle("设置与说明")
            .toolbar { Button("知道了") { showHelp = false } }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct StatusLine: View {
    let game: Game

    var body: some View {
        let model = game.model
        Text(status)
            .font(.subheadline)
            .foregroundStyle(model.won ? .green : model.collision ? .red : model.onLine ? .yellow : .secondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sensoryFeedback(.error, trigger: model.collision) { _, hit in hit }
            .sensoryFeedback(.success, trigger: model.won) { _, won in won }
    }

    private var status: String {
        let model = game.model, pressing = game.pedal > 0
        let fit = ParkingModel.fit(model.pose, in: model.layout)
        if model.won, let f = fit {
            return String(format: "%@ · 歪 %.1f° · 偏 %.2f 米", f.perfect ? "完美入库" : "入库成功", f.angle, abs(f.offset))
        }
        if model.collision { return "碰到了 · 换挡驶离" }
        if model.noseIn { return "车头朝里了，要倒进去才算" }
        if !pressing, !model.moving, let f = fit, !f.good { return advice(f) }
        if model.onLine { return "压线了，调整方向" }
        if model.gear == 0 { return game.scenario.hint }
        if !pressing { return model.gear < 0 ? "R · 按住电门倒车" : "D · 按住电门前进" }
        return model.gear < 0 ? "R 倒车中" : "D 前进中"
    }

    private func advice(_ f: ParkingModel.Fit) -> String {
        var parts: [String] = []
        if f.angle > 3 { parts.append(String(format: "歪了 %.1f°", f.angle)) }
        if abs(f.offset) > 0.3 {
            let side = game.model.layout.parallel ? (f.offset > 0 ? "太靠路边" : "离路边太远") : (f.offset > 0 ? "偏右" : "偏左")
            parts.append(String(format: "%@ %.2f 米", side, abs(f.offset)))
        }
        return "已进库，" + parts.joined(separator: "，") + "，再调正"
    }
}

private struct Viewport: View {
    let game: Game
    let paint: CarPaint

    var body: some View {
        let model = game.model
        if let world = game.world {
            DriverPanel(world: world, model: model, showGuide: game.showGuide, paint: paint)
        } else {
            ParkingCanvas(model: model, showGuide: game.showGuide, paint: paint)
                .overlay(alignment: .topLeading) { GearSpeed(model: model).padding(8) }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 6) {
                        AlignChip(model: model)
                        RadarChip(model: model)
                    }
                    .padding(8)
                }
        }
    }
}
