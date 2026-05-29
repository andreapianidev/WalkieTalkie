# Architettura Talky — Pattern, Decisioni, Flusso Dati

## Pattern Architetturale

### Service-Oriented Singleton Managers (NON MVVM classico)

Il progetto **non usa MVVM formale con ViewModel per ogni view**. Usa invece un pattern a servizi:
- **Singleton Manager** (`.shared`) per ogni dominio funzionale
- **Combine `@Published`** per binding reattivo SwiftUI
- **`@MainActor`** su manager che toccano UI state
- **UserDefaults bridge keys** per comunicazione inter-modulo (basso accoppiamento)

**Perché questo pattern?** L'app ha stato condiviso complesso (audio, connessioni P2P, IAP, temi) che diverse view devono osservare. Injectare ViewModel nidificati sarebbe fragile con le race condition audio/Multipeer.

### Manager Principali e Loro Responsabilità

```
WalkieTalkieApp.swift (@main)
├── RadioManager.shared          — 310 stazioni, AVPlayer streaming, Now Playing, Live Activity
├── MultipeerManager.shared      — MCSession P2P, advertising, browsing, audio TX/RX
├── AudioManager.shared          — AVAudioSession, riproduzione PCM, white noise, EQ
├── IAPManager.shared            — StoreKit 2, acquisti, restore, entitlements
├── AdManager.shared             — Bootstrap AdMob, preload, convenience methods
├── ConsentManager.shared        — UMP GDPR + ATT consent flow
├── ThemeManager.shared          — Tema attivo, validazione accesso Pro
├── LiveActivityManager.shared   — ActivityKit serialization, start/update/end, intent handling
├── SettingsManager()            — UserDefaults wrapper reattivo (NON singleton, ma @StateObject in root)
├── NotificationManager()        — UNUserNotificationCenter delegate, anti-spam cooldowns
├── FirebaseManager.shared       — Analytics + Crashlytics wrapper
├── PowerManager()               — Battery monitoring, low-power ottimizzazioni
├── PerformanceMonitor()         — FPS/memory debug overlay
├── HapticManager.shared         — CoreHaptics feedback system
├── SleepTimerManager()          — Timer sleep radio
├── PrivateChannelManager()      — Canali privati password-protected
├── TransmissionHistoryManager() — Storico trasmissioni
├── RecordingsManager()          — Registrazioni sessioni (Pro)
└── EqualizerManager()           — 5-band EQ (AVAudioUnitEQ, Pro)
```

### Flusso di Avvio

1. `WalkieTalkieApp.init()` — crea tutti gli `@StateObject` e `@EnvironmentObject`
2. `AppDelegate.didFinishLaunching` — configura Firebase + Crashlytics + UNUserNotificationCenter
3. ScenePhase `.active` — trigger app-open ad, sync entitlements, bootstrap AdMob (UMP → ATT → SDK)
4. UI decide: OnboardingView (primo lancio) o ContentView (normale)
5. `LiveActivityManager.bootstrap()` — pulisce stale activities da cold launch

### Dependency Injection

- **`@StateObject`** nella root (`WalkieTalkieApp`): SettingsManager, NotificationManager, AdManager, IAPManager, ThemeManager
- **`@EnvironmentObject`** propagato ai child: adManager, iapManager, themeManager
- **`@ObservedObject`** per injection mirata: multipeerManager passato a ConnectionsView, ExploreView
- **`.shared` accesso diretto**: RadioManager.shared, AudioManager.shared, FirebaseManager.shared
- **Nessun container DI formale** — SwiftUI environment è il meccanismo di propagation

### Bridge Keys Pattern

Alcuni moduli devono conoscere lo stato di altri moduli senza dipendenza diretta (es. ThemeManager deve sapere se l'utente è Pro senza importare IAPManager):

```swift
// IAPManager scrive:
UserDefaults.standard.set(true, forKey: "fastboot_isProUser")

// ThemeManager (e altri) leggono:
UserDefaults.standard.bool(forKey: "fastboot_isProUser")
```

**Chiavi attive:**
- `fastboot_isProUser` — l'utente ha un abbonamento Pro attivo
- `fastboot_hasThemesPack` — l'utente ha acquistato All Themes Pack

---

## Gestione Audio: La Parte Più Delicata

### Due Modalità Mutualmente Esclusive

| Modalità | AVAudioSession Category | Chi la usa |
|---|---|---|
| **Walkie (WT)** | `.playAndRecord` + `.defaultToSpeaker` + `.allowBluetooth` | MultipeerManager + AudioManager |
| **Radio (FM)** | `.playback` + `.allowBluetoothA2DP` + `.allowAirPlay` | RadioManager |

**La regola d'oro: MAI cambiare category durante l'init.** RadioManager non attiva `.playback` nel costruttore — lo fa solo in `playStation()`. Altrimenti clobbera la sessione walkie e genera `OSStatus -50` (paramErr).

### Sequenza di Category Swap

```
Utente entra in FM → playStation() → activateAudioSessionForPlayback() → .playback
Utente esce da FM → stopRadio() → restoreWalkieAudioSession() → .playAndRecord
```

Tra una stazione e l'altra (next/prev): la categoria resta `.playback` (no swap), per evitare latenza.

### Interruzioni (Telefonate/Siri)

RadioManager osserva `AVAudioSession.interruptionNotification`:
- `.began` → mette in pausa, aggiorna Now Playing e Live Activity
- `.ended` con `shouldResume` → riattiva sessione e riprende playback

### White Noise / Suoni di Sottofondo

AudioManager riproduce 3 file MP3 in loop durante il walkie su frequenze non-home.
Utilizza l'AVAudioEngine già attivo per il PTT — non crea un secondo player.

---

## Design Decision Importanti

### Perché UserDefaults e non CoreData / SwiftData?
- SwiftData richiede iOS 17+, il target è 15.6
- CoreData è overkill per preferenze e array di ID
- UserDefaults bridge keys sono sufficienti per flag booleani e array di Int

### Perché AVPlayer e non AVAudioPlayer?
- AVPlayer supporta streaming HLS/AAC/MP3 nativamente
- AVAudioPlayer richiede file locali o buffer completi
- KVO su AVPlayer per buffering state è più affidabile

### Perché Multipeer Connectivity e non Network.framework?
- MC è la soluzione Apple per P2P locale
- Gestisce discovery, encryption, e trasporto automaticamente
- Il progetto non ha un server centrale — è veramente P2P

### Perché KVO e non Combine per AVPlayer?
- AVPlayer è un tipo reference non-Combine-ready
- KVO su `timeControlStatus` e `AVPlayerItem.status` copre tutti i casi
- Combine `publisher(for:)` su KVO avrebbe la stessa semantica

---

## Thread Safety

- **Main Actor**: IAPManager, ThemeManager, AdManager, LiveActivityManager → tutte le mutazioni `@Published` su main
- **RadioManager**: NON è @MainActor, ma marshal-izza esplicitamente ogni callback KVO e RemoteCommand su `DispatchQueue.main`
- **MultipeerManager**: callback MCSession arrivano su thread arbitrari → dispatch su main per mutazioni @Published
- **AudioManager**: callback AVAudioEngine su thread real-time → nessuna mutazione UI diretta, solo segnali

### Race Condition Note

La race più pericolosa è in RadioManager KVO: quando cambi stazione, `radioPlayer` viene sostituito
ma il vecchio player può ancora inviare callback KVO. Il guard `player === self.radioPlayer` è essenziale.
**NON RIMUOVERE QUESTO GUARD.**
