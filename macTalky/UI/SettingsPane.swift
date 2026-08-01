//creato da Andrea Piani - Immaginet Srl - 01/08/26 - https://www.andreapiani.com - SettingsPane.swift
//  macTalky
//
//  Scena Settings standard macOS (⌘,): identità sulla rete, comportamento
//  del link TALKY1, PTT, acquisti e informazioni.

import SwiftUI

struct SettingsPane: View {
    @EnvironmentObject private var engine: WalkieEngine
    @EnvironmentObject private var iap: IAPManager
    @EnvironmentObject private var settings: SettingsManager

    @State private var restoreMessage: String?

    var body: some View {
        Form {
            Section("Identity") {
                TextField("Device name on the network", text: $settings.deviceName)
                Text("Other Talky devices see this name. Changes apply after restarting the link.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Walkie-talkie") {
                Toggle("Start network link at launch", isOn: $settings.autoStartNetwork)
                Toggle("Hold Space bar to talk", isOn: $settings.spacebarPTT)
                LabeledContent("Microphone") {
                    if engine.hasMicPermission {
                        Label("Authorized", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Request access") { engine.requestMicPermission() }
                    }
                }
                Button("Restart network link") {
                    engine.channelDidChange()
                }
            }

            Section("Talky Pro") {
                LabeledContent("Status") {
                    Text(iap.isProUser ? "Pro active" : "Free")
                        .foregroundStyle(iap.isProUser ? .green : .secondary)
                }
                Button("Restore purchases") {
                    Task {
                        do {
                            try await iap.restorePurchases()
                            restoreMessage = iap.isProUser
                                ? "Pro subscription restored."
                                : "No active purchases found for this Apple Account."
                        } catch {
                            restoreMessage = error.localizedDescription
                        }
                    }
                }
                if let restoreMessage {
                    Text(restoreMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("About") {
                LabeledContent("Version") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }
                Link("Talky for iPhone & iPad", destination: URL(string: "https://apps.apple.com/app/id6748584483")!)
                Link("Source code on GitHub", destination: URL(string: "https://github.com/andreapianidev/WalkieTalkie")!)
                Link("andreapiani.com", destination: URL(string: "https://www.andreapiani.com")!)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 480)
    }
}
