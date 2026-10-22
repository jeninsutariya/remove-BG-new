# Recon map: Calm (iOS)

Scope: the core loop of a sleep and meditation app. Guided audio sessions
(meditations, sleep stories), ambient background scenes, a guided breathing
exercise, a daily session, mood check-ins, streaks and stats, reminders,
Apple Health, and a subscription paywall with a free trial.
For: the user's own product, to sell on the App Store.
Date: 2026-10-22

## Sources

This session's network policy blocked apps.apple.com, calm.com and
support.calm.com, so nothing was fetched directly. Everything below comes from
web search results that quote these pages. Re-check anything marked medium or
guess against the live app on your own phone.

| # | source | URL | notes |
| --- | --- | --- | --- |
| 1 | app store listing | https://apps.apple.com/us/app/calm/id571800810 | the link the user gave. Pitch: Sleep Stories, Daily Calm, breathing, "Daily Streaks & Mindful Minutes" |
| 2 | help center: Features and Customization | https://support.calm.com/hc/en-us/sections/360001941774-Features-and-Customization | playlists, favorites, stats, history, streak, reminders |
| 3 | help center: sleep timers and playlists | https://support.calm.com/hc/en-us/articles/115002582908-How-to-Use-the-Calm-App-to-Fall-Asleep-Sleep-Timers-Playlists | Scenes, "play sounds outside the app", music timer |
| 4 | help center: Apple Health | https://support.calm.com/hc/en-us/articles/115005140814-Apple-Health | writes Mindful Minutes for guided sessions only, not Scenes |
| 5 | help center: reminders | https://support.calm.com/hc/en-us/articles/360008620774-How-to-Set-Reminders | Profile > gear > Notifications: Daily Mindfulness, Bedtime, Mood Check-In, Gratitude |
| 6 | help center: billing and renewal | https://support.calm.com/hc/en-us/articles/115002587948-How-Calm-Subscriptions-Are-Billed-Renewed | auto-renewing subscription |
| 7 | help center: yearly premium | https://support.calm.com/hc/en-us/articles/115002473687-How-to-Purchase-a-Yearly-Calm-Premium-Subscription | 7-day trial, then yearly |
| 8 | pricing roundup | https://carepaths.com/calm-app-pricing/ | ~$69.99/yr on iOS, $14.99 to $16.99/mo, lifetime $399.99 to $499.99, family $99.99/yr for 6 |
| 9 | onboarding teardown | https://screensdesign.com/articles/calm-onboarding-design/ | deep breath first, "What brings you to Calm?" multi-select, experience level, then paywall |
| 10 | onboarding teardown | https://goodux.appcues.com/blog/calm-app-new-user-experience | same flow, paywall after setup |
| 11 | review | https://www.healthline.com/health/mental-health/calm-app-reviews | free tier: daily meditation, breathing, mood tracker, some stories and music |
| 12 | review | https://carepaths.com/calm-app-review/ | tabs: Home, Sleep, Meditate, Music, Masterclass (one user's account) |
| 13 | review | https://www.techradar.com/reviews/calm | Watch, WearOS and smart speaker apps exist |

Next, to firm this up: screenshots of each screen from your own phone in
`replica/screens/` (named S01.png, S02.png...), and a public walkthrough video.

## Core loop

Open the app at night or during a stressful moment, press play on a guided
audio session over a calming background, and come back tomorrow to keep the
streak going. Users pay for the full content library.

## Screens

