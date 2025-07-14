//creato da Andrea Piani - Immaginet Srl - 15/01/25 - https://www.andreapiani.com - README.md

# Talky - Professional Walkie-Talkie & FM Radio App

[![iOS](https://img.shields.io/badge/iOS-15.0+-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)](https://swift.org/)
[![Xcode](https://img.shields.io/badge/Xcode-14.0+-blue.svg)](https://developer.apple.com/xcode/)
[![License](https://img.shields.io/badge/License-Proprietary-red.svg)]()

## 📱 Overview

Talky è un'app iOS professionale che combina funzionalità di walkie-talkie Push-to-Talk con radio FM integrata. Sviluppata con SwiftUI e tecnologie moderne, offre comunicazione peer-to-peer tramite Multipeer Connectivity e streaming radio in tempo reale.

## ✨ Features

- 🎙️ **Push-to-Talk Communication**: Sistema walkie-talkie professionale
- 📻 **FM Radio Integration**: Radio streaming con controlli avanzati
- 🔗 **Multipeer Connectivity**: Comunicazione peer-to-peer senza internet
- 🔔 **Smart Notifications**: Sistema notifiche intelligente con cooldown
- 🌍 **Multi-language Support**: Italiano, Inglese, Spagnolo
- ⚡ **Power Management**: Gestione ottimizzata della batteria
- 🎵 **Audio Management**: Controllo avanzato sessioni audio
- 📳 **Haptic Feedback**: Feedback tattile per migliorare UX

## 🏗️ Architecture

### Design Pattern
- **MVVM (Model-View-ViewModel)**: Architettura principale
- **Singleton Pattern**: Per manager condivisi
- **Observer Pattern**: Tramite `@Published` e `ObservableObject`
- **Dependency Injection**: Tramite `@StateObject` e `@ObservedObject`

### Core Components

#### Managers
- **AudioManager**: Gestione sessioni audio, recording, playback
- **MultipeerManager**: Comunicazione peer-to-peer, discovery, connessioni
- **RadioManager**: Streaming radio FM, controlli playback
- **NotificationManager**: Sistema notifiche con anti-spam
- **SettingsManager**: Persistenza preferenze utente
- **PowerManager**: Monitoraggio stato batteria
- **HapticManager**: Feedback tattile
- **Logger**: Sistema logging centralizzato

#### Views
- **ContentView**: Interfaccia principale con toggle Radio/Walkie-Talkie
- **ConnectionsView**: Gestione connessioni peer-to-peer
- **ExploreView**: Discovery e connessione nuovi dispositivi
- **SettingsView**: Configurazione app e preferenze

## 📁 Project Structure

```
WalkieTalkie/
├── WalkieTalkie.xcodeproj/          # Progetto Xcode
│   ├── project.pbxproj              # Configurazione progetto
│   └── project.xcworkspace/         # Workspace
├── WalkieTalkie/                    # Source code principale
│   ├── Managers/                    # Business Logic
│   │   ├── AudioManager.swift       # Gestione audio
│   │   ├── MultipeerManager.swift   # Comunicazione P2P
│   │   ├── RadioManager.swift       # Radio FM
│   │   ├── NotificationManager.swift # Notifiche
│   │   ├── SettingsManager.swift    # Preferenze
│   │   ├── PowerManager.swift       # Batteria
│   │   └── HapticManager.swift      # Feedback tattile
│   ├── Views/                       # SwiftUI Views
│   │   ├── ContentView.swift        # Main interface
│   │   ├── ConnectionsView.swift    # Connessioni
│   │   ├── ExploreView.swift        # Discovery
│   │   └── SettingsView.swift       # Impostazioni
│   ├── Utils/                       # Utilities
│   │   ├── Logger.swift             # Sistema logging
│   │   └── String+Localization.swift # Estensioni localizzazione
│   ├── Resources/                   # Risorse
│   │   ├── Assets.xcassets/         # Immagini e colori
│   │   ├── radio2.mp3               # Audio samples
│   │   ├── radio3.mp3
│   │   └── radio4.mp3
│   ├── Localization/                # Traduzioni
│   │   ├── it.lproj/
│   │   ├── en.lproj/
│   │   └── es.lproj/
│   ├── Configuration/               # Configurazione
│   │   ├── Info.plist
│   │   ├── WalkieTalkie-Info.plist
│   │   └── WalkieTalkieApp.swift    # App entry point
├── Documentation/
│   ├── plan.md                      # Piano sviluppo
│   ├── AppStore_Description.md      # Descrizione App Store
│   └── README.md                    # Questo file
```

## 🛠️ Technical Requirements

### System Requirements
- **iOS**: 15.0+
- **Xcode**: 14.0+
- **Swift**: 5.0+
- **Device**: iPhone/iPad con supporto Multipeer Connectivity

### Frameworks Used
- **SwiftUI**: UI framework
- **MultipeerConnectivity**: Comunicazione P2P
- **AVFoundation**: Audio recording/playback
- **UserNotifications**: Sistema notifiche
- **Combine**: Reactive programming
- **UIKit**: Componenti legacy

### Permissions Required
- **Microphone**: Per recording audio
- **Local Network**: Per Multipeer Connectivity
- **Notifications**: Per notifiche push locali

## 🚀 Setup & Installation

### Prerequisites
1. macOS con Xcode 14.0+
2. Account Apple Developer (per testing su device)
3. iOS device per testing Multipeer Connectivity

### Installation Steps

1. **Clone Repository**
   ```bash
   git clone [repository-url]
   cd WalkieTalkie
   ```

2. **Open Project**
   ```bash
   open WalkieTalkie.xcodeproj
   ```

3. **Configure Signing**
   - Seleziona il tuo Team in "Signing & Capabilities"
   - Modifica Bundle Identifier se necessario

4. **Build & Run**
   - Seleziona target device
   - Cmd+R per build e run

## 🔧 Configuration

### App Configuration
- **Bundle ID**: Configurabile in `project.pbxproj`
- **Display Name**: "Talky" (configurabile)
- **Service Type**: `walkie-talkie` per Multipeer Connectivity

### Audio Configuration
- **Audio Session**: `.playAndRecord` con `.defaultToSpeaker`
- **Sample Rate**: 44.1 kHz
- **Bit Depth**: 16-bit
- **Channels**: Mono per walkie-talkie, Stereo per radio

### Network Configuration
- **Multipeer Service**: `_walkie-talkie._tcp`
- **Auto-discovery**: Abilitato di default
- **Max Peers**: 8 dispositivi simultanei

## 🧪 Testing

### Unit Testing
- Testare ogni Manager individualmente
- Mock delle dipendenze esterne
- Test delle funzioni di utility

### Integration Testing
- Test comunicazione Multipeer
- Test sessioni audio
- Test persistenza dati

### Device Testing
- Test su dispositivi fisici per Multipeer
- Test performance audio
- Test gestione memoria

## 📊 Performance Considerations

### Memory Management
- Uso di `weak self` in closures
- Cleanup automatico delle connessioni
- Gestione ottimizzata delle sessioni audio

### Battery Optimization
- **PowerManager** per monitoraggio batteria
- Modalità "Low Power" per ridurre consumi
- Gestione intelligente delle connessioni

### Network Optimization
- Compressione audio per trasmissione
- Gestione automatica reconnection
- Timeout configurabili

## 🐛 Debugging

### Logging System
- **Logger.swift**: Sistema centralizzato
- Categorie: Audio, Network, UI, Error
- Output su console Xcode

### Common Issues
1. **Multipeer non funziona**: Verificare permessi Local Network
2. **Audio non registra**: Controllare permessi Microphone
3. **Notifiche non arrivano**: Verificare autorizzazioni

## 🔒 Security & Privacy

### Data Privacy
- Nessun dato inviato a server esterni
- Comunicazione solo locale (Multipeer)
- Audio non salvato permanentemente

### Security Measures
- Validazione input utente
- Gestione sicura delle connessioni
- No hardcoded secrets

## 📈 Future Enhancements

### Planned Features
- [ ] Registrazione conversazioni
- [ ] Gruppi di comunicazione
- [ ] Crittografia end-to-end
- [ ] Supporto Apple Watch
- [ ] Widget iOS

### Technical Debt
- [ ] Refactoring AudioManager
- [ ] Miglioramento test coverage
- [ ] Ottimizzazione performance
- [ ] Documentazione API

## 👨‍💻 Contributing

### Code Style
- Seguire Swift Style Guide
- Usare SwiftLint per consistency
- Documentare funzioni pubbliche
- Test per nuove features

### Git Workflow
- Feature branches per nuove funzionalità
- Pull requests per review
- Commit messages descrittivi
- Tag per releases

## 📄 License

Proprietary - © 2025 Andrea Piani - Immaginet Srl

## 📞 Support

- **Developer**: Andrea Piani
- **Company**: Immaginet Srl
- **Website**: https://www.andreapiani.com
- **Email**: [contact-email]

---

**Note**: Questo progetto è in sviluppo attivo. Consultare `plan.md` per lo stato corrente delle features e i prossimi sviluppi.