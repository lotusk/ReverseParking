import SwiftUI

@main
struct ReverseParkingApp: App {
    var body: some Scene {
        WindowGroup { HomeView().preferredColorScheme(.dark) }
    }
}

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("倒车练习").font(.largeTitle.bold())
                Text("两种视角，同一套场景和操作").foregroundStyle(.secondary)
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
