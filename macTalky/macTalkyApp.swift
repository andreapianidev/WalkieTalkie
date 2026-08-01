//creato da Andrea Piani - Immaginet Srl - 01/08/26 - https://www.andreapiani.com - macTalkyApp.swift
//  macTalky
//
//  Walkie-talkie + radio Internet per macOS 26+. Parla con Talky iOS e
//  Talky Android sulla rete locale via protocollo TALKY1 (Bonjour + TCP).

import SwiftUI

@main
struct macTalkyApp: App {
    @StateObject private var engine = WalkieEngine.shared
    @StateObject private var radio = RadioManager.shared
    @StateObject private var iap = IAPManager.shared
    @StateObject private var settings = SettingsManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
                .environmentObject(radio)
                .environmentObject(iap)
                .environmentObject(settings)
                .frame(minWidth: 880, minHeight: 600)
                .preferredColorScheme(.dark)
                .task {
                    await iap.bootstrap()
                    radio.setVolume(settings.radioVolume)
                    engine.refreshMicPermission()
                    if settings.autoStartNetwork {
                        engine.start()
                    }
                }
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
                .preferredColorScheme(.dark)
        }
    }
}
