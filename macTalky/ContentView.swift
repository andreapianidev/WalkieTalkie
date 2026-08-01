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

    @State private var section: ConsoleSection = .walkie
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            AuroraBackground()

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
