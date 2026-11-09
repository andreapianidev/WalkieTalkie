//creato da Andrea Piani - 09/11/26 - https://www.andreapiani.com - PairingHelpCard.swift
//  WalkieTalkie

import Combine
import SwiftUI

/// Quello che si vede in Esplora quando non c'e' nessuno: e' il punto esatto in
/// cui chi ha appena installato si blocca e cancella l'app ("non trova l'altro
/// iPhone", quasi tutte le recensioni negative).
///
/// Tre stati, nell'ordine in cui contano:
/// - permesso Rete locale negato: senza quello non si trovera' mai nessuno,
///   quindi lo si dice in rosso con il tasto per le Impostazioni;
/// - appena aperto: si sta cercando, e intanto si puo' invitare chi e' accanto;
/// - dopo `helpDelay` secondi senza nessuno: la lista dei controlli da fare.
struct PairingHelpCard: View {
    @ObservedObject private var network = LocalNetworkGuard.shared
    let searchStarted: Date
    let onSearchAgain: () -> Void

    @State private var now = Date()
    @State private var showInvite = false

    static let helpDelay: TimeInterval = 20

    private var showChecklist: Bool { now.timeIntervalSince(searchStarted) >= Self.helpDelay }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if network.isDenied {
                deniedBlock
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("no_devices_detected".localized)
                        .font(.body.weight(.semibold))
                        .foregroundColor(Color("PrimaryTextColor"))
                }
                if showChecklist {
                    Text("pairing_help_title".localized)
                        .font(.headline)
                        .foregroundColor(Color("PrimaryTextColor"))
                    step("1", "pairing_help_step_open".localized)
                    step("2", "pairing_help_step_radios".localized)
                    step("3", "pairing_help_step_channel".localized)
                    step("4", "pairing_help_step_close".localized)
                    step("5", "pairing_help_step_permission".localized)
                    HStack(spacing: 10) {
                        smallButton("pairing_search_again".localized, icon: "arrow.clockwise", action: onSearchAgain)
                        smallButton("pairing_open_settings".localized, icon: "gearshape", action: LocalNetworkGuard.openAppSettings)
                    }
                } else {
                    Text("ensure_devices_open".localized)
                        .font(.caption)
                        .foregroundColor(Color("PrimaryTextColor").opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                showInvite = true
            } label: {
                Label("invite_button".localized, systemImage: "qrcode")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color("PrimaryTextColor")))
            }
            Text("invite_hint".localized)
                .font(.caption)
                .foregroundColor(Color("PrimaryTextColor").opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .onAppear { network.check() }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { now = $0 }
        .sheet(isPresented: $showInvite) { InviteSheet() }
    }

    private var deniedBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("pairing_denied_title".localized, systemImage: "exclamationmark.octagon.fill")
                .font(.headline)
                .foregroundColor(.red)
            Text("pairing_denied_body".localized)
                .font(.body)
                .foregroundColor(Color("PrimaryTextColor"))
                .fixedSize(horizontal: false, vertical: true)
            Button(action: LocalNetworkGuard.openAppSettings) {
                Label("pairing_open_settings".localized, systemImage: "gearshape.fill")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.red))
            }
        }
    }

    private func step(_ n: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(n)
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color("PrimaryTextColor")))
            Text(text)
                .font(.subheadline)
                .foregroundColor(Color("PrimaryTextColor"))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func smallButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color("PrimaryTextColor"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).stroke(Color("PrimaryTextColor").opacity(0.4)))
        }
    }
}
