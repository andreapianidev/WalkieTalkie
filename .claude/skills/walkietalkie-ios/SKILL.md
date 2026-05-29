---
name: walkietalkie-ios
description: >
  Use when working on the Talky (WalkieTalkie) iOS project, or when the user mentions Talky,
  WalkieTalkie, walkie-talkie P2P, radio FM streaming, push-to-talk iOS, Multipeer Connectivity
  in this project, Live Activities / Dynamic Island for this app, AdMob monetization for this app,
  StoreKit 2 IAP subscriptions for this app, Firebase Analytics/Crashlytics configuration,
  or any feature of this specific codebase. Symptoms: "fix the radio", "add a station",
  "change the paywall", "update the theme", "the audio session is broken", "Live Activity not showing".
---
# WalkieTalkie / Talky iOS — Skill del Progetto

Conosce l'intero codebase di Talky (WalkieTalkie), l'architettura, i pattern, i vincoli,
e le procedure per aggiungere feature, fixare bug, e orchestrare agenti paralleli.

---

## Quick Reference

| Dominio | File |
|---------|------|
| Architettura, pattern, design decision | `references/architecture.md` |
| Struttura progetto, ogni file e scopo | `references/project-structure.md` |
| Radio: stazioni, stream, verifica, aggiunta | `references/radio-system.md` |
| UI: temi, Live Activities, onboarding, settings | `references/ui-systems.md` |
| Monetizzazione: IAP + AdMob | `references/monetization.md` |
| Orchestrazione agenti e skill superpowers | `references/agent-orchestration.md` |

> Carica i riferimenti on-demand. Non caricarli tutti insieme.

---

## Workflow Standard

### Aggiungere Stazioni Radio

1. Leggi `references/radio-system.md`
2. Verifica ogni stream URL con `curl -I --max-time 5 -L "<URL>"`
3. **Mai** aggiungere stazioni con stream non verificati
4. Inserisci nel blocco MARK appropriato di `RadioManager.swift`
5. Specifica `isPro` esplicitamente — non fidarti del default `id > 30`

### Modificare IAP

1. Leggi `references/monetization.md`
2. Non cambiare Product ID senza aggiornare App Store Connect
3. Mantieni sincronizzati i bridge keys: `fastboot_isProUser`, `fastboot_hasThemesPack`

### Feature Multi-file

1. Task complessi con 2+ file indipendenti → carica `references/agent-orchestration.md`
2. Usa `dispatching-parallel-agents` per task senza dipendenze
3. Usa `subagent-driven-development` per piani strutturati

---

## Vincoli Critici

### iOS / Swift
- **Target**: iOS 15.6 (app), iOS 16.2 (Widget Extension)
- **Swift 5.0** — niente `@Observable` (iOS 17+), niente SwiftData, niente async/await avanzato
- Usa `@Published` + `ObservableObject`, `DispatchQueue.main.async` per thread safety

### Audio
- **NON mischiare le category.** `.playAndRecord` per walkie, `.playback` per radio
- Category swap solo in `playStation()` / `stopRadio()` — mai all'init
- KVO identity guard: `player === self.radioPlayer` è essenziale — **non rimuoverlo**

### StoreKit 2
- `Transaction.currentEntitlements` per stato Pro
- Bridge keys UserDefaults: `fastboot_isProUser`, `fastboot_hasThemesPack`

### AdMob
- Mai ID reali in DEBUG — `AdConfig` splitta automaticamente
- Bootstrap: UMP → ATT → SDK init → parallel preload
- Gate universale: `!isProUser && !adsRemoved`

---

## Pattern di Codice

```swift
// Singleton Manager (tutti i manager usano questo)
class FooManager: NSObject, ObservableObject {
    static let shared = FooManager()
    private override init() { super.init(); /* setup */ }
}

// Bridge keys per comunicazione inter-modulo
UserDefaults.standard.bool(forKey: "fastboot_isProUser")
```

`IAPManager`, `ThemeManager`, `AdManager`, `LiveActivityManager` sono `@MainActor`.
Mai chiamarli da background thread senza `await` o `DispatchQueue.main.async`.

---

## Verifica Build

```bash
xcodebuild -project "WalkieTalkie.xcodeproj" -scheme WalkieTalkie -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20
xcodebuild -project "WalkieTalkie.xcodeproj" -scheme TalkyLiveActivities -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20
```

Il progetto non ha test unitari. Verifica = build + code review.

---

## Dati del Progetto

- **App Store**: "Talky - Walkie Talkie, Radio" (ID `6748584483`, bundle `com.immaginet.talky`)
- **Firebase**: project `walkietalkie-6f630`
- **310 stazioni radio** hardcoded in `RadioManager.swift`
- **16 temi** (5 free + 11 Pro), 2 con GPU shader
- **5 lingue**: it, en, es, ms, zh-Hant
- **Licenza**: PolyForm Noncommercial 1.0.0
- **2 target**: WalkieTalkie (iOS 15.6) + TalkyLiveActivities (iOS 16.2)
- **2 remote git**: `origin` e `andreapianidev` (stesso repo)
- **Niente watchOS** — solo idea futura

---

## Apple Policy

- `NSMicrophoneUsageDescription`: spiegare PERCHE' il microfono serve, non COSA fa
- `NSLocalNetworkUsageDescription` + `NSBonjourServices` (`_walkie-talkie._tcp`)
- `NSBluetoothAlwaysUsageDescription` — MC puo' usare BT come fallback
- ATT dopo UMP; se negato → AdMob usa IDFV
- `UIBackgroundModes: audio` per radio in background
- `NSSupportsLiveActivities: YES`
- `GADApplicationIdentifier` + `SKAdNetworkItems` (60+) in Info.plist
- No VoIP background mode — walkie funziona solo foreground/audio background
