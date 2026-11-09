//creato da Andrea Piani - 09/11/26 - https://www.andreapiani.com - PresetIntents+App.swift
//  WalkieTalkie
//
//  Cosa fanno sull'iPhone i tasti dei widget radio dichiarati in
//  Shared/WidgetLink/PresetIntents.swift. Girano qui, nel processo dell'app,
//  anche quando il sistema la lancia in background per l'occasione.

import AppIntents

@available(iOS 17.0, *)
extension PlayPresetIntent {
    @MainActor
    func perform() async throws -> some IntentResult {
        let radio = RadioManager.shared
        // Il catalogo intero e non le sole stazioni attive: se una preferita
        // e' a riposo dopo un errore, chi la tocca dal widget vuole riprovarla.
        if let station = radio.catalog.first(where: { $0.id == stationID }) {
            radio.playFromWidget(station)
        }
        return .result()
    }
}

@available(iOS 17.0, *)
extension StopRadioIntent {
    @MainActor
    func perform() async throws -> some IntentResult {
        RadioManager.shared.stopRadio()
        return .result()
    }
}

@available(iOS 17.0, *)
extension PlayFavoriteRadioIntent {
    @MainActor
    func perform() async throws -> some IntentResult {
        guard UserDefaults.standard.bool(forKey: "fastboot_isProUser") else {
            // Prima di iOS 26 un controllo non puo' portare avanti l'app:
            // il controllo mostra gia' il lucchetto, e il tocco non fa niente.
            if #available(iOS 26.0, *) {
                try await continueInForeground(alwaysConfirm: false)
                if let pro = URL(string: "talky://pro") { LiveActivityDeepLink.handle(pro) }
            }
            return .result()
        }
        let radio = RadioManager.shared
        radio.playFromWidget(radio.presetStations.first ?? radio.resumeStation)
        return .result()
    }
}
