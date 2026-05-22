// Created by Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - README.md

# Talky — Walkie-Talkie & FM Radio (Open Source iOS App)

![Talky App](https://www.andreapiani.com/talky.png)

[![iOS](https://img.shields.io/badge/iOS-15.6+-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org/)
[![Xcode](https://img.shields.io/badge/Xcode-16.0+-blue.svg)](https://developer.apple.com/xcode/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](#-license)
[![Open Source](https://img.shields.io/badge/Open-Source-brightgreen.svg)]()

> **Talky** is a SwiftUI iOS app that combines **offline peer-to-peer push-to-talk** (Multipeer Connectivity) with a **global FM/internet radio browser** (135 stations across 50+ countries) plus a complete **Pro tier** (themes, animated backgrounds, equalizer, recording, sleep timer) and a production-grade **AdMob monetization stack** for the free tier.

**App Store**: search for **Talky — Walkie & Radio** · Bundle ID `com.immaginet.talky`
**Repository**: <https://github.com/andreapianidev/WalkieTalkie>

---

## Table of Contents

- [Highlights](#-highlights)
- [Feature Matrix (Free vs Pro)](#-feature-matrix-free-vs-pro)
- [Walkie-Talkie Engine](#-walkie-talkie-engine)
- [Radio Browser (135 stations)](#-radio-browser-135-stations)
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
- 🎨 **16 themes** (5 free + 11 paid/Pro) including 2 fully-animated GPU backgrounds (Black Hole, Galaxy)
- 🔊 **5-band EQ**, **sleep timer**, **session recording** and **transmission history**
- 💎 **Talky Pro** subscription (weekly/yearly) with paywall, restore purchases and StoreKit 2
- 📣 **Full AdMob stack** (App Open, Interstitial, Rewarded, **Native Advanced**) with UMP + ATT consent flow
- 🌍 **5 localizations**: 🇮🇹 Italian · 🇬🇧 English · 🇪🇸 Spanish · 🇲🇾 Malay · 🇹🇼 Traditional Chinese
- 🔒 **Privacy-first**: walkie-talkie audio never leaves the device, no accounts, no cloud
- 🧱 **Clean MVVM + SwiftUI + Combine**, singleton managers, Swift 6 strict concurrency-ready

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
└──────────────────────────┬────────────────────────────────┘
                           │
┌──────────────────────────▼────────────────────────────────┐
│ Apple frameworks                                          │
│  MultipeerConnectivity · AVFoundation · StoreKit 2        │
│  UserNotifications · Combine · CoreHaptics                │
│  AppTrackingTransparency                                  │
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
WalkieTalkie/                            ← Xcode project root
├── WalkieTalkie.xcodeproj/
├── WalkieTalkie/                        ← App source
│   ├── WalkieTalkieApp.swift            ← @main + AppDelegate (Firebase, ad bootstrap)
│   ├── ContentView.swift                ← Main UI: radio/walkie tabs
│   ├── OnboardingView.swift             ← First-run permissions + intro
│   ├── ExploreView.swift                ← Peer discovery
│   ├── ConnectionsView.swift            ← Active peer list
│   ├── SettingsView.swift               ← Preferences + Pro upsell
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

### Good first issues
- Add more radio stations (extend `RadioManager.radioStations`)
- Add additional language translations (clone an existing `.lproj` folder)
- New themes — add a new file under `Theme/` and register into `ThemeRegistry`
- Apple Watch companion app
- iOS Widgets for quick PTT

---

## 📄 License

**MIT License** © 2025–2026 Andrea Piani / Immaginet Srl.

Free for personal, educational and commercial use. You can fork, modify, ship your own version on the App Store — just keep the copyright notice. Ad networks, Firebase keys and StoreKit product IDs must be replaced with your own.

See the `LICENSE` file for the full text.

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
