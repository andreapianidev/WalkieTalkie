//creato da Andrea Piani - 12/11/26 - https://www.andreapiani.com - TalkyWatchApp.swift
//  TalkyWatch
//
//  Talky sull'Apple Watch, chiesto da yao89 nella issue #11. Tre pagine:
//  la radio del mondo che suona sul polso, il PTT del walkie dell'iPhone e
//  le condizioni delle bande. Il walkie senza internet resta sull'iPhone:
//  su watchOS non ci sono Multipeer ne' Bonjour.

import SwiftUI

@main
struct TalkyWatchApp: App {
    @StateObject private var phone = PhoneLink.shared
    @StateObject private var radio = WristRadio()
    @State private var page = Self.firstPage

    var body: some Scene {
        WindowGroup {
            TabView(selection: $page) {
                RadioPage().tag(0)
                WalkiePage().tag(1)
                BandsPage().tag(2)
            }
            .tabViewStyle(.verticalPage)
            .tint(TalkyDial.amber)
            .environmentObject(phone)
            .environmentObject(radio)
            .task {
                phone.start()
                #if DEBUG
                if let station = phone.stations.first(where: { $0.id == ShotMode.play }) { await radio.play(station) }
                if ShotMode.probe { await ShotMode.runProbe(phone) }
                #endif
            }
        }
    }
}

extension TalkyWatchApp {
    private static var firstPage: Int {
        #if DEBUG
        if ShotMode.on { return ShotMode.page }
        #endif
        return 0
    }
}

extension String {
    /// I testi del Watch stanno nella tabella Watch: Localizable e' gia'
    /// quella dei widget, che il Watch usa per aperta, debole e chiusa.
    var wrist: String { NSLocalizedString(self, tableName: "Watch", comment: "") }
}
