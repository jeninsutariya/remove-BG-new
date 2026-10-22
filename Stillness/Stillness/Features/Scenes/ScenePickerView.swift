import SwiftUI

/// S14. The background picture and looping sound behind the whole app.
struct ScenePickerView: View {
    @Environment(CatalogService.self) private var catalog
    @Environment(ScenePlayer.self) private var scenes
    @Environment(SubscriptionStore.self) private var subscriptions
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Keys.selectedSceneID) private var selectedSceneID = "dusk"
    @AppStorage(Keys.sceneAfterMinutes) private var afterMinutes = 15
    @State private var isPaywallPresented = false

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        @Bindable var scenes = scenes

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(catalog.scenes) { scene in
                            Button {
                                select(scene)
                            } label: {
                                VStack(spacing: 6) {
                                    ArtworkView(colors: scene.colors, symbol: scene.symbol, symbolSize: 24)
                                        .aspectRatio(1, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                                                .stroke(Theme.accent, lineWidth: scene.id == selectedSceneID ? 3 : 0)
                                        )
                                        .overlay(alignment: .topTrailing) {
                                            if !scene.isFree && !subscriptions.isPremium { LockBadge().padding(6) }
                                        }
                                    Text(scene.name)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Theme.text)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(scene.name)
                            .accessibilityAddTraits(scene.id == selectedSceneID ? .isSelected : [])
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sound volume")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.text)
                        HStack {
                            Image(systemName: "speaker.fill")
                            Slider(value: $scenes.volume, in: 0...1)
                                .tint(Theme.accent)
                                .accessibilityLabel("Sound volume")
                            Image(systemName: "speaker.wave.3.fill")
                        }
                        .foregroundStyle(Theme.textMuted)
                    }

                    LabeledContent("Keep playing after you leave the app") {
                        Picker("Keep playing", selection: $afterMinutes) {
                            Text("Off").tag(0)
                            Text("15 min").tag(15)
                            Text("30 min").tag(30)
                            Text("1 hour").tag(60)
                        }
                        .pickerStyle(.menu)
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.text)
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Scenes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $isPaywallPresented) { PaywallView() }
        }
    }

    private func select(_ scene: SceneItem) {
        guard scene.isFree || subscriptions.isPremium else {
            isPaywallPresented = true
            return
        }
        selectedSceneID = scene.id
        scenes.play(scene)
    }
}
