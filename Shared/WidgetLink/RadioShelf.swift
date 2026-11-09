//creato da Andrea Piani - 09/11/26 - https://www.andreapiani.com - RadioShelf.swift
//  Talky
//
//  Quello che l'app lascia ai widget: le stazioni preferite, cosa e' in onda
//  e il canale del walkie. App ed estensione hanno contenitori separati, e
//  l'unico posto che leggono tutte e due e' l'App Group. Finche' il gruppo
//  non e' nei profili di firma l'app scrive nelle sue preferenze e i widget
//  restano vuoti: vuoti, non sbagliati.

import Foundation
import WidgetKit

/// Una stazione come la disegna un widget. Niente URL dello stream: quello
/// serve solo all'app, che e' l'unica a suonare.
nonisolated struct PresetCard: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
    let flag: String
    /// Frequenza FM o genere, come sul display della radio.
    let dial: String
    let isPro: Bool
    /// Fine del pass di 24 ore guadagnato con un video, se c'e'.
    let passUntil: Date?

    /// Il widget sa da StoreKit se c'e' Talky Pro; il pass lo sa solo l'app,
    /// per questo viaggia con la stazione.
    func locked(hasPro: Bool, at date: Date) -> Bool {
        isPro && !hasPro && (passUntil ?? .distantPast) <= date
    }
}

/// La stazione in onda, oppure l'ultima ascoltata quando la radio e' spenta.
nonisolated struct OnAirCard: Codable, Hashable {
    let station: PresetCard
    /// Il titolo che lo stream manda (ICY o ID3). Nil se la stazione non lo trasmette.
    let title: String?
    let playing: Bool
}

nonisolated enum RadioShelf {
    /// Da registrare sull'App ID e da mettere negli entitlement di app ed estensioni.
    static let group = "group.com.Andrea-Piani.WalkieTalkie"

    static let presetsKind = "TalkyPresets"
    static let onAirKind = "TalkyOnAir"
    static let walkieControlKind = "com.Andrea-Piani.WalkieTalkie.walkie"
    static let favoriteControlKind = "com.Andrea-Piani.WalkieTalkie.favorite-radio"

    private static let presetsKey = "shelf_presets"
    private static let recentsKey = "shelf_presets_are_recents"
    private static let onAirKey = "shelf_on_air"
    private static let channelKey = "shelf_walkie_channel"
    private static let proKey = "shelf_pro"

    private static var store: UserDefaults { UserDefaults(suiteName: group) ?? .standard }

    // MARK: lettura, dai widget

    /// Le preferite in ordine d'ascolto, al massimo otto. Se non ce ne sono,
    /// le ultime ascoltate (vedi `presetsAreRecents`).
    static var presets: [PresetCard] {
        decode([PresetCard].self, presetsKey) ?? []
    }

    static var presetsAreRecents: Bool { store.bool(forKey: recentsKey) }

    static var onAir: OnAirCard? { decode(OnAirCard.self, onAirKey) }

    /// Nome del canale privato del walkie; nil quando si e' sul canale pubblico.
    static var walkieChannel: String? { store.string(forKey: channelKey) }

    /// Talky Pro come lo vede l'app (in Debug anche la scelta Free/Pro
    /// dell'avvio). Nil finche' l'app non l'ha mai scritto.
    static var appSaysPro: Bool? { store.object(forKey: proKey) as? Bool }

    // MARK: scrittura, dall'app

    static func savePresets(_ cards: [PresetCard], recents: Bool) {
        let recentsChanged = store.bool(forKey: recentsKey) != recents
        if recentsChanged { store.set(recents, forKey: recentsKey) }
        if write(cards, presetsKey) || recentsChanged {
            WidgetCenter.shared.reloadTimelines(ofKind: presetsKind)
            reloadControl(favoriteControlKind)
        }
    }

    static func saveOnAir(_ card: OnAirCard?) {
        let before = onAir
        guard write(card, onAirKey) else { return }
        WidgetCenter.shared.reloadTimelines(ofKind: onAirKind)
        // "Le mie radio" del brano in onda non mostra niente: cambia solo se
        // cambia la stazione che suona, non a ogni titolo nuovo.
        if before?.station.id != card?.station.id || before?.playing != card?.playing {
            WidgetCenter.shared.reloadTimelines(ofKind: presetsKind)
        }
    }

    /// Comprato, scaduto o (in Debug) scelto all'avvio: lucchetti e griglie
    /// cambiano in tutti i widget, quindi si ricaricano tutti. Succede di rado.
    static func savePro(_ pro: Bool) {
        guard appSaysPro != pro else { return }
        store.set(pro, forKey: proKey)
        reloadEverything()
    }

    /// Per quando il widget mostra uno stato che l'app ha appena smentito
    /// (un play su una stazione che per l'app e' chiusa).
    static func reloadEverything() {
        WidgetCenter.shared.reloadAllTimelines()
        reloadControl(favoriteControlKind)
    }

    static func saveWalkieChannel(_ name: String?) {
        guard store.string(forKey: channelKey) != name else { return }
        store.set(name, forKey: channelKey)
        reloadControl(walkieControlKind)
    }

    // MARK: -

    /// Scrive solo se il dato e' cambiato: ogni scrittura costa un ricaricamento
    /// dei widget, e WidgetKit ne concede un numero limitato.
    private static func write<T: Encodable>(_ value: T?, _ key: String) -> Bool {
        let data = value.flatMap { try? JSONEncoder().encode($0) }
        guard store.data(forKey: key) != data else { return false }
        store.set(data, forKey: key)
        return true
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        store.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    private static func reloadControl(_ kind: String) {
        if #available(iOS 18.0, macOS 26.0, *) {
            ControlCenter.shared.reloadControls(ofKind: kind)
        }
    }
}
