import SwiftUI

struct ParkingCanvas: View {
    let model: ParkingModel
    let showGuide: Bool
    var paint = CarPaint.pearl
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
            let lineColor = Color.white.opacity(0.85)
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
                context.stroke(outline, with: .color(lineColor), lineWidth: 2)
            }
            if l.aisleEdge > 1 {
                let edge = l.aisleEdge
                context.fill(Path(rect(Box(x: min(0, l.leftEdge), y: 0, width: max(24, l.rightEdge) - min(0, l.leftEdge), height: edge))),
                             with: .color(Color(red: 0.2, green: 0.21, blue: 0.24)))
                context.stroke(line(Vector(x: min(0, l.leftEdge), y: edge), Vector(x: max(24, l.rightEdge), y: edge)),
                               with: .color(lineColor), lineWidth: 2)
                for (i, x) in stride(from: 1.0, through: 21.0, by: 3.2).enumerated() {
                    drawSedan(context, at: point(Vector(x: x + 1.6, y: edge - 2.7)), heading: .pi / 2, scale: scale,
                              paint: Color(uiColor: ParkedPaint.row(i)))
                }
            } else {
                context.stroke(line(Vector(x: 1, y: 3.5), Vector(x: 23, y: 3.5)),
                               with: .color(.white.opacity(0.25)),
                               style: StrokeStyle(lineWidth: 2, dash: [14, 12]))
            }

            for (i, b) in l.cars.enumerated() {
                drawSedan(context, at: point(Vector(x: b.x + b.width / 2, y: b.y + b.height / 2)),
                          heading: b.height > b.width ? -.pi / 2 : 0, scale: scale, paint: Color(uiColor: ParkedPaint.bay(i)),
                          length: max(b.width, b.height), width: min(b.width, b.height))
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
            drawSedan(context, at: point(Vector(x: p.x, y: p.y)), heading: p.heading, scale: scale,
                      paint: paint.color, steering: model.steering, reversing: model.gear < 0,
                      outline: model.won ? .green : model.collision ? .red : nil)

            // Parking sensor bars, in the same order as ParkingModel.sensors: front, right, rear, left.
            let hl = ParkingModel.length / 2, hw = ParkingModel.width / 2
            let edges = [(hl, -hw, hl, hw, 1.0, 0.0), (hl, hw, -hl, hw, 0.0, 1.0),
                         (-hl, hw, -hl, -hw, -1.0, 0.0), (-hl, -hw, hl, -hw, 0.0, -1.0)]
            func world(_ lx: Double, _ ly: Double) -> CGPoint {
                point(Vector(x: p.x + lx * cos(p.heading) - ly * sin(p.heading),
                             y: p.y + lx * sin(p.heading) + ly * cos(p.heading)))
            }
            for (i, d) in ParkingModel.sensors(p, in: l).enumerated() where d < 1.0 && !model.won {
                let (ax, ay, bx, by, nx, ny) = edges[i / 3]
                let t0 = (Double(i % 3) + 0.1) / 3, t1 = (Double(i % 3) + 0.9) / 3
                var bar = Path()
                bar.move(to: world(ax + (bx - ax) * t0 + nx * 0.28, ay + (by - ay) * t0 + ny * 0.28))
                bar.addLine(to: world(ax + (bx - ax) * t1 + nx * 0.28, ay + (by - ay) * t1 + ny * 0.28))
                context.stroke(bar, with: .color(d < 0.3 ? .red : d < 0.6 ? .orange : .yellow),
                               style: StrokeStyle(lineWidth: max(3, 0.16 * scale), lineCap: .round))
            }
        }
        .accessibilityLabel("倒车入库俯视练习场")
    }
}
