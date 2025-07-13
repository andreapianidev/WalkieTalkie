//creato da Andrea Piani - Immaginet Srl - 12/07/25 - https://www.andreapiani.com - plan.md

# WalkieTalkie App Development Plan

## To Do

### Priorità Alta
- [ ] Migliorare gestione audio (riproduzione audio ricevuto)
- [ ] Implementare whitelist di dispositivi fidati
- [ ] Aggiungere crittografia end-to-end per i messaggi audio
- [ ] Interfaccia utente per configurazione timeout
- [ ] Dashboard statistiche connessione
- [ ] Notifiche push per riconnessioni
- [ ] Aggiungere più stazioni radio internazionali
- [ ] Implementare salvataggio stazione preferita
- [ ] Aggiungere ricerca stazioni per genere/paese

### Funzionalità Avanzate
- [ ] Implementare view Explore con canali disponibili
- [ ] Implementare view Profile con impostazioni utente
- [ ] Aggiungere suoni di notifica per connessioni
- [ ] Ottimizzare qualità audio e ridurre latenza
- [ ] Testare sistema di logging e gestione errori su dispositivi fisici
- [ ] Compressione audio adattiva basata su qualità rete
- [ ] Backup automatico configurazioni
- [ ] Modalità risparmio energetico
- [ ] Supporto connessioni multiple simultanee
- [ ] Analytics utilizzo app

## Done
- [x] Corretto ciclo di vita dell'audio engine e del tap per push-to-talk, prevenendo errori -10851 e trasmissione real-time errata
- [x] Implementata localizzazione completa dell'app per italiano, inglese e spagnolo
  - Creati file Localizable.strings per tutte e tre le lingue
  - Aggiunta estensione String+Localization per facilitare l'uso delle stringhe localizzate
  - Localizzate tutte le stringhe hardcoded in ContentView.swift, ConnectionsView.swift, ExploreView.swift e SettingsView.swift
  - Supporto per oltre 80 stringhe localizzate inclusi UI elements, messaggi di errore, istruzioni e impostazioni

### Funzionalità Base
- [x] Configurazione MultipeerConnectivity
- [x] Gestione sessioni audio
- [x] Interfaccia utente base
- [x] Sistema di logging
- [x] Gestione permessi Info.plist
- [x] Risoluzione errore NSNetServices -72008

### Sicurezza e Connessioni
- [x] Validazione peer autorizzati
- [x] Rimozione connessione automatica
- [x] Gestione errori peer non autorizzati
- [x] Logging sicurezza per tentativi non autorizzati

### Gestione Connessione Avanzata
- [x] Timeout personalizzabili (5-60 secondi)
- [x] Riconnessione automatica con delay di 5 secondi
- [x] Sistema heartbeat ogni 10 secondi
- [x] Retry logic con massimo 3 tentativi
- [x] Gestione errori migliorata con fallback
- [x] Ottimizzazione bandwidth per audio
- [x] Memory management con weak references

### Bug Fix e Correzioni
- [x] Risoluzione errori compilazione ExploreView: sostituito nearbyPeers con discoveredPeers
- [x] Correzione metodo restartDiscovery con stopBrowsing() + startBrowsing()
- [x] Risoluzione errori compilazione RadioManager: aggiunta ereditarietà NSObject e override per KVO
- [x] **RadioManager.swift**: Risolti errori di compilazione KVO
  - Aggiunta ereditarietà da `NSObject` per supportare Key-Value Observing
  - Corretto metodo `observeValue` con `override` keyword
  - Aggiunto `override` al costruttore `init()` e chiamata a `super.init()`
- [x] **RadioManager.swift**: Migliorata gestione errori streaming
  - Aggiornato URL NRJ Francia per risolvere errore 404
  - Aggiunta proprietà `@Published var lastError` per feedback errori
  - Implementato metodo `handlePlaybackError` per gestione errori
  - Aggiunto observer per errori del player AVPlayer
  - Migliorato logging degli errori di streaming
  - [x] Espansione lista stazioni da 20 a 50 stazioni internazionali
