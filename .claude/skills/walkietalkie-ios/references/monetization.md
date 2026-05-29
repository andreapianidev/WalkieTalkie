# Monetizzazione — IAP StoreKit 2 + AdMob Stack

## Modello di Business

Talky ha un modello **freemium con ads + abbonamento Pro**:

| Tier | Walkie-Talkie | Radio | Temi | Ads | Prezzo |
|---|---|---|---|---|---|
| **Free** | 24 canali, PTT illimitato | ~165 stazioni | 5 temi | App Open + Interstitial + Native + Rewarded | Gratis |
| **Pro** | Tutto + EQ + registrazioni | 310 stazioni | 16 temi | 0 ads | Weekly / Yearly |
| **Themes Pack** | — | — | 16 temi | — | One-shot |

---

## IAP: StoreKit 2 (iOS 15+)

### File Rilevanti
- `IAP/IAPProducts.swift` — enum ProductID
- `IAP/IAPManager.swift` — @MainActor purchase/restore/entitlements
- `IAP/PaywallView.swift` — UI paywall

### Product IDs (App Store Connect)

```swift
enum ProductID: String, CaseIterable {
    case ProWeeklyWT  = "app.immaginet.talky.pro.weekly"
    case ProAnnualYT  = "app.immaginet.talky.pro.annual"
    case themesPack   = "app.immaginet.talky.themes.allpack"
    
    static var subscriptionIDs: Set<String> { ... }  // ProWeeklyWT + ProAnnualYT
}
```

### Flusso di Acquisto

```
1. IAPManager.startListeningForTransactions() — listener Task per Transaction.updates
2. updateEntitlements() — loop Transaction.currentEntitlements, controlla subscription attive + themes pack
3. UserDefaults.set(fastboot_isProUser / fastboot_hasThemesPack) — bridge keys per avvio rapido
4. Altri manager leggono bridge keys senza importare IAPManager
```

### Fast-Boot Bridge Keys

All'avvio, IAPManager verifica `Transaction.currentEntitlements` e setta:
```swift
UserDefaults.standard.set(true, forKey: "fastboot_isProUser")
UserDefaults.standard.set(true, forKey: "fastboot_hasThemesPack")
```

Questo evita flicker UI: il paywall non appare per un frame prima che StoreKit risponda.

### Restore Purchases

`IAPManager.restorePurchases()` → AppStore.sync() → updateEntitlements() → Firebase analytics `subscription_restored`

### Simulatore Debug

```swift
#if DEBUG
// Alert per scegliere Free/Pro tier nel simulatore
#endif
```
Cerca `#if DEBUG` in IAPManager per i controlli simulatore.

---

## AdMob Stack

### File Rilevanti
- `Ads/AdConfig.swift` — Ad unit IDs + frequency caps
- `Ads/AdManager.swift` — @MainActor orchestrator
- `Ads/ConsentManager.swift` — UMP GDPR + ATT
- `Ads/AppOpenAdManager.swift` — App open ad
- `Ads/InterstitialAdCoordinator.swift` — Interstitials
- `Ads/RewardedAdCoordinator.swift` — Rewarded "1h no ads"
- `Ads/NativeAdCoordinator.swift` — Native Advanced
- `Ads/NativeAdCardView.swift` — SwiftUI card per native ad
- `Ads/AdViewControllerRepresentable.swift` — UIKit → SwiftUI bridge

### Bootstrap Ordine (CRITICO — non cambiare)

```
1. UMP Consent (GDPR per EEA/UK)
2. ATT prompt (post-UMP)
3. GADMobileAds.start() (SDK init)
4. Parallel preload: AppOpen + Interstitial + Rewarded + Native
```

### Configurazione

```swift
// Ad unit IDs — automatic split DEBUG/Release
// DEBUG: usa Google test ad unit IDs
// Release: production IDs

// Frequency Caps
appOpenMaxAge: 4 ore           // Non mostrare app-open se l'ultima è < 4h fa
interstitialMinInterval: 180s  // Minimo tra interstitials
interstitialDailyMax: 5        // Max interstitials al giorno
removeAdsDuration: 3600s       // Rewarded: 1 ora senza ads
```

### Gate Universale

Tutti gli ad show passano attraverso AdManager che controlla:
```swift
guard !isProUser && !adsRemoved else { return }
```
Dove `isProUser = UserDefaults.standard.bool(forKey: "fastboot_isProUser")`

### Quando Mostrare gli Ads

- **App Open**: cold launch + return from background (soppresso durante PTT attivo)
- **Interstitial**: cambio frequenza walkie, cambio stazione radio, altre transizioni naturali
- **Native**: banner persistente in alcune view (ExploreView, etc.)
- **Rewarded**: pulsante esplicito "Rimuovi ads per 1 ora" in Settings

### SKAdNetwork / Info.plist

`Info.plist` contiene `SKAdNetworkItems` con 60+ entries per AdMob mediation.
`GADApplicationIdentifier` = `ca-app-pub-1193280742171051~5179465988`

---

## Paywall UI

### File: IAP/PaywallView.swift

Design system "Field Radio":
- Palette adattiva: dark (`#0E0D0B` / `#F4EFE4`) vs light (`#FAF7F0` / `#161513`)
- Accent: `#FFCC00` (giallo radio vintage)
- Cards weekly/yearly con "TX active LED" sul selezionato
- Features list, restore button, Terms/Privacy links

### Trigger

- Tap su stazione Pro da utente Free → `RadioManager.blockedByPaywall = true`
- Tap su tema Pro-locked → `ThemePurchaseSheet`
- Tap su feature Pro-gated in Settings (EQ, registrazioni, canali privati, cronologia)

---

## Vincoli da Rispettare

- **NON cambiare Product ID** senza aggiornare App Store Connect
- **NON rimuovere bridge keys** — sono il collante inter-modulo
- **NON skippare UMP** — obbligatorio per GDPR in EEA/UK
- **NON usare ID ads reali in DEBUG** — `AdConfig` gestisce lo split
- **NON forzare show ads se isProUser** — il gate è universale
