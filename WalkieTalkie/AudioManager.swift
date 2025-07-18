//creato da Andrea Piani - Immaginet Srl - 12/07/25 - https://www.andreapiani.com - AudioManager.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 12/07/25.
//

import Foundation
import AVFoundation
import Combine
import os.log

/// Gestisce l'audio di sottofondo e i permessi per l'app WalkieTalkie
class AudioManager: ObservableObject {
    static let shared = AudioManager()
    
    private var backgroundAudioPlayer: AVAudioPlayer?
    private var playbackAudioEngine: AVAudioEngine?
    private var playbackPlayerNode: AVAudioPlayerNode?
    private let logger = Logger.shared
    private let settingsManager = SettingsManager.shared
    private let powerManager = PowerManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var hasAudioPermission = false
    @Published var isPlayingBackground = false
    @Published var isPlayingFrequencyAudio = false
    
    private let backgroundSounds = ["radio2.mp3", "radio3.mp3", "radio4.mp3"]
    private var frequencyAudioPlayer: AVAudioPlayer?
    private let frequencyAudioFiles = Array(1...24).map { "f\($0).mp3" }
    
    private init() {
        setupAudioSession()
        checkAudioPermission()
        setupSettingsObservers()
        setupNotificationObservers()
    }
    
    private func setupSettingsObservers() {
        // Osserva i cambiamenti nelle impostazioni del rumore bianco
        settingsManager.$isBackgroundAudioEnabled
            .sink { [weak self] isEnabled in
                DispatchQueue.main.async {
                    if isEnabled {
                        self?.startBackgroundAudioIfNeeded()
                    } else {
                        self?.stopBackgroundAudio()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Osserva i cambiamenti nel volume
        settingsManager.$backgroundVolume
            .sink { [weak self] volume in
                self?.setBackgroundVolume(volume)
            }
            .store(in: &cancellables)
    }
    
    private func setupNotificationObservers() {
        // Osserva le interruzioni audio
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, 
                                       mode: .voiceChat, 
                                       options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try audioSession.setActive(true)
            logger.logAudioInfo("Audio session configurata correttamente")
        } catch {
            logger.logAudioError(error, context: "Configurazione audio session")
        }
    }
    
    // MARK: - Permissions
    
    func requestAudioPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.hasAudioPermission = granted
                self?.logger.logAudioInfo("Permesso microfono: \(granted ? "concesso" : "negato")")
                
                if granted {
                    self?.startBackgroundAudioIfNeeded()
                }
            }
        }
    }
    
    private func checkAudioPermission() {
        let status = AVAudioSession.sharedInstance().recordPermission
        hasAudioPermission = status == .granted
        
        if hasAudioPermission {
            startBackgroundAudioIfNeeded()
        }
    }
    
    // MARK: - Background Audio
    
    func startBackgroundAudioIfNeeded() {
        guard hasAudioPermission && settingsManager.isBackgroundAudioEnabled else {
            if !hasAudioPermission {
                logger.logAudioWarning("Tentativo di avviare audio senza permessi")
            } else {
                logger.logAudioInfo("Rumore bianco disabilitato dalle impostazioni")
            }
            return
        }
        
        startBackgroundAudio()
    }
    
    func startBackgroundAudio() {
        guard hasAudioPermission else {
            logger.logAudioWarning("Tentativo di avviare audio senza permessi")
            return
        }
        
        // Seleziona un file audio casuale
        let randomSound = backgroundSounds.randomElement() ?? "radio2.mp3"
        
        guard let soundURL = Bundle.main.url(forResource: randomSound.replacingOccurrences(of: ".mp3", with: ""), withExtension: "mp3") else {
            logger.logAudioError(NSError(domain: "AudioManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "File audio non trovato: \(randomSound)"]), context: "Caricamento audio di sottofondo")
            return
        }
        
        do {
            backgroundAudioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            backgroundAudioPlayer?.numberOfLoops = -1 // Loop infinito
            backgroundAudioPlayer?.volume = settingsManager.backgroundVolume
            backgroundAudioPlayer?.prepareToPlay()
            
            if backgroundAudioPlayer?.play() == true {
                isPlayingBackground = true
                logger.logAudioInfo("Audio di sottofondo avviato: \(randomSound)")
            }
        } catch {
            logger.logAudioError(error, context: "Avvio audio di sottofondo")
        }
    }
    
    // Controlla se il rumore bianco deve essere riprodotto in base alla modalità
    func updateBackgroundAudioForMode(isRadioMode: Bool) {
        if isRadioMode {
            // In modalità FM, ferma il rumore bianco
            if isPlayingBackground {
                stopBackgroundAudio()
                logger.logAudioInfo("Rumore bianco fermato per modalità FM")
            }
        } else {
            // In modalità walkie-talkie, avvia il rumore bianco se non è già in riproduzione e se abilitato
            if !isPlayingBackground && hasAudioPermission && settingsManager.isBackgroundAudioEnabled {
                startBackgroundAudio()
                logger.logAudioInfo("Rumore bianco avviato per modalità walkie-talkie")
            }
        }
    }
    
    func stopBackgroundAudio() {
        backgroundAudioPlayer?.stop()
        backgroundAudioPlayer = nil
        isPlayingBackground = false
        logger.logAudioInfo("Audio di sottofondo arrestato")
    }
    
    /// Riproduce un file MP3 casuale per le frequenze non-home
    func playRandomFrequencyAudio() {
        guard let randomFile = frequencyAudioFiles.randomElement() else {
            logger.logAudioError(NSError(domain: "AudioManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Nessun file audio frequenza disponibile"]), context: "Selezione file frequenza")
            return
        }
        
        guard let soundURL = Bundle.main.url(forResource: randomFile.replacingOccurrences(of: ".mp3", with: ""), withExtension: "mp3") else {
            logger.logAudioError(NSError(domain: "AudioManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "File audio frequenza non trovato: \(randomFile)"]), context: "Caricamento audio frequenza")
            return
        }
        
        do {
            // Ferma l'audio precedente se in riproduzione
            stopFrequencyAudio()
            
            frequencyAudioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            frequencyAudioPlayer?.numberOfLoops = -1 // Loop infinito
            frequencyAudioPlayer?.volume = powerManager.isLowPowerModeActive ? 0.3 : 0.5
            frequencyAudioPlayer?.play()
            
            isPlayingFrequencyAudio = true
            logger.logAudioInfo("Avviata riproduzione audio frequenza: \(randomFile)")
            
        } catch {
            logger.logAudioError(error, context: "Riproduzione audio frequenza")
        }
    }
    
    /// Ferma la riproduzione dell'audio delle frequenze
    func stopFrequencyAudio() {
        frequencyAudioPlayer?.stop()
        frequencyAudioPlayer = nil
        isPlayingFrequencyAudio = false
        logger.logAudioInfo("Audio frequenza arrestato")
    }
    
    func setBackgroundVolume(_ volume: Float) {
        let clampedVolume = max(0.0, min(1.0, volume))
        let optimizedVolume = powerManager.getOptimizedBackgroundVolume(clampedVolume)
        backgroundAudioPlayer?.volume = optimizedVolume
        logger.logAudioDebug("Volume sottofondo impostato a: \(optimizedVolume) (originale: \(clampedVolume))")
    }
    
    // MARK: - Voice Communication
    
    func lowerBackgroundVolumeForVoice() {
        backgroundAudioPlayer?.volume = settingsManager.backgroundVolume * 0.2 // Abbassa al 20%
        logger.logAudioDebug("Volume sottofondo abbassato per voce")
    }
    
    func restoreBackgroundVolume() {
        backgroundAudioPlayer?.volume = settingsManager.backgroundVolume
        logger.logAudioDebug("Volume sottofondo ripristinato")
    }
    
    func playReceivedAudio(_ data: Data) {
        logger.logAudioDebug("Riproduzione audio ricevuto: \(data.count) bytes")
        
        // Abbassa temporaneamente il volume di sottofondo
        lowerBackgroundVolumeForVoice()
        
        // Usa AVAudioEngine per riprodurre i dati PCM raw
        playPCMAudio(data)
    }
    
    private func playPCMAudio(_ data: Data) {
        // Ferma riproduzione precedente se in corso
        stopCurrentPlayback()
        
        playbackAudioEngine = AVAudioEngine()
        playbackPlayerNode = AVAudioPlayerNode()
        
        guard let audioEngine = playbackAudioEngine,
              let playerNode = playbackPlayerNode else {
            logger.logAudioError(NSError(domain: "AudioManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "Impossibile creare componenti audio"]), context: "Inizializzazione playback")
            restoreBackgroundVolume()
            return
        }
        
        do {
            // Configura il formato audio usando la frequenza di campionamento nativa del sistema
            let audioSession = AVAudioSession.sharedInstance()
            let nativeSampleRate = audioSession.sampleRate
            let audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                          sampleRate: nativeSampleRate,
                                          channels: 1,
                                          interleaved: false)
            
            guard let format = audioFormat else {
                logger.logAudioError(NSError(domain: "AudioManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Formato audio non valido"]), context: "Configurazione formato per riproduzione")
                restoreBackgroundVolume()
                return
            }
            
            // Crea buffer audio dai dati ricevuti
            let frameCount = AVAudioFrameCount(data.count / MemoryLayout<Float32>.size)
            guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                logger.logAudioError(NSError(domain: "AudioManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Impossibile creare buffer audio"]), context: "Creazione buffer per riproduzione")
                restoreBackgroundVolume()
                return
            }
            
            audioBuffer.frameLength = frameCount
            
            // Copia i dati nel buffer
            data.withUnsafeBytes { bytes in
                guard let floatPointer = bytes.bindMemory(to: Float32.self).baseAddress else { return }
                guard let channelData = audioBuffer.floatChannelData?[0] else { return }
                channelData.assign(from: floatPointer, count: Int(frameCount))
            }
            
            // Configura audio engine
            audioEngine.attach(playerNode)
            audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
            
            try audioEngine.start()
            
            // Riproduci il buffer
            playerNode.scheduleBuffer(audioBuffer, completionHandler: { [weak self] in
                DispatchQueue.main.async {
                    self?.stopCurrentPlayback()
                    self?.restoreBackgroundVolume()
                    self?.logger.logAudioDebug("Riproduzione audio completata")
                }
            })
            
            playerNode.play()
            logger.logAudioDebug("Avviata riproduzione audio PCM: \(frameCount) frames")
            
        } catch {
            logger.logAudioError(error, context: "Riproduzione audio PCM")
            stopCurrentPlayback()
            restoreBackgroundVolume()
        }
    }
    
    private func stopCurrentPlayback() {
        playbackPlayerNode?.stop()
        playbackAudioEngine?.stop()
        playbackAudioEngine = nil
        playbackPlayerNode = nil
    }
    
    // MARK: - Background Handling
    
    func handleAppDidEnterBackground() {
        // Mantieni la sessione audio attiva in background
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            logger.logAudioInfo("Sessione audio mantenuta attiva in background")
        } catch {
            logger.logAudioError(error, context: "Mantenimento sessione audio in background")
        }
    }
    
    func handleAppWillEnterForeground() {
        // Riattiva la sessione audio quando l'app torna in primo piano
        setupAudioSession()
        
        // Riavvia l'audio di sottofondo se era attivo
        if settingsManager.isBackgroundAudioEnabled && !isPlayingBackground {
            startBackgroundAudioIfNeeded()
        }
    }
    
    @objc private func handleAudioInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSession.interruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            logger.logAudioInfo("Interruzione audio iniziata")
            // L'interruzione è iniziata (es. chiamata in arrivo)
            backgroundAudioPlayer?.pause()
            frequencyAudioPlayer?.pause()
            
        case .ended:
            logger.logAudioInfo("Interruzione audio terminata")
            // L'interruzione è terminata
            if let optionsValue = userInfo[AVAudioSession.interruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // Riprendi la riproduzione
                    backgroundAudioPlayer?.play()
                    frequencyAudioPlayer?.play()
                    try? AVAudioSession.sharedInstance().setActive(true)
                }
            }
            
        @unknown default:
            break
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        stopBackgroundAudio()
        NotificationCenter.default.removeObserver(self)
    }
}