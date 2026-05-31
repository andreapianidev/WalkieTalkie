//creato da Andrea Piani - Immaginet Srl - 2024 - https://www.andreapiani.com - SettingsView.swift

import SwiftUI
import Combine
import FirebaseAnalytics

struct SettingsView: View {
    @ObservedObject var audioManager: AudioManager
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @EnvironmentObject private var adManager: AdManager
    @EnvironmentObject private var iapManager: IAPManager
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showingInstructions = false
    @State private var showingPerformance = false
    @State private var showPaywall = false
    @State private var didLogSettingsRewardImpression = false
    @State private var showThemeSelector = false
    @State private var showHistory = false
    @State private var showSleepTimer = false
    @State private var showEqualizer = false
    @State private var showRecordings = false
    @State private var showPrivateChannels = false
    @State private var rewardClock = Date()
    /// Tema che ha innescato la sheet del themes pack. Non-nil = sheet visibile.
    @State private var themesPackTriggerTheme: Theme? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            ScrollView {
                VStack(spacing: 20) {
                    // Pro Section (paywall / status)
                    proSection

                    // Ads / Privacy section — risalita in alto: il rewarded
                    // "guarda un video → 1h senza ads" era l'ultima sezione e
                    // non veniva mai servito. Qui è visibile subito dopo il Pro.
                    adsSection

                    // Personalization Section (themes + history)
                    personalizationSection

                    // Notifications Section
                    notificationsSection

                    // Live Activities Section
                    liveActivitiesSection

                    // Audio Settings Section
                    audioSettingsSection

                    // Appearance Section
                    appearanceSection

                    // Performance Section
                    performanceSection

                    // Instructions Section
                    instructionsSection

                    // App Info Section
                    appInfoSection

                    // Support Section
                    supportSection

                    // Peak App Section
                    peakAppSection

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .background(Color("BackgroundColor"))
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(trigger: "settings_manual")
        }
        .sheet(isPresented: $showThemeSelector) {
            ThemeSelectorView(onLockedTap: { tappedTheme in
                showThemeSelector = false
                // Piccolo delay per evitare conflitto di animazioni tra sheet e sheet.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    themesPackTriggerTheme = tappedTheme
                }
            })
        }
        .sheet(item: $themesPackTriggerTheme) { triggerTheme in
            ThemePurchaseSheet(theme: triggerTheme, onSubscribeTap: {
                // L'utente preferisce la subscription al pack: apriamo il paywall.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    showPaywall = true
                }
            })
        }
        .sheet(isPresented: $showHistory) {
            TransmissionHistoryView(onUnlockTap: {
                showHistory = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showPaywall = true
                }
            })
        }
        .sheet(isPresented: $showSleepTimer) {
            SleepTimerSheet(onUnlockTap: {
                showSleepTimer = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showPaywall = true
                }
            })
        }
        .sheet(isPresented: $showEqualizer) {
            EqualizerView(onLockedTap: {
                showEqualizer = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showPaywall = true
                }
            })
        }
        .sheet(isPresented: $showRecordings) {
            RecordingsListView(onUnlockTap: {
                showRecordings = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showPaywall = true
                }
            })
        }
        .sheet(isPresented: $showPrivateChannels) {
            PrivateChannelSheet(onLockedTap: {
                showPrivateChannels = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showPaywall = true
                }
            })
        }
        .onAppear {
            // Sync audio manager with settings manager
            if settingsManager.isBackgroundAudioEnabled {
                audioManager.setBackgroundVolume(settingsManager.backgroundVolume)
            } else {
                audioManager.setBackgroundVolume(0.0)
            }
        }
    }

    // MARK: - Pro Section

    /// Brand color allineato alla paywall ("Field Radio" #FFCC00).
    private var proBrand: Color { Color(red: 1.0, green: 0.8, blue: 0.0) }
    private var proBrandDeep: Color { Color(red: 0.91, green: 0.71, blue: 0.0) }

    private var proSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(iapManager.isProUser ? Color.green : proBrand)
                    .frame(width: 6, height: 6)
                    .shadow(color: settingsManager.isDarkModeEnabled
                            ? (iapManager.isProUser ? Color.green.opacity(0.6) : proBrand.opacity(0.6))
                            : .clear,
                            radius: 4)
                Text((iapManager.isProUser ? "settings.pro.title_active" : "settings.pro.title").localized)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(3.5)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.8))
                Spacer()
            }

            if iapManager.isProUser {
                proActiveCard
            } else {
                proUnlockCard
            }

            restoreButton
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color("SurfaceColor"))
        )
    }

    /// Card "TX active": Pro attivo. Tap → apri gestione abbonamento.
    private var proActiveCard: some View {
        Button(action: openManageSubscriptions) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.green.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.green)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("settings.pro.manage_subscription".localized)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(Color("PrimaryTextColor"))
                    Text("settings.pro.manage_subscription_subtitle".localized)
                        .font(.system(size: 12))
                        .foregroundColor(Color("PrimaryTextColor").opacity(0.65))
                        .lineLimit(1)
                }

                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.5))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color("BackgroundColor").opacity(0.6))
            )
        }
        .buttonStyle(.plain)
    }

    /// Card unlock: replica il linguaggio visivo della Paywall (icona brand-square
    /// + brand capsule CTA), così l'utente vede coerenza fra Settings e Paywall.
    private var proUnlockCard: some View {
        Button(action: { showPaywall = true }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(proBrand)
                        .frame(width: 36, height: 36)
                        .shadow(color: settingsManager.isDarkModeEnabled
                                ? proBrand.opacity(0.35) : .clear,
                                radius: 10, y: 3)
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("settings.pro.unlock".localized)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(Color("PrimaryTextColor"))
                    Text("settings.pro.unlock_subtitle".localized)
                        .font(.system(size: 12))
                        .foregroundColor(Color("PrimaryTextColor").opacity(0.65))
                        .lineLimit(1)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.5))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color("BackgroundColor").opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(proBrand.opacity(settingsManager.isDarkModeEnabled ? 0.4 : 0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// Restore: pulsante secondario testuale, niente fondo, per non competere
    /// con la CTA primaria di unlock (riduce il rumore visivo).
    private var restoreButton: some View {
        Button(action: restorePurchases) {
            HStack(spacing: 8) {
                if iapManager.isLoading {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                }
                Text("settings.pro.restore_purchases".localized)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
            }
            .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
            .padding(.horizontal, 12)
            .padding(.top, 2)
        }
        .buttonStyle(.plain)
        .disabled(iapManager.isLoading)
    }

    // MARK: - Personalization Section

    private var personalizationSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(Color("PrimaryTextColor"))
                Text("settings.personalization.title".localized)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color("PrimaryTextColor"))
                Spacer()
            }

            VStack(spacing: 12) {
                // Temi
                Button(action: { showThemeSelector = true }) {
                    HStack {
                        Circle()
                            .fill(themeManager.currentTheme.accentColor)
                            .frame(width: 24, height: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("settings.personalization.themes".localized)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(Color("PrimaryTextColor"))
                            Text(themeManager.currentTheme.displayName)
                                .font(.caption)
                                .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                        }
                        Spacer()
                        if !iapManager.isProUser {
                            proBadge
                        }
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color("PrimaryTextColor").opacity(0.5))
                            .font(.caption)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color("SurfaceColor"))
                    )
                }

                // Cronologia trasmissioni
                proRow(
                    icon: "clock.arrow.circlepath",
                    title: "settings.personalization.history.title".localized,
                    subtitle: "settings.personalization.history.subtitle".localized,
                    action: { showHistory = true }
                )

                // Sleep Timer Radio
                proRow(
                    icon: "moon.zzz.fill",
                    title: "settings.personalization.sleep_timer.title".localized,
                    subtitle: "settings.personalization.sleep_timer.subtitle".localized,
                    action: { showSleepTimer = true }
                )

                // Equalizer
                proRow(
                    icon: "slider.horizontal.3",
                    title: "settings.personalization.equalizer.title".localized,
                    subtitle: "settings.personalization.equalizer.subtitle".localized,
                    action: { showEqualizer = true }
                )

                // Registrazioni
                proRow(
                    icon: "mic.circle.fill",
                    title: "settings.personalization.recordings.title".localized,
                    subtitle: "settings.personalization.recordings.subtitle".localized,
                    action: { showRecordings = true }
                )

                // Canali privati
                proRow(
                    icon: "lock.shield.fill",
                    title: "settings.personalization.private_channels.title".localized,
                    subtitle: "settings.personalization.private_channels.subtitle".localized,
                    action: { showPrivateChannels = true }
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color("SurfaceColor"))
        )
    }

    /// Riga riutilizzabile per feature Pro nella sezione Personalizzazione.
    /// Mostra il badge "PRO" se l'utente non è abbonato.
    private func proRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Color("PrimaryTextColor"))
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color("PrimaryTextColor"))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                }
                Spacer()
                if !iapManager.isProUser {
                    proBadge
                }
                Image(systemName: "chevron.right")
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.5))
                    .font(.caption)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("SurfaceColor"))
            )
        }
    }

    private var proBadge: some View {
        Text("PRO")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.black)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(Color.yellow)
            )
    }

    private func restorePurchases() {
        Task {
            do {
                try await iapManager.restorePurchases()
            } catch {
                // Errore già loggato a livello manager.
            }
        }
    }

    private func openManageSubscriptions() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        UIApplication.shared.open(url)
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "gearshape.fill")
                .foregroundColor(Color("PrimaryTextColor"))
                .font(.title2)
            
            Spacer()
            
            VStack {
                Text("settings".localized)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color("PrimaryTextColor"))
                Text("configure_app".localized)
                    .font(.caption)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
            }
            
            Spacer()
            
            Button(action: {
                showingInstructions.toggle()
            }) {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(Color("PrimaryTextColor"))
                    .font(.title2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 15)
    }
    
    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "bell")
                    .foregroundColor(Color("PrimaryTextColor"))
                Text("notifications".localized)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color("PrimaryTextColor"))
                Spacer()
            }
            
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(notificationManager.notificationsEnabled ? "disable_notifications".localized : "enable_notifications".localized)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(Color("PrimaryTextColor"))
                        Text("notification_description".localized)
                            .font(.caption)
                            .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { notificationManager.notificationsEnabled },
                        set: { newValue in
                            if newValue != notificationManager.notificationsEnabled {
                                notificationManager.toggleNotifications()
                            }
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: Color("ToggleAccentColor")))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("SurfaceColor"))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color("SurfaceColor"))
        )
    }
    
    private var liveActivitiesSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "rectangle.inset.filled.on.rectangle")
                    .foregroundColor(Color("PrimaryTextColor"))
                Text("live_activities.title".localized)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color("PrimaryTextColor"))
                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("live_activities.toggle".localized)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color("PrimaryTextColor"))
                    Text("live_activities.description".localized)
                        .font(.caption)
                        .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                }

                Spacer()

                Toggle("", isOn: $settingsManager.isLiveActivitiesEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: Color("ToggleAccentColor")))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("SurfaceColor"))
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color("SurfaceColor"))
        )
    }

    private var audioSettingsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "speaker.wave.2")
                    .foregroundColor(Color("PrimaryTextColor"))
                Text("audio".localized)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color("PrimaryTextColor"))
                Spacer()
            }
            
            VStack(spacing: 12) {
                // Background Audio Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("white_noise".localized)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(Color("PrimaryTextColor"))
                        Text("background_audio".localized)
                            .font(.caption)
                            .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $settingsManager.isBackgroundAudioEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: Color("ToggleAccentColor")))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("SurfaceColor"))
                )
                
                // Volume Slider (only when background audio is enabled)
                if settingsManager.isBackgroundAudioEnabled {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("noise_volume".localized)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(Color("PrimaryTextColor"))
                            Text("adjust_background_volume".localized)
                                .font(.caption)
                                .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                        }
                        
                        Spacer()
                        
                        VStack {
                            Slider(value: $settingsManager.backgroundVolume, in: 0.05...0.5, step: 0.05)
                            .accentColor(Color("PrimaryTextColor"))
                            
                            Text("\(Int(settingsManager.backgroundVolume * 100))%")
                                .font(.caption2)
                                .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                        }
                        .frame(width: 100)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color("SurfaceColor"))
                    )
                }
                
                // Haptic Feedback Setting
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("haptic_feedback".localized)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(Color("PrimaryTextColor"))
                        Text("vibration_on_buttons".localized)
                            .font(.caption)
                            .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $settingsManager.isHapticFeedbackEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: Color("ToggleAccentColor")))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                         .fill(Color("SurfaceColor"))
                )
                
                // Auto Connect Setting
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("auto_connect".localized)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(Color("PrimaryTextColor"))
                        Text("auto_connect_description".localized)
                            .font(.caption)
                            .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $settingsManager.isAutoConnectEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: Color("ToggleAccentColor")))
                }
                .padding()
                .background(
                     RoundedRectangle(cornerRadius: 12)
                         .fill(Color("SurfaceColor"))
                 )
                
                // Voice Activation Setting
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("voice_activation".localized)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(Color("PrimaryTextColor"))
                        Text("voice_activation_description".localized)
                            .font(.caption)
                            .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $settingsManager.isVoiceActivationEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: Color("ToggleAccentColor")))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("SurfaceColor"))
                )
                
                // Voice Activation Threshold (only when voice activation is enabled)
                if settingsManager.isVoiceActivationEnabled {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("voice_sensitivity".localized)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(Color("PrimaryTextColor"))
                            Text("voice_sensitivity_description".localized)
                                .font(.caption)
                                .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                        }
                        
                        Spacer()
                        
                        VStack {
                            Slider(value: $settingsManager.voiceActivationThreshold, in: 0.1...0.8, step: 0.1)
                                .accentColor(Color("PrimaryTextColor"))
                            
                            Text("\(Int(settingsManager.voiceActivationThreshold * 100))%")
                                .font(.caption2)
                                .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                        }
                        .frame(width: 100)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color("SurfaceColor"))
                    )
                }
                
                // Low Power Mode Setting
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("low_power_mode".localized)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(Color("PrimaryTextColor"))
                        Text("low_power_mode_description".localized)
                            .font(.caption)
                            .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $settingsManager.isLowPowerModeEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: Color("ToggleAccentColor")))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                          .fill(Color("SurfaceColor"))
                 )
                 
                 // Reset Settings Button
                 Button(action: {
                     settingsManager.resetToDefaults()
                     // Sync with audio manager
                     if settingsManager.isBackgroundAudioEnabled {
                         audioManager.setBackgroundVolume(settingsManager.backgroundVolume)
                     } else {
                         audioManager.setBackgroundVolume(0.0)
                     }
                 }) {
                     HStack {
                         Image(systemName: "arrow.clockwise")
                             .foregroundColor(.white)
                         Text("reset_settings".localized)
                             .font(.body)
                             .fontWeight(.medium)
                             .foregroundColor(.white)
                     }
                     .frame(maxWidth: .infinity)
                     .padding()
                     .background(
                         RoundedRectangle(cornerRadius: 12)
                             .fill(Color.red.opacity(0.8))
                     )
                 }
             }
         }
         .padding()
         .background(
             RoundedRectangle(cornerRadius: 15)
                 .fill(Color("SurfaceColor"))
         )
     }
    
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(Color("PrimaryTextColor"))
                Text("performance".localized)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color("PrimaryTextColor"))
                Spacer()
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    showingPerformance = true
                }) {
                    HStack {
                        Image(systemName: "speedometer")
                            .foregroundColor(.white)
                        Text("view_performance".localized)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.8))
                    )
                }
            }
        }
        .padding()
        .background(
                 RoundedRectangle(cornerRadius: 15)
                     .fill(Color("SurfaceColor"))
             )
        .sheet(isPresented: $showingPerformance) {
            PerformanceStatsView()
        }
    }
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(Color("PrimaryTextColor"))
                Text("how_to_use".localized)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color("PrimaryTextColor"))
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                instructionItem(
                    icon: "1.circle.fill",
                    title: "instruction_1_title".localized,
                    description: "instruction_1_description".localized
                )
                
                instructionItem(
                    icon: "2.circle.fill",
                    title: "instruction_2_title".localized,
                    description: "instruction_2_description".localized
                )
                
                instructionItem(
                    icon: "3.circle.fill",
                    title: "instruction_3_title".localized,
                    description: "instruction_3_description".localized
                )
                
                instructionItem(
                    icon: "4.circle.fill",
                    title: "instruction_4_title".localized,
                    description: "instruction_4_description".localized
                )
                
                instructionItem(
                    icon: "5.circle.fill",
                    title: "instruction_5_title".localized,
                    description: "instruction_5_description".localized
                )
            }
        }
        .padding()
        .background(
             RoundedRectangle(cornerRadius: 15)
                 .fill(Color("SurfaceColor"))
         )
    }
    
    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "app.badge")
                    .foregroundColor(Color("PrimaryTextColor"))
                Text("app_info".localized)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color("PrimaryTextColor"))
                Spacer()
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text("version".localized)
                        .font(.body)
                        .foregroundColor(Color("PrimaryTextColor"))
                    Spacer()
                    Text("1.0.0")
                        .font(.body)
                        .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                }
                
                Divider()
                
                HStack {
                    Text("developed_by".localized)
                        .font(.body)
                        .foregroundColor(Color("PrimaryTextColor"))
                    Spacer()
                    Text("Andrea Piani - Immaginet Srl")
                        .font(.body)
                        .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                }
                
                Divider()
                
                HStack {
                    Text("website".localized)
                        .font(.body)
                        .foregroundColor(Color("PrimaryTextColor"))
                    Spacer()
                    Text("www.andreapiani.com")
                        .font(.body)
                        .foregroundColor(.blue)
                }

                Divider()

                Button(action: {
                    if let url = URL(string: "https://github.com/andreapianidev/WalkieTalkie") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Text("open_source".localized)
                            .font(.body)
                            .foregroundColor(Color("PrimaryTextColor"))
                        Spacer()
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("view_on_github".localized)
                            .font(.body)
                            .foregroundColor(.blue)
                    }
                }

                Divider()

                Button(action: {
                    if let url = URL(string: "https://github.com/andreapianidev/WalkieTalkie/blob/main/WalkieTalkie/LICENSE") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Text("license".localized)
                            .font(.body)
                            .foregroundColor(Color("PrimaryTextColor"))
                        Spacer()
                        Text("PolyForm Noncommercial")
                            .font(.body)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("SurfaceColor"))
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color("SurfaceColor"))
        )
    }
    
    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(Color("PrimaryTextColor"))
                Text("support_development".localized)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color("PrimaryTextColor"))
                Spacer()
            }
            
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("support_description".localized)
                            .font(.body)
                            .foregroundColor(Color("PrimaryTextColor"))
                    }
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("SurfaceColor"))
                )
                
                Button(action: {
                    if let url = URL(string: "https://buymeacoffee.com/andreapianidev") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "cup.and.saucer.fill")
                            .foregroundColor(.white)
                        Text("buy_me_coffee".localized)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange.opacity(0.8))
                    )
                }
            }
        }
        .padding()
        .background(
             RoundedRectangle(cornerRadius: 15)
                 .fill(Color("SurfaceColor"))
         )
    }
    
    private func instructionItem(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color("PrimaryTextColor"))
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("PrimaryTextColor"))
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("SurfaceColor"))
        )
    }
    
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "paintbrush.fill")
                    .foregroundColor(Color("PrimaryTextColor"))
                Text("appearance".localized)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color("PrimaryTextColor"))
                Spacer()
            }
            
            VStack(spacing: 12) {
                // Dark Mode Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("dark_mode".localized)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(Color("PrimaryTextColor"))
                        Text("dark_mode_description".localized)
                            .font(.caption)
                            .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $settingsManager.isDarkModeEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: Color("ToggleAccentColor")))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("SurfaceColor"))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color("SurfaceColor"))
        )
    }
    
    private var peakAppSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "mountain.2.fill")
                    .foregroundColor(Color("PrimaryTextColor"))
                Text("peak_app_title".localized)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color("PrimaryTextColor"))
                Spacer()
            }
            
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("peak_app_description".localized)
                            .font(.body)
                            .foregroundColor(Color("PrimaryTextColor"))
                    }
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("SurfaceColor"))
                )
                
                Button(action: {
                    // Universal App Store link (works for all countries)
                    if let url = URL(string: "https://apps.apple.com/app/peak-altimetro-gps-barometro/id6477742031") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.down.app.fill")
                            .foregroundColor(.white)
                        Text("download_peak_app".localized)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.8))
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color("SurfaceColor"))
        )
    }

    private var adsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(Color("PrimaryTextColor"))
                Text("ads_section_title".localized)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color("PrimaryTextColor"))
                Spacer()
            }

            VStack(spacing: 12) {
                rewardRow

                if adManager.consent.isPrivacyOptionsRequired {
                    Button(action: {
                        Task { await adManager.consent.presentPrivacyOptions() }
                    }) {
                        HStack {
                            Image(systemName: "shield.lefthalf.filled")
                                .foregroundColor(Color("PrimaryTextColor"))
                            Text("manage_privacy".localized)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(Color("PrimaryTextColor"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(Color("PrimaryTextColor").opacity(0.5))
                                .font(.caption)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color("SurfaceColor"))
                        )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color("SurfaceColor"))
        )
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            rewardClock = Date()
        }
    }

    @ViewBuilder
    private var rewardRow: some View {
        if iapManager.isProUser {
            // I Pro non hanno pubblicità: offrire "rimuovi ads" non avrebbe senso.
            EmptyView()
        } else if adManager.adsRemoved {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ads_removed_active".localized)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color("PrimaryTextColor"))
                    Text(remainingText)
                        .font(.caption)
                        .foregroundColor(Color("PrimaryTextColor").opacity(0.7))
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("SurfaceColor"))
            )
        } else {
            Button(action: {
                adManager.presentRewardedRemoveAds(source: "settings")
            }) {
                HStack {
                    Image(systemName: "play.rectangle.fill")
                        .foregroundColor(.white)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("watch_ad_remove_ads".localized)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        Text("watch_ad_remove_ads_subtitle".localized)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                    if !adManager.rewarded.isAdReady {
                        ProgressView()
                            .tint(.white)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.85))
                )
            }
            .disabled(!adManager.rewarded.isAdReady)
            .opacity(adManager.rewarded.isAdReady ? 1.0 : 0.6)
            .onAppear {
                guard !didLogSettingsRewardImpression else { return }
                didLogSettingsRewardImpression = true
                Analytics.logEvent("rewarded_cta_shown", parameters: ["source": "settings"])
            }
        }
    }

    private var remainingText: String {
        _ = rewardClock // re-render on timer tick
        guard let remaining = adManager.removeAdsRemaining else {
            return ""
        }
        let minutes = Int(ceil(remaining / 60))
        let template = "ads_removed_remaining".localized
        return String(format: template, minutes)
    }
}

#Preview {
    SettingsView(audioManager: AudioManager.shared)
        .environmentObject(AdManager.shared)
}