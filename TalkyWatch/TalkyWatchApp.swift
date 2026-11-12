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

    var body: some Scene {
        WindowGroup {
            TabView {
                RadioPage()
                WalkiePage()
                BandsPage()
            }
            .tabViewStyle(.verticalPage)
            .tint(TalkyDial.amber)
            .environmentObject(phone)
            .environmentObject(radio)
            .task { phone.start() }
        }
    }
}

extension String {
    /// I testi del Watch stanno nella tabella Watch: Localizable e' gia'
    /// quella dei widget, che il Watch usa per aperta, debole e chiusa.
    var wrist: String { NSLocalizedString(self, tableName: "Watch", comment: "") }
}