| ID | screen | route / how to reach | purpose | key components | states seen |
| --- | --- | --- | --- | --- | --- |
| S01 | Splash + breathe intro | first launch | one guided deep breath to set the mood before anything else | animated breathing circle, "Take a deep breath" text, continue | first launch only |
| S02 | Goals quiz | onboarding | "What brings you to Calm?" | multi-select chips (sleep, stress, anxiety, focus...), continue | none selected, some selected |
| S03 | Experience quiz | onboarding | meditation experience level | single-select list (new, some, a lot) | default, selected |
| S04 | Sign up / log in | onboarding, Profile | create an account | Sign in with Apple, email, log in link | default, error, loading |
| S05 | Paywall | end of onboarding, any locked item | start a free trial | plan cards (yearly with trial, monthly), restore purchases, terms links, close X | default, purchasing, failed, restored |
| S06 | Reminder setup | end of onboarding, Settings | pick a daily time | time picker, notification permission prompt | permission allowed, denied |
| S07 | Home | tab 1 | today's session and personalised rows | Daily session hero card, carousels by goal, streak badge, Scenes button (top left) | free, premium, offline |
| S08 | Sleep | tab 2 | sleep stories and sleep sounds | category chips, content grid, locked badges | loading, filled, locked |
| S09 | Meditate | tab 3 | guided meditations by topic | topic chips (anxiety, focus, beginners...), list rows, length filter | loading, filled, locked |
| S10 | Music / Soundscapes | tab 4 | focus and sleep music, ambient soundscapes | content grid | loading, filled, locked |
| S11 | Content detail | tap any card | describe a session or series before playing | cover art, title, narrator, length, description, play, download, favorite, series episode list | free, locked, downloaded |
| S12 | Player | play from S11 or S07 | listen | play/pause, skip ±15s, scrubber, timer, favorite, add to playlist, share, background volume | playing, paused, buffering, ended, offline |
| S13 | Session complete | end of a guided session | reward and nudge the habit | streak count, mindful minutes, "how do you feel" prompt, done | streak continued, streak started |
| S14 | Scenes picker | Scenes button on S07 | choose the background image and looping sound | scene grid, volume slider, play outside the app timer | selected, previewing |
| S15 | Breathe | Home row or Meditate | guided breathing exercise | expanding/contracting shape, pace options, length options | running, paused, finished |
| S16 | Check-in | Home card, reminder, S13 | log mood, sleep or gratitude | mood scale, reason tags, optional note, save | empty, saved |
| S17 | Profile | tab 5 or avatar | stats and library | streak, total sessions, mindful minutes, history, favorites, playlists, downloads | new user (zeros), filled |
| S18 | Check-in history | S17 | look back at moods | list or calendar of entries | empty, filled |
| S19 | Settings | gear on S17 | account and preferences | notifications (S06), Apple Health toggle, subscription, restore, log out, delete account | default |

Masterclass tab and kids content are out of scope (see below).

## Flows

```
F01 First launch to first session (the one to get right)
    S01 -> S02 -> S03 -> S04 -> S05 -> S06 -> S07 -> S11 -> S12 -> S13
    happy path clicks: about 9 (breathe, pick goals, continue, pick level, Sign in with Apple, start trial or close, set reminder, tap daily card, play)
    edge: user closes the paywall (must still reach free content), denies notifications, no network on first launch, Apple sign-in cancelled

F02 Fall asleep with a sleep story
    S07 -> S08 -> S11 -> S12 (screen locks, audio keeps playing)
    happy path clicks: 3
    edge: story is locked (-> S05), phone locked mid-story, headphones unplugged, incoming call, background scene keeps playing after the story for the chosen time

F03 Daily session and streak
    S07 daily card -> S12 -> S13
    happy path clicks: 2
    edge: missed a day (streak resets), time zone change, played offline (counts when back online), session stopped early (does it count?)

F04 Breathe for one minute
    S07 or S09 -> S15
    happy path clicks: 2
    edge: app backgrounded mid-exercise, sound off, haptics off

F05 Mood check-in
    reminder notification or S07 card -> S16 -> saved -> S18 later
    happy path clicks: 3
    edge: two check-ins on one day, no note, check-in from the notification

F06 Change the background scene
    S07 Scenes button -> S14 -> pick -> back
    happy path clicks: 2
    edge: scene sound plays under a session and must duck, volume at zero

F07 Download for offline
    S11 download -> later, airplane mode -> S17 downloads -> S12
    happy path clicks: 1 to download, 3 to play
    edge: storage full, subscription lapsed (downloads lock), download interrupted

F08 Subscribe or restore
    any locked item -> S05 -> Apple purchase sheet -> unlocked
    happy path clicks: 2
    edge: purchase cancelled, payment fails, already subscribed on another device (restore), trial already used, Family Sharing

F09 Set reminders and Apple Health
    S17 -> S19 -> S06 / Health toggle
    happy path clicks: 3
    edge: permission denied in iOS settings, Health write denied, Scenes must not be written as mindful minutes

F10 Favorites and playlists
    S12 favorite / add to playlist -> S17 library
    happy path clicks: 2
    edge: breathing exercises, timed meditations and soundscapes cannot go in playlists (per source 2)
```

## Components

| component | variants | states | used on |
| --- | --- | --- | --- |
| Content card | large hero, square, wide row | default, pressed, locked (lock badge), downloaded | S07, S08, S09, S10 |
| Carousel row | titled horizontal scroll | loading (skeleton), filled | S07, S08, S09, S10 |
| Category chips | single-select, multi-select | default, selected | S02, S08, S09 |
| Primary button | filled, outline, text | default, pressed, disabled, loading | everywhere |
| Plan card | yearly (badge "free trial"), monthly | default, selected | S05 |
| Tab bar | 5 tabs | selected, unselected | S07 to S10, S17 |
| Mini player | bar above tab bar | playing, paused | all tabs while audio plays |
| Full player controls | play/pause, ±15s, scrubber, timer | playing, paused, buffering | S12 |
| Breathing shape | circle/blob animation | inhale, hold, exhale | S01, S15 |
| Mood scale | 5 faces or words | none, selected | S16 |
| Streak badge | small (home), large (complete screen) | 0, active | S07, S13, S17 |
| Stat tile | number + label | zero, filled | S13, S17 |
| Time picker | wheel | default | S06 |
| Toggle row | setting row with switch | on, off, disabled | S19 |
| Full-screen background | still image or looping video + sound | playing, muted | S07, S12, S14 |
| Bottom sheet | timer options, playlist picker | open, closed | S12 |

## Inferred data model

```
User           id, apple_user_id or email, display_name, created_at,
               goals (text[]), experience_level, timezone,
               selected_scene_id
               evidence: S02, S03, S04, S14
               confidence: high

Subscription   user_id, product_id (yearly | monthly | lifetime | family),
               status (trial | active | grace | expired), started_at,
               expires_at, original_transaction_id
               evidence: S05, sources 6, 7, 8
               confidence: high (with StoreKit 2 this lives on the device and in
               App Store Server Notifications, mirrored to your server)

Content        id, type (meditation | sleep_story | music | soundscape |
               breathing | daily), title, description, narrator_id,
               duration_sec, audio_url, cover_url, is_free, topics (text[]),
               series_id, episode_number, published_at
               evidence: S08 to S12, source 2 (playlist exclusions by type)
               confidence: high

Series         id, title, description, cover_url
               evidence: S11 episode list
               confidence: medium

Narrator       id, name, bio, photo_url
               evidence: S11
               confidence: medium

DailySession   date, content_id
               evidence: S07 hero card ("Daily Calm" in sources 1, 11)
               confidence: high

Scene          id, name, image_or_video_url, loop_audio_url, is_free
               evidence: S14, source 3
               confidence: high

Session        id, user_id, content_id, started_at, ended_at,
               seconds_listened, completed (bool), wrote_to_health (bool)
               evidence: S13, S17 history, source 4
               confidence: high

Streak         derived from Session by day in the user's timezone
               (current, longest)
               evidence: S13, S17
               confidence: medium (exact rule unknown: minimum minutes? any play?)

CheckIn        id, user_id, kind (mood | sleep | gratitude), value (1-5),
               tags (text[]), note, created_at
               evidence: S16, source 5
               confidence: medium

Favorite       user_id, content_id, created_at
               evidence: S12, source 2
               confidence: high

Playlist       id, user_id, name; PlaylistItem playlist_id, content_id, position
               evidence: source 2
               confidence: high

Download       device-local only: content_id, file_path, downloaded_at
               evidence: F07
               confidence: high

Reminder       user_id, kind (mindfulness | bedtime | mood | gratitude),
               time_of_day, enabled
               evidence: S06, source 5
               confidence: high
```

Relationships: User 1-n Session, User 1-n CheckIn, User 1-n Favorite,
User 1-n Playlist, Playlist 1-n PlaylistItem, Series 1-n Content,
Narrator 1-n Content, Content 1-n Session, User 1-1 Subscription.

## Feature matrix

See `features.csv`. Must: 23, should: 12, could: 5, skip: 6.

## Out of scope (cannot or should not be cloned)

- **Calm's audio library.** Every meditation, sleep story, music track and
  scene video is licensed content Calm owns. Your app needs its own: record
  it yourself, hire voice talent, license royalty-free music and nature
  sounds, or generate audio with a text-to-speech service whose terms allow
  commercial use. This is the biggest cost of the project, bigger than the code.
- **Celebrity narrators and Masterclasses.** Talent deals, not a feature.
- **The "Calm" name, logo, blue-gradient lake look and wording.** Changed by
  `/replica-brand` before launch.
- **Calm Health, Calm Business, partner deals** (employers, insurers, Amazon
  Prime, etc.).
- **Kids content.** Possible later, but it brings extra App Store rules (Kids
  Category, COPPA). Not in the first version.
- **Apple Watch, widgets, Android, smart speakers.** Not cloned now. Watch and
  a widget are "could" rows for later.

## Size

Screens 19, flows 10, entities 13. Hard parts:

1. **The content.** You need about 30 to 50 good audio pieces at launch for a
   paid subscription to feel worth it. Plan where they come from before you
   build anything.
2. **Audio playback that never breaks**: background audio, lock screen
   controls, two layers (session + scene loop with ducking), interruptions
   (calls, Siri, headphones), sleep timers, offline files.
3. **Subscriptions**: StoreKit 2, free trial, restore, family sharing, server
   notifications, and App Review's rules for paywalls (clear price, easy close,
   terms and privacy links).

Also: streak rules across time zones, HealthKit permissions, notification
scheduling.

Size: **M** for the app (a few weeks for one developer in SwiftUI with a
simple backend), plus the content work, which can take longer than the code.