- [x] Correzione URL NRJ Francia (da 404 a URL funzionante)
- [x] Verifica e aggiornamento URL stazioni radio
- [x] Correzione errore compilazione: logAudioError richiede Error non String
- [x] **MultipeerManager.swift**: Risolto crash per formato audio non compatibile
  - Connesso `inputNode` al `mainMixerNode` con formato nativo per stabilire un formato coerente
  - Impostato volume di `mainMixerNode` a 0 per evitare feedback audio
  - Corretto gestione dei tipi non-opzionali per `inputNode` e `nativeFormat`
- [x] **MultipeerManager.swift**: Risolto crash per errore di avvio AVAudioEngine (AUIOClient_StartIO failed)
  - Rimosso collegamento diretto tra `inputNode` e `mainMixerNode` che causava conflitti
  - Aggiunto `audioEngine.prepare()` prima di `audioEngine.start()` per garantire corretta inizializzazione
  - Migliorata gestione del formato audio nativo dell'input node

### Sistema Radio FM
- [x] Creazione RadioManager con 20 stazioni internazionali
- [x] Integrazione toggle Walkie-Talkie/Radio FM nell'header
- [x] Controlli radio: play/pause, previous/next station, volume
- [x] Display informazioni stazione (frequenza, paese, buffering)
- [x] Gestione AVPlayer per streaming audio
- [x] Stazioni da Italia, Francia, Germania, UK, Spagna, USA, Brasile, Giappone, Australia, Canada, Olanda, Belgio, Svizzera
- [x] Connection pooling per peer multipli
- [x] Monitoraggio qualità connessione
- [x] Statistiche di rete in tempo reale
- [x] Risoluzione errori compilazione WalkieTalkieError
- [x] Implementazione playReceivedAudio in AudioManager
- [x] Pulsanti Previous/Forward per cambio frequenza
- [x] Gestione permessi microfono con richiesta automatica
- [x] Alert per permessi microfono negati
- [x] Correzione invio messaggi audio - verifica permessi prima trasmissione
- [x] Re-inizializzazione audio engine quando necessario
- [x] Aggiunto WalkieTalkieError.audioPermissionDenied
- [x] Modificato sistema trasmissione: accumulo audio durante pressione
- [x] Invio messaggio audio completo al rilascio del pulsante
- [x] Migliorato logging per distinguere heartbeat da messaggi audio

## Audio Message Transmission System

