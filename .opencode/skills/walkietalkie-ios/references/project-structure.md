# Struttura del Progetto — Ogni File e il Suo Scopo

## Albero Completo

```
WalkieTalkie/                              ← Root Xcode project (iOS 15.6)
│
├── WalkieTalkie.xcodeproj/                ← Xcode project file
│   ├── project.pbxproj                    ← Build settings, targets, SPM deps
│   └── project.xcworkspace/
│       └── xcshareddata/swiftpm/
│           └── Package.resolved           ← Versioni esatte SPM packages
│
├── Shared/                                ← Codice condiviso app + Widget Extension
│   ├── LiveActivityAttributes.swift        ← RadioActivityAttributes + WalkieActivityAttributes
│   └── RadioActivityIntents.swift          ← iOS 17+ LiveActivityIntent (play/pause/next/prev)
│
├── TalkyLiveActivities/                    ← Widget Extension target (iOS 16.2+)
│   ├── TalkyLiveActivitiesBundle.swift     ← @main WidgetBundle (radio + walkie widgets)
│   ├── RadioActivityWidget.swift           ← Lock Screen + Dynamic Island per radio
│   ├── WalkieActivityWidget.swift          ← Lock Screen + Dynamic Island per walkie
│   └── Info.plist                          ← Config estensione
│
├── WalkieTalkie/                           ← Main app target
│   │
│   ├── WalkieTalkieApp.swift               ← @main App + AppDelegate (Firebase, UN delegate, URL routing)
│   ├── ContentView.swift                   ← Main UI: 4-tab layout, WT/FM toggle, PTT button, radio controls
│   ├── OnboardingView.swift                ← 6-page onboarding (hook, no-internet, PTT, freq, radio, quick-start)
│   ├── OnboardingStrings.swift             ← Testi statici onboarding
│   ├── ExploreView.swift                   ← Radar-style peer discovery (sonar sweep, range rings, device dots)
│   ├── ConnectionsView.swift               ← Lista peer connessi, advertising/browsing status
│   ├── SettingsView.swift                  ← Full settings UI (Pro, temi, notifiche, audio, debug)
│   ├── ModeSwitchHintOverlay.swift          ← Hint una-tantum per toggle WT/FM
│   ├── FirstRunCoachView.swift             ← Coach overlay per nuovi utenti
│   ├── FirstTimeEventTracker.swift         ← Analytics eventi first-time
│   ├── PerformanceStatsView.swift          ← FPS/memory overlay debug (attivabile da Settings)
│   ├── String+Localization.swift           ← `.localized` computed property via NSLocalizedString
│   │
│   │── SettingsManager.swift               ← ObservableObject UserDefaults wrapper
│   ├── AudioManager.swift                  ← AVAudioSession + PTT capture/render + white noise + EQ chain
│   ├── MultipeerManager.swift              ← MCSession P2P engine (discovery, advertising, audio TX/RX, heartbeat)
│   ├── RadioManager.swift                  ← 310 stazioni, AVPlayer streaming, KVO, Now Playing, Live Activity glue
│   ├── NotificationManager.swift           ← UNUserNotificationCenter delegate, anti-spam cooldowns
│   ├── PowerManager.swift                  ← Battery level + Low Power Mode monitoring
│   ├── HapticManager.swift                 ← CoreHaptics (light/medium/heavy taps, success/error/warning)
│   ├── FirebaseManager.swift               ← Analytics + Crashlytics wrapper
│   ├── PerformanceMonitor.swift            ← Connection/latency profiling
│   ├── Logger.swift                        ← OSLog wrapper + WalkieTalkieError enum
│   │
│   ├── LiveActivity/                       ← App-side orchestrazione Live Activities
│   │   ├── LiveActivityManager.swift       ← @MainActor singleton: start/update/end serializzati, intent handler
│   │   └── LiveActivityDeepLink.swift      ← talky://radio/<action> per iOS 16.x fallback
│   │
│   ├── Ads/                                ← AdMob monetization stack
│   │   ├── AdConfig.swift                  ← Ad unit IDs (DEBUG/Release split), frequency caps
│   │   ├── AdManager.swift                 ← @MainActor orchestrator: bootstrap, preload, guard gate
│   │   ├── ConsentManager.swift            ← UMP GDPR + ATT consent flow
│   │   ├── AppOpenAdManager.swift          ← Cold-launch + return-from-background ad
│   │   ├── InterstitialAdCoordinator.swift ← Frequency-capped interstitials (5/day, 180s interval)
│   │   ├── RewardedAdCoordinator.swift     ← Rewarded ad: "remove ads for 1h"
│   │   ├── NativeAdCoordinator.swift       ← Native Advanced ad loader
│   │   └── AdViewControllerRepresentable.swift ← UIKit GAD ad → SwiftUI bridge
│   │
│   ├── IAP/                                ← StoreKit 2 (iOS 15+)
│   │   ├── IAPProducts.swift               ← ProductID enum (ProWeeklyWT, ProAnnualYT, themes pack)
│   │   ├── IAPManager.swift                ← @MainActor StoreKit 2: purchase, restore, entitlements, listener
│   │   └── PaywallView.swift               ← Fullscreen paywall UI ("Field Radio" design, adaptive palette)
│   │
│   ├── Theme/                              ← 16-theme engine
│   │   ├── Theme.swift                     ← Enum 16 casi + facade properties a ThemeRegistry
│   │   ├── ThemeMetadata.swift             ← Metadata struct + ThemeRegistry (lazy static dictionary)
│   │   ├── ThemeColorPack.swift            ← 5 free themes (Default, Ocean, Forest, Sunset, Midnight)
│   │   ├── ThemeIdentityPack.swift         ← 9 Pro themes (Military, Retro80s, VintageRadio, …)
│   │   ├── ThemeAnimatedPack.swift         ← 2 GPU-shader themes (Black Hole, Galaxy)
│   │   ├── ThemeManager.swift              ← @MainActor singleton: load/save/validate Pro access
│   │   ├── ThemeSelectorView.swift         ← Theme picker grid UI
│   │   ├── ThemePurchaseSheet.swift        ← Single-theme purchase flow
│   │   ├── FontManager.swift               ← Custom PostScript font registration
│   │   ├── ThemeSoundManager.swift         ← Themed sound packs (morse, sonar, glitch, synth, radio)
│   │   └── AnimatedBackgroundView.swift    ← GPU-animated backgrounds (TimelineView + Canvas, 60fps)
│   │
│   ├── Radio/                              ← Radio browser UI
│   │   ├── StationBrowserSheet.swift       ← Search + favorites + recents + gruppi paese/genere
│   │   ├── SleepTimerSheet.swift           ← Timer sleep UI
│   │   └── SleepTimerManager.swift         ← Timer logic
│   │
│   ├── Channels/                           ← Canali privati
│   │   ├── PrivateChannelSheet.swift       ← Password-protected channel UI
│   │   └── PrivateChannelManager.swift     ← Channel creation/validation logic
│   │
│   ├── Audio/                              ← Pro audio features
│   │   ├── EqualizerManager.swift          ← 5-band EQ (AVAudioUnitEQ)
│   │   ├── EqualizerView.swift             ← EQ controls UI
│   │   ├── RecordingsManager.swift         ← Persist + replay session recordings
│   │   └── RecordingsListView.swift        ← Recordings list UI
│   │
│   ├── History/                            ← Transmission history
│   │   ├── TransmissionEntry.swift         ← Data model
│   │   ├── TransmissionHistoryManager.swift ← Persistence + filtering
│   │   └── TransmissionHistoryView.swift   ← History list UI
│   │
│   └── Assets.xcassets/                    ← App icon, color sets (SurfaceColor, BackgroundColor, PrimaryTextColor, ToggleAccentColor)
│
├── Localization directories (nested in WalkieTalkie/):
│   ├── it.lproj/Localizable.strings + InfoPlist.strings
│   ├── en.lproj/
│   ├── es.lproj/
│   ├── ms.lproj/
│   └── zh-Hant.lproj/
│
├── Info.plist                              ← Permissions (mic, Bonjour, Bluetooth, Live Activities), GAD ID, URL scheme
└── GoogleService-Info.plist                ← Firebase project config (walkietalkie-6f630)
```

---

## Numeri Chiave

| Cosa | Valore |
|---|---|
| Stazioni radio totali | 310 |
| Stazioni Free | ~165 |
| Stazioni Pro | ~145 |
| Temi | 16 (5 free + 11 Pro) |
| Temi animati GPU | 2 (Black Hole, Galaxy) |
| Canali frequenza walkie | 24 |
| Paesi rappresentati | 55+ |
| Lingue localizzate | 5 (it, en, es, ms, zh-Hant) |
| File Swift totali | ~55 |
| Target Xcode | 2 (app + Widget Extension) |
| SPM dependencies | ~13 (Firebase + Google Ads stack) |

---

## Flusso dei Dati per Funzionalità

### Riproduzione Radio
```
ContentView (tap stazione) → RadioManager.playStation()
  → Pro gate (fastboot_isProUser) → AVPlayer(url) → KVO timeControlStatus
  → MPNowPlayingInfoCenter (lock screen) → LiveActivityManager.startOrUpdateRadio()
  → Firebase Analytics (trackRadioUsage) → UserDefaults (last station, recents)
```

### Push-to-Talk
```
ContentView (tap PTT button) → MultipeerManager.startTransmission()
  → AVAudioEngine input tap → accumula Float32 PCM → [rilascio] → stopTransmission()
  → sendData(.reliable) a tutti i peer connessi via MCSession

Ricezione: MultipeerManager.didReceive(data) → AudioManager.playPCMAudio(data)
  → Data → AVAudioPCMBuffer → AVAudioEngine playback chain (con EQ opzionale)
```

### Acquisto Pro
```
PaywallView (tap buy) → IAPManager.purchase(product)
  → StoreKit 2 Transaction → IAPManager.updateEntitlements()
  → UserDefaults fastboot_isProUser = true
  → ThemeManager ri-valida accesso → AdManager adesso skippa ads
  → RadioManager.availableStations ora include stazioni Pro
```

### Live Activity Lifecycle
```
Radio: playStation() → LiveActivityManager.startOrUpdateRadio()
 Walkie: connessione peer → LiveActivityManager.startOrUpdateWalkie()
 Stop radio → LiveActivityManager.endRadio() → se walkie attivo → .resyncWalkieFromCurrentState()
 App in background → LA sopravvive (iOS 16.2+), tap LA → intent o deep-link
 Widget Extension (TalkyLiveActivities) → renderizza UI per Lock Screen + Dynamic Island
```
