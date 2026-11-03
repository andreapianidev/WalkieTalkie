//creato da Andrea Piani - 03/11/26 - https://www.andreapiani.com - ProPerks.swift
//  Talky (iOS e Mac)
//
//  Cosa da' Talky Pro, in un posto solo: la paywall, la pagina dell'onboarding
//  e la schermata "il tuo Talky Pro" leggono questa lista, cosi' quello che si
//  promette prima dell'acquisto e quello che si ritrova dopo non divergono.
//  I testi stanno nella tabella Tour (Shared/Tour/<lingua>.lproj/Tour.strings).

import Foundation

enum ProPerk: String, CaseIterable, Identifiable {
    case live, widgets, noAds, stations, privateChannels, recordings, history, themes, sleepTimer, equalizer, everyDevice

    var id: String { rawValue }

    /// Le funzioni che esistono su questa piattaforma: sul Mac niente
    /// pubblicita', registrazioni, cronologia, sleep timer ed equalizzatore.
    static var here: [ProPerk] {
        #if os(macOS)
        [.live, .widgets, .stations, .privateChannels, .themes, .everyDevice]
        #else
        allCases
        #endif
    }

    var symbol: String {
        switch self {
        case .live: "dot.radiowaves.left.and.right"
        case .widgets: "square.grid.2x2.fill"
        case .noAds: "xmark.circle.fill"
        case .stations: "globe"
        case .privateChannels: "lock.shield.fill"
        case .recordings: "mic.circle.fill"
        case .history: "clock.arrow.circlepath"
        case .themes: "paintpalette.fill"
        case .sleepTimer: "moon.zzz.fill"
        case .equalizer: "slider.horizontal.3"
        case .everyDevice: "laptopcomputer.and.iphone"
        }
    }

    private var key: String {
        switch self {
        case .noAds: "noads"
        case .privateChannels: "private"
        case .sleepTimer: "sleep"
        case .equalizer: "eq"
        case .everyDevice: "devices"
        default: rawValue
        }
    }

    func title(stations: Int) -> String {
        let text = Tour.text("tour.perk.\(key).title")
        return self == .stations ? String(format: text, stations) : text
    }

    /// Cosa fa e, dove serve, come ci si arriva.
    var detail: String {
        #if os(macOS)
        if self == .widgets { return Tour.text("tour.perk.widgets.detail.mac") }
        #endif
        return Tour.text("tour.perk.\(key).detail")
    }

    /// Dove si trova, per la schermata "il tuo Talky Pro". Nil dove non serve
    /// dirlo (la radio e le bande sono gia' sul quadrante) o dove sul Mac la
    /// funzione vive solo nell'app per iPhone.
    var location: String? {
        switch self {
        case .widgets:
            #if os(macOS)
            return Tour.text("tour.perk.widgets.where.mac")
            #else
            return Tour.text("tour.perk.widgets.where")
            #endif
        case .privateChannels, .recordings, .history, .themes, .sleepTimer, .equalizer:
            #if os(macOS)
            return nil
            #else
            return Tour.text("tour.where.settings")
            #endif
        default:
            return nil
        }
    }
}

enum Tour {
    static func text(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: "Tour")
    }
}