### Changes Made:
1. **Modified transmission paradigm**: Changed from continuous streaming to accumulating audio during button press and sending complete message upon release
2. **Added audio accumulation**: Implemented `recordedAudioData` property and `accumulateAudioData()` method in `MultipeerManager.swift`
3. **Complete message transmission**: Added `sendAccumulatedAudio()` method to send accumulated audio reliably using `.reliable` transmission
4. **Improved logging**: Enhanced logging in received data handling to distinguish between heartbeats and audio messages
5. **Fixed audio format compatibility**: Standardized audio format to `.pcmFormatFloat32` at 44100Hz, 1 channel in both recording and playback
6. **Enhanced playback engine**: Improved `AudioManager.swift` with proper lifecycle management for `AVAudioEngine` and `AVAudioPlayerNode` during playback
7. **Added playback cleanup**: Implemented `stopCurrentPlayback()` method to properly manage audio engine resources
8. **Fixed format mismatch crash**: Resolved `com.apple.coreaudio.avfaudio` exception by using native input format for tap and converting to standard format
9. **Added audio format conversion**: Implemented `accumulateAudioDataWithConversion()` with `AVAudioConverter` for seamless format handling
10. **Reduced background volume**: Lowered MP3 background audio volume from 0.3 to 0.15 (50% reduction) for better user experience
11. **Dynamic reception status**: Implemented dynamic "RICEZIONE IN CORSO" indicator that shows when audio is being received, replacing static "nessuna trasmissione" text
12. **Fixed tabBar consistency**: Removed NavigationView from ConnectionsView to ensure tabBarView is always in the same position across all views
13. **Fixed tabBar positioning**: Moved tabBarView to absolute positioning using ZStack to prevent movement between different views
14. **Implemented persistent settings**: Created SettingsManager with UserDefaults for persistent app settings
15. **Added new useful settings**: Added haptic feedback, auto-connect, voice activation, low power mode settings
16. **Fixed AVAudioFormat crash**: Updated audio format to use native sample rate instead of fixed 44100 Hz in both MultipeerManager and AudioManager
17. **Added settings reset**: Implemented reset to defaults functionality with confirmation button
18. **Fixed AudioManager format mismatch**: Updated AudioManager to use native system sample rate (48000 Hz) instead of hardcoded 44100 Hz to prevent crash
19. **Fixed audio session conflicts**: Resolved AVAudioFormat crash by improving audio session management, ensuring proper cleanup of audio taps before engine restart, and adding audio session reactivation to prevent format conflicts between multiple audio components
20. **Enhanced FM radio mode**: 
   - Modified connectionStatusView to display radio station information (name, genre, country, buffering status) when in FM mode instead of connection status
   - Disabled tap-to-talk functionality in FM mode with visual feedback (grayed out button with "MODALITÀ RADIO FM ATTIVA" text)
    - Implemented automatic white noise suppression in FM mode by adding updateBackgroundAudioForMode method to AudioManager
    - White noise (MP3 background audio) is now automatically stopped when switching to FM mode and resumed when returning to walkie-talkie mode
- [x] **Fixed audio engine startup crash**: Resolved AUIOClient_StartIO error (2003329396) by removing conflicting inputNode-to-mainMixerNode connection and adding proper engine preparation with prepare() call before start()
- [x] Risolto errore di compilazione relativo a `stopAudioEngine`
- [x] Ripristinata la logica push-to-talk per la registrazione e l'invio di flussi audio singoli
- [x] Risolto crash `Failed to create tap due to format mismatch` in `MultipeerManager.swift`
  - Utilizzato formato nativo dell'input node direttamente invece di creare formato standardizzato
  - Semplificata funzione `accumulateAudioDataWithConversion` per evitare conversioni non necessarie

