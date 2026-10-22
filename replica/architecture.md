# Architecture: Stillness (working name), an iOS sleep and meditation app

Reads `replica/recon.md` and `replica/features.csv`. "Stillness" is a
placeholder name until `/replica-brand` picks the real one.

## Stack

| layer | choice | why |
| --- | --- | --- |
| app | SwiftUI, iOS 17+, iPhone | Observation (`@Observable`) and SwiftData need iOS 17; that covers most active iPhones |
| local data | SwiftData | sessions, check-ins, favorites, playlists and downloads live on the device. No server needed for v1 |
| content catalog | `catalog.json` bundled now, same JSON from your CDN later | one file describes every track, so adding content needs no app update once it is remote |
| audio files | bundled samples now, then a CDN (Cloudflare R2, S3 + CloudFront, or Bunny) | cheap, fast streaming of large files |
| playback | AVFoundation (`AVPlayer` for sessions, looping `AVAudioPlayer` for scenes) + MediaPlayer for the lock screen | the system tools; handles background audio and interruptions |
| payments | StoreKit 2 with a local `.storekit` file for testing | no server needed; Apple handles trials, renewals and Family Sharing |
| sign in | Sign in with Apple (optional) | one tap, and Apple requires it if you add other social logins |
| health | HealthKit mindful minutes | in the recon (source 4) |
| reminders | UserNotifications, local daily triggers | no push server needed |
| later | a backend (Supabase or CloudKit) for sync across devices | only once users ask for it |

One app target, one test target. No third-party packages.

## Data

Content (read-only, from `catalog.json`):

```
Catalog     topics[], narrators[], series[], items[], scenes[], dailyRotation[]
ContentItem id, kind (meditation | sleepStory | music | soundscape | breathing),
            title, summary, narratorID?, seriesID?, episode?, durationSeconds,
            audio ("bundle:file.wav" or https URL), symbol, colors[], isFree, topics[]
SceneItem   id, name, symbol, colors[], loopAudio?, isFree
```

User data (SwiftData, on the device):

```
SessionRecord   id, contentID, kindRaw, startedAt, secondsListened, completed
CheckInRecord   id, kindRaw (mood | sleep | gratitude), value 1-5, tags[], note, createdAt
FavoriteRecord  contentID (unique), createdAt
PlaylistRecord  id, name, createdAt, itemIDs[] (ordered)
DownloadRecord  contentID (unique), fileName, downloadedAt
```

Settings (UserDefaults): onboarding done, goals, experience, chosen scene,
scene volume, how long scenes keep playing outside the app, Apple Health on/off,
reminder times, Apple user ID.

Subscription state comes from StoreKit (`Transaction.currentEntitlements`)
every launch, never from a stored flag.

## Rules

- A session counts toward the streak if it was completed or ran 60 seconds or
  more. Days are calendar days in the phone's time zone.
- Apple Health gets meditations, sleep stories and breathing only. Music and
  scenes are not saved.
- Playlists accept meditations, sleep stories and music only (recon source 2).
- Premium content shows a lock badge. Opening it shows its details; pressing
  Play opens the paywall.

## Build order

1. Vertical slice: Home, then detail, then the player plays a bundled file.
2. Must-haves: onboarding, paywall, Sleep/Meditate/Music tabs, scenes,
   breathing, check-ins, streak, profile, downloads, reminders, Health.
3. Should-haves: search, playlists, history, mini player.
4. The fixes `/replica-entrepreneur` finds.

## Risky parts

1. **Content.** The code is the smaller job. Plan the 30 to 50 launch tracks now.
2. **Audio edge cases:** calls, Siri, unplugged headphones, sleep timer with
   the screen locked. Test on a real phone, not only the simulator.
3. **App Review:** the paywall must show the price clearly, have a close button,
   restore, and terms and privacy links. Health and audio background modes
   must be used for what you say they are.
