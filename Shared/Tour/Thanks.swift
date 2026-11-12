//creato da Andrea Piani - 12/11/26 - https://www.andreapiani.com - Thanks.swift
//  Talky
//
//  Chi ha reso Talky migliore, accanto a "Scrivimi" su iPhone e Mac: stessa
//  lista del README. Chi segnala un problema o chiede una funzione che poi
//  arriva entra qui.

import Foundation

nonisolated struct Thanks: Identifiable {
    /// Il nome come lo si scrive ovunque: non si traduce.
    let who: String
    let key: String
    let link: URL?

    var id: String { key }
    var why: String { Self.text(key) }

    static var title: String { text("thanks.title") }
    static var intro: String { text("thanks.intro") }

    static let all: [Thanks] = [
        Thanks(who: "@pilot51", key: "thanks.pilot51",
               link: URL(string: "https://github.com/andreapianidev/WalkieTalkie/issues/12")),
        Thanks(who: "@yao89", key: "thanks.yao89",
               link: URL(string: "https://github.com/andreapianidev/WalkieTalkie/issues/11")),
        Thanks(who: "@Joaov41", key: "thanks.joaov41",
               link: URL(string: "https://github.com/andreapianidev/WalkieTalkie/pull/1")),
        Thanks(who: "John Seamons · KiwiSDR", key: "thanks.kiwi", link: URL(string: "http://kiwisdr.com")),
        Thanks(who: "Pierre Ynard · rx.linkfanel.net", key: "thanks.ynard", link: URL(string: "http://rx.linkfanel.net")),
        Thanks(who: "Mumble", key: "thanks.mumble", link: URL(string: "https://www.mumble.info")),
        Thanks(who: "NOAA SWPC", key: "thanks.noaa", link: URL(string: "https://www.swpc.noaa.gov")),
        Thanks(who: text("thanks.you.title"), key: "thanks.you",
               link: URL(string: "https://github.com/andreapianidev/WalkieTalkie/issues")),
    ]

    private static func text(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: "Tour")
    }
}