### Implementazioni Dettagliate
- [x] Creato progetto Xcode base
- [x] Analizzato design da foto di riferimento
- [x] Implementata interfaccia principale con design giallo
- [x] Creato display frequenza (428.283) con font digitale
- [x] Aggiunti controlli playback (emoji, play, pause, power)
- [x] Implementata griglia di punti per speaker
- [x] Aggiunto pulsante "Push to talk" centrale con feedback
- [x] Creata tab bar inferiore (Talk, Explore, Friends, Profile)
- [x] Implementato MultipeerConnectivity per comunicazione P2P
- [x] Aggiunta gestione audio base (registrazione)
- [x] Implementato discovery e connessione dispositivi automatica
- [x] Aggiunti permessi microfono e rete locale
- [x] Creata ConnectionsView per gestire dispositivi connessi
- [x] Migliorata UI con textbox stato connessione sotto header
- [x] Redesign pulsante push-to-talk con stile moderno
- [x] Aggiunta griglia speaker più grande (8x9 punti)
- [x] Aggiunto indicatore scansione dispositivi
- [x] Migliorata ConnectionsView con icona antenna
- [x] Aggiunti tutti i permessi necessari (Bluetooth, rete locale, microfono)
- [x] Tradotte descrizioni permessi in italiano
- [x] Aggiunto feedback visivo durante trasmissione con animazioni
- [x] Risolto problema auto-pairing nel simulatore
- [x] Migliorato pulsante push-to-talk con gesture press/release
- [x] Cambiata icona Explore da rocket a magnifyingglass
- [x] Corretti servizi Bonjour nel plist (rimosso UDP)
- [x] Aggiunto discoveryInfo per migliorare scoperta dispositivi
- [x] Implementato metodo per forzare richiesta permesso rete locale
- [x] Modificata configurazione sessione con encryptionPreference optional
- [x] Sistema di logging centralizzato con os.log
- [x] Gestione errori personalizzata con WalkieTalkieError
- [x] Logging dettagliato per operazioni di rete e audio
- [x] Stato di connessione dinamico nell'interfaccia utente
- [x] Alert per visualizzazione errori all'utente
- [x] Validazione input e controlli di sicurezza migliorati
- [x] Risolto errore NSNetServices -72008 aggiornando Info.plist con permessi completi
- [x] Implementato sistema di sicurezza per prevenire connessioni non autorizzate
- [x] Rimossa auto-connessione automatica per maggiore controllo utente
- [x] Aggiunta validazione peer per bloccare dispositivi non fidati
- [x] Aggiornato tabBarView: Rimossa tab "Friends", rinominata "Profile" in "Impostazioni", cambiata icona "Friends" in "antenna.radiowaves.left.and.right" per "Connections", cambiata icona "Profile" in "gearshape.fill" per "Impostazioni"
- [x] Implemented SettingsView: Created complete settings interface with background audio toggle, volume slider, step-by-step instructions for app usage, and app information section
- [x] Implemented ExploreView: Created radar-style interface with animated sonar display, concentric circles showing range, rotating sweep line, pulsing effects, detected device visualization with distance estimation, and device list with connection capabilities

## ✅ COMPLETED TASKS

### 1. Audio Engine and Push-to-Talk Lifecycle ✅
- **Status**: COMPLETED
- **Description**: Implemented comprehensive audio engine with proper lifecycle management for push-to-talk functionality
- **Key Components**:
  - AudioManager with singleton pattern for centralized audio control
  - Proper microphone permission handling with user-friendly alerts
  - Real-time audio recording and playback with optimized buffer management
  - Audio session configuration for walkie-talkie use case
  - Memory-efficient audio data handling
  - Integration with MultipeerManager for seamless audio transmission

### 2. App Localization (Italian, English, Spanish) ✅
- **Status**: COMPLETED
- **Description**: Full localization of the WalkieTalkie app into three languages
- **Key Components**:
  - Created `Localizable.strings` files for Italian (`it.lproj`), English (`en.lproj`), and Spanish (`es.lproj`)
  - Implemented `String+Localization.swift` extension for easy string localization
  - Localized over 80 UI strings across all major views:
    - `ContentView.swift`: Main interface, radio controls, walkie-talkie features, tab navigation, alerts
    - `ConnectionsView.swift`: Connection management, device status, alerts
    - `ExploreView.swift`: Device discovery, signal strength indicators
    - `SettingsView.swift`: All settings options, descriptions, and instructions
  - Comprehensive coverage including:
    - General UI terms and navigation
    - Radio and walkie-talkie specific terminology
    - Error messages and alerts
    - Settings descriptions and help text
    - Dynamic UI elements and status indicators

### 3. Push Notifications System ✅
- **Status**: COMPLETED
- **Description**: Implemented comprehensive push notification system with multilingual support
- **Key Components**:
  - Created `NotificationManager.swift` with singleton pattern for centralized notification control
  - Bell button in main interface to toggle notifications on/off with visual feedback
  - Notifications section in Settings with detailed controls
  - Integrated notifications throughout the app:
    - New device detection notifications
    - Connection established/lost notifications
    - Incoming transmission alerts
    - Background scanning notifications
  - Full localization support for all notification messages in Italian, English, and Spanish
  - Proper permission handling and user preference management
  - Background mode support in Info.plist for notification delivery
  - Integration with MultipeerManager for real-time event notifications

