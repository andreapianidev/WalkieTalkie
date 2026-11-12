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
    
    // Riproduzione della voce ricevuta, tutta sul main. Un engine e un player
    // che restano vivi e una coda di buffer, come sul Mac: prima ogni messaggio
    // fermava quello in corso, e la completion del vecchio buffer (che scatta
    // anche su stop) spegneva subito anche il nuovo. Con il ponte i messaggi
    // ritrasmessi arrivano in ritardo e si sovrappongono spesso alla risposta.
    private var playbackAudioEngine: AVAudioEngine?
    private var playbackPlayerNode: AVAudioPlayerNode?
    private var playbackSampleRate: Double = 0
    private var framesInCoda = 0
    private var avvioRitardato: DispatchWorkItem?
    private var spegnimento: DispatchWorkItem?

    private enum Coda {
        /// Un messaggio solo non suona piu' di cosi'.
        static let massimoMessaggio: Double = 30
        /// Audio in attesa oltre il quale quello nuovo si scarta: meglio perdere
        /// un messaggio che sentire una conversazione con un minuto di ritardo.
        static let massimoInAttesa: Double = 60
        /// Pochi frame da Android vanno in underrun se partono subito.
        static let preroll: Double = 0.15
        static let attesaPreroll: Double = 0.12
        /// Senza niente in coda per questo tempo l'engine si spegne.
        static let spegniDopo: Double = 3
    }
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
                                       options: [.defaultToSpeaker, .allowBluetoothHFP])
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
        let sampleRate = AVAudioSession.sharedInstance().sampleRate
        guard sampleRate > 0, let player = preparaRiproduzione(sampleRate: sampleRate),
              let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate,
                                         channels: 1, interleaved: false) else {
            logger.logAudioError(NSError(domain: "AudioManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Riproduzione non disponibile"]), context: "Configurazione riproduzione")
            return
        }

        let spazio = Int(sampleRate * Coda.massimoInAttesa) - framesInCoda
        let frameCount = min(data.count / MemoryLayout<Float32>.size, Int(sampleRate * Coda.massimoMessaggio), spazio)
        guard frameCount > 0 else {
            logger.logAudioWarning("Coda di riproduzione piena: messaggio da \(data.count) bytes scartato")
            return
        }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            logger.logAudioError(NSError(domain: "AudioManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Impossibile creare buffer audio"]), context: "Creazione buffer per riproduzione")
            return
        }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        data.withUnsafeBytes { bytes in
            guard let src = bytes.bindMemory(to: Float32.self).baseAddress,
                  let dst = buffer.floatChannelData?[0] else { return }
            dst.update(from: src, count: frameCount)
        }

        spegnimento?.cancel()
        framesInCoda += frameCount
        player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            DispatchQueue.main.async {
                // Un player gia' sostituito (cambio di frequenza) non conta piu'.
                guard let self, self.playbackPlayerNode === player else { return }
                self.framesInCoda = max(0, self.framesInCoda - frameCount)
                if self.framesInCoda == 0 { self.programmaSpegnimento() }
            }
        }
        logger.logAudioDebug("In coda \(frameCount) frames, in attesa \(framesInCoda)")

        guard !player.isPlaying else { return }
        if Double(framesInCoda) / sampleRate >= Coda.preroll {
            avvioRitardato?.cancel()
            player.play()
        } else if avvioRitardato == nil {
            let avvio = DispatchWorkItem { [weak self] in
                self?.avvioRitardato = nil
                if self?.playbackPlayerNode === player, !player.isPlaying { player.play() }
            }
            avvioRitardato = avvio
            DispatchQueue.main.asyncAfter(deadline: .now() + Coda.attesaPreroll, execute: avvio)
        }
    }

    /// Engine e player da riusare; si rifanno solo se la frequenza della
    /// sessione e' cambiata (cuffie Bluetooth) o se il sistema li ha fermati.
    private func preparaRiproduzione(sampleRate: Double) -> AVAudioPlayerNode? {
        if let engine = playbackAudioEngine, let player = playbackPlayerNode,
           engine.isRunning, playbackSampleRate == sampleRate {
            return player
        }
        stopCurrentPlayback()

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate,
                                         channels: 1, interleaved: false) else { return nil }
        engine.attach(player)
        // Inserisce l'Equalizer Pro in catena se presente.
        EqualizerManager.shared.attach(to: engine)
        if let eq = EqualizerManager.shared.audioUnitEQ {
            engine.connect(player, to: eq, format: format)
            engine.connect(eq, to: engine.mainMixerNode, format: format)
        } else {
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
        do {
            try engine.start()
        } catch {
            logger.logAudioError(error, context: "Avvio engine di riproduzione")
            return nil
        }
        playbackAudioEngine = engine
        playbackPlayerNode = player
        playbackSampleRate = sampleRate
        return player
    }

    private func programmaSpegnimento() {
        spegnimento?.cancel()
        let lavoro = DispatchWorkItem { [weak self] in
            guard let self, self.framesInCoda == 0 else { return }
            self.stopCurrentPlayback()
            self.logger.logAudioDebug("Riproduzione audio completata")
        }
        spegnimento = lavoro
        DispatchQueue.main.asyncAfter(deadline: .now() + Coda.spegniDopo, execute: lavoro)
    }

    private func stopCurrentPlayback() {
        avvioRitardato?.cancel()
        avvioRitardato = nil
        spegnimento?.cancel()
        spegnimento = nil
        // Prima si stacca il player, poi lo si ferma: le completion che scattano
        // con lo stop vedono che non e' piu' quello corrente e non toccano niente.
        let player = playbackPlayerNode
        let engine = playbackAudioEngine
        playbackPlayerNode = nil
        playbackAudioEngine = nil
        playbackSampleRate = 0
        framesInCoda = 0
        player?.stop()
        engine?.stop()
    }

}