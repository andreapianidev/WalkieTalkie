//creato da Andrea Piani - 02/08/26 - https://www.andreapiani.com - SettingsPane.swift
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
                .tabItem { Label(MacString.tabGeneral.text, systemImage: "gearshape") }
            walkieTab
                .tabItem { Label("Walkie", systemImage: "dot.radiowaves.left.and.right") }
            radioTab
                .tabItem { Label(MacString.radio.text, systemImage: "antenna.radiowaves.left.and.right") }
            appearanceTab
                .tabItem { Label(MacString.tabAppearance.text, systemImage: "paintpalette") }
            proTab
                .tabItem { Label("Talky Pro", systemImage: "crown") }
            aboutTab
                .tabItem { Label(MacString.tabAbout.text, systemImage: "info.circle") }
        }
        .frame(width: 520, height: 460)
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section(MacString.identity.text) {
                TextField(MacString.deviceName.text, text: $settings.deviceName)
                Text(MacString.identityNote.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section(MacString.startup.text) {
                Toggle(MacString.autoStartLink.text, isOn: $settings.autoStartNetwork)
                Toggle(MacString.autoResumeRadio.text, isOn: $settings.autoResumeRadio)
            }
            Section(MacString.menuBar.text) {
                Toggle(MacString.showMiniConsole.text, isOn: $settings.showMenuBarExtra)
                Text(MacString.menuBarNote.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Button(MacString.resetDefaults.text) {
                    settings.resetToDefaults()
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Walkie

    private var walkieTab: some View {
        Form {
            Section(MacString.pushToTalk.text) {
                Toggle(MacString.holdSpace.text, isOn: $settings.spacebarPTT)
                LabeledContent(MacString.maxTransmission.text) { Text(MacString.tenSeconds.text) }
                Text(MacString.transmissionNote.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section(MacString.microphone.text) {
                LabeledContent(MacString.permission.text) {
                    if engine.hasMicPermission {
                        Label(MacString.authorized.text, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if engine.micPermissionDenied {
                        // Il prompt di sistema non si ripresenta dopo un rifiuto:
                        // un bottone "chiedi accesso" qui sarebbe un vicolo cieco.
                        Button(MacString.openSystemSettings.text) {
                            if let url = URL(string:
                                "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    } else {
                        // Guideline 5.1.1(iv): prima del prompt di sistema il bottone
                        // resta neutro, come quello del roster in WalkieView.
                        Button(MacString.continueButton.text) { engine.requestMicPermission() }
                    }
                }
            }
            Section(MacString.networkLink.text) {
                LabeledContent(MacString.status.text) { Text(engine.status) }
                LabeledContent(MacString.connectedPeers.text) { Text("\(engine.connectedPeerCount)") }
                HStack {
                    Button(engine.isNetworkActive ? MacString.stopLink.text : MacString.startLink.text) {
                        engine.isNetworkActive ? engine.stop() : engine.start()
                    }
                    Button(MacString.restartLink.text) { engine.channelDidChange() }
                }
                Text(MacString.bonjourNote.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Radio

    private var radioTab: some View {
        Form {
            Section(MacString.playback.text) {
                LabeledContent(MacString.volume.text) {
                    Slider(
                        value: Binding(
                            get: { Double(settings.radioVolume) },
                            set: { settings.radioVolume = Float($0) }
                        ),
                        in: 0...1
                    )
                    .frame(width: 180)
                }
                Toggle(MacString.resumeLastStation.text, isOn: $settings.autoResumeRadio)
            }
            Section(MacString.stations.text) {
                LabeledContent(MacString.catalog.text) { Text(MacString.catalogValue.format(radio.radioStations.count, radio.freeStations.count)) }
                LabeledContent(MacString.favorites.text) { Text("\(radio.favoriteStations.count)") }
                Text(MacString.duckNote.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Appearance

    private var appearanceTab: some View {
        Form {
            Section(MacString.consoleBackdrop.text) {
                ForEach(ConsoleBackdrop.allCases) { item in
                    backdropRow(item)
                }
                Text(MacString.premiumNote.text)
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
            Section(MacString.status.text) {
                LabeledContent("Talky Pro") {
                    Text(iap.isProUser ? MacString.active.text : MacString.notActive.text)
                        .foregroundStyle(iap.isProUser ? .green : .secondary)
                }
                LabeledContent(MacString.themesPack.text) {
                    Text(iap.hasThemesPack ? MacString.purchased.text : MacString.notPurchased.text)
                        .foregroundStyle(iap.hasThemesPack ? .green : .secondary)
                }
            }
            if !iap.isProUser {
                Section(MacString.subscribe.text) {
                    ForEach(iap.products.filter { ProductID.subscriptionIDs.contains($0.id) }, id: \.id) { product in
                        LabeledContent(product.displayName.isEmpty ? product.id : product.displayName) {
                            Button(product.displayPrice) {
                                Task { _ = try? await iap.purchase(product) }
                            }
                        }
                    }
                    if iap.products.isEmpty {
                        Text(MacString.loadingProducts.text)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                Button(MacString.restorePurchases.text) {
                    Task { try? await iap.restorePurchases() }
                }
                Link(MacString.manageSubscription.text, destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                Text(MacString.universalNote.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - About

    /// Mail verso Andrea con versione, sistema e modello in fondo: chi segnala
    /// un problema non deve sapere quali dati servono, e non si chiedono dopo.
    private static func mailURL(topic: String) -> URL {
        let info = Bundle.main.infoDictionary
        let version = "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: max(size, 1))
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        let lang = Locale.preferredLanguages.first ?? "?"
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = "andreapiani.dev@gmail.com"
        c.queryItems = [
            URLQueryItem(name: "subject", value: "Talky Mac \(version): \(topic)"),
            URLQueryItem(name: "body", value: "\n\n\n---\nTalky Mac \(version) · macOS \(os) · \(String(cString: model)) · \(lang)")
        ]
        return c.url ?? URL(string: "mailto:andreapiani.dev@gmail.com")!
    }

    private var aboutTab: some View {
        Form {
            Section("macTalky") {
                LabeledContent(MacString.version.text) {
                    Text("\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                }
                LabeledContent(MacString.protocolLabel.text) { Text("TALKY1 · Bonjour + TCP · PCM 48 kHz") }
            }
            Section(MacString.writeToMe.text) {
                Text(MacString.writeIntro.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Link(MacString.reportProblem.text, destination: Self.mailURL(topic: "problem"))
                Link(MacString.suggestFeature.text, destination: Self.mailURL(topic: "idea"))
                Link(MacString.sayHello.text, destination: Self.mailURL(topic: "message"))
                Link(MacString.rateTalky.text, destination: URL(string: "macappstore://apps.apple.com/app/id6748584483?action=write-review")!)
            }
            Section {
                ForEach(Thanks.all) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        if let link = entry.link {
                            Link(entry.who, destination: link).fontWeight(.semibold)
                        } else {
                            Text(entry.who).fontWeight(.semibold)
                        }
                        Text(entry.why)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(Thanks.title)
            } footer: {
                Text(Thanks.intro)
            }
            Section(MacString.links.text) {
                Link(MacString.talkyIPhone.text, destination: URL(string: "https://apps.apple.com/app/id6748584483")!)
                Link(MacString.talkyAndroid.text, destination: URL(string: "https://github.com/andreapianidev/WalkieTalkie/releases")!)
                Link(MacString.sourceCode.text, destination: URL(string: "https://github.com/andreapianidev/WalkieTalkie")!)
                Link(MacString.website.text, destination: URL(string: "https://walkie-talky.vercel.app")!)
                Link("andreapiani.com", destination: URL(string: "https://www.andreapiani.com")!)
            }
            Section {
                Text("© 2026 Andrea Piani · NIE Z2331796-S · Tijarafe, Santa Cruz de Tenerife · Islas Canarias. " + MacString.license.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
