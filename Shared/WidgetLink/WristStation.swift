//creato da Andrea Piani - 12/11/26 - https://www.andreapiani.com - WristStation.swift
//  Talky
//
//  Quello che l'iPhone manda all'Apple Watch con WatchConnectivity, e con
//  quali chiavi. Le stazioni le sa solo l'iPhone (RadioManager): il Watch le
//  riceve, se le tiene e le suona da solo.

import Foundation

/// Una stazione come la suona il Watch: a differenza di PresetCard qui c'e'
/// lo stream, perche' sul polso suona davvero.
nonisolated struct WristStation: Codable, Hashable, Identifiable, Sendable {
    let id: Int
    let name: String
    let flag: String
    /// Il paese nella lingua dell'iPhone.
    let place: String
    /// Frequenza FM o genere, come sul display della radio.
    let dial: String
    let url: String
    let isPro: Bool
}

nonisolated enum WristKey {
    /// [WristStation] in JSON.
    static let catalog = "catalog"
    /// [Int]: id delle preferite, nell'ordine dell'iPhone.
    static let favorites = "favorites"
    static let pro = "pro"
    /// Quanti dispositivi sono collegati al walkie dell'iPhone.
    static let peers = "peers"
    static let channel = "channel"
    /// Messaggio dal Watch: true quando si preme il tasto, false quando si lascia.
    static let ptt = "ptt"
}
