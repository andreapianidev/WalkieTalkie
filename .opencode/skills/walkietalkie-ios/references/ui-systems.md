# UI Systems — Temi, Live Activities, Onboarding, Settings

Copre i 4 macro-sistemi UI dell'app che hanno logica complessa oltre la semplice view SwiftUI.

---

## Sistema Temi (16 Temi)

### File
- `Theme/Theme.swift` — Enum 16 casi, facade a ThemeRegistry
- `Theme/ThemeMetadata.swift` — Struct ThemeMetadata + ThemeRegistry (lazy static dict)
- `Theme/ThemeColorPack.swift` — 5 temi free (Default, Ocean, Forest, Sunset, Midnight)
- `Theme/ThemeIdentityPack.swift` — 9 temi Pro (Military, Retro80s, VintageRadio, Cyberpunk, Stealth, Aurora, Submarine, HamRadio, Festival)
- `Theme/ThemeAnimatedPack.swift` — 2 GPU-shader (Black Hole, Galaxy)
- `Theme/ThemeManager.swift` — @MainActor singleton, load/save/validate Pro access
- `Theme/ThemeSelectorView.swift` — Grid UI picker
- `Theme/ThemePurchaseSheet.swift` — Per-theme purchase flow
- `Theme/FontManager.swift` — Custom PostScript font registration (PressStart2P-Regular, etc.)
- `Theme/ThemeSoundManager.swift` — Themed sound packs (morse, sonar, glitch, synth, radio)
- `Theme/AnimatedBackgroundView.swift` — GPU-animated backgrounds (TimelineView + Canvas, 60fps)

### Architettura Registro Temi

```
ThemeRegistry (enum con lazy static dictionary)
  ├── registrazioni da ThemeColorPack (free)
  ├── registrazioni da ThemeIdentityPack (Pro, custom fonts + sounds)
  └── registrazioni da ThemeAnimatedPack (Pro, GPU shaders)

ThemeManager.shared
  ├── activeTheme: Theme (da UserDefaults "talky_active_theme")
  ├── validateAccess() → controlla fastboot_isProUser / fastboot_hasThemesPack
  └── setTheme(_) -> Bool (false se Pro-locked senza accesso)
```

### Come Aggiungere un Nuovo Tema

1. Aggiungi il case all'enum `Theme` (in `Theme.swift`)
2. Registra in uno dei pack file (ColorPack per free, IdentityPack o AnimatedPack per Pro)
3. Crea le color definitions nel pack appropriato
4. Se ha font custom: registra in `FontManager`
5. Se ha suoni: registra in `ThemeSoundManager`
6. Se animato: aggiungi shader in `AnimatedBackgroundView`

### Vincoli
- I temi Pro-locked devono avere `isProLocked: true` nel metadata
- `ThemeManager.setTheme()` restituisce `false` se l'utente non ha accesso
- I bridge keys (`fastboot_isProUser`, `fastboot_hasThemesPack`) sono l'unico meccanismo di gating

---

## Live Activities / Dynamic Island (iOS 16.2+)

### File
- `LiveActivity/LiveActivityManager.swift` — @MainActor singleton, serializza richieste ActivityKit
- `LiveActivity/LiveActivityDeepLink.swift` — Parsing URL `talky://radio/<action>` per iOS 16.x
- `Shared/LiveActivityAttributes.swift` — `RadioActivityAttributes` + `WalkieActivityAttributes` (Codable, Hashable)
- `Shared/RadioActivityIntents.swift` — iOS 17+ `LiveActivityIntent` (play/pause/next/prev)
- `TalkyLiveActivities/` (Widget Extension target):
  - `TalkyLiveActivitiesBundle.swift` — @main WidgetBundle
  - `RadioActivityWidget.swift` — Lock Screen banner + Dynamic Island (compact/minimal/expanded)
  - `WalkieActivityWidget.swift` — Lock Screen + Dynamic Island per walkie

### Meccanismo di Serializzazione

`LiveActivityManager` usa una coda interna per serializzare le richieste ActivityKit:

```
enqueue(task) → processNext()
  ├── Se radio già attiva e arriva update walkie → skip (radio ha precedenza)
  ├── Se walkie già attivo e arriva radio → end walkie, start radio
  └── Se nessuna activity → start nuova
```

### Radio Precedence Rule

La radio ha SEMPRE precedenza sul walkie nella Dynamic Island. Se l'utente sta ascoltando la radio e si connette a un peer walkie, la Live Activity radio NON viene rimpiazzata. Viceversa, se il walkie è attivo e l'utente avvia la radio, la LA walkie viene terminata.

### Bootstrap

All'avvio (`WalkieTalkieApp`), `LiveActivityManager.bootstrap()` pulisce eventuali stale activities rimaste da un crash/kill precedente. Senza questo, l'utente vedrebbe una LA "fantasma" che non risponde.

