//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - SleepTimerSheet.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import SwiftUI

/// Sheet che permette all'utente Pro di impostare uno sleep timer per la radio.
/// Per gli utenti non Pro mostra un overlay paywall.
struct SleepTimerSheet: View {
    @StateObject private var sleepTimer = SleepTimerManager.shared
    @Environment(\.dismiss) private var dismiss

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
                } else if sleepTimer.isActive {
                    activeCountdown
                } else {
                    durationPicker
                }
            }
            .navigationTitle("sleep_timer.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("sleep_timer.close".localized) {
                        dismiss()
                    }
                    .foregroundColor(Color("PrimaryTextColor"))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    // MARK: - Stati UI

    /// Overlay paywall per utenti non Pro (stesso pattern di TransmissionHistoryView).
    private var paywallOverlay: some View {
        VStack(spacing: 20) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 56))
                    .foregroundColor(accent)
                    .padding(.top, 8)

                Text("sleep_timer.paywall_message".localized)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal)

                Button(action: onUnlockTap) {
                    Text("sleep_timer.unlock_pro".localized)
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

    /// Countdown grande con bottone di annullamento (timer attivo).
    private var activeCountdown: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 56))
                .foregroundColor(accent)

            Text("sleep_timer.countdown_label".localized)
                .font(.headline)
                .foregroundColor(.secondary)

            Text(sleepTimer.formattedRemaining)
                .font(.system(size: 72, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)

            Spacer()

            Button {
                sleepTimer.cancel()
            } label: {
                Text("sleep_timer.cancel".localized)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Picker delle durate (timer non attivo): 5 bottoni in stack verticale.
    private var durationPicker: some View {
        VStack(spacing: 16) {
            Text("sleep_timer.picker_prompt".localized)
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.top, 8)

            VStack(spacing: 12) {
                ForEach(SleepTimerDuration.allCases) { duration in
                    Button {
                        // Avvia il timer e chiudi la sheet: la UI principale mostrerà lo stato attivo.
                        if sleepTimer.start(duration: duration) {
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "clock")
                            Text(duration.displayName)
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(.primary)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(accent.opacity(0.15))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(accent.opacity(0.4), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if DEBUG
struct SleepTimerSheet_Previews: PreviewProvider {
    static var previews: some View {
        SleepTimerSheet(onUnlockTap: {})
    }
}
#endif