### 4. Haptic Feedback System ✅
- **Status**: COMPLETED
- **Description**: Comprehensive haptic feedback management with different intensity levels
- **Key Components**:
  - Created `HapticManager.swift` with different intensity levels (light, medium, heavy)
  - Specialized feedback for transmission events, connection status changes
  - Settings-based enable/disable functionality
  - ContentView Integration: Haptic feedback for frequency navigation, transmission start/stop, connection errors, and tab navigation
  - MultipeerManager Integration: Haptic feedback for connection establishment and loss events
  - All haptic feedback respects user preferences from SettingsManager

### 5. Low Power Mode System ✅
- **Status**: COMPLETED
- **Description**: Advanced power management with battery monitoring and optimization
- **Key Components**:
  - Created `PowerManager.swift` with battery monitoring and system low power mode detection
  - Automatic activation below 20% battery
  - Optimized intervals for scanning and heartbeat
  - Reduced audio quality and volume in low power mode
  - MultipeerManager Integration: Dynamic heartbeat intervals based on power status
  - AudioManager Integration: Optimized background audio volume based on power mode
  - Complete battery status strings localization in Italian, English, and Spanish

### 6. Localization Fixes ✅
- **Status**: COMPLETED
- **Description**: Comprehensive review and correction of localization strings across all languages
- **Issues Fixed**:
  - Removed duplicate strings in all localization files
  - Corrected inconsistent key names (e.g., `step_X_title` → `instruction_X_title`)
  - Fixed missing translations (e.g., "Strong", "Medium", "Weak" in Italian)
  - Standardized key naming conventions across all languages
  - Added missing notification and battery status strings
  - Removed unused "unknown" duplicate entries
- **Files Modified**: `it.lproj/Localizable.strings`, `en.lproj/Localizable.strings`, `es.lproj/Localizable.strings`
- **Result**: All hardcoded strings are now properly localized with consistent keys across Italian, English, and Spanish

### 7. iOS Deprecation Warnings Fix ✅
- **Status**: COMPLETED
- **Description**: Fixed iOS deprecation warnings to use modern APIs
- **Issues Fixed**:
  - Updated `RadioManager.swift`: Replaced deprecated `.allowBluetooth` with `.allowBluetoothA2DP` for iOS 8.0+ compatibility
  - Updated `SettingsView.swift`: Replaced deprecated `onChange(of:perform:)` with new two-parameter syntax for iOS 17.0+ compatibility
- **Files Modified**: `RadioManager.swift`, `SettingsView.swift`
- **Result**: Eliminated all deprecation warnings and ensured compatibility with latest iOS APIs

### 8. Notification System Bug Fix ✅

### 9. Push to Talk System Analysis ✅
**Status**: Already Implemented and Functional

**Current Implementation**:
- **Main Button**: Large circular button in ContentView with visual feedback
- **Gesture Control**: Uses `DragGesture` for press/release detection
- **Visual Feedback**: 
  - Button scaling animation during transmission
  - Pulsating red circle effect when transmitting
  - Dynamic text labels ("HOLD PRESSED TO TALK" / "RELEASE TO SEND")
- **Audio Integration**: Integrated with `AudioManager` and `MultipeerManager`
- **Haptic Feedback**: 
  - Heavy tap + light tap on transmission start
  - Medium tap on transmission end
- **Permission Handling**: Automatic microphone permission check
- **Connection Validation**: Prevents transmission without connected peers
- **Localization**: Full support for IT/EN/ES languages

**Key Features**:
- ✅ Press and hold to transmit
- ✅ Release to stop transmission
- ✅ Visual transmission indicators
- ✅ Haptic feedback for start/stop
- ✅ Permission validation
- ✅ Connection status validation
- ✅ Authentic walkie-talkie experience
- ✅ Radio mode toggle (disables PTT when in FM mode)