### iOS 16.x vs 17+ Handling

- **iOS 17+**: tap sulla Live Activity → `LiveActivityIntent` eseguito direttamente dal sistema
- **iOS 16.x**: tap sulla LA → deep-link `talky://radio/play` → `LiveActivityDeepLink.handle(url)` → azione corrispondente

### Widget Extension Layout

Il Widget Extension target (`TalkyLiveActivities`) contiene solo SwiftUI layout — nessuna logica di business:
- **Lock Screen**: banner con nome stazione, paese, frequenza, genere, stato play/pause
- **Dynamic Island compact**: icona + nome stazione + indicatore play/pause
- **Dynamic Island minimal**: solo icona radio/walkie
- **Dynamic Island expanded**: nome stazione, info complete, pulsanti interattivi (iOS 17+)

---

## Onboarding (6 Pagine)

### File
- `OnboardingView.swift` — 6-page TabView con logica permessi
- `OnboardingStrings.swift` — Testi statici (hook, spiegazioni)

### Flusso Pagine
1. **Hook**: "Il walkie-talkie che non sapevi di avere" — cattura attenzione
2. **No-internet**: Spiega che funziona senza internet (P2P locale)
3. **PTT instruction**: Come usare il push-to-talk (tieni premuto, parla, rilascia)
4. **Frequenze/canali**: Spiega i 24 canali disponibili
5. **Radio mode**: Spiega la modalità FM con 310 stazioni
6. **Quick-start**: Riepilogo passi per iniziare subito

### Permessi (Sheet dopo l'onboarding)

```
Onboarding completato → sheet permessi:
  ├── Microfono: grant / deny / skip
  └── Notifiche: grant / deny / skip
```

L'utente può skippare entrambi. L'app funziona senza microfono (solo radio) e senza notifiche.

### Onboarding vs FirstRunCoach

- **OnboardingView**: primo lancio in assoluto (`UserDefaults "talky_onboarding_completed" == nil`)
- **FirstRunCoachView**: overlay coach per nuove feature introdotte in aggiornamenti successivi

---

## Settings UI

### File
- `SettingsView.swift` — Full settings UI
- `SettingsManager.swift` — ObservableObject UserDefaults wrapper

### Sezioni

| Sezione | Contenuto | Gating |
|---|---|---|
| **Pro** | Unlock card, manage subscription, restore | Nessuno (visibile a tutti) |
| **Personalization** | Temi, cronologia, sleep timer, EQ, registrazioni, canali privati | EQ/registrazioni/canali: PRO badge |
| **Notifications** | Toggle on/off + Live Activities toggle | Nessuno |
| **Audio** | White noise toggle, volume, haptic feedback, auto-connect, voice activation, low-power mode, reset | Nessuno |
| **Appearance** | Dark mode toggle | Nessuno |
| **Performance** | Debug overlay toggle | Nessuno (nascosto in release?) |
| **Instructions** | Guida rapida | Nessuno |
| **App Info** | Versione, build, licenza | Nessuno |
| **Support** | Buy Me a Coffee, Peak app cross-promo, Ads/rewarded | Ads: nascosto se Pro |

### SettingsManager (NON singleton)

A differenza degli altri manager, `SettingsManager` è un `@StateObject` nella root (non `.shared`). Questo perché:
- È leggero (solo UserDefaults wrapper)
- Viene creato una volta sola all'avvio
- Non serve accesso globale — solo la SettingsView e poche altre view lo osservano

### Chiavi UserDefaults gestite da SettingsManager

- `talky_background_audio` — white noise in background
- `talky_volume` — volume riproduzione (0.0-1.0)
- `talky_haptic_feedback` — vibrazione PTT
- `talky_auto_connect` — auto-reconnect ai peer
- `talky_frequency` — frequenza walkie corrente
- `talky_voice_activation` — PTT vocale (non ancora implementato?)
- `talky_voice_threshold` — soglia attivazione vocale
- `talky_low_power_mode` — ottimizzazioni risparmio energetico
- `talky_dark_mode` — dark/light mode
- `talky_first_run_coach` — stato first-run coach
- `talky_live_activities` — toggle Live Activities

---

## Dark/Light Mode

L'app supporta dark e light mode con palette adattiva.
Il toggle è in Settings → Appearance.
Implementato via `.preferredColorScheme()` su ContentView, controllato da `SettingsManager.isDarkModeEnabled`.

### Color Assets (in Assets.xcassets)

- `BackgroundColor` — sfondo principale
- `SurfaceColor` — sfondo card/sheet
- `PrimaryTextColor` — testo principale
- `ToggleAccentColor` — accento toggle/switch

Questi color set hanno varianti per dark e light mode definite nell'asset catalog.
