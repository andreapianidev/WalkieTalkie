//creato da Andrea Piani - 09/11/26 - https://www.andreapiani.com - WhatsNewSheet.swift
//  WalkieTalkie
//
//  Le novita' della versione a chi aggiorna, una volta sola. Chi aggiorna non
//  rivede l'onboarding, quindi senza questo foglio le cose nuove le trovava
//  solo per caso.

import SwiftUI

enum WhatsNew {
    /// La versione di cui parla il foglio. Quando cambiano le novita' cambiano
    /// anche questo numero e i testi `whats_new_*`.
    static let notesVersion = "4.0"

    private static let seenKey = "talky_whats_new_seen"

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    /// Vero sulla 4.0 (e sulle 4.0.x) finche' il foglio non e' stato visto. Chi
    /// installa adesso lo segna come visto alla fine dell'onboarding.
    static var isPending: Bool {
        appVersion.hasPrefix(notesVersion)
            && UserDefaults.standard.string(forKey: seenKey) != notesVersion
    }

    static func markSeen() {
        UserDefaults.standard.set(notesVersion, forKey: seenKey)
    }
}

struct WhatsNewSheet: View {
    /// Porta alla novita' principale, il POC su cui si parla.
    let onTry: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    Text(String(format: "whats_new_title".localized, WhatsNew.notesVersion))
                        .font(.title.bold())
                        .foregroundColor(Color("PrimaryTextColor"))
                        .padding(.top, 28)

                    row("dot.radiowaves.up.forward", "whats_new_poc".localized)
                    row("key.fill", "whats_new_rooms".localized)
                    row("square.grid.2x2", "whats_new_widgets".localized)
                    row("questionmark.circle", "whats_new_pairing".localized)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: 10) {
                if #available(iOS 16.0, *) {
                    Button {
                        Funnel.log(Funnel.whatsNewTried, ["version": WhatsNew.notesVersion])
                        WhatsNew.markSeen()
                        dismiss()
                        // Dopo la chiusura del foglio: la banda parte sulla
                        // schermata del walkie, non sotto un foglio che scende.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: onTry)
                    } label: {
                        Text("whats_new_try".localized)
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Capsule().fill(Color("PrimaryTextColor")))
                    }
                }

                Button {
                    dismiss()
                } label: {
                    Text("got_it".localized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .padding(.top, 8)
        }
        .background(Color("BackgroundColor").ignoresSafeArea())
        .onAppear {
            Funnel.log(Funnel.whatsNewShown, ["version": WhatsNew.notesVersion])
        }
    }

    private func row(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.yellow)
                .frame(width: 40, height: 34)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.black))
            Text(text)
                .font(.body)
                .foregroundColor(Color("PrimaryTextColor"))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
