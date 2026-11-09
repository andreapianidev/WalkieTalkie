//creato da Andrea Piani - 09/11/26 - https://www.andreapiani.com - PresetIntents+App.swift
//  macTalky
//
//  Cosa fanno sul Mac i tasti dei widget radio dichiarati in
//  Shared/WidgetLink/PresetIntents.swift. Girano nell'app, che il sistema
//  apre se non e' gia' aperta.

import AppIntents
import AppKit

extension PlayPresetIntent {
    @MainActor
    func perform() async throws -> some IntentResult {
        let radio = RadioManager.shared
        // Il catalogo intero e non le sole stazioni attive: se una preferita
        // e' a riposo dopo un errore, chi la tocca dal widget vuole riprovarla.
        if let station = radio.catalog.first(where: { $0.id == stationID }) {
            radio.playStation(station)
        }
        return .result()
    }
}

extension StopRadioIntent {
    @MainActor
    func perform() async throws -> some IntentResult {
        RadioManager.shared.stopRadio()
        return .result()
    }
}

extension PlayFavoriteRadioIntent {
    @MainActor
    func perform() async throws -> some IntentResult {
        guard UserDefaults.standard.bool(forKey: "fastboot_isProUser") else {
            // Senza Pro si porta avanti la console e si apre la paywall,
            // che ContentView mostra per ogni talky:// che non riconosce.
            try await continueInForeground(alwaysConfirm: false)
            if let pro = URL(string: "talky://pro") { NSWorkspace.shared.open(pro) }
            return .result()
        }
        let radio = RadioManager.shared
        radio.playStation(radio.presetStations.first ?? radio.resumeStation)
        return .result()
    }
}
