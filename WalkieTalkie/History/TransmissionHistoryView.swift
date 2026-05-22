//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - TransmissionHistoryView.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import SwiftUI

/// Schermata cronologia trasmissioni ricevute.
/// Feature Pro-locked: controlla `UserDefaults.standard.bool(forKey: "fastboot_isProUser")`.
struct TransmissionHistoryView: View {
    @StateObject private var historyManager = TransmissionHistoryManager.shared
    @State private var showClearConfirmation = false

    /// Closure invocata quando l'utente non Pro tocca "Sblocca Pro".
    let onUnlockTap: () -> Void

    // TODO: usare ThemeManager.shared.currentTheme.accentColor quando disponibile
    private let accent: Color = .yellow

    private var isPro: Bool {
        UserDefaults.standard.bool(forKey: "fastboot_isProUser")
    }

    init(onUnlockTap: @escaping () -> Void = {}) {
        self.onUnlockTap = onUnlockTap
    }

    var body: some View {
        NavigationView {
            Group {
                if !isPro {
                    paywallOverlay
                } else if historyManager.entries.isEmpty {
                    emptyState
                } else {
                    entriesList
                }
            }
            .navigationTitle("history.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Mostriamo il bottone solo se ci sono entry e l'utente è Pro
                    Group {
                        if isPro && !historyManager.entries.isEmpty {
                            Button {
                                showClearConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(accent)
                            }
                            .accessibilityLabel("history.delete".localized)
                        } else {
                            EmptyView()
                        }
                    }
                }
            }
            .confirmationDialog(
                "history.clear_confirm_title".localized,
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("history.clear_all".localized, role: .destructive) {
                    historyManager.clearAll()
                }
                Button("history.cancel".localized, role: .cancel) { }
            }
        }
    }

    // MARK: - Stati UI

    /// Overlay paywall per utenti non Pro.
    private var paywallOverlay: some View {
        VStack(spacing: 20) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 56))
                    .foregroundColor(accent)
                    .padding(.top, 8)

                Text("history.paywall_message".localized)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal)

                Button(action: onUnlockTap) {
                    Text("history.unlock_pro".localized)
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(accent)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(accent.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(accent.opacity(0.5), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Empty state per utenti Pro senza ricezioni.
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text("history.empty".localized)
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Lista delle trasmissioni ricevute.
    private var entriesList: some View {
        List(historyManager.entries) { entry in
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 32))
                    .foregroundColor(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.peerName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("\(entry.relativeTimeString) · \(entry.durationFormatted)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .listStyle(.plain)
    }
}

#if DEBUG
struct TransmissionHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        TransmissionHistoryView(onUnlockTap: {})
    }
}
#endif
