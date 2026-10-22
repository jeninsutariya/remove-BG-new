import SwiftUI

// MARK: Buttons

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyledButton(configuration: configuration, filled: true)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyledButton(configuration: configuration, filled: false)
    }
}

private struct StyledButton: View {
    let configuration: ButtonStyleConfiguration
    let filled: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(filled ? Theme.onAccent : Theme.text)
            .frame(maxWidth: .infinity, minHeight: 24)
            .padding(.vertical, 15)
            .background {
                if filled {
                    Capsule().fill(Theme.accent)
                } else {
                    Capsule().fill(Theme.surface).overlay(Capsule().stroke(Theme.border))
                }
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

/// Round icon button with a text label for VoiceOver.
struct IconButton: View {
    let symbol: String
    let label: String
    var isActive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(isActive ? Theme.accent : Theme.text)
                .frame(width: 44, height: 44)
                .background(Theme.surface.opacity(0.8), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: Artwork and cards

/// Gradient with an SF Symbol. Stands in for cover art until you have your own images.
struct ArtworkView: View {
    let colors: [String]
    let symbol: String
    var symbolSize: CGFloat = 34

    var body: some View {
        ZStack {
            Theme.gradient(colors)
            Image(systemName: symbol)
                .font(.system(size: symbolSize, weight: .light))
                .foregroundStyle(.white.opacity(0.85))
        }
        .accessibilityHidden(true)
    }
}

struct ContentCard: View {
    let item: ContentItem
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArtworkView(colors: item.colors, symbol: item.symbol)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
                .overlay(alignment: .topTrailing) {
                    if isLocked { LockBadge().padding(8) }
                }
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text("\(item.kind.label) · \(item.durationLabel)")
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text(isLocked ? "Premium" : ""))
    }
}

struct ContentRow: View {
    let item: ContentItem
    var detail: String? = nil
    var isLocked = false

    var body: some View {
        HStack(spacing: 14) {
            ArtworkView(colors: item.colors, symbol: item.symbol, symbolSize: 20)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                Text(detail ?? "\(item.kind.label) · \(item.durationLabel)")
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
            }
            Spacer(minLength: 0)
            if isLocked { LockBadge() }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct LockBadge: View {
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Theme.onAccent)
            .padding(6)
            .background(Theme.accent, in: Circle())
            .accessibilityLabel("Premium")
    }
}

struct CarouselRow: View {
    let title: String
    let items: [ContentItem]
    @Environment(SubscriptionStore.self) private var subscriptions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.text)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(items) { item in
                        NavigationLink(value: item) {
                            ContentCard(item: item, isLocked: !item.isFree && !subscriptions.isPremium)
                                .frame(width: 150)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollClipDisabled()
        }
    }
}

// MARK: Chips

struct Chip: View {
    let title: String
    var symbol: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected ? Theme.onAccent : Theme.text)
            .background(isSelected ? Theme.accent : Theme.surface, in: Capsule())
            .overlay(Capsule().stroke(isSelected ? Color.clear : Theme.border))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Lays children out left to right and wraps to new lines, like words in a paragraph.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: Stats

struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.text)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
        .accessibilityElement(children: .combine)
    }
}

struct StreakBadge: View {
    let days: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
            Text("\(days)")
                .monospacedDigit()
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(days > 0 ? Theme.accent : Theme.textMuted)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Theme.surface, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(days == 1 ? "1 day streak" : "\(days) day streak")
    }
}

// MARK: Breathing

struct BreathingCircle: View {
    var scale: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.accent.opacity(0.12))
                .scaleEffect(scale * 1.18)
            Circle()
                .fill(RadialGradient(
                    colors: [Theme.accent.opacity(0.9), Theme.accent.opacity(0.3)],
                    center: .center,
                    startRadius: 4,
                    endRadius: 150
                ))
                .scaleEffect(scale)
        }
        .accessibilityHidden(true)
    }
}

// MARK: Backgrounds and mini player

/// The selected scene's colors fading into the app background.
struct SceneBackdrop: View {
    @Environment(CatalogService.self) private var catalog
    @AppStorage(Keys.selectedSceneID) private var selectedSceneID = "dusk"

    var body: some View {
        let colors = catalog.scene(id: selectedSceneID)?.colors ?? []
        ZStack {
            Theme.background
            if !colors.isEmpty {
                Theme.gradient(colors).opacity(0.55)
                LinearGradient(colors: [.clear, Theme.background], startPoint: .center, endPoint: .bottom)
            }
        }
        .ignoresSafeArea()
    }
}

struct MiniPlayerBar: View {
    let item: ContentItem
    @Environment(PlayerController.self) private var player
    @Environment(AppRouter.self) private var router

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(colors: item.colors, symbol: item.symbol, symbolSize: 16)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small))
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                ProgressView(value: player.duration > 0 ? min(1, player.currentTime / player.duration) : 0)
                    .tint(Theme.accent)
            }
            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
            Button {
                player.stop()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 36, height: 44)
            }
            .accessibilityLabel("Stop")
        }
        .foregroundStyle(Theme.text)
        .padding(10)
        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
        .contentShape(Rectangle())
        .onTapGesture { router.isPlayerPresented = true }
        .accessibilityAction(named: "Open player") { router.isPlayerPresented = true }
    }
}

private struct MiniPlayerInset: ViewModifier {
    @Environment(PlayerController.self) private var player
    @Environment(AppRouter.self) private var router

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom) {
            if let item = player.current, !router.isPlayerPresented {
                MiniPlayerBar(item: item)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
            }
        }
    }
}

extension View {
    /// Shows the mini player above the tab bar while something is playing.
    func miniPlayer() -> some View {
        modifier(MiniPlayerInset())
    }

    /// For the first screen in each tab: mini player plus navigation to content details.
    func rootScreen() -> some View {
        miniPlayer()
            .navigationDestination(for: ContentItem.self) { item in
                ContentDetailView(item: item)
            }
    }
}
