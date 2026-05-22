//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - ThemeSoundManager.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import Foundation
import AudioToolbox
import Combine

/// Eventi che possono trigger-are un suono tematico.
enum ThemeSoundEvent {
    case pttPress        // utente preme il PTT
    case channelChange   // utente cambia frequenza/canale
    case transmitStart   // inizio trasmissione walkie
    case receptionStart  // qualcuno trasmette verso di noi
}

/// Manager che riproduce suoni tematici associati al tema corrente.
/// V1.1: usa system sounds (AudioToolbox) come placeholder.
/// V1.2: caricamento da .mp3 nel bundle quando l'utente fornisce gli asset.
@MainActor
final class ThemeSoundManager: ObservableObject {
    static let shared = ThemeSoundManager()

    private let logger = Logger.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Reagisce al cambio tema per eventuale precaricamento futuro.
        ThemeManager.shared.$currentTheme
            .sink { [weak self] theme in
                self?.logger.logInfo("ThemeSoundManager: tema cambiato a \(theme.rawValue), packID=\(ThemeRegistry.metadata(for: theme).soundPackID ?? "nil")")
            }
            .store(in: &cancellables)
    }

    /// Trigger principale: chiamato dal resto dell'app per riprodurre il suono tematico
    /// appropriato all'evento. Se il tema corrente non ha sound pack, no-op.
    func play(_ event: ThemeSoundEvent) {
        let packID = ThemeRegistry.metadata(for: ThemeManager.shared.currentTheme).soundPackID
        guard let packID else { return }

        let systemSoundID = systemSound(for: packID, event: event)
        guard let systemSoundID else { return }
        AudioServicesPlaySystemSound(systemSoundID)
        logger.logAudioDebug("ThemeSound: \(packID) / \(event) → systemSound \(systemSoundID)")
    }

    /// Mapping placeholder pack → systemSoundID per evento.
    /// I codici system sound iOS sono pubblicamente documentati (es. 1057 = SMS sent).
    /// Sostituire con AVAudioPlayer + MP3 quando arriveranno gli asset.
    private func systemSound(for packID: String, event: ThemeSoundEvent) -> SystemSoundID? {
        switch (packID, event) {
        case ("morse", .pttPress):           return 1057   // tink
        case ("morse", .transmitStart):      return 1106   // beep
        case ("sonar", .channelChange):      return 1112   // sonar-like
        case ("sonar", .receptionStart):     return 1106
        case ("radio", .channelChange):      return 1104   // click
        case ("radio", .pttPress):           return 1306
        case ("glitch", .transmitStart):     return 1110   // glitch-y
        case ("glitch", .pttPress):          return 1521   // crispy
        case ("synth", .channelChange):      return 1003   // notification
        case ("synth", .pttPress):           return 1057
        default:                              return nil
        }
    }
}
