//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - EqualizerManager.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import Foundation
import AVFoundation
import Combine

/// Preset selezionabili per l'equalizzatore audio.
/// Le frequenze gestite sono 5 bande: 60Hz, 230Hz, 910Hz, 4kHz, 14kHz.
enum EqualizerPreset: String, CaseIterable, Codable {
    case flat
    case bass
    case vocal
    case rock
    case pop

    /// Nome localizzato.
    var displayName: String {
        switch self {
        case .flat: return "equalizer.preset.flat".localized
        case .bass: return "equalizer.preset.bass".localized
        case .vocal: return "equalizer.preset.vocal".localized
        case .rock: return "equalizer.preset.rock".localized
        case .pop: return "equalizer.preset.pop".localized
        }
    }

    /// Guadagni in dB per le 5 bande: [60Hz, 230Hz, 910Hz, 4kHz, 14kHz].
    var gains: [Float] {
        switch self {
        case .flat: return [0, 0, 0, 0, 0]
        case .bass: return [6, 4, 0, -2, -3]
        case .vocal: return [-2, 0, 4, 5, 2]
        case .rock: return [4, 2, -1, 3, 5]
        case .pop: return [2, 4, 3, 0, 2]
        }
    }

    /// Icona SF Symbol associata.
    var iconName: String {
        switch self {
        case .flat: return "slider.horizontal.3"
        case .bass: return "speaker.wave.3.fill"
        case .vocal: return "mic.fill"
        case .rock: return "guitars.fill"
        case .pop: return "music.note"
        }
    }
}

/// Manager singleton per l'equalizzatore audio.
/// I preset diversi da .flat sono Pro-only.
@MainActor
final class EqualizerManager: ObservableObject {
    static let shared = EqualizerManager()

    // MARK: - Published

    @Published var currentPreset: EqualizerPreset = .flat

    // MARK: - Private

    private let logger = Logger.shared
    private static let storageKey = "selected_eq_preset"

    /// Frequenze centrali delle 5 bande dell'EQ.
    private let bandFrequencies: [Float] = [60, 230, 910, 4000, 14000]

    /// Istanza condivisa di AVAudioUnitEQ applicata alla pipeline audio.
    /// Esposta package-private per consentire l'attach esterno; nil finché non viene
    /// chiamato `attach(to:)`.
    private(set) var audioUnitEQ: AVAudioUnitEQ?

    // MARK: - Init

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey).flatMap(EqualizerPreset.init(rawValue:)) ?? .flat
        // Pro-gate al load: se non Pro forza .flat
        if !isProUser && stored != .flat {
            self.currentPreset = .flat
            UserDefaults.standard.set(EqualizerPreset.flat.rawValue, forKey: Self.storageKey)
        } else {
            self.currentPreset = stored
        }
        logger.logAudioInfo("EqualizerManager inizializzato (preset=\(currentPreset.rawValue), isPro=\(isProUser))")
    }

    // MARK: - Pro check (bridge UserDefaults, no import diretto di IAPManager)

    var isProUser: Bool {
        UserDefaults.standard.bool(forKey: "fastboot_isProUser")
    }

    // MARK: - Public API

    /// Installa l'EQ con 5 bande sull'engine fornito e collega input -> EQ -> mainMixer.
    /// Applica immediatamente il preset corrente.
    /// Va chiamato dopo aver creato l'engine e prima di `start()`.
    func attach(to engine: AVAudioEngine) {
        let eq = AVAudioUnitEQ(numberOfBands: bandFrequencies.count)
        eq.globalGain = 0
        for (index, frequency) in bandFrequencies.enumerated() {
            let band = eq.bands[index]
            band.filterType = .parametric
            band.frequency = frequency
            band.bandwidth = 1.0
            band.bypass = false
            band.gain = 0
        }
        engine.attach(eq)
        self.audioUnitEQ = eq
        applyCurrentPresetToBands()
        logger.logAudioInfo("EQ collegato all'engine (preset=\(currentPreset.rawValue))")
    }

    /// Imposta un preset.
    /// - Returns: false se il preset richiede Pro e l'utente non è Pro.
    @discardableResult
    func setPreset(_ preset: EqualizerPreset) -> Bool {
        if preset != .flat && !isProUser {
            logger.logAudioWarning("Tentativo di impostare preset Pro '\(preset.rawValue)' senza Pro user")
            return false
        }
        currentPreset = preset
        UserDefaults.standard.set(preset.rawValue, forKey: Self.storageKey)
        applyCurrentPresetToBands()
        logger.logAudioInfo("Preset EQ impostato: \(preset.rawValue)")
        return true
    }

    // MARK: - Internals

    private func applyCurrentPresetToBands() {
        guard let eq = audioUnitEQ else { return }
        let gains = currentPreset.gains
        for index in 0..<min(gains.count, eq.bands.count) {
            eq.bands[index].gain = gains[index]
        }
    }
}
