import SwiftUI

struct BreathPattern: Identifiable, Hashable {
    let id: String
    let name: String
    let inhale: Double
    let hold: Double
    let exhale: Double
    let holdAfter: Double

    static let all = [
        BreathPattern(id: "even", name: "Even", inhale: 5, hold: 0, exhale: 5, holdAfter: 0),
        BreathPattern(id: "relax", name: "Relax", inhale: 4, hold: 7, exhale: 8, holdAfter: 0),
        BreathPattern(id: "box", name: "Box", inhale: 4, hold: 4, exhale: 4, holdAfter: 4),
    ]
}

/// S15. A shape that grows as you breathe in and shrinks as you breathe out.
struct BreatheView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(HealthService.self) private var health
    @AppStorage(Keys.healthEnabled) private var healthEnabled = false

    @State private var pattern = BreathPattern.all[0]
    @State private var minutes = 1
    @State private var isRunning = false
    @State private var isFinished = false
    @State private var phaseText = "Ready when you are"
    @State private var scale: CGFloat = 0.55
    @State private var startedAt = Date()
    @State private var endsAt = Date()
    @State private var runTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 28) {
                HStack {
                    Spacer()
                    IconButton(symbol: "xmark", label: "Close") {
                        stop()
                        dismiss()
                    }
                }

                Spacer(minLength: 0)

                BreathingCircle(scale: scale)
                    .frame(width: 260, height: 260)

                Text(phaseText)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.text)
                    .contentTransition(.opacity)
                    .accessibilityAddTraits(.updatesFrequently)

                if isRunning {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(PlayerView.format(max(0, endsAt.timeIntervalSince(context.date))))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(Theme.textMuted)
                    }
                }

                Spacer(minLength: 0)

                if isRunning {
                    Button("Stop", action: stop)
                        .buttonStyle(.secondary)
                } else {
                    VStack(spacing: 14) {
                        Picker("Pattern", selection: $pattern) {
                            ForEach(BreathPattern.all) { Text($0.name).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Picker("Length", selection: $minutes) {
                            Text("1 min").tag(1)
                            Text("3 min").tag(3)
                            Text("5 min").tag(5)
                        }
                        .pickerStyle(.segmented)
                        Button(isFinished ? "Go again" : "Start", action: start)
                            .buttonStyle(.primary)
                    }
                }
            }
            .padding(24)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: phaseText)
        .onDisappear { stop() }
    }

    private func start() {
        isRunning = true
        isFinished = false
        startedAt = .now
        let total = Double(minutes * 60)
        endsAt = startedAt.addingTimeInterval(total)
        let current = pattern

        runTask = Task { @MainActor in
            while !Task.isCancelled && Date.now < endsAt {
                await phase("Breathe in", to: 1, for: current.inhale)
                if current.hold > 0 { await phase("Hold", to: 1, for: current.hold) }
                await phase("Breathe out", to: 0.55, for: current.exhale)
                if current.holdAfter > 0 { await phase("Hold", to: 0.55, for: current.holdAfter) }
            }
            guard !Task.isCancelled else { return }
            finish(completed: true)
            phaseText = "Well done"
            isFinished = true
        }
    }

    private func stop() {
        guard isRunning else { return }
        runTask?.cancel()
        finish(completed: false)
        phaseText = "Ready when you are"
    }

    private func finish(completed: Bool) {
        isRunning = false
        withAnimation(.easeInOut(duration: 0.6)) { scale = 0.55 }
        SessionLogger(context: context, health: health, healthEnabled: healthEnabled).log(
            contentID: "breathe-\(pattern.id)",
            kind: .breathing,
            startedAt: startedAt,
            seconds: Date.now.timeIntervalSince(startedAt),
            completed: completed
        )
    }

    @MainActor
    private func phase(_ text: String, to target: CGFloat, for seconds: Double) async {
        guard !Task.isCancelled else { return }
        phaseText = text
        withAnimation(.easeInOut(duration: seconds)) { scale = target }
        try? await Task.sleep(for: .seconds(seconds))
    }
}
