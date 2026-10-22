# Stillness (working name)

An iPhone sleep and meditation app in SwiftUI: guided audio, sleep stories,
background scenes, breathing, mood check-ins, streaks, Apple Health,
reminders, offline downloads and a subscription with a free trial.

It rebuilds what the recon in `../replica/recon.md` found the app does, written
from scratch. It has no code, audio, images, wording or branding from any
other app. "Stillness" is a placeholder. Run `/replica-brand` to choose the
real name before you launch.

## Run it

You need a Mac with **Xcode 16 or newer**.

1. Open `Stillness/Stillness.xcodeproj`.
2. Select the **Stillness** target, then **Signing & Capabilities**:
   - **Team**: your Apple developer team.
   - **Bundle Identifier**: change `com.stillness.app` to one you own, like `com.yourname.yourapp`.
3. Use the local test store for purchases: **Product > Scheme > Edit Scheme > Run > Options >
   StoreKit Configuration**, then pick `Products.storekit`.
4. Pick an iPhone simulator and press **Run** (⌘R).
5. Run the tests with ⌘U.

Use a real iPhone to test the lock screen controls, background audio,
Apple Health and reminders properly. The simulator can't do all of it.

## What's in it

| Screen | File |
| --- | --- |
| S01 to S06 onboarding: breathe, goals, experience, sign in, reminder | `Features/Onboarding/OnboardingFlow.swift` |
| S05 paywall | `Features/Paywall/PaywallView.swift` |
| S07 Home | `Features/Home/HomeView.swift` |
| S08 to S10 Sleep, Meditate, Music tabs | `Features/Browse/BrowseView.swift` |
| S11 content detail, add to playlist | `Features/Browse/ContentDetailView.swift` |
| S12 player, S13 session complete | `Features/Player/PlayerView.swift` |
| S14 scenes | `Features/Scenes/ScenePickerView.swift` |
| S15 breathe | `Features/Breathe/BreatheView.swift` |
| S16 check-in, S18 history | `Features/CheckIn/CheckInView.swift` |
| S17 profile and library | `Features/Profile/ProfileView.swift`, `LibraryViews.swift` |
| S19 settings | `Features/Profile/SettingsView.swift` |

| Service | What it does |
| --- | --- |
| `CatalogService` | reads `Resources/catalog.json`: every track, topic, scene and the daily session |
| `PlayerController` | plays sessions with the screen locked, lock screen controls, sleep timer, handles calls and unplugged headphones |
| `ScenePlayer` | looping background sound, quieter while a session plays |
| `SubscriptionStore` | StoreKit 2: products, purchase, restore, free-trial eligibility |
| `HealthService` | writes mindful minutes to Apple Health |
| `ReminderService` | daily local notifications |
| `DownloadService` | saves audio for offline listening |
| `AuthService` | optional Sign in with Apple |

User data (sessions, check-ins, favorites, playlists, downloads) is saved on
the phone with SwiftData. There's no server yet.

## Before you can sell it

1. **Your own audio.** Every item in `catalog.json` labelled "Sample" plays
   generated noise. Record your own sessions, hire narrators, or license
   music and stories for commercial use. Aim for 30 to 50 tracks at launch.
   Then either bundle the files (`"audio": "bundle:my-file.m4a"`) or host them
   on a CDN (`"audio": "https://cdn.example.com/my-file.m4a"`) and load
   `catalog.json` from there in `CatalogService.load()`.
2. **Name and look.** `/replica-brand` gives you a name, colours (edit
   `Design/Theme.swift`) and an app icon brief. Replace
   `Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`.
3. **App Store Connect.** Create the app, then three in-app purchases with
   exactly these IDs, or change `SubscriptionStore.productIDs` to match yours:
   - `stillness.premium.yearly`, an auto-renewable subscription with a 1-week free trial
   - `stillness.premium.monthly`, an auto-renewable subscription in the same group
   - `stillness.premium.lifetime`, a non-consumable
4. **Links.** Put real terms, privacy and support URLs in `App/AppState.swift`
   (`AppLinks`). App Review checks them.
5. **Capabilities.** HealthKit and Sign in with Apple are already in
   `Config/Stillness.entitlements`. With automatic signing, Xcode turns them on
   for your App ID. Background audio is set in `Config/Info.plist`.

## Notes

- iOS 17 and newer, iPhone only, dark mode, Swift 5 language mode.
- The project uses Xcode 16 synced folders: add a file to `Stillness/` in
  Finder or in Xcode and it's part of the app automatically.
- Remaining features from `../replica/features.csv`: email sign-in (needs a
  server), Apple Watch, opening the check-in screen from a reminder, and
  "play all" for playlists.
