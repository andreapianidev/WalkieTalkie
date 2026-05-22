//creato da Andrea Piani - Immaginet Srl - 22/05/26 - https://www.andreapiani.com - PrivateChannelSheet.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 22/05/26.
//

import SwiftUI

/// Sheet per creare/entrare in un canale walkie privato protetto da password.
/// Per utenti free viene mostrato un overlay di paywall che richiama `onLockedTap`.
struct PrivateChannelSheet: View {
    // MARK: - Input

    /// Callback invocata quando un utente free tocca il CTA del paywall.
    /// Il chiamante è responsabile di presentare `PaywallView`.
    let onLockedTap: () -> Void

    // MARK: - Env

    @Environment(\.dismiss) private var dismiss
    @StateObject private var channelManager = PrivateChannelManager.shared

    // MARK: - State

    @State private var channelName: String = ""
    @State private var password: String = ""
    @State private var showForm: Bool = false
    @State private var errorMessage: String? = nil

    // MARK: - Theme

    private var brandYellow: Color {
        Color(red: 1.0, green: 0.8, blue: 0.0)
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        if channelManager.isProUser {
                            proContent
                        } else {
                            paywallOverlay
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("private_channels.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("private_channels.close".localized) { dismiss() }
                }
            }
        }
    }

    // MARK: - Pro Content

    @ViewBuilder
    private var proContent: some View {
        // Stato corrente
        if channelManager.currentChannelID == PrivateChannelManager.publicChannelID {
            publicStateCard
        } else {
            privateStateCard
        }

        // Form per entrare in un canale (visibile se richiesto dall'utente o se in pubblico senza scelta attiva)
        if showForm || channelManager.currentChannelID == PrivateChannelManager.publicChannelID {
            joinFormCard
        }
    }

    private var publicStateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("private_channels.public_state_title".localized)
                    .font(.headline)
            }
            Text("private_channels.public_state_description".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if !showForm {
                Button {
                    showForm = true
                } label: {
                    Text("private_channels.create_or_join".localized)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(brandYellow)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private var privateStateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundColor(brandYellow)
                VStack(alignment: .leading) {
                    Text("private_channels.private_state_title".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(channelManager.currentChannelName ?? "private_channels.channel_fallback".localized)
                        .font(.title3)
                        .fontWeight(.bold)
                }
            }

            Text("private_channels.private_state_description".localized)
                .font(.footnote)
                .foregroundColor(.secondary)

            Button {
                channelManager.leaveChannel()
                channelName = ""
                password = ""
                errorMessage = nil
                dismiss()
            } label: {
                Text("private_channels.leave".localized)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.15))
                    .foregroundColor(.red)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private var joinFormCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("private_channels.form.title".localized)
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("private_channels.form.name_label".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("private_channels.form.name_placeholder".localized, text: $channelName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("private_channels.form.password_label".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("private_channels.form.password_placeholder".localized, text: $password)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
            }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
            }

            Button {
                attemptJoin()
            } label: {
                Text("private_channels.form.submit".localized)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSubmit ? brandYellow : Color.gray.opacity(0.3))
                    .foregroundColor(.black)
                    .cornerRadius(12)
            }
            .disabled(!canSubmit)

            Text("private_channels.form.hint".localized)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Paywall Overlay

    private var paywallOverlay: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.black)
                VStack(alignment: .leading, spacing: 4) {
                    Text("private_channels.paywall.pro_feature".localized)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.black.opacity(0.7))
                    Text("private_channels.paywall.headline".localized)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                }
            }

            Text("private_channels.paywall.description".localized)
                .font(.subheadline)
                .foregroundColor(.black.opacity(0.85))

            Button {
                onLockedTap()
            } label: {
                Text("private_channels.paywall.cta".localized)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(brandYellow)
        .cornerRadius(16)
    }

    // MARK: - Validation / Actions

    private var canSubmit: Bool {
        !channelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && password.count >= PrivateChannelManager.minPasswordLength
    }

    private func attemptJoin() {
        errorMessage = nil

        let trimmedName = channelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "private_channels.error.empty_name".localized
            return
        }
        guard password.count >= PrivateChannelManager.minPasswordLength else {
            errorMessage = String(format: "private_channels.error.password_min".localized, PrivateChannelManager.minPasswordLength)
            return
        }

        let success = channelManager.joinChannel(name: trimmedName, password: password)
        if success {
            password = ""
            dismiss()
        } else {
            errorMessage = "private_channels.error.join_failed".localized
        }
    }
}

#Preview {
    PrivateChannelSheet(onLockedTap: {})
}