**Technical Implementation**:
```swift
.gesture(
    DragGesture(minimumDistance: 0)
        .onChanged { _ in startTransmitting() }
        .onEnded { _ in stopTransmitting() }
)
```

The app already provides a complete and professional Push to Talk implementation that mimics real walkie-talkie behavior.

### 10. App Store Connect Build Preparation ✅
**Problem**: Due errori impedivano il caricamento su App Store Connect:
1. Bundle name "Walkie Talkie" già utilizzato da altre app
2. Valore UIBackgroundModes non valido: 'background-processing'

**Solution**:
- **Bundle Display Name**: Cambiato da "Walkie Talkie" a "WalkieTalkie Pro"
- **UIBackgroundModes**: Rimosso 'background-processing', mantenuto solo 'remote-notification'
- **Files Modified**: 
  - `Info.plist`: Aggiornato UIBackgroundModes
  - `project.pbxproj`: Aggiornato CFBundleDisplayName per Debug e Release

**Result**: App pronta per il caricamento su App Store Connect senza conflitti di naming e con configurazioni valide.

### 11. Notification Button Enhancement ✅
- **Problem**: Il pulsante delle notifiche nel ContentView non funzionava correttamente
- **Root Cause**: Il metodo `toggleNotifications()` non faceva effettivamente il toggle della proprietà `notificationsEnabled`
- **Solution**: 
  - Corretto il metodo `toggleNotifications()` per fare il toggle della proprietà
  - Aggiunto metodo `sendNotificationActivatedConfirmation()` per inviare notifica di conferma
  - Implementato `AppDelegate` con `UNUserNotificationCenterDelegate` per mostrare notifiche anche quando l'app è in primo piano
  - Aggiunto ritardo di 1 secondo alla notifica di conferma per migliorare l'esperienza utente
  - Aggiunte stringhe di localizzazione per "notifications_enabled" e "notifications_activated_message" in tutte le lingue
- **Files Modified**: 
  - `NotificationManager.swift`: Corretto toggleNotifications e aggiunto metodo di conferma
  - `WalkieTalkieApp.swift`: Aggiunto AppDelegate per gestire notifiche in primo piano
  - `en.lproj/Localizable.strings`, `it.lproj/Localizable.strings`, `es.lproj/Localizable.strings`: Aggiunte nuove stringhe
- **Status**: COMPLETED
- **Description**: Fixed critical bug causing app freeze when enabling notifications from settings
- **Root Cause**: Infinite loop between Toggle binding and toggleNotifications() method
- **Issues Fixed**:
  - Removed redundant `notificationsEnabled.toggle()` call in `toggleNotifications()` method
  - Added proper permission handling when user denies notification access
  - Improved synchronization between system notification permissions and app state
  - Added automatic disabling of notifications when permissions are revoked
- **Files Modified**: `NotificationManager.swift`
- **Result**: Notifications can now be safely enabled/disabled without app freezing

### 9. Radar/Sonar UI Enhancement ✅
- **Status**: COMPLETED
- **Description**: Improved radar display in ExploreView with better visual effects and fixed positioning
- **Improvements Made**:
  - Fixed range labels positioning using GeometryReader for proper centering
  - Added radar sweep trail effect for more realistic sonar appearance
  - Enhanced device dots with glow effects and better visibility
  - Improved center dot design with white border
  - Added background styling with subtle border
  - Enhanced gradient effects for radar sweep line
  - Fixed all positioning calculations to use dynamic center point
- **Files Modified**: `ExploreView.swift`
- **Result**: Radar now displays correctly with stable labels and enhanced visual effects

## Notes
- Design: Sfondo giallo (#FFD700 circa), elementi neri/bianchi
- Framework: MultipeerConnectivity per P2P offline
- Audio: AVAudioEngine per registrazione/riproduzione
- UI: SwiftUI con layout responsive
- Target: iOS devices only (iPhone/iPad)
- Frequenza mostrata: 428.283 (simulata, non reale)