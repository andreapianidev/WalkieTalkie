# Documentazione Architettura Walkie-Talkie P2P

Questo documento contiene i dettagli implementativi per replicare fedelmente il sistema Walkie-Talkie.

## Indice
1. [Integrazione Info.plist](#1-integrazione-infoplist)
2. [Configurazione AVFoundation (Audio)](#2-configurazione-avfoundation-audio)
3. [Configurazione MultipeerConnectivity (Rete)](#3-configurazione-multipeerconnectivity-rete)
4. [Componenti UI (SwiftUI)](#4-componenti-ui-swiftui)

---

### 1. Integrazione Info.plist
Assicurati che il file `Info.plist` del target contenga:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>L'app necessita del microfono per trasmettere la tua voce.</string>
<key>NSLocalNetworkUsageDescription</key>
<string>L'app utilizza la rete locale per trovare e connettersi ad altri dispositivi vicini.</string>
<key>NSBonjourServices</key>
<array>
    <string>_walkie-talkie._tcp</string>
</array>
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

### 2. Configurazione AVFoundation (Audio)
Il cuore dell'audio utilizza `AVAudioEngine`.
**Setup di AVAudioSession:**
```swift
let session = AVAudioSession.sharedInstance()
try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
try session.setActive(true)
```
**Cattura Microfono (Registrazione):**
Usa un tap sull'`inputNode` dell'`AVAudioEngine`:
```swift
let inputNode = audioEngine.inputNode
let format = inputNode.inputFormat(forBus: 0)
inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { (buffer, time) in
    // Converti AVAudioPCMBuffer in Data e invia tramite MCSession
}
```
**Riproduzione Audio Ricevuto:**
Costruisci un `AVAudioPlayerNode`, attaccalo all'`audioEngine` e fai la schedule del buffer ricevuto.

### 3. Configurazione MultipeerConnectivity (Rete)
Il sistema usa `MCSession` per il P2P locale.
*   **Service Type:** Deve essere breve e corrispondere al Bonjour service (es. `walkie-talkie`).
*   **Discovery:** Usa `MCNearbyServiceAdvertiser` per farti trovare e `MCNearbyServiceBrowser` per cercare.
*   **Channel Sicuri:** Passa un `discoveryInfo` dict all'advertiser contenente l'hash (SHA256) del canale, così i peer filtreranno le connessioni:
```swift
let advertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: ["channelHash": mySecretHash], serviceType: "walkie-talkie")
```
*   **Invio Dati:**
```swift
try session.send(audioData, toPeers: session.connectedPeers, with: .reliable)
```

### 4. Componenti UI (SwiftUI)
**Il Display Digitale:**
```swift
Text("88.5 FM")
    .font(.system(size: 36, weight: .bold, design: .monospaced))
    .foregroundColor(.yellow)
    .padding()
    .background(RoundedRectangle(cornerRadius: 15).fill(Color.black))
```

**Il Bottone Push-To-Talk (PTT):**
```swift
ZStack {
    Circle().fill(Color.black).frame(width: 140, height: 140)
    Image(systemName: "mic.fill")
        .font(.system(size: 50))
        .foregroundColor(.white)
}
.scaleEffect(isPressed ? 0.95 : 1.0)
.gesture(
    DragGesture(minimumDistance: 0)
        .onChanged { _ in
            if !isPressed { isPressed = true; HapticManager.shared.lightTap(); startTransmitting() }
        }
        .onEnded { _ in
            isPressed = false; HapticManager.shared.lightTap(); stopTransmitting()
        }
)
```
Usa `UIImpactFeedbackGenerator` per gli Haptics.
