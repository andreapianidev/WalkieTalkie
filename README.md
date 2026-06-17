// Created by Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - README.md

# Talky — Walkie-Talkie & FM Radio (Source-Available iOS + Android App)

![Talky App](https://www.andreapiani.com/talky.png)

[![Website](https://img.shields.io/badge/Website-walkie--talky.vercel.app-7cf9de.svg?style=flat&logo=vercel&logoColor=white)](https://walkie-talky.vercel.app)
[![App Store](https://img.shields.io/badge/App%20Store-Free%20Download-0a84ff.svg?style=flat&logo=appstore&logoColor=white)](https://apps.apple.com/app/id6748584483)
[![iOS](https://img.shields.io/badge/iOS-15.6+-blue.svg)](https://developer.apple.com/ios/)
[![Android](https://img.shields.io/badge/Android-12+%20(Beta)-3ddc84.svg?logo=android&logoColor=white)](#-android-beta)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org/)
[![Kotlin](https://img.shields.io/badge/Kotlin-2.0+-7f52ff.svg?logo=kotlin&logoColor=white)](https://kotlinlang.org/)
[![Xcode](https://img.shields.io/badge/Xcode-16.0+-blue.svg)](https://developer.apple.com/xcode/)
[![License: PolyForm NC 1.0.0](https://img.shields.io/badge/License-PolyForm%20Noncommercial%201.0.0-red.svg)](LICENSE)
[![Commercial use: NOT permitted](https://img.shields.io/badge/Commercial%20use-NOT%20permitted-critical.svg)](#-license)
[![Source available](https://img.shields.io/badge/Source-Available-brightgreen.svg)]()

> **Talky** is a SwiftUI iOS app that combines **offline peer-to-peer push-to-talk** (Multipeer Connectivity) with a **global FM/internet radio browser** (135 stations across 50+ countries), **Live Activities + Dynamic Island** controls (iOS 16.2+), a complete **Pro tier** (themes, animated backgrounds, equalizer, recording, sleep timer) and a production-grade **AdMob monetization stack** for the free tier.

> ⚠️ **This project is source-available, NOT MIT/Apache/BSD/GPL.** It is distributed under the **[PolyForm Noncommercial License 1.0.0](LICENSE)** — you may read, fork, modify and run it for personal/educational/non-profit purposes, but **commercial use (including shipping a derived app on any app store, paid services, ad-supported services and consulting deliverables) is strictly prohibited without a separate written commercial license.** See [License](#-license) for details and commercial-license contact.

**Website**: <https://walkie-talky.vercel.app>
**App Store**: [Talky — Walkie Talkie, Radio](https://apps.apple.com/app/id6748584483) · Free · Bundle ID `com.immaginet.talky`
**Repository**: <https://github.com/andreapianidev/WalkieTalkie>

---

## Table of Contents

- [Highlights](#-highlights)
- [Android (Beta)](#-android-beta)
- [Feature Matrix (Free vs Pro)](#-feature-matrix-free-vs-pro)
- [Walkie-Talkie Engine](#-walkie-talkie-engine)
- [Radio Browser (135 stations)](#-radio-browser-135-stations)
- [Live Activities & Dynamic Island](#-live-activities--dynamic-island)
- [Theme System (16 themes)](#-theme-system-16-themes)
- [Pro Tier — IAP & Paywall](#-pro-tier--iap--paywall)
- [AdMob Monetization](#-admob-monetization)
- [Privacy & Consent (UMP + ATT)](#-privacy--consent-ump--att)
- [Localization](#-localization)
- [Architecture](#-architecture)
- [Project Structure](#-project-structure)
- [Build & Run](#-build--run)
- [Configuration](#-configuration)
- [Testing](#-testing)
- [Performance & Battery](#-performance--battery)
- [Contributing](#-contributing)
- [License](#-license)
- [Credits & Links](#-credits--links)

---

## ✨ Highlights

- 🎙️ **Push-to-Talk** over peer-to-peer (no internet, no servers) — up to 8 simultaneous peers
- 📻 **135 verified live radio stations** across **50+ countries**, with favorites, recents, nearby, search and grouping by country/genre
- 🏝️ **Live Activities + Dynamic Island** (iOS 16.2+) for both radio and walkie modes — with iOS 17+ interactive controls (play/pause, next/previous from the lock screen and Dynamic Island)
- 🎨 **16 themes** (5 free + 11 paid/Pro) including 2 fully-animated GPU backgrounds (Black Hole, Galaxy)
- 🔊 **5-band EQ**, **sleep timer**, **session recording** and **transmission history**
- 💎 **Talky Pro** subscription (weekly/yearly) with paywall, restore purchases and StoreKit 2
- 📣 **Full AdMob stack** (App Open, Interstitial, Rewarded, **Native Advanced**) with UMP + ATT consent flow
- 🌍 **5 localizations**: 🇮🇹 Italian · 🇬🇧 English · 🇪🇸 Spanish · 🇲🇾 Malay · 🇹🇼 Traditional Chinese
- 🔒 **Privacy-first**: walkie-talkie audio never leaves the device, no accounts, no cloud
- 🧱 **Clean MVVM + SwiftUI + Combine**, singleton managers, Swift 6 strict concurrency-ready
- ⚖️ **Source-available** under PolyForm Noncommercial 1.0.0 — fork it, study it, learn from it; commercial reuse requires a separate license

---

## 🤖 Android (Beta)

Talky now ships an **Android port** too — it lives in [`Android/`](Android/) inside this same repo and is distributed under the **same [PolyForm Noncommercial License](LICENSE)** as the iOS app.

> ⚠️ **Status: Beta.** The Android app is a younger, leaner port of the iOS original. The core experience (push-to-talk + radio) is functional and builds a **signed release APK**, but it does **not yet** have feature parity on the Pro tier (no IAP/paywall, no Live Activities, single base theme).

### What works today
- 🎙️ **Push-to-talk** over the local network (`CrossPlatformWalkieManager`, Network Service Discovery / NSD) with an `AudioManager` PTT pipeline
- 📻 **343 radio stations** — the **same catalogue as iOS**, kept in sync from [`RadioManager.swift`](WalkieTalkie/RadioManager.swift) into [`Android/.../radio/RadioManager.kt`](Android/app/src/main/java/com/immaginet/talky/radio/RadioManager.kt)
- 📣 **AdMob** stack (banner / interstitial / rewarded / app-open) with **UMP consent** — uses Google **test ad units** by default (see note below)
- 🔥 **Firebase** Analytics + Crashlytics
- 🎨 **Jetpack Compose** UI (Material 3), dark "hardware radio" aesthetic

### Tech stack
| | |
|---|---|
| Language | **Kotlin** |
| UI | **Jetpack Compose** + Material 3 |
| Min / Target SDK | **30 (Android 12)** / **36** |
| P2P | Network Service Discovery (NSD) |
| Ads | Google Mobile Ads + User Messaging Platform |
| Backend | Firebase (Analytics + Crashlytics) |
| Build | Gradle (Kotlin DSL), R8 minify + resource shrinking |

### Build the Android app
```bash
cd Android
# Provide your signing credentials (see keystore.properties.sample)
cp keystore.properties.sample keystore.properties   # then edit values, or remove to build unsigned

./gradlew assembleDebug      # debug APK
./gradlew assembleRelease    # signed, minified release APK → app/build/outputs/apk/release/
```
- Requires the Android SDK and a `local.properties` with `sdk.dir` (Android Studio generates it automatically).
- `google-services.json` is included for Firebase; replace it with yours or remove the Firebase plugins.

> 📣 **Ad units note** — for the open-source / sideload APK, [`AdConfig.kt`](Android/app/src/main/java/com/immaginet/talky/ads/AdConfig.kt) intentionally uses Google's **test** ad units (and a test AdMob App ID in the manifest). This is the policy-compliant choice for an APK that is **not** distributed via the Play Store. Replace the `LIVE_*` IDs and the manifest App ID with your own real AdMob IDs before any Play Store release — the config switches to live IDs automatically once real (non-placeholder) values are present in a release build.

> 🚫 **Not on Google Play (yet).** This repo ships the Android **source + a signed APK via [GitHub Releases](https://github.com/andreapianidev/WalkieTalkie/releases)** for sideloading. A Play Store listing would additionally require real AdMob IDs and a Play Console upload.

---

## 📊 Feature Matrix (Free vs Pro)

| Capability | Free | Talky Pro |
|---|:--:|:--:|
| Push-to-talk over Multipeer (up to 8 peers) | ✅ | ✅ |
| 24 frequency channels (f1.mp3 … f24.mp3) | ✅ | ✅ |
| Radio stations available | 30 free | **All 135** |
| Station browser (search / favorites / recents / nearby) | ✅ | ✅ |
| Themes available | 5 base | **All 16** |
| Animated themes (Black Hole, Galaxy) | ❌ | ✅ |
| 5-band Equalizer | ❌ | ✅ |
| Session recording (RecordingsManager) | ❌ | ✅ |
| Sleep timer | ✅ | ✅ |
| Transmission history | ✅ | ✅ |
| Ads (banner / interstitial / native / app-open) | Shown | **Removed** |
| Rewarded "remove ads for 1 hour" | ✅ | n/a |
| App Tracking Transparency prompt | Shown | Shown¹ |

¹ ATT is required by Apple regardless of Pro status; only ad delivery is disabled for Pro users.

---

## 🎙️ Walkie-Talkie Engine

Backed by **`MultipeerManager`** and **`AudioManager`**:

- **Service type**: `walkie-talkie` (MCSession / MCNearbyServiceAdvertiser + Browser)
- **No internet required** — works over Wi-Fi, peer-to-peer Wi-Fi, or Bluetooth
- **Up to 8 simultaneous peers**
- **Audio session** `.playAndRecord` with `.defaultToSpeaker`, mixWithOthers off during PTT
- **Background audio** entitlement for radio + incoming PTT alerts
- **Anti-spam** notifications via `NotificationManager` cooldown
- **Haptic feedback** on PTT press/release via `HapticManager`
- **Auto-reconnect** with exponential backoff
- **24 frequency channels** for quick audible signalling (`f1.mp3` … `f24.mp3`)

---

## 📻 Radio Browser (135 stations)

The radio side is a full streaming client (`RadioManager` + `StationBrowserSheet`):

- **135 live stations** across 50+ countries (Italy, USA, UK, Spain, France, Germany, Japan, Brazil, Australia, Argentina, Mexico, Canada, Netherlands, Sweden, India, and 30+ more)
- **30 stations free** · **105 stations Pro-only** (`isPro = id > 30`)
- **Smart UX**:
  - 🔍 Full-text search by name / country / genre
  - ⭐ **Favorites** (persisted in `UserDefaults`)
  - 🕘 **Recents** (auto-tracked)
  - 📍 **Nearby** — surfaces stations matching `deviceCountry` (CoreTelephony / Locale)
  - 🌍 Grouping by country (with flag emoji)
  - 🎵 Grouping by genre
- **Native AdMob slot** rendered between personal sections and country list (non-Pro only)
- **Background playback** (radio keeps streaming when app is backgrounded)
- **Sleep timer** (`SleepTimerSheet` + `SleepTimerManager`) — 5/10/15/30/45/60 min or end-of-track
- **Pro paywall trigger** when a free user taps a locked station

---

## 🏝️ Live Activities & Dynamic Island

Shipped in commit [`4c0f54e`](https://github.com/andreapianidev/WalkieTalkie/commit/4c0f54e) — a full **ActivityKit** widget extension (`TalkyLiveActivities/`) plus a main-app **LiveActivityManager** that surfaces both modes on the Lock Screen and the Dynamic Island.

### Targets & files
| Component | Path |
|---|---|
| Shared attributes (radio + walkie content state) | [`Shared/LiveActivityAttributes.swift`](Shared/LiveActivityAttributes.swift) |
| Interactive intents (iOS 17+) | [`Shared/RadioActivityIntents.swift`](Shared/RadioActivityIntents.swift) |
| Widget extension bundle | [`TalkyLiveActivities/TalkyLiveActivitiesBundle.swift`](TalkyLiveActivities/TalkyLiveActivitiesBundle.swift) |
| Radio widget UI (Lock Screen + Dynamic Island) | [`TalkyLiveActivities/RadioActivityWidget.swift`](TalkyLiveActivities/RadioActivityWidget.swift) |
| Walkie widget UI | [`TalkyLiveActivities/WalkieActivityWidget.swift`](TalkyLiveActivities/WalkieActivityWidget.swift) |
| App-side orchestrator (start / update / end) | [`WalkieTalkie/LiveActivity/LiveActivityManager.swift`](WalkieTalkie/LiveActivity/LiveActivityManager.swift) |
| Deep-link routing from LA → app | [`WalkieTalkie/LiveActivity/LiveActivityDeepLink.swift`](WalkieTalkie/LiveActivity/LiveActivityDeepLink.swift) |

### Radio Live Activity — content state
- Station name, country, flag emoji, frequency, genre
- `isPlaying` and `isBuffering` flags driving the play/pause glyph
- **Interactive controls (iOS 17+)**: ⏮ previous · ⏯ play/pause · ⏭ next — wired via `LiveActivityIntent` and broadcast back to the app through `NotificationCenter` (`talkyRadioTogglePlayPause`, `talkyRadioNextStation`, `talkyRadioPreviousStation`)
- "Next/previous" prioritises **favorites** when the user has any, otherwise walks the full available station pool

### Walkie Live Activity — content state
- Connected peer count (badge in Dynamic Island compact view)
- First 3 peer names (Lock Screen expanded view)
- Current channel name
- Optional **`talkerName`** — surfaced live when a peer is transmitting, so the user can see who's on the air without opening the app

### Lifecycle & safety
- `@MainActor`-isolated singleton (`LiveActivityManager.shared`), gated to **iOS 16.2+**
- One-at-a-time semantics: starting a radio LA ends any walkie LA and vice-versa (modes are mutually exclusive in the UI)
- Bootstrap on app launch reconnects to any in-flight Activity (e.g. app killed while LA is still on screen)
- Respects user toggle in iOS Settings → Talky → Live Activities (`ActivityAuthorizationInfo().areActivitiesEnabled`)
- Mirrors the data already pushed into `MPNowPlayingInfoCenter`, so older devices (< iOS 16.2) keep the existing Now-Playing behaviour
- No push token / no `pushType: nil` — pure local updates from the app

> Design spec lives in [`docs/`](docs/) (see commit [`23e97ac`](https://github.com/andreapianidev/WalkieTalkie/commit/23e97ac)). The two widget files contain the full SwiftUI layout for the Lock Screen card, the compact/minimal/expanded Dynamic Island regions, and the iOS 17 interactive button rows.

---

## 🎨 Theme System (16 themes)

Themes are organised into 3 pluggable **packs** registered into a central `ThemeRegistry`:

### 🎨 Color Pack — Free (5 themes)
| Theme | Accent | Icon |
|---|---|---|
| Default (Talky Yellow) | `#FFCC00` | `radio` |
| Ocean | Cyan | `water.waves` |
| Forest | Green | `leaf.fill` |
| Sunset | Orange | `sun.horizon.fill` |
| Midnight | Indigo | `moon.stars.fill` |

### 🎭 Identity Pack — €0.99 each OR included in Pro (9 themes)
- **Military** · **Retro 80s** · **Vintage Radio** · **Cyberpunk** · **Stealth** · **Aurora** · **Submarine** · **Ham Radio** · **Festival**

Each Identity theme bundles:
- Custom `accentColor`
- Optional custom PostScript font (e.g. `PressStart2P-Regular` for Retro 80s) via `FontManager`
- Optional themed sound pack (e.g. `morse`, `sonar`, `glitch`) via `ThemeSoundManager`

### 🌌 Animated Pack — €1.99 each OR included in Pro (2 themes)
- **Black Hole** — GPU shader gravitational lensing background
- **Galaxy** — Procedural starfield

Rendered by `AnimatedBackgroundView` using `TimelineView` + Canvas for 60 fps.

> Themes can be purchased individually (StoreKit 2 non-consumable) or unlocked all-at-once via Talky Pro subscription. Unlocking is enforced by `ThemeManager` reading `IAPManager.shared.ownedProducts`.

---

## 💎 Pro Tier — IAP & Paywall

Backed by **StoreKit 2** in [`IAP/IAPManager.swift`](WalkieTalkie/WalkieTalkie/IAP/IAPManager.swift) with product IDs declared in [`IAP/IAPProducts.swift`](WalkieTalkie/WalkieTalkie/IAP/IAPProducts.swift).

### Subscriptions (auto-renewing)
| Product ID | Plan |
|---|---|
| `app.immaginet.talky.pro.weekly` | Weekly |
| `app.immaginet.talky.pro.yearly` | Yearly (best value) |

### One-shot theme purchases (non-consumable)
- `app.immaginet.talky.theme.<name>` — one per Identity / Animated theme

### Paywall — [`IAP/PaywallView.swift`](WalkieTalkie/WalkieTalkie/IAP/PaywallView.swift)
- Trigger-aware (`station_browser`, `theme_locked`, `equalizer`, …) for analytics
- Restore Purchases
- Receipt validation via Apple's `Transaction.currentEntitlements`
- Fast-boot Pro flag cached in `UserDefaults("fastboot_isProUser")` to avoid UI flicker on cold launch

---

## 📣 AdMob Monetization

A complete, **policy-compliant** AdMob stack lives under [`Ads/`](WalkieTalkie/WalkieTalkie/Ads/):

| Format | Coordinator | Where it shows |
|---|---|---|
| **App Open** | `AppOpenAdManager` | Cold launch + return-from-background |
| **Interstitial** | `InterstitialAdCoordinator` | Natural breaks (frequency-capped: 5/day, 180s min interval) |
| **Rewarded** | `RewardedAdCoordinator` | "Remove ads for 1 hour" opt-in |
| **Native Advanced** | `NativeAdCoordinator` + `NativeAdCardView` | Inline card inside the radio browser |

Implementation notes:
- **SDK**: Google Mobile Ads SDK **13.x** (modern types: `InterstitialAd`, `Request`, `MobileAds.shared.start`, etc. — no `GAD` prefix)
- **DEBUG**: always uses Google's test ad unit IDs (no risk of policy strikes during development)
- **Release**: production unit IDs under account `ca-app-pub-1193280742171051`
- **Native ad card** is styled with the app's design tokens (`Color("SurfaceColor")`, `Color("PrimaryTextColor")`) so it visually matches the surrounding station rows; the AdMob "Ad" badge is always visible (policy compliance)
- **Frequency capping**: `AdConfig.FrequencyCap` enforces interstitial cool-downs + rewarded-ads remove-ads duration
- **Pro / `adsRemoved` users**: every coordinator guards on `IAPManager.shared.isProUser` and `AdManager.shared.adsRemoved` — Pro users never see an ad

### Bootstrap order ([`Ads/AdManager.swift`](WalkieTalkie/WalkieTalkie/Ads/AdManager.swift))
```
1. UMP consent flow   ──► gatherConsent()
2. ATT prompt         ──► requestATTIfNeeded()
3. SDK init           ──► MobileAds.shared.start
4. Parallel preload   ──► appOpen | interstitial | rewarded | nativeStation
```

This order is mandatory for both Apple review and AdMob eCPM (Google must see the consent + IDFA signal before any ad request).

---

## 🔒 Privacy & Consent (UMP + ATT)

`Ads/ConsentManager.swift` orchestrates the full **GDPR + ATT** flow:

- **UMP SDK**: shows the AdMob consent form to EEA/UK users; gates ad requests on `canRequestAds`
- **ATT (App Tracking Transparency)**: prompted **after** UMP resolution and only once UI is active (Apple requirement for iOS 14.5+)
- **Privacy policy & terms** hosted at <https://privacypolicyhub.vercel.app>
- **What we DON'T collect**:
  - Walkie-talkie audio (stays on-device, peer-to-peer encrypted by Multipeer)
  - Location (no GPS in this app — radio "nearby" uses Locale country only)
  - Personally identifiable information
- **What we DO collect** (only with consent):
  - Anonymous Firebase Analytics + Crashlytics
  - AdMob ad-targeting signals (IDFA) — only if user consents to ATT

---

## 🌍 Localization

5 full translations under `WalkieTalkie/<locale>.lproj/Localizable.strings`:

| Locale | Language |
|---|---|
| `it` | 🇮🇹 Italiano |
| `en` | 🇬🇧 English |
| `es` | 🇪🇸 Español |
| `ms` | 🇲🇾 Bahasa Melayu |
| `zh-Hant` | 🇹🇼 繁體中文 (Traditional Chinese) |

All UI strings flow through `String+Localization.swift` (`.localized`). i18n keys are kept in sync across languages — see commit `6ba6d06` for the latest dedup audit.

---

## 🏗️ Architecture

**Pattern**: MVVM + Singleton Managers + Combine for reactive UI.

```
┌───────────────────────────────────────────────────────────┐
│ SwiftUI Views (@StateObject / @ObservedObject)            │
│  ContentView · ExploreView · ConnectionsView · Settings   │
│  StationBrowserSheet · PaywallView · ThemeSelectorView    │
└──────────────────────────┬────────────────────────────────┘
                           │  @Published / Combine
┌──────────────────────────▼────────────────────────────────┐
│ Singleton Managers (.shared)                              │
│  AudioManager · MultipeerManager · RadioManager           │
│  NotificationManager · SettingsManager · PowerManager     │
│  HapticManager · FirebaseManager · ThemeManager           │
│  IAPManager · AdManager · ConsentManager                  │
│  EqualizerManager · RecordingsManager · SleepTimerManager │
│  LiveActivityManager (iOS 16.2+ · ActivityKit)            │
└──────────────────────────┬────────────────────────────────┘
                           │
┌──────────────────────────▼────────────────────────────────┐
│ Apple frameworks                                          │
│  MultipeerConnectivity · AVFoundation · StoreKit 2        │
│  UserNotifications · Combine · CoreHaptics                │
│  AppTrackingTransparency · ActivityKit · WidgetKit        │
│  AppIntents (iOS 17+ Live Activity controls)              │
└──────────────────────────┬────────────────────────────────┘
                           │
┌──────────────────────────▼────────────────────────────────┐
│ Third-party (SPM)                                         │
│  GoogleMobileAds (13.x) · UserMessagingPlatform           │
│  Firebase (Analytics + Crashlytics + Performance)         │
└───────────────────────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
WalkieTalkie/                            ← Repo root (Xcode project + Android port)
├── Android/                             ← 🤖 Android app (Kotlin + Jetpack Compose)
│   ├── app/src/main/java/com/immaginet/talky/
│   │   ├── MainActivity.kt              ← Compose UI (radio + walkie)
│   │   ├── net/CrossPlatformWalkieManager.kt  ← P2P PTT over NSD
│   │   ├── radio/RadioManager.kt        ← 343 stations (synced from iOS)
│   │   ├── audio/ · ads/ · firebase/ · protocol/
│   ├── keystore.properties.sample       ← signing config template
│   └── build.gradle.kts                 ← R8 minify + signing
├── WalkieTalkie.xcodeproj/
├── LICENSE                              ← PolyForm Noncommercial 1.0.0
├── README.md
├── Shared/                              ← Code shared between app + widget extension
│   ├── LiveActivityAttributes.swift     ← ActivityAttributes for radio + walkie
│   └── RadioActivityIntents.swift       ← Interactive intents (iOS 17+)
│
├── TalkyLiveActivities/                 ← Widget extension target
│   ├── TalkyLiveActivitiesBundle.swift  ← @main WidgetBundle
│   ├── RadioActivityWidget.swift        ← Lock Screen + Dynamic Island UI (radio)
│   ├── WalkieActivityWidget.swift       ← Lock Screen + Dynamic Island UI (walkie)
│   └── Info.plist
│
├── WalkieTalkie/                        ← App source
│   ├── WalkieTalkieApp.swift            ← @main + AppDelegate (Firebase, ad bootstrap)
│   ├── ContentView.swift                ← Main UI: radio/walkie tabs
│   ├── OnboardingView.swift             ← First-run permissions + intro
│   ├── ExploreView.swift                ← Peer discovery
│   ├── ConnectionsView.swift            ← Active peer list
│   ├── SettingsView.swift               ← Preferences + Pro upsell
│   │
│   ├── LiveActivity/                    ← App-side orchestration
│   │   ├── LiveActivityManager.swift    ← Start/update/end + intent handling
│   │   └── LiveActivityDeepLink.swift   ← LA tap → app deep-link routing
│   │
│   ├── Ads/                             ← AdMob stack (5 files)
│   │   ├── AdConfig.swift               ← Ad unit IDs (DEBUG/Release split)
│   │   ├── AdManager.swift              ← Bootstrap + lifecycle
│   │   ├── ConsentManager.swift         ← UMP + ATT
│   │   ├── AppOpenAdManager.swift
│   │   ├── InterstitialAdCoordinator.swift
│   │   ├── RewardedAdCoordinator.swift
│   │   ├── NativeAdCoordinator.swift    ← NEW: Native Advanced loader
│   │   ├── NativeAdCardView.swift       ← NEW: SwiftUI card UI
│   │   └── AdViewControllerRepresentable.swift
│   │
│   ├── IAP/                             ← StoreKit 2
│   │   ├── IAPProducts.swift            ← Subscription + theme product IDs
│   │   ├── IAPManager.swift             ← Purchase / restore / entitlements
│   │   └── PaywallView.swift            ← Paywall UI with trigger analytics
│   │
│   ├── Theme/                           ← 16-theme engine
│   │   ├── Theme.swift                  ← enum Theme (16 cases)
│   │   ├── ThemeMetadata.swift          ← Tier + accent + font + sound
│   │   ├── ThemeColorPack.swift         ← 5 free themes
│   │   ├── ThemeIdentityPack.swift      ← 9 identity themes (€0.99)
│   │   ├── ThemeAnimatedPack.swift      ← 2 animated themes (€1.99)
│   │   ├── ThemeManager.swift           ← Active theme + persistence
│   │   ├── ThemeSelectorView.swift      ← Theme picker
│   │   ├── ThemePurchaseSheet.swift     ← Single-theme purchase flow
│   │   ├── ThemeSoundManager.swift      ← Themed sound packs
│   │   ├── FontManager.swift            ← Custom PostScript fonts
│   │   └── AnimatedBackgroundView.swift ← GPU animated backgrounds
│   │
│   ├── Radio/                           ← Radio browser
│   │   ├── StationBrowserSheet.swift    ← Search + favorites + recents + groups
│   │   ├── SleepTimerSheet.swift        ← Timer UI
│   │   └── SleepTimerManager.swift
│   │
│   ├── Audio/                           ← Pro audio features
│   │   ├── EqualizerManager.swift       ← 5-band EQ (AVAudioUnitEQ)
│   │   ├── EqualizerView.swift
│   │   ├── RecordingsManager.swift      ← Persist + replay sessions
│   │   └── RecordingsListView.swift
│   │
│   ├── History/
│   │   └── TransmissionHistoryView.swift
│   │
│   ├── Managers (core)/
│   │   ├── AudioManager.swift           ← AVAudioSession + PTT pipeline
│   │   ├── MultipeerManager.swift       ← MCSession + peer discovery
│   │   ├── RadioManager.swift           ← AVPlayer + 135 stations
│   │   ├── NotificationManager.swift    ← Anti-spam local notifications
│   │   ├── SettingsManager.swift        ← UserDefaults wrapper
│   │   ├── PowerManager.swift           ← Battery monitoring
│   │   ├── HapticManager.swift          ← CoreHaptics
│   │   ├── FirebaseManager.swift        ← Analytics + Crashlytics
│   │   ├── PerformanceMonitor.swift     ← FPS / memory profiling
│   │   └── Logger.swift                 ← Categorised logs
│   │
│   ├── String+Localization.swift
│   ├── FirstTimeEventTracker.swift      ← Onboarding analytics
│   ├── FirstRunCoachView.swift
│   │
│   ├── Audio resources/
│   │   └── f1.mp3 … f24.mp3, radio2.mp3, radio3.mp3, radio4.mp3
│   │
│   ├── Assets.xcassets/                 ← App icons, color sets
│   │
│   ├── it.lproj · en.lproj · es.lproj · ms.lproj · zh-Hant.lproj
│   │
│   └── Info.plist · GoogleService-Info.plist
│
└── README.md · AppStore_Description.md · plan.md
```

---

## 🚀 Build & Run

### Prerequisites
- **macOS** with **Xcode 16.0+** (Xcode 17 fully supported)
- **iOS 15.6+** target device (physical device required — Multipeer Connectivity does not run in the Simulator)
- **Apple Developer account** for code signing
- **(Optional) Firebase project** — replace `GoogleService-Info.plist` with yours or remove Firebase frameworks
- **(Optional) AdMob account** — replace production unit IDs in [`Ads/AdConfig.swift`](WalkieTalkie/WalkieTalkie/Ads/AdConfig.swift); DEBUG builds always use Google's test IDs

### Clone & open
```bash
git clone https://github.com/andreapianidev/WalkieTalkie.git
cd WalkieTalkie
open WalkieTalkie/WalkieTalkie.xcodeproj
```

### Command-line build
```bash
# Debug build
xcodebuild -project WalkieTalkie/WalkieTalkie.xcodeproj \
           -scheme WalkieTalkie -configuration Debug build

# Release archive
xcodebuild -project WalkieTalkie/WalkieTalkie.xcodeproj \
           -scheme WalkieTalkie -configuration Release archive
```

### Code-signing
1. Open the project in Xcode
2. Target **WalkieTalkie** → **Signing & Capabilities** → choose your **Team**
3. Set a unique **Bundle Identifier** (the default `com.immaginet.talky` is owned by the original developer)
4. Run on a physical device with **Cmd+R**

### Swift Package Manager dependencies (auto-resolved)
- [`swift-package-manager-google-mobile-ads`](https://github.com/googleads/swift-package-manager-google-mobile-ads) (Google Mobile Ads SDK)
- [`firebase-ios-sdk`](https://github.com/firebase/firebase-ios-sdk) (Analytics + Crashlytics + Performance)
- UMP SDK is bundled with Google Mobile Ads

---

## ⚙️ Configuration

### AdMob unit IDs — [`Ads/AdConfig.swift`](WalkieTalkie/WalkieTalkie/Ads/AdConfig.swift)
```swift
#if DEBUG
// Google's official test ad units — safe during development.
static let appOpenAdUnitID       = "ca-app-pub-3940256099942544/5575463023"
static let interstitialAdUnitID  = "ca-app-pub-3940256099942544/4411468910"
static let rewardedAdUnitID      = "ca-app-pub-3940256099942544/1712485313"
static let nativeStationAdUnitID = "ca-app-pub-3940256099942544/3986624511"
#else
// Replace with YOUR AdMob account IDs before shipping.
static let appOpenAdUnitID       = "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX"
static let interstitialAdUnitID  = "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX"
static let rewardedAdUnitID      = "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX"
static let nativeStationAdUnitID = "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX"
#endif
```

### Frequency capping
```swift
enum FrequencyCap {
    static let appOpenMaxAge: TimeInterval = 4 * 3600      // 4h
    static let interstitialMinInterval: TimeInterval = 180 // 3min between interstitials
    static let interstitialDailyMax: Int = 5
    static let removeAdsRewardDuration: TimeInterval = 3600 // 1h
}
```

### Info.plist permission strings
- `NSMicrophoneUsageDescription` — walkie-talkie recording
- `NSLocalNetworkUsageDescription` — Multipeer Connectivity discovery
- `NSBonjourServices` — `_walkie-talkie._tcp`, `_walkie-talkie._udp`
- `NSUserTrackingUsageDescription` — ATT prompt copy
- `GADApplicationIdentifier` — AdMob app ID
- `SKAdNetworkItems` — see Info.plist (full list of partner SKAdNetwork IDs)

### Audio session
- Category `.playAndRecord` with `.defaultToSpeaker, .allowBluetooth, .mixWithOthers`
- 44.1 kHz, 16-bit PCM, mono for PTT / stereo for radio
- Background audio entitlement enabled

---

## 🧪 Testing

> ⚠️ **Multipeer Connectivity does not work in the iOS Simulator.** You need at least one physical device (two for PTT testing).

Recommended test matrix:
- **PTT**: 2+ physical iPhones on the same Wi-Fi → discover → connect → press-to-talk
- **Radio**: pick a station from each of the 14 region groups, verify audio + sleep timer + favorite/unfavorite
- **IAP**: create a StoreKit configuration file with the product IDs in [`IAPProducts.swift`](WalkieTalkie/WalkieTalkie/IAP/IAPProducts.swift), test the paywall + restore on a sandbox account
- **Ads**: launch a DEBUG build → the AdMob test creatives must appear (app-open, interstitial after 5 mode switches, native card inside station browser)
- **Consent**: change device region to EU → UMP consent form must appear on first launch, then ATT prompt
- **Theme purchase**: try to apply a locked theme → `ThemePurchaseSheet` should open with the correct price

There is no automated test target in this repo — contributions welcome.

---

## 🔋 Performance & Battery

- `PowerManager` watches `UIDevice.batteryLevel` + `ProcessInfo.isLowPowerModeEnabled` and reduces radio polling
- `PerformanceMonitor` exposes a debug overlay with FPS / memory / active peers (gated by a hidden build flag)
- AVAudioSession is **deactivated** when both modes are idle to free the audio hardware
- All Combine subscriptions store `cancellables` and are torn down in `deinit` to avoid retain cycles
- `MultipeerManager` automatically disconnects idle peers after a configurable timeout to save battery
- AdMob ads are **preloaded once** and reused; frequency caps prevent ad-storm scenarios

---

## 🤝 Contributing

Contributions are welcome! Please:

1. **Fork** the repo and create a feature branch (`feat/<short-name>` or `fix/<short-name>`)
2. **Match the existing code style** — Swift API Design Guidelines, no force-unwraps, prefer `@MainActor` and `nonisolated` correctness over `@unchecked Sendable`
3. **Update localizations** if you change any UI string (`it`, `en`, `es`, `ms`, `zh-Hant` must stay in sync)
4. **Build & run on a physical device** before opening the PR
5. **Open a PR** with a clear description, screenshots for UI changes, and reference any related issue

Conventional-commit prefixes are appreciated: `feat:`, `fix:`, `chore:`, `refactor:`, `docs:`, `style:`.

### Contributor license agreement

By opening a pull request you agree that **your contribution is licensed under the same [PolyForm Noncommercial License 1.0.0](LICENSE)** as the rest of the project, and that you grant Andrea Piani / Immaginet Srl a perpetual, worldwide, royalty-free right to relicense your contribution under **any other license (including commercial)** as part of the official Talky distribution. This is the standard inbound=outbound model used by most source-available projects and is required to keep the commercial-license path viable.

### Good first issues
- Add more radio stations (extend `RadioManager.radioStations`)
- Add additional language translations (clone an existing `.lproj` folder)
- New themes — add a new file under `Theme/` and register into `ThemeRegistry`
- Apple Watch companion app
- Home Screen / Lock Screen widgets for quick PTT (separate from the Live Activity)
- StandBy mode large-radio widget (iOS 17+)

---

## 📄 License

**[PolyForm Noncommercial License 1.0.0](LICENSE)** — © 2025–2026 Andrea Piani / Immaginet Srl. All rights reserved.

> 🚫 **This is NOT an MIT/Apache/BSD/GPL project.** It is **source-available**, not "open-source" in the OSI sense. Commercial use is **strictly prohibited** without a separate written license signed by the copyright holder.

### ✅ What you ARE allowed to do (free of charge)
- **Read, study and learn** from the code — this repo exists primarily as an educational reference for production-grade SwiftUI / Multipeer / StoreKit / AdMob / ActivityKit integration.
- **Fork and modify** for personal, academic, research, journalism, hobby or non-profit purposes.
- **Run** your modified copy on your own devices.
- **Share** the source or your patches, as long as the [`LICENSE`](LICENSE) file and the copyright notice stay intact.
- **Use by educational institutions, public-research organisations, NGOs, charities and government bodies** is explicitly permitted (see PolyForm §"Noncommercial Organizations").

### 🚫 What you ARE NOT allowed to do without a commercial license
- ❌ **Publish, distribute or sell** this app — or any app substantially derived from this codebase — on the **Apple App Store, Google Play, AltStore, Setapp, or any other paid or ad-supported channel**.
- ❌ Use this code, in whole or in part, in any **product, service, SaaS, enterprise deployment, paid app, ad-supported service, sponsored build, consulting deliverable** or any activity primarily directed toward **commercial advantage or monetary compensation**.
- ❌ Train **commercial machine-learning models** on this codebase.
- ❌ **Re-license** the code under more permissive terms (MIT, Apache-2.0, BSD, GPL, …) — this is explicitly forbidden.
- ❌ Remove, alter, or obscure the **copyright notice**, the [`LICENSE`](LICENSE) file, the in-app "About" attribution, the project name, or the identifying branding from any distributed copy.
- ❌ Pretend the code is yours.

### 💼 Commercial license

If you want to use Talky (or a derivative) in any commercial context — including shipping it on an app store, bundling it inside another paid product, or offering it as a service — you must obtain a **separate written commercial license** from the copyright holder.

📧 **Commercial licensing contact**: **andreapiani.dev@gmail.com**
🌐 https://www.andreapiani.com

Reasonable commercial terms are available for individuals, startups and enterprises. Just write — we'll work it out.

### 🛡️ Enforcement & DMCA

Violations of this license — including unauthorised App Store submissions, paid-app derivatives and trademark-passing-off — will be enforced through **App Store / Play Store DMCA take-down requests**, **GitHub DMCA**, and where appropriate **legal action under Italian and EU copyright law (Law 633/1941 as amended) and the Berne Convention**. Please don't make us do that — just email instead.

### 📜 Full legal text

The authoritative legal terms are in the **[`LICENSE`](LICENSE)** file at the root of this repository (PolyForm Noncommercial License 1.0.0, verbatim text). The license is hosted at <https://polyformproject.org/licenses/noncommercial/1.0.0/>.

The plain-language summary above is informational only and does not replace the legal text.

---

## 🏔️ Credits & Links

- **Developer**: Andrea Piani · **Company**: Immaginet Srl
- **Website**: <https://www.andreapiani.com>
- **Privacy policy**: <https://privacypolicyhub.vercel.app>
- **Support coffee** ☕: <https://buymeacoffee.com/andreapianidev>

### Sister app — Peak (GPS Altimeter + Walkie)
The walkie-talkie engine from Talky also powers **Peak — GPS Altimeter Barometer**, an outdoor companion app with professional altimetry and built-in PTT.

[![Download Peak](https://img.shields.io/badge/Download-Peak%20on%20App%20Store-blue?style=for-the-badge&logo=apple&logoColor=white)](https://apps.apple.com/app/peak-altimetro-gps-barometro/id6477742031)

---

> 💛 If Talky helped you, ship something cool with it, or just learn how to build a freemium SwiftUI app — drop a ⭐ on GitHub and consider a coffee. Pull requests, station packs and theme contributions are always welcome.
