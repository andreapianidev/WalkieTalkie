//creato da Andrea Piani - Immaginet Srl - 2024 - https://www.andreapiani.com - SettingsView.swift

import SwiftUI

struct SettingsView: View {
    @ObservedObject var audioManager: AudioManager
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var showingInstructions = false
    @State private var showingPerformance = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            ScrollView {
                VStack(spacing: 20) {
                    // Notifications Section
                    notificationsSection
                    
                    // Audio Settings Section
                    audioSettingsSection
                    
                    // Performance Section
                    performanceSection
                    
                    // Instructions Section
                    instructionsSection
                    
                    // App Info Section
                    appInfoSection
                    
                    // Support Section
                    supportSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .background(Color.yellow)
        .onAppear {
            // Sync audio manager with settings manager
            if settingsManager.isBackgroundAudioEnabled {
                audioManager.setBackgroundVolume(settingsManager.backgroundVolume)
            } else {
                audioManager.setBackgroundVolume(0.0)
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "gearshape.fill")
                .foregroundColor(.black)
                .font(.title2)
            
            Spacer()
            
            VStack {
                Text("settings".localized)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                Text("configure_app".localized)
                    .font(.caption)
                    .foregroundColor(.black.opacity(0.7))
            }
            
            Spacer()
            
            Button(action: {
                showingInstructions.toggle()
            }) {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.black)
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
                    .foregroundColor(.black)
                Text("notifications".localized)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                Spacer()
            }
            
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(notificationManager.notificationsEnabled ? "disable_notifications".localized : "enable_notifications".localized)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                        Text("notification_description".localized)
                            .font(.caption)
                            .foregroundColor(.black.opacity(0.7))
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
                    .toggleStyle(SwitchToggleStyle(tint: .black))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.1))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.9))
        )
    }
    
    private var audioSettingsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "speaker.wave.2")
                    .foregroundColor(.black)
                Text("audio".localized)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                Spacer()
            }
            
            VStack(spacing: 12) {
                // Background Audio Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("white_noise".localized)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                        Text("background_audio".localized)
                            .font(.caption)
                            .foregroundColor(.black.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $settingsManager.isBackgroundAudioEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .black))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.1))
                )
                
                // Volume Slider (only when background audio is enabled)
                if settingsManager.isBackgroundAudioEnabled {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("noise_volume".localized)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.black)
                            Text("adjust_background_volume".localized)
                                .font(.caption)
                                .foregroundColor(.black.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        VStack {
                            Slider(value: $settingsManager.backgroundVolume, in: 0.05...0.5, step: 0.05)
                            .accentColor(.black)
                            
                            Text("\(Int(settingsManager.backgroundVolume * 100))%")
                                .font(.caption2)
                                .foregroundColor(.black.opacity(0.7))
                        }
                        .frame(width: 100)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.1))
                    )
                }
                
                // Haptic Feedback Setting
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("haptic_feedback".localized)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                        Text("vibration_on_buttons".localized)
                            .font(.caption)
                            .foregroundColor(.black.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $settingsManager.isHapticFeedbackEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .black))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.1))
                )
                
                // Auto Connect Setting
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("auto_connect".localized)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                        Text("auto_connect_description".localized)
                            .font(.caption)
                            .foregroundColor(.black.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $settingsManager.isAutoConnectEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .black))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.1))
                )
                
                // Voice Activation Setting
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("voice_activation".localized)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                        Text("voice_activation_description".localized)
                            .font(.caption)
                            .foregroundColor(.black.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $settingsManager.isVoiceActivationEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .black))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.1))
                )
                
                // Voice Activation Threshold (only when voice activation is enabled)
                if settingsManager.isVoiceActivationEnabled {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("voice_sensitivity".localized)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.black)
                            Text("voice_sensitivity_description".localized)
                                .font(.caption)
                                .foregroundColor(.black.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        VStack {
                            Slider(value: $settingsManager.voiceActivationThreshold, in: 0.1...0.8, step: 0.1)
                                .accentColor(.black)
                            
                            Text("\(Int(settingsManager.voiceActivationThreshold * 100))%")
                                .font(.caption2)
                                .foregroundColor(.black.opacity(0.7))
                        }
                        .frame(width: 100)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.1))
                    )
                }
                
                // Low Power Mode Setting
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("low_power_mode".localized)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                        Text("low_power_mode_description".localized)
                            .font(.caption)
                            .foregroundColor(.black.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $settingsManager.isLowPowerModeEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .black))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                         .fill(Color.black.opacity(0.1))
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
                 .fill(Color.white.opacity(0.9))
         )
     }
    
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.black)
                Text("performance".localized)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
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
                .fill(Color.white.opacity(0.9))
        )
        .sheet(isPresented: $showingPerformance) {
            PerformanceStatsView()
        }
    }
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.black)
                Text("how_to_use".localized)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
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
                .fill(Color.white.opacity(0.9))
        )
    }
    
    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "app.badge")
                    .foregroundColor(.black)
                Text("app_info".localized)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                Spacer()
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text("version".localized)
                        .font(.body)
                        .foregroundColor(.black)
                    Spacer()
                    Text("1.0.0")
                        .font(.body)
                        .foregroundColor(.black.opacity(0.7))
                }
                
                Divider()
                
                HStack {
                    Text("developed_by".localized)
                        .font(.body)
                        .foregroundColor(.black)
                    Spacer()
                    Text("Andrea Piani - Immaginet Srl")
                        .font(.body)
                        .foregroundColor(.black.opacity(0.7))
                }
                
                Divider()
                
                HStack {
                    Text("website".localized)
                        .font(.body)
                        .foregroundColor(.black)
                    Spacer()
                    Text("www.andreapiani.com")
                        .font(.body)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.1))
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.9))
        )
    }
    
    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.black)
                Text("support_development".localized)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                Spacer()
            }
            
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("support_description".localized)
                            .font(.body)
                            .foregroundColor(.black)
                    }
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.1))
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
                .fill(Color.white.opacity(0.9))
        )
    }
    
    private func instructionItem(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.black)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.black.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.1))
        )
    }
}

#Preview {
    SettingsView(audioManager: AudioManager.shared)
}