//creato da Andrea Piani - Immaginet Srl - 02/08/26 - https://www.andreapiani.com - SettingsPane.swift
//  macTalky
//
//  Scena Settings (⌘,) replicata dalla SettingsView iOS, adattata al Mac:
//  Generali / Walkie / Radio / Aspetto / Pro / Info. Le voci iOS senza senso
//  su desktop (haptics, Live Activities, low power) non sono replicate.

import SwiftUI
import StoreKit

struct SettingsPane: View {
    @EnvironmentObject private var engine: WalkieEngine
    @EnvironmentObject private var iap: IAPManager
    @EnvironmentObject private var settings: SettingsManager
    @EnvironmentObject private var radio: RadioManager

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            walkieTab
                .tabItem { Label("Walkie", systemImage: "dot.radiowaves.left.and.right") }
            radioTab
                .tabItem { Label("Radio", systemImage: "antenna.radiowaves.left.and.right") }
            appearanceTab
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
            proTab
                .tabItem { Label("Talky Pro", systemImage: "crown") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 460)
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section("Identity") {
                TextField("Device name on the network", text: $settings.deviceName)
                Text("Other Talky devices (iPhone, Android, Mac) see this name. Applied after restarting the link.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Startup") {
                Toggle("Start network link at launch", isOn: $settings.autoStartNetwork)
                Toggle("Resume last radio station at launch", isOn: $settings.autoResumeRadio)
            }
            Section {
                Button("Reset all settings to defaults") {
                    settings.resetToDefaults()
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Walkie

    private var walkieTab: some View {
        Form {
            Section("Push-to-talk") {
                Toggle("Hold Space bar to talk", isOn: $settings.spacebarPTT)
                LabeledContent("Max transmission") { Text("10 seconds") }
                Text("One transmission is sent as a single TALKY1 frame — the 10 s cap keeps it compatible with Talky iOS and Android receivers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Microphone") {
                LabeledContent("Permission") {
                    if engine.hasMicPermission {
                        Label("Authorized", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Request access") { engine.requestMicPermission() }
                    }
                }
            }
            Section("Network link") {
                LabeledContent("Status") { Text(engine.status) }
                LabeledContent("Connected peers") { Text("\(engine.connectedPeerCount)") }
                HStack {
                    Button(engine.isNetworkActive ? "Stop link" : "Start link") {
                        engine.isNetworkActive ? engine.stop() : engine.start()
                    }
                    Button("Restart link") { engine.channelDidChange() }
                }
                Text("Talky devices discover each other over Bonjour on the local network — no internet, no accounts (TALKY1 protocol).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Radio

    private var radioTab: some View {
        Form {
            Section("Playback") {
                LabeledContent("Volume") {
                    Slider(
                        value: Binding(
                            get: { Double(settings.radioVolume) },
                            set: { settings.radioVolume = Float($0) }
                        ),
                        in: 0...1
                    )
                    .frame(width: 180)
                }
                Toggle("Resume last station at launch", isOn: $settings.autoResumeRadio)
            }
            Section("Stations") {
                LabeledContent("Catalog") { Text("\(radio.radioStations.count) stations · \(radio.freeStations.count) free") }
                LabeledContent("Favorites") { Text("\(radio.favoriteStations.count)") }
                Text("While a peer talks on the walkie, the radio automatically ducks to 20% and comes back after the message.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Appearance

    private var appearanceTab: some View {
        Form {
            Section("Console backdrop") {
                ForEach(ConsoleBackdrop.allCases) { item in
                    backdropRow(item)
                }
                Text("Premium backdrops unlock with Talky Pro or the Themes Pack — the same purchases as the iOS app (universal purchase).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func backdropRow(_ item: ConsoleBackdrop) -> some View {
        let selected = settings.backdropRaw == item.rawValue
        let locked = item.isPro && !(iap.isProUser || iap.hasThemesPack)

        return Button {
            guard !locked else { return }
            settings.backdropRaw = item.rawValue
        } label: {
            HStack {
                Circle()
                    .fill(item.swatch)
                    .frame(width: 14, height: 14)
                Text(item.title)
                Spacer()
                if locked {
                    Image(systemName: "lock.fill").foregroundStyle(.secondary)
                } else if selected {
                    Image(systemName: "checkmark").foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(locked)
    }

    // MARK: - Pro

    private var proTab: some View {
        Form {
            Section("Status") {
                LabeledContent("Talky Pro") {
                    Text(iap.isProUser ? "Active" : "Not active")
                        .foregroundStyle(iap.isProUser ? .green : .secondary)
                }
                LabeledContent("Themes Pack") {
                    Text(iap.hasThemesPack ? "Purchased" : "Not purchased")
                        .foregroundStyle(iap.hasThemesPack ? .green : .secondary)
                }
            }
            if !iap.isProUser {
                Section("Subscribe") {
                    ForEach(iap.products.filter { ProductID.subscriptionIDs.contains($0.id) }, id: \.id) { product in
                        LabeledContent(product.displayName.isEmpty ? product.id : product.displayName) {
                            Button(product.displayPrice) {
                                Task { _ = try? await iap.purchase(product) }
                            }
                        }
                    }
                    if iap.products.isEmpty {
                        Text("Products are loading from the App Store…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                Button("Restore purchases") {
                    Task { try? await iap.restorePurchases() }
                }
                Link("Manage subscription", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                Text("One purchase unlocks Pro on iPhone, iPad and Mac (universal purchase).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - About

    private var aboutTab: some View {
        Form {
            Section("macTalky") {
                LabeledContent("Version") {
                    Text("\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                }
                LabeledContent("Protocol") { Text("TALKY1 · Bonjour + TCP · PCM 48 kHz") }
            }
            Section("Links") {
                Link("Talky for iPhone & iPad", destination: URL(string: "https://apps.apple.com/app/id6748584483")!)
                Link("Talky for Android (GitHub Releases)", destination: URL(string: "https://github.com/andreapianidev/WalkieTalkie/releases")!)
                Link("Source code on GitHub", destination: URL(string: "https://github.com/andreapianidev/WalkieTalkie")!)
                Link("Website", destination: URL(string: "https://walkie-talky.vercel.app")!)
                Link("andreapiani.com", destination: URL(string: "https://www.andreapiani.com")!)
            }
            Section {
                Text("© 2026 Andrea Piani — Immaginet Srl. Source-available under the PolyForm Noncommercial License 1.0.0.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
