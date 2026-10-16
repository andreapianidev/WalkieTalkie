//creato da Andrea Piani - 12/07/25 - https://www.andreapiani.com - AudioManager.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 12/07/25.
//

import Foundation
import AVFoundation
import Combine
import os.log

/// Gestisce la sessione audio, i permessi e la riproduzione della voce ricevuta.
/// Niente audio finto: quello che si sente arriva da un telefono vicino, da un
/// ricevitore HF o da un canale POC veri.
class AudioManager: ObservableObject {
    static let shared = AudioManager()
    
    private var playbackAudioEngine: AVAudioEngine?
    private var playbackPlayerNode: AVAudioPlayerNode?
    private let logger = Logger.shared
    
    @Published var hasAudioPermission = false
    
    private init() {
        setupAudioSession()
        checkAudioPermission()
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, 
                                       mode: .default, 
                                       options: [.defaultToSpeaker, .allowBluetooth])
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
            }
        }
    }
    
    private func checkAudioPermission() {
        let status = AVAudioSession.sharedInstance().recordPermission
        hasAudioPermission = status == .granted
    }
    
    func playReceivedAudio(_ data: Data) {
        // Il chiamante (MultipeerManager) invoca questo metodo da una coda globale
        // di background. Le mutazioni dei player (playbackAudioEngine,
        // playbackPlayerNode) devono avvenire sullo stesso thread: si serializza
        // sul main, la copia del breve buffer PCM PTT costa poco.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.logger.logAudioDebug("Riproduzione audio ricevuto: \(data.count) bytes")

            // Usa AVAudioEngine per riprodurre i dati PCM raw
            self.playPCMAudio(data)
        }
    }
    
    private func playPCMAudio(_ data: Data) {
        // Ferma riproduzione precedente se in corso
        stopCurrentPlayback()
        
        playbackAudioEngine = AVAudioEngine()
        playbackPlayerNode = AVAudioPlayerNode()
        
        guard let audioEngine = playbackAudioEngine,
              let playerNode = playbackPlayerNode else {
            logger.logAudioError(NSError(domain: "AudioManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "Impossibile creare componenti audio"]), context: "Inizializzazione playback")
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
                return
            }
            
            // Crea buffer audio dai dati ricevuti
            let frameCount = AVAudioFrameCount(data.count / MemoryLayout<Float32>.size)
            guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                logger.logAudioError(NSError(domain: "AudioManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Impossibile creare buffer audio"]), context: "Creazione buffer per riproduzione")
                return
            }
            
            audioBuffer.frameLength = frameCount
            
            // Copia i dati nel buffer
            data.withUnsafeBytes { bytes in
                guard let floatPointer = bytes.bindMemory(to: Float32.self).baseAddress else { return }
                guard let channelData = audioBuffer.floatChannelData?[0] else { return }
                channelData.assign(from: floatPointer, count: Int(frameCount))
            }
            
            // Configura audio engine — inserisce l'Equalizer Pro in catena se presente.
            audioEngine.attach(playerNode)
            EqualizerManager.shared.attach(to: audioEngine)
            if let eq = EqualizerManager.shared.audioUnitEQ {
                audioEngine.connect(playerNode, to: eq, format: format)
                audioEngine.connect(eq, to: audioEngine.mainMixerNode, format: format)
            } else {
                audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
            }

            try audioEngine.start()
            
            // Riproduci il buffer
            playerNode.scheduleBuffer(audioBuffer, completionHandler: { [weak self] in
                DispatchQueue.main.async {
                    self?.stopCurrentPlayback()
                    self?.logger.logAudioDebug("Riproduzione audio completata")
                }
            })
            
            playerNode.play()
            logger.logAudioDebug("Avviata riproduzione audio PCM: \(frameCount) frames")
            
        } catch {
            logger.logAudioError(error, context: "Riproduzione audio PCM")
            stopCurrentPlayback()
        }
    }
    
    private func stopCurrentPlayback() {
        playbackPlayerNode?.stop()
        playbackAudioEngine?.stop()
        playbackAudioEngine = nil
        playbackPlayerNode = nil
    }

}