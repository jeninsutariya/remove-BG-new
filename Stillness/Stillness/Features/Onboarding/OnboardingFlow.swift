import SwiftUI
import AuthenticationServices

/// S01 to S06: breathe, goals, experience, sign in, paywall, reminder.
struct OnboardingFlow: View {
    enum Step: Int, CaseIterable {
        case breathe, goals, experience, signIn, paywall, reminder
    }

    @Environment(SubscriptionStore.self) private var subscriptions
    @Environment(AuthService.self) private var auth
    @AppStorage(Keys.hasOnboarded) private var hasOnboarded = false
    @State private var step: Step = .breathe

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            Group {
                switch step {
                case .breathe: BreatheIntroView(onContinue: advance)
                case .goals: GoalsView(onContinue: advance)
                case .experience: ExperienceView(onContinue: advance)
                case .signIn: SignInView(onContinue: advance)
                case .paywall: PaywallView(onClose: advance)
                case .reminder: ReminderSetupView(onFinish: finish)
                }
            }
            .id(step)
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.35), value: step)
    }

    private func advance() {
        var next = Step(rawValue: step.rawValue + 1)
        if next == .signIn, auth.isSignedIn { next = .paywall }
        if next == .paywall, subscriptions.isPremium { next = .reminder }
        if let next { step = next } else { finish() }
    }

    private func finish() {
        hasOnboarded = true
    }
}

// MARK: S01

struct BreatheIntroView: View {
    let onContinue: () -> Void
    @State private var expanded = false
    @State private var label = "Breathe in"
    @State private var isDone = false

    var body: some View {
        VStack(spacing: 36) {
            HStack {
                Spacer()
                Button("Skip", action: onContinue)
                    .foregroundStyle(Theme.textMuted)
            }
            Spacer()
            Text("Take a deep breath")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.text)
            BreathingCircle(scale: expanded ? 1 : 0.55)
                .frame(width: 240, height: 240)
            Text(label)
                .font(.headline)
                .foregroundStyle(Theme.textMuted)
                .contentTransition(.opacity)
            Spacer()
            Button("Continue", action: onContinue)
                .buttonStyle(.primary)
                .opacity(isDone ? 1 : 0)
                .disabled(!isDone)
        }
        .padding(24)
        .task {
            withAnimation(.easeInOut(duration: 4)) { expanded = true }
            try? await Task.sleep(for: .seconds(4))
            label = "Breathe out"
            withAnimation(.easeInOut(duration: 5)) { expanded = false }
            try? await Task.sleep(for: .seconds(5))
            label = "Nice. Let's set things up for you."
            withAnimation { isDone = true }
        }
    }
}

// MARK: S02

struct GoalsView: View {
    let onContinue: () -> Void
    @Environment(CatalogService.self) private var catalog
    @AppStorage(Keys.goals) private var goalsRaw = ""
    @State private var selected: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer().frame(height: 24)
            Text("What brings you here?")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Theme.text)
            Text("Pick as many as you like. We'll use them to suggest sessions.")
                .foregroundStyle(Theme.textMuted)
            FlowLayout(spacing: 10) {
                ForEach(catalog.topics) { topic in
                    Chip(title: topic.title, symbol: topic.symbol, isSelected: selected.contains(topic.id)) {
                        if selected.contains(topic.id) {
                            selected.remove(topic.id)
                        } else {
                            selected.insert(topic.id)
                        }
                    }
                }
            }
            Spacer()
            Button("Continue") {
                goalsRaw = catalog.topics.map(\.id).filter { selected.contains($0) }.joined(separator: ",")
                onContinue()
            }
            .buttonStyle(.primary)
        }
        .padding(24)
        .onAppear {
            selected = Set(goalsRaw.split(separator: ",").map(String.init))
        }
    }
}

// MARK: S03

struct ExperienceView: View {
    let onContinue: () -> Void
    @AppStorage(Keys.experience) private var experience = ""

    private let options = [
        ("new", "I'm new to this"),
        ("some", "I've tried it a few times"),
        ("regular", "I do it often"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer().frame(height: 24)
            Text("How much have you meditated?")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Theme.text)
            VStack(spacing: 12) {
                ForEach(options, id: \.0) { option in
                    Button {
                        experience = option.0
                    } label: {
                        HStack {
                            Text(option.1)
                            Spacer()
                            if experience == option.0 {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                        .padding(18)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                                .stroke(experience == option.0 ? Theme.accent : Theme.border)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(experience == option.0 ? .isSelected : [])
                }
            }
            Spacer()
            Button("Continue", action: onContinue)
                .buttonStyle(.primary)
        }
        .padding(24)
    }
}

// MARK: S04

struct SignInView: View {
    let onContinue: () -> Void
    @Environment(AuthService.self) private var auth

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Theme.accent)
            Text("Save your progress")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Theme.text)
            Text("Sign in to keep your streak and favorites when you change phones. You can do this later in Settings.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textMuted)
            Spacer()
            SignInWithAppleButton(.signUp) { request in
                request.requestedScopes = [.fullName]
            } onCompletion: { result in
                if auth.handle(result) { onContinue() }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 52)
            .clipShape(Capsule())
            Button("Not now", action: onContinue)
                .foregroundStyle(Theme.textMuted)
                .padding(.vertical, 8)
        }
        .padding(24)
    }
}

// MARK: S06

struct ReminderSetupView: View {
    let onFinish: () -> Void
    @Environment(ReminderService.self) private var reminders
    @State private var time = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 24)
            Text("When should we remind you?")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
            Text("People who pick a time are more likely to make it a habit.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textMuted)
            DatePicker("Reminder time", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
            Spacer()
            Button {
                isSaving = true
                Task {
                    await reminders.update(.mindfulness, enabled: true, time: time)
                    onFinish()
                }
            } label: {
                if isSaving { ProgressView().tint(Theme.onAccent) } else { Text("Remind me") }
            }
            .buttonStyle(.primary)
            .disabled(isSaving)
            Button("Not now", action: onFinish)
                .foregroundStyle(Theme.textMuted)
                .padding(.vertical, 8)
        }
        .padding(24)
    }
}
