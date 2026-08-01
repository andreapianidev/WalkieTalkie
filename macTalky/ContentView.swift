//creato da Andrea Piani - Immaginet Srl - 01/08/26 - https://www.andreapiani.com - ContentView.swift
//  macTalky
//
//  Root: sidebar console + area operativa (Walkie / Radio) sopra lo sfondo
//  aurora Metal. Sidebar custom, niente NavigationSplitView di default —
//  la console deve sembrare un pezzo di hardware, non un file browser.

import SwiftUI

enum ConsoleSection: String, CaseIterable, Identifiable {
    case walkie
    case radio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .walkie: return "Walkie"
        case .radio: return "Radio"
        }
    }

    var icon: String {
        switch self {
        case .walkie: return "dot.radiowaves.left.and.right"
        case .radio: return "antenna.radiowaves.left.and.right"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var engine: WalkieEngine
    @EnvironmentObject private var radio: RadioManager
    @EnvironmentObject private var iap: IAPManager
    @EnvironmentObject private var settings: SettingsManager

    @State private var section: ConsoleSection
    @State private var showPaywall = false

    init() {
        // Launch argument `-mac_start_section radio` (via NSArgumentDomain):
        // usato da automazioni/screenshot per aprire su una sezione precisa.
        let raw = UserDefaults.standard.string(forKey: "mac_start_section") ?? ""
        _section = State(initialValue: ConsoleSection(rawValue: raw) ?? .walkie)
    }

    private var backdrop: ConsoleBackdrop {
        ConsoleBackdrop(rawValue: settings.backdropRaw) ?? .carbon
    }

    /// Gli sfondi Pro si sbloccano con Talky Pro O con il Themes Pack.
    private var hasThemeEntitlement: Bool {
        iap.isProUser || iap.hasThemesPack
    }

    var body: some View {
        ZStack {
            TacticalBackground(
                backdrop: backdrop,
                transmitting: engine.isTransmitting,
                receiving: engine.isReceiving
            )

            HStack(spacing: 0) {
                sidebar
                    .frame(width: 216)

                Divider()
                    .overlay(Talky.stroke)

                Group {
                    switch section {
                    case .walkie:
                        WalkieView(showPaywall: $showPaywall)
                    case .radio:
                        RadioView(showPaywall: $showPaywall)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .onChange(of: radio.blockedByPaywall) { _, blocked in
            if blocked {
                showPaywall = true
                radio.blockedByPaywall = false
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Brand
            VStack(alignment: .leading, spacing: 2) {
                Text("macTALKY")
                    .font(.vfd(19, weight: .heavy))
                    .kerning(3)
                    .foregroundStyle(Talky.amber)
                    .shadow(color: Talky.amberDeep.opacity(0.6), radius: 8)
                Text("FIELD COMMS CONSOLE")
                    .font(.vfd(8, weight: .semibold))
                    .kerning(2.4)
                    .foregroundStyle(Talky.dim)
            }
            .padding(.top, 48)
            .padding(.horizontal, 20)
            .padding(.bottom, 28)

            PanelLabel("Modules")
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            VStack(spacing: 4) {
                ForEach(ConsoleSection.allCases) { item in
                    sidebarRow(item)
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            // Selettore sfondo tattico
            VStack(alignment: .leading, spacing: 8) {
                PanelLabel("Backdrop")
                HStack(spacing: 8) {
                    ForEach(ConsoleBackdrop.allCases) { item in
                        backdropSwatch(item)
                    }
                }
                Text(backdrop.title.uppercased())
                    .font(.vfd(8, weight: .semibold))
                    .kerning(1.6)
                    .foregroundStyle(Talky.dim.opacity(0.8))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            // Network status
            ConsolePanel(padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        StatusLamp(color: Talky.signal, on: engine.isNetworkActive)
                        Text(engine.isNetworkActive ? "LINK ACTIVE" : "LINK DOWN")
                            .font(.vfd(10, weight: .bold))
                            .kerning(1.2)
                            .foregroundStyle(engine.isNetworkActive ? Talky.signal : Talky.dim)
                        Spacer()
                    }
                    Text("\(engine.connectedPeerCount) peer\(engine.connectedPeerCount == 1 ? "" : "s") · \(engine.status)")
                        .font(.vfd(9))
                        .foregroundStyle(Talky.dim)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            // Pro upsell / badge
            if iap.isProUser {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Talky.amber)
                    Text("TALKY PRO")
                        .font(.vfd(10, weight: .bold))
                        .kerning(1.5)
                        .foregroundStyle(Talky.amber)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 18)
            } else {
                Button {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    withAnimation { showUpsell() }
                } label: {
                    Text("UNLOCK PRO")
                }
                .buttonStyle(ChipButtonStyle(filled: true))
                .frame(maxWidth: .infinity)
                .padding(.bottom, 18)
            }
        }
        .background(Talky.panel.opacity(0.55))
        .background(.ultraThinMaterial)
    }

    private func showUpsell() {
        showPaywall = true
    }

    private func backdropSwatch(_ item: ConsoleBackdrop) -> some View {
        let selected = backdrop == item
        let locked = item.isPro && !hasThemeEntitlement

        return Button {
            if locked {
                showPaywall = true
            } else {
                withAnimation(.easeOut(duration: 0.25)) {
                    settings.backdropRaw = item.rawValue
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(item.swatch.opacity(locked ? 0.35 : 0.9))
                    .frame(width: 18, height: 18)
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(Talky.coal)
                }
            }
            .overlay(
                Circle().strokeBorder(
                    selected ? Talky.text : Talky.stroke,
                    lineWidth: selected ? 2 : 1
                )
            )
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(item.isPro ? "\(item.title) (Pro)" : item.title)
    }

    private func sidebarRow(_ item: ConsoleSection) -> some View {
        let selected = section == item
        let lampOn = item == .walkie ? engine.connectedPeerCount > 0 : radio.isPlaying

        return Button {
            withAnimation(.easeOut(duration: 0.15)) { section = item }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18)
                Text(item.title.uppercased())
                    .font(.vfd(12, weight: .bold))
                    .kerning(1.6)
                Spacer()
                StatusLamp(color: item == .walkie ? Talky.signal : Talky.amber, on: lampOn)
            }
            .foregroundStyle(selected ? Talky.text : Talky.dim)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? Talky.panelRaised.opacity(0.9) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(selected ? Talky.stroke : .clear, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .environmentObject(WalkieEngine.shared)
        .environmentObject(RadioManager.shared)
        .environmentObject(IAPManager.shared)
        .environmentObject(SettingsManager.shared)
}
