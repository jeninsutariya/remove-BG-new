import SwiftUI

struct RootView: View {
    @AppStorage(Keys.hasOnboarded) private var hasOnboarded = false

    var body: some View {
        Group {
            if hasOnboarded {
                MainTabView()
            } else {
                OnboardingFlow()
            }
        }
        .background(Theme.background.ignoresSafeArea())
    }
}
