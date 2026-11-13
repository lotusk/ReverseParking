import SwiftUI

// Analog pedal: touch to go, slide up to go faster, let go to stop.
struct Pedal: View {
    @Binding var value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Color.white.opacity(0.08)
                LinearGradient(colors: [Color(red: 0.1, green: 0.75, blue: 0.4), Color(red: 0.05, green: 0.5, blue: 0.3)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: geo.size.height * value)
                VStack(spacing: 6) {
                    Image(systemName: value > 0 ? "pedal.accelerator.fill" : "pedal.accelerator").font(.system(size: 32))
                    Text(value > 0 ? String(format: "%.0f%%", value * 100) : "按住走")
                        .font(.subheadline.bold().monospacedDigit())
                    Text("越靠上越快").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { touch in
                    let level = 1 - touch.location.y / geo.size.height
                    value = 0.15 + 0.85 * max(0, min(1, level))
                }
                .onEnded { _ in value = 0 })
        }
        .frame(width: 86)
        .accessibilityLabel("电门，按住走，往上滑更快，松开停车")
    }
}

struct GearColumn: View {
    let game: Game

    var body: some View {
        VStack(spacing: 8) {
            button("R", value: -1, color: .orange)
            button("P", value: 0, color: .gray)
            button("D", value: 1, color: .blue)
        }
        .frame(width: 58)
        .sensoryFeedback(.impact(weight: .medium), trigger: game.model.gear)
    }

    private func button(_ title: String, value: Double, color: Color) -> some View {
        let selected = game.model.gear == value
        return Button { game.shift(value) } label: {
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(selected ? color : Color.white.opacity(0.08))
                .foregroundStyle(selected ? .white : .gray)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
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
                wheel(side: side).position(center)
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
                    let dx = value.location.x - center.x, dy = value.location.y - center.y
                    // Near the hub a tiny finger move is a huge angle, so ignore it.
                    guard hypot(dx, dy) > side * 0.18 else { lastTouch = nil; return }
                    let touch = atan2(dy, dx) * 180 / .pi
                    if let last = lastTouch {
                        var delta = touch - last
                        if delta > 180 { delta -= 360 }
                        if delta < -180 { delta += 360 }
                        angle = max(-maxAngle, min(maxAngle, angle + delta))
                    }
                    lastTouch = touch
                }
                .onEnded { _ in
                    lastTouch = nil
                    if abs(angle) < 4 { angle = 0 }
                })
        }
        .sensoryFeedback(.selection, trigger: detent)
        .accessibilityLabel("方向盘")
        .accessibilityValue(label)
    }

    private var detent: Int {
        abs(angle) >= maxAngle ? (angle > 0 ? 2 : -2) : abs(angle) < 4 ? 0 : (angle > 0 ? 1 : -1)
    }

    private var label: String {
        if abs(angle) < 4 { return "方向正" }
        return String(format: "%@ %.2f 圈", angle < 0 ? "左" : "右", abs(angle) / 360)
    }

    private func wheel(side: CGFloat) -> some View {
        let d = side * 0.94
        let shade = LinearGradient(colors: [Color(white: 0.36), Color(white: 0.13)], startPoint: .top, endPoint: .bottom)
        return ZStack {
            Circle().strokeBorder(shade, lineWidth: d * 0.115)
            Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            Circle().strokeBorder(Color.black.opacity(0.5), lineWidth: 1).padding(d * 0.115)
            ZStack {
                ForEach([0.0, 180.0, 90.0], id: \.self) { a in
                    Capsule()
                        .fill(Color(white: 0.2))
                        .frame(width: d * 0.33, height: d * (a == 90 ? 0.1 : 0.12))
                        .offset(x: d * 0.25)
                        .rotationEffect(.degrees(a))
                }
                RoundedRectangle(cornerRadius: d * 0.09)
                    .fill(LinearGradient(colors: [Color(white: 0.3), Color(white: 0.17)], startPoint: .top, endPoint: .bottom))
                    .frame(width: d * 0.4, height: d * 0.3)
                Capsule()
                    .fill(Color.red)
                    .frame(width: d * 0.04, height: d * 0.115)
                    .offset(y: -d / 2 + d * 0.0575)
            }
            .rotationEffect(.degrees(angle))
        }
        .frame(width: d, height: d)
        .opacity(abs(angle) >= maxAngle ? 0.75 : 1)
    }
}
