---
name: walkietalkie-integration
description: Integra la funzionalità radio P2P Walkie-Talkie (MultipeerConnectivity + AVFoundation) con l'interfaccia utente standard hardware-style in una nuova app iOS o in un nuovo modulo. Usa questa skill ogni volta che l'utente ti chiede di "aggiungere la funzione walkie talkie", "creare la radio P2P", "configurare la connessione vocale locale" o integrare un walkie talkie in SwiftUI.
---

# Walkie-Talkie P2P Integration Skill

Questa skill fornisce le linee guida per replicare e integrare il sistema Walkie-Talkie in stile hardware nelle app iOS.

## 📚 Documentazione e Riferimenti (IMPORTANTE)
**Prima di scrivere codice per questa skill, DEVI LEGGERE il file di riferimento dell'architettura:**
Vai a leggere `references/walkietalkie_architecture.md` (nella cartella di questa skill) per trovare l'**Indice** e gli **snippet di codice esatti** per `Info.plist`, `AVFoundation`, `MultipeerConnectivity` e l'estetica `SwiftUI`.

## 1. Configurazione di Base (Integrazione di Sistema)
Consulta il file di riferimento per i valori precisi da inserire in `Info.plist`:
*   `NSMicrophoneUsageDescription`
*   `NSLocalNetworkUsageDescription`
*   `NSBonjourServices`
*   `UIBackgroundModes` (audio)

## 2. Architettura Logica (I Manager)
Non inserire la logica di rete nelle view. Genera e utilizza queste classi (consulta il riferimento per il codice `AVAudioEngine` e `MCSession`):
1.  **`MultipeerManager`**: Gestisce advertiser, browser e invio `Data` (.reliable).
2.  **`AudioManager`**: Imposta `AVAudioSession` su `.playAndRecord`. Gestisce il tap sull'`inputNode`.
3.  **`PrivateChannelManager`**: (Opzionale). Esegue l'hashing (es. SHA256) per il `discoveryInfo`.

## 3. Interfaccia Grafica (UI "Hardware")
La grafica deve richiamare un dispositivo fisico. Consulta il riferimento per il codice del bottone e del display:
*   **Tema Scuro e Background**: Usa `Color.black` come base.
*   **Display Digitale (Frequenza)**: Font monospaziati e colorati (ambra/giallo) su sfondo nero.
*   **Pulsante Push-To-Talk (PTT)**: Grande `ZStack` circolare con `DragGesture(minimumDistance: 0)` per gestire la pressione continua, con Haptics.
*   **Dettagli Hardware**: Griglie `LazyVGrid` di piccoli cerchi (5x5 pt) per simulare fori speaker.

## 4. Flusso di Lavoro Esecutivo
Quando applichi questa skill:
1.  Leggi il file `references/walkietalkie_architecture.md`.
2.  Chiedi conferma all'utente sui nomi esatti dei file da generare.
3.  Configura l'`Info.plist`.
4.  Implementa i Manager (`MultipeerManager`, `AudioManager`).
5.  Crea la UI seguendo i principi di design descritti.
