//creato da Andrea Piani - Immaginet Srl - 01/08/26 - https://www.andreapiani.com - macTalkyApp.swift
//  macTalky
//
//  Walkie-talkie + radio Internet per macOS 26+. Parla con Talky iOS e
//  Talky Android sulla rete locale via protocollo TALKY1 (Bonjour + TCP).

import SwiftUI
import AppKit

/// Bootstrap di lancio: StoreKit, volume radio, permesso microfono, link di rete
/// e auto-ripresa radio. Deve girare UNA volta per esecuzione dell'app — legarlo
/// al `.task` della WindowGroup lo faceva ripartire a ogni riapertura della
/// finestra, interrompendo lo stream radio in corso.
@MainActor
final class AppBootstrap {
    static let shared = AppBootstrap()
    private var didRun = false

    private init() {}

    func runOnce() async {
        guard !didRun else { return }
        didRun = true

        let settings = SettingsManager.shared
        let radio = RadioManager.shared
        let engine = WalkieEngine.shared

        await IAPManager.shared.bootstrap()
        radio.setVolume(settings.radioVolume)
        engine.refreshMicPermission()
        if settings.autoStartNetwork {
            engine.start()
        }
        // Auto-ripresa radio (impostazione utente) oppure launch argument
        // `-mac_autoplay_radio YES` (screenshot/demo).
        if settings.autoResumeRadio || UserDefaults.standard.bool(forKey: "mac_autoplay_radio") {
            radio.playStation(radio.resumeStation)
        }
        // Launch argument `-mac_window_rect "x,y,w,h"` (punti, origine
        // bottom-left): posiziona la finestra a un frame esatto per gli
        // screenshot automatizzati.
        if let rect = UserDefaults.standard.string(forKey: "mac_window_rect") {
            let p = rect.split(separator: ",").compactMap { Double($0) }
            if p.count == 4, let window = NSApp.windows.first(where: { $0.isVisible }) {
                window.setFrame(NSRect(x: p[0], y: p[1], width: p[2], height: p[3]), display: true)
            }
        }
    }
}

@main
struct macTalkyApp: App {
    @StateObject private var engine = WalkieEngine.shared
    @StateObject private var radio = RadioManager.shared
    @StateObject private var iap = IAPManager.shared
    @StateObject private var settings = SettingsManager.shared

    /// Stessa chiave usata da SettingsManager.showMenuBarExtra: @AppStorage è
    /// il pattern supportato per `MenuBarExtra(isInserted:)` (un binding a
    /// @StateObject qui non materializza la status item su macOS 26+).
    @AppStorage("mac_show_menubar_extra") private var menuBarInserted = true

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(engine)
                .environmentObject(radio)
                .environmentObject(iap)
                .environmentObject(settings)
                .frame(minWidth: 880, minHeight: 600)
                .preferredColorScheme(.dark)
                // `.task` rigira a ogni ricostruzione della finestra: il
                // bootstrap vero è idempotente e vive in AppBootstrap, così
                // chiudere e riaprire la console non riavvia la radio né
                // ripete il bootstrap StoreKit.
                .task { await AppBootstrap.shared.runOnce() }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Radio") {
                Button(radio.isPlaying ? "Pause" : "Play") {
                    if radio.isPlaying {
                        radio.pauseRadio()
                    } else if radio.currentStation != nil {
                        radio.resumeRadio()
                    } else {
                        radio.playStation(radio.resumeStation)
                    }
                }
                .keyboardShortcut("p", modifiers: [.command])
                Button("Next Station") { radio.nextStation() }
                    .keyboardShortcut(.rightArrow, modifiers: [.command])
                Button("Previous Station") { radio.previousStation() }
                    .keyboardShortcut(.leftArrow, modifiers: [.command])
                Divider()
                Button("Stop") { radio.stopRadio() }
                    .keyboardShortcut(".", modifiers: [.command])
            }
        }

        Settings {
            SettingsPane()
                .environmentObject(engine)
                .environmentObject(iap)
                .environmentObject(settings)
                .environmentObject(radio)
                .preferredColorScheme(.dark)
        }

        // Mini-console nella menu bar: PTT, stato peer e controlli radio
        // sempre a portata di clic, anche a finestra chiusa.
        MenuBarExtra(isInserted: $menuBarInserted) {
            MenuBarPanel()
                .environmentObject(engine)
                .environmentObject(radio)
                .environmentObject(settings)
                .preferredColorScheme(.dark)
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)
    }
}
