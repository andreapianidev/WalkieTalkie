//creato da Andrea Piani - Immaginet Srl - 12/07/25 - https://www.andreapiani.com - ContentView.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 12/07/25.
//

import SwiftUI
import MultipeerConnectivity
import AudioToolbox

struct ContentView: View {
    @StateObject private var multipeerManager = MultipeerManager()
    @StateObject private var audioManager = AudioManager.shared
    @StateObject private var radioManager = RadioManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var hapticManager = HapticManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var sleepTimerManager = SleepTimerManager.shared
    @StateObject private var crossPlatformManager = TalkyCrossPlatformManager.shared
    @EnvironmentObject private var adManager: AdManager
    @State private var frequencyChangeCount = 0
    @State private var stationChangeCount = 0
    @State private var interstitialDebounceTask: Task<Void, Never>?
    @State private var isTransmitting = false
    @State private var frequency = "428.283"
    @State private var showingPermissionAlert = false
    @AppStorage("talky_is_radio_mode") private var isRadioMode = false
    @State private var frequencyChangeAnimation = false
    @State private var showBrowser = false
    @State private var showSleepTimer = false
    @State private var showPaywall = false
    @State private var showModeSwitchHint = false
    @AppStorage("isOnboardingComplete") private var isOnboardingComplete = false
    
    // Frequenze realistiche per walkie-talkie
    private let availableFrequencies = [
        "428.283", "428.325", "428.367", "428.409", "428.451",
        "428.493", "428.535", "428.577", "428.619", "428.661",
        "428.703", "428.745", "428.787", "428.829", "428.871",
        "429.913", "429.955", "429.997", "430.039", "430.081"
    ]
    @State private var currentFrequencyIndex = 0
    @State private var selectedTab = 0

    /// iPhone SE/8 e simili (≤667pt): il layout a misure fisse sforava lo schermo
    /// e la tab bar risultava tagliata/irraggiungibile (recensioni App Store).
    private var isCompactHeight: Bool { UIScreen.main.bounds.height < 700 }
    @State private var showingConnectionAlert = false
    @State private var showingErrorAlert = false
    @State private var isPoweredOn = true

    private var connectedWalkiePeerCount: Int {
        multipeerManager.connectedPeers.count + crossPlatformManager.connectedPeerCount
    }

    private var hasWalkieConnection: Bool {
        connectedWalkiePeerCount > 0
    }

    private var walkieConnectionStatusText: String {
        if connectedWalkiePeerCount == 0 {
            return multipeerManager.connectionStatus
        }
        if crossPlatformManager.connectedPeerCount > 0 && multipeerManager.connectedPeers.isEmpty {
            return "Connesso Android (\(crossPlatformManager.connectedPeerCount))"
        }
        if crossPlatformManager.connectedPeerCount > 0 {
            return "Connesso (\(connectedWalkiePeerCount), Android \(crossPlatformManager.connectedPeerCount))"
        }
        return multipeerManager.connectionStatus
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Sfondo adattivo (animato per i temi blackHole/galaxy)
                AnimatedBackgroundView()
                    .ignoresSafeArea()
                
                // Contenuto principale
                VStack(spacing: 0) {
                    if selectedTab == 0 {
                        // Main walkie talkie view
                        VStack(spacing: 0) {
                            // Header
                            headerView
                            
                            // Connection status textbox
                            connectionStatusView
                            
                            // Display frequenza
                            frequencyDisplayView
                            
                            // Controlli playback
                            playbackControlsView
                            
                            Spacer()
                            
                            // Area speaker con griglia punti
                            speakerAreaView
                            
                            Spacer()
                        }
                    } else if selectedTab == 1 {
                        // Explore view
                        ExploreView(multipeerManager: multipeerManager)
                    } else if selectedTab == 2 {
                        // Friends/Connections view
                        ConnectionsView(multipeerManager: multipeerManager)
                    } else if selectedTab == 3 {
                        // Settings view
                        SettingsView(audioManager: audioManager)
                    } else {
                        // Placeholder per altri tab
                        VStack {
                            Spacer()
                            Text("coming_soon".localized)
                            .font(.title)
                            .foregroundColor(.black)
                        Text(getTabTitle(selectedTab))
                            .font(.subheadline)
                            .foregroundColor(.black.opacity(0.7))
                            Spacer()
                        }
                    }

                    // Spazio per la tab bar
                    Spacer()
                        .frame(height: isCompactHeight ? 76 : 100)
                }
                
                // Tab bar fissa in basso
                VStack {
                    Spacer()
                    tabBarView
                }

                // First-run coach overlay (non-blocking)
                if !settingsManager.hasSeenFirstRunCoach && selectedTab == 0 && !isRadioMode {
                    FirstRunCoachView(
                        connectedPeersCount: connectedWalkiePeerCount,
                        isTransmitting: isTransmitting,
                        onGoToExplore: {
                            withAnimation { selectedTab = 1 }
                        },
                        onDismiss: dismissFirstRunCoach
                    )
                    .allowsHitTesting(true)
                }

                // Mode switch discovery hint (one-time, after onboarding)
                if showModeSwitchHint {
                    ModeSwitchHintOverlay(isShown: $showModeSwitchHint)
                        .zIndex(100)
                        .transition(.opacity)
                }

                // Rewarded CTA pill: shown for 8s after the user sees an interstitial.
                // Gives users who just experienced an ad a one-tap path to remove them.
                if adManager.showRewardedPill {
                    rewardedPillOverlay
                        .zIndex(90)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onAppear {
                maybeShowModeSwitchHint()
                restorePersistedAudioMode()
            }
        }
    }

    /// Aligns the background-audio (white noise) state with the persisted mode
    /// after a cold launch. Non auto-plays radio: solo coerenza dello stato audio.
    private func restorePersistedAudioMode() {
        audioManager.updateBackgroundAudioForMode(isRadioMode: isRadioMode)
    }

    /// Shows the WT/FM toggle discovery hint once, only after onboarding is done.
    private func maybeShowModeSwitchHint() {
        guard isOnboardingComplete else { return }
        guard !UserDefaults.standard.bool(forKey: "talky_seen_mode_switch_hint") else { return }
        guard !showModeSwitchHint else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.25)) {
                showModeSwitchHint = true
            }
        }
    }

    private func dismissFirstRunCoach() {
        guard !settingsManager.hasSeenFirstRunCoach else { return }
        settingsManager.hasSeenFirstRunCoach = true
        FirstTimeEventTracker.shared.fireOnce(FirstTimeEventTracker.Events.firstRunCoachDismissed)
    }
    
    private var headerView: some View {
        HStack {
            // Segmented toggle: Walkie / Radio — entrambe le modalità visibili
            // per scoperta immediata della feature radio (anche da App Review).
            HStack(spacing: 0) {
                modeSegment(
                    isActive: !isRadioMode,
                    icon: "antenna.radiowaves.left.and.right",
                    label: "walkie_talkie".localized,
                    targetRadio: false
                )
                modeSegment(
                    isActive: isRadioMode,
                    icon: "radio",
                    label: "radio_fm".localized,
                    targetRadio: true
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black.opacity(0.12), lineWidth: 0.5)
            )
            
            Spacer()
            
            VStack {
                Text(isRadioMode ? "radio_fm".localized : "frequency_owner".localized)
                    .font(.caption)
                    .foregroundColor(Color("PrimaryTextColor"))
                Text(isRadioMode ? (radioManager.currentStation?.name ?? "radio_fm".localized) : "walkie_talkie".localized)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color("PrimaryTextColor"))
            }
            
            Spacer()
            
            Button(action: {
                    notificationManager.toggleNotifications()
                }) {
                    Image(systemName: notificationManager.notificationsEnabled ? "bell.fill" : "bell.slash")
                        .foregroundColor(notificationManager.notificationsEnabled ? .blue : .gray)
                        .font(.title2)
                }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    @ViewBuilder
    private func modeSegment(isActive: Bool, icon: String, label: String, targetRadio: Bool) -> some View {
        Button(action: { switchMode(toRadio: targetRadio) }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundColor(isActive ? Color("PrimaryTextColor") : Color("PrimaryTextColor").opacity(0.55))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.white.opacity(0.85) : Color.clear)
                    .shadow(color: isActive ? Color.black.opacity(0.12) : .clear, radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : .isButton)
    }

    private func switchMode(toRadio newRadioMode: Bool) {
        if showModeSwitchHint {
            UserDefaults.standard.set(true, forKey: "talky_seen_mode_switch_hint")
            withAnimation(.easeIn(duration: 0.2)) {
                showModeSwitchHint = false
            }
        }
        guard newRadioMode != isRadioMode else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            isRadioMode = newRadioMode
        }
        if newRadioMode {
            multipeerManager.stopTransmitting()
            radioManager.playStation(radioManager.resumeStation)
            audioManager.updateBackgroundAudioForMode(isRadioMode: true)
        } else {
            radioManager.stopRadio()
            audioManager.updateBackgroundAudioForMode(isRadioMode: false)
        }
        hapticManager.lightTap()
    }

    private var connectionStatusView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if isRadioMode {
                    // Modalità FM - Mostra info stazione radio
                    HStack {
                        Text("station".localized + ": \(radioManager.currentStation?.name ?? "no_station".localized)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color("PrimaryTextColor"))
                        
                        if radioManager.isBuffering {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("buffering".localized)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    Text("genre".localized + ": \(radioManager.currentStation?.genre ?? "--")")
                        .font(.caption)
                        .foregroundColor(Color("PrimaryTextColor").opacity(0.8))
                    
                    HStack(spacing: 6) {
                        Text("country".localized + ": \(radioManager.currentStation?.country ?? "--")")
                            .font(.caption2)
                            .foregroundColor(Color("PrimaryTextColor").opacity(0.6))

                        if let station = radioManager.currentStation {
                            HStack(spacing: 2) {
                                Image(systemName: "wave.3.right")
                                    .font(.caption2)
                                Text(station.quality.rawValue)
                                    .font(.caption2.monospaced())
                            }
                            .foregroundColor(Color("PrimaryTextColor").opacity(0.6))
                        }
                    }
                } else {
                    // Modalità Walkie-Talkie - Mostra info connessione
                    HStack {
                        Text("device".localized + ": \(multipeerManager.localPeerID.displayName)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color("PrimaryTextColor"))
                        
                        if multipeerManager.isBrowsing {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("scanning".localized)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    Text("status".localized + ": \(walkieConnectionStatusText)")
                        .font(.caption)
                        .foregroundColor(hasWalkieConnection ? .green : .red)
                    
                    // Mostra errore se presente
                    if let error = multipeerManager.lastError {
                        Text("⚠️ \(error.localizedDescription)")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .lineLimit(1)
                    } else {
                        Text("no_error".localized)
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
            
            Circle()
                .fill(isRadioMode ? (radioManager.isPlaying ? Color.green : Color.orange) : (hasWalkieConnection ? Color.green : Color.red))
                .frame(width: 12, height: 12)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("SurfaceColor"))
        )
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    private var frequencyDisplayView: some View {
        VStack(spacing: 8) {
            // Display principale frequenza
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.black)
                    .frame(height: isCompactHeight ? 80 : 100)
                
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text("channel_1".localized)
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    Text("\(connectedWalkiePeerCount)")
                        .foregroundColor(.white)
                        .font(.caption)
                    
                    Image(systemName: hasWalkieConnection ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                        .foregroundColor(.white)
                        .font(.caption)
                }
                .padding(.horizontal, 15)
                .padding(.top, -25)
                
                // Frequenza principale o info radio
                if isRadioMode {
                    VStack(spacing: 4) {
                        Text(radioManager.currentStation?.displayLabel ?? "---.--")
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundColor(.yellow)
                        
                        Text(radioManager.currentStation?.country ?? "")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        if radioManager.isBuffering {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(.yellow)
                                Text("buffering".localized)
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                    .padding(.top, 10)
                } else {
                    Text(isPoweredOn ? frequency : "OFF")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(isPoweredOn ? .yellow : .red)
                    .padding(.top, 10)
                    .scaleEffect(frequencyChangeAnimation ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: frequencyChangeAnimation)
                    .opacity(isPoweredOn ? 1.0 : 0.7)
                }
                
                // Indicatori inferiori
                HStack {
                    Text("en".localized)
                    .foregroundColor(.white)
                    .font(.caption)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        ForEach(0..<5) { _ in
                            Circle()
                                .fill(Color.gray.opacity(0.5))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 8)
                .padding(.top, 25)
            }
            .padding(.horizontal, 20)
            .simultaneousGesture(
                // Swipe orizzontale: solo in modalità radio, prev/next stazione.
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        guard isRadioMode else { return }
                        if value.translation.width < -30 {
                            radioManager.nextStation()
                            maybeShowInterstitialOnStationChange()
                        } else if value.translation.width > 30 {
                            radioManager.previousStation()
                            maybeShowInterstitialOnStationChange()
                        }
                    }
            )
        }
        .padding(.top, 20)
    }

    private var playbackControlsView: some View {
        VStack(spacing: 16) {
            if isRadioMode {
                radioSecondaryControlsRow
            }

            mainPlaybackRow
        }
        .padding(.top, 20)
    }

    /// Riga superiore (solo radio): Browse, Preferito, Sleep Timer.
    private var radioSecondaryControlsRow: some View {
        HStack(spacing: 24) {
            // Browse stations
            Button(action: {
                HapticManager.shared.lightTap()
                showBrowser = true
            }) {
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 44, height: 44)

                    Image(systemName: "list.bullet")
                        .foregroundColor(.white)
                        .font(.title3)
                }
            }
            .accessibilityLabel("browse_stations".localized)

            Spacer()

            // Favorite toggle per la stazione corrente
            if let station = radioManager.currentStation {
                Button(action: {
                    HapticManager.shared.lightTap()
                    radioManager.toggleFavorite(station)
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 44, height: 44)

                        Image(systemName: radioManager.isFavorite(station) ? "star.fill" : "star")
                            .foregroundColor(radioManager.isFavorite(station) ? .yellow : .white)
                            .font(.title3)
                    }
                }
                .accessibilityLabel("favorites".localized)
            }

            Spacer()

            // Sleep timer
            Button(action: {
                HapticManager.shared.lightTap()
                showSleepTimer = true
            }) {
                HStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 44, height: 44)

                        Image(systemName: sleepTimerManager.isActive ? "moon.zzz.fill" : "moon.zzz")
                            .foregroundColor(sleepTimerManager.isActive ? .yellow : .white)
                            .font(.title3)
                    }

                    if sleepTimerManager.isActive {
                        Text(sleepTimerManager.formattedRemaining)
                            .font(.caption2.monospaced())
                            .foregroundColor(.yellow)
                    }
                }
            }
            .accessibilityLabel("sleep_timer".localized)
            .accessibilityValue(sleepTimerManager.isActive ? sleepTimerManager.formattedRemaining : "")
        }
        .padding(.horizontal, 30)
    }

    /// Riga principale dei controlli (radio o walkie talkie).
    private var mainPlaybackRow: some View {
        HStack(spacing: 20) {
            if isRadioMode {
                // Controlli Radio FM

                // Volume down
                Button(action: {
                    let newVolume = max(0.0, radioManager.volume - 0.1)
                    radioManager.setVolume(newVolume)
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 50, height: 50)

                        Image(systemName: "speaker.minus")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                }

                // Previous station (tap: previous, long press: jump -10)
                Button(action: {
                    radioManager.previousStation()
                    maybeShowInterstitialOnStationChange()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 50, height: 50)

                        Image(systemName: "backward.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                        radioManager.jumpStations(by: -10)
                        HapticManager.shared.lightTap()
                    }
                )

                // Play/Pause
                Button(action: {
                    if radioManager.isPlaying {
                        radioManager.pauseRadio()
                    } else {
                        radioManager.resumeRadio()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(radioManager.isPlaying ? Color.red : Color.green)
                            .frame(width: 60, height: 60)

                        Image(systemName: radioManager.isPlaying ? "pause.fill" : "play.fill")
                            .foregroundColor(.white)
                            .font(.title)
                    }
                }

                // Next station (tap: next, long press: jump +10)
                Button(action: {
                    radioManager.nextStation()
                    maybeShowInterstitialOnStationChange()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 50, height: 50)

                        Image(systemName: "forward.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                        radioManager.jumpStations(by: 10)
                        HapticManager.shared.lightTap()
                    }
                )

                // Volume up
                Button(action: {
                    let newVolume = min(1.0, radioManager.volume + 0.1)
                    radioManager.setVolume(newVolume)
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 50, height: 50)

                        Image(systemName: "speaker.plus")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                }

            } else {
                // Controlli Walkie-Talkie originali
                
                // Home frequency button
                Button(action: {
                    if isPoweredOn {
                        hapticManager.mediumTap()
                        returnToHomeFrequency()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(currentFrequencyIndex == 0 ? Color.green : Color.black)
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "house.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                }
                .opacity(isPoweredOn ? 1.0 : 0.3)
                .disabled(!isPoweredOn)
                
                // Previous button
                Button(action: {
                    if isPoweredOn {
                        hapticManager.mediumTap()
                        previousFrequency()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "backward.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                }
                .opacity(isPoweredOn ? 1.0 : 0.3)
                .disabled(!isPoweredOn)
                
                // forward button
                Button(action: {
                    if isPoweredOn {
                        hapticManager.mediumTap()
                        nextFrequency()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "forward.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                }
                .opacity(isPoweredOn ? 1.0 : 0.3)
                .disabled(!isPoweredOn)
                
                // Power button
                Button(action: {
                    hapticManager.lightTap()
                    togglePower()
                }) {
                    ZStack {
                        Circle()
                            .fill(isPoweredOn ? Color.green : Color.red)
                            .frame(width: 50, height: 50)

                        Image(systemName: "power")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                }
            }
        }
    }

    private var speakerAreaView: some View {
        VStack(spacing: isCompactHeight ? 14 : 30) {
            // Griglia di punti per simulare speaker - aumentata
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                ForEach(0..<(isCompactHeight ? 40 : 88), id: \.self) { _ in
                    Circle()
                        .fill(Color.black)
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 40)
            
            // Push to talk button migliorato con gesture (disabilitato in modalità FM)
            VStack(spacing: 15) {
                ZStack {
                    // Cerchio esterno
                    Circle()
                        .fill(isRadioMode ? Color.gray.opacity(0.5) : (isTransmitting ? Color.red : Color.black))
                        .frame(width: isCompactHeight ? 116 : 140, height: isCompactHeight ? 116 : 140)

                    // Cerchio interno
                    Circle()
                        .fill(isRadioMode ? Color.gray.opacity(0.3) : Color.white)
                        .frame(width: isCompactHeight ? 98 : 120, height: isCompactHeight ? 98 : 120)
                    
                    // Testo centrale
                    VStack(spacing: 4) {
                        if isRadioMode {
                            Text("radio_mode".localized)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.gray)
                            Text("radio_fm_caps".localized)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                            Text("active".localized)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        } else {
                            Text(isTransmitting ? "release".localized : "hold".localized)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                            Text(isTransmitting ? "to_send".localized : "pressed".localized)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.black)
                            Text(isTransmitting ? "" : "to_talk".localized)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.black)
                        }
                    }
                    
                    // Effetto pulsazione quando trasmette (solo in modalità walkie-talkie)
                    if isTransmitting && !isRadioMode {
                        Circle()
                            .stroke(Color.red.opacity(0.6), lineWidth: 3)
                            .frame(width: isCompactHeight ? 116 : 140, height: isCompactHeight ? 116 : 140)
                            .scaleEffect(isTransmitting ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isTransmitting)
                    }
                }
                .scaleEffect(isTransmitting && !isRadioMode ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isTransmitting)
                .opacity(isPoweredOn && currentFrequencyIndex == 0 ? 1.0 : 0.3)
                .gesture(
                    // Disabilita gesture in modalità FM, quando spento, o su frequenze non-home
                    (isRadioMode || !isPoweredOn || currentFrequencyIndex != 0) ? nil : DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isTransmitting && isPoweredOn && currentFrequencyIndex == 0 {
                                // Controlla permessi prima di trasmettere
                                if !audioManager.hasAudioPermission {
                                    checkMicrophonePermission()
                                    return
                                }
                                startTransmitting()
                            }
                        }
                        .onEnded { _ in
                            if isTransmitting {
                                stopTransmitting()
                            }
                        }
                )
                
                // Status sotto il pulsante
                VStack(spacing: 4) {
                    if !hasWalkieConnection {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            Text("no_connection".localized)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("\(connectedWalkiePeerCount) " + "devices_connected".localized)
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    
                    if isTransmitting {
                        HStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .scaleEffect(1.2)
                                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isTransmitting)
                            Text("transmission_in_progress".localized)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                    } else if multipeerManager.isReceiving {
                        HStack {
                            Image(systemName: "speaker.wave.2")
                                .foregroundColor(.blue)
                                .scaleEffect(1.2)
                                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: multipeerManager.isReceiving)
                            Text("reception_in_progress".localized)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    } else {
                        Text("no_transmission".localized)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isCompactHeight ? 8 : 20)
    }

    private var tabBarView: some View {
        VStack(spacing: 0) {
            // Peak promotion button integrated with tab bar (nascosto sugli
            // schermi compatti: ruba altezza alla tab bar su iPhone SE/8)
            if !isCompactHeight {
                peakAppPromotionBanner
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }

            HStack {
                // Tab buttons
                TabButton(icon: "grid.circle.fill", title: "talk".localized, isSelected: selectedTab == 0) {
                    selectedTab = 0
                }

                TabButton(icon: "magnifyingglass", title: "explore".localized, isSelected: selectedTab == 1) {
                    selectedTab = 1
                }

                TabButton(icon: "antenna.radiowaves.left.and.right", title: "connections".localized, isSelected: selectedTab == 2) {
                    selectedTab = 2
                }

                TabButton(icon: "gearshape.fill", title: "settings_tab".localized, isSelected: selectedTab == 3) {
                    selectedTab = 3
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, isCompactHeight ? 10 : 15)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.black)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, isCompactHeight ? 12 : 30)
        }
        .onAppear {
            setupMultipeerConnection()
        }
        .alert("connection_request".localized, isPresented: $showingConnectionAlert) {
            Button("accept".localized) {
                multipeerManager.acceptInvitation()
            }
            Button("decline".localized) {
                multipeerManager.declineInvitation()
            }
        } message: {
            if let invitation = multipeerManager.receivedInvitation {
                Text("\(invitation.0.displayName) " + "wants_to_connect".localized)
            }
        }
        .onReceive(multipeerManager.$receivedInvitation) { invitation in
            showingConnectionAlert = invitation != nil
        }
        .alert("error".localized, isPresented: $showingErrorAlert) {
            Button("ok".localized) {
                multipeerManager.lastError = nil
            }
        } message: {
            if let error = multipeerManager.lastError {
                Text(error.localizedDescription)
            }
        }
        .alert("microphone_permission_required".localized, isPresented: $showingPermissionAlert) {
            Button("settings".localized) {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("retry".localized) {
                audioManager.requestAudioPermission()
            }
            Button("cancel".localized, role: .cancel) { }
        } message: {
            Text("microphone_permission_message".localized)
        }
        .onReceive(multipeerManager.$lastError) { error in
            showingErrorAlert = error != nil
        }
        .onReceive(audioManager.$hasAudioPermission) { hasPermission in
            if !hasPermission {
                showingPermissionAlert = true
            }
        }
        .sheet(isPresented: $showBrowser) {
            StationBrowserSheet()
        }
        .sheet(isPresented: $showSleepTimer) {
            SleepTimerSheet(onUnlockTap: {
                showSleepTimer = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showPaywall = true
                }
            })
        }
        .fullScreenCover(isPresented: $showPaywall, onDismiss: {
            radioManager.blockedByPaywall = false
        }) {
            PaywallView(trigger: "radio_pro_station")
        }
        .onReceive(radioManager.$blockedByPaywall) { blocked in
            // Se la radio segnala paywall e il browser non è in primo piano, mostralo qui.
            if blocked && !showBrowser {
                showPaywall = true
            }
        }
        .onAppear {
            // Inizializza l'indice della frequenza corrente
            if let index = availableFrequencies.firstIndex(of: frequency) {
                currentFrequencyIndex = index
            }

            // Controlla i permessi all'avvio
            checkMicrophonePermission()
        }
    }


    // MARK: - Peak App Promotion Button
    private var peakAppPromotionBanner: some View {
        Button(action: {
            openPeakApp()
        }) {
            HStack(spacing: 8) {
                Text("⛰️")
                    .font(.caption)

                Text("peak_altimeter_free".localized)
                    .font(.caption2)
                    .foregroundColor(.gray)

                Text("•")
                    .font(.caption2)
                    .foregroundColor(.gray)

                Text("peak_walkie_ai_description".localized)
                    .font(.caption2)
                    .foregroundColor(.gray)

                Spacer()

                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.black.opacity(0.8))
            )
        }
        .buttonStyle(.plain)
    }

    private func openPeakApp() {
        // Universal App Store link (works for all countries)
        let peakAppURL = "https://apps.apple.com/us/app/peak-altimeter-gps-barometer/id6477742031"

        if let url = URL(string: peakAppURL) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Rewarded CTA Pill

    private var rewardedPillOverlay: some View {
        VStack {
            Spacer()
            Button(action: {
                adManager.presentRewardedRemoveAds(source: "post_interstitial")
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("watch_ad_remove_ads".localized)
                            .font(.system(size: 14, weight: .semibold))
                        Text("watch_ad_remove_ads_subtitle".localized)
                            .font(.system(size: 12))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.blue.opacity(0.9))
                        .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
            .buttonStyle(.plain)
            .disabled(!adManager.rewarded.isAdReady)
            .opacity(adManager.rewarded.isAdReady ? 1.0 : 0.5)
        }
    }

    // MARK: - Helper Functions
    
    private func previousFrequency() {
        currentFrequencyIndex = (currentFrequencyIndex - 1 + availableFrequencies.count) % availableFrequencies.count
        frequency = availableFrequencies[currentFrequencyIndex]

        // Feedback realistico per cambio frequenza
        playFrequencyChangeSound()
        showFrequencyChangeIndicator()

        // Gestione audio per frequenze non-home
        handleFrequencyAudio()

        FirstTimeEventTracker.shared.fireOnce(
            FirstTimeEventTracker.Events.channelChange,
            parameters: ["direction": "prev"]
        )

        maybeShowInterstitialOnChannelChange()
        ThemeSoundManager.shared.play(.channelChange)
    }

    private func nextFrequency() {
        currentFrequencyIndex = (currentFrequencyIndex + 1) % availableFrequencies.count
        frequency = availableFrequencies[currentFrequencyIndex]

        // Feedback realistico per cambio frequenza
        playFrequencyChangeSound()
        showFrequencyChangeIndicator()

        // Gestione audio per frequenze non-home
        handleFrequencyAudio()

        FirstTimeEventTracker.shared.fireOnce(
            FirstTimeEventTracker.Events.channelChange,
            parameters: ["direction": "next"]
        )

        maybeShowInterstitialOnChannelChange()
        ThemeSoundManager.shared.play(.channelChange)
    }

    private func maybeShowInterstitialOnChannelChange() {
        // Never interrupt a live transmission or reception.
        guard !isTransmitting, !multipeerManager.isReceiving else { return }
        frequencyChangeCount += 1
        // Skip the very first change after launch.
        guard frequencyChangeCount > 1 else { return }
        scheduleInterstitialAfterIdle()
    }

    /// Radio counterpart of `maybeShowInterstitialOnChannelChange`. Fires only on
    /// explicit user station changes (tuner prev/next + swipe) — never on the
    /// auto-resume that runs when switching into radio mode. The actual cadence
    /// (180s min interval, 5/day) is enforced centrally by AdManager, so these
    /// extra call sites only widen the pool of eligible moments, they don't raise
    /// the cap.
    private func maybeShowInterstitialOnStationChange() {
        stationChangeCount += 1
        // Skip the very first change so we never greet a fresh session with an ad.
        guard stationChangeCount > 1 else { return }
        scheduleInterstitialAfterIdle()
    }

    private func scheduleInterstitialAfterIdle() {
        interstitialDebounceTask?.cancel()
        interstitialDebounceTask = Task { @MainActor in
            let delay = UInt64(AdConfig.FrequencyCap.interstitialIdleDelay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            guard !isTransmitting, !multipeerManager.isReceiving else { return }
            adManager.showInterstitialIfAllowed()
            interstitialDebounceTask = nil
        }
    }
    
    private func playFrequencyChangeSound() {
        // Suono di "click" del selettore di frequenza
        AudioServicesPlaySystemSound(1104) // Suono di "click" del sistema
    }
    
    private func showFrequencyChangeIndicator() {
        // Breve animazione per indicare il cambio frequenza
        frequencyChangeAnimation = true
        
        // Reset dell'animazione dopo un breve delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            frequencyChangeAnimation = false
        }
    }
    
    private func returnToHomeFrequency() {
        // Torna alla frequenza principale (indice 0) per la comunicazione reale
        currentFrequencyIndex = 0
        frequency = availableFrequencies[0]
        
        // Feedback visivo
        showFrequencyChangeIndicator()
        
        // Suono di conferma
        playFrequencyChangeSound()
        
        // Gestione audio per frequenze non-home
        handleFrequencyAudio()
    }
    
    private func handleFrequencyAudio() {
        if currentFrequencyIndex == 0 {
            // Frequenza home: ferma l'audio casuale per permettere conversazioni
            audioManager.stopFrequencyAudio()
            // Riattiva il rumore bianco se abilitato nelle impostazioni
            audioManager.startBackgroundAudioIfNeeded()
        } else {
            // Frequenze non-home: ferma il rumore bianco e riproduci audio casuale in loop
            audioManager.stopBackgroundAudio()
            audioManager.playRandomFrequencyAudio()
        }
    }
    
    private func togglePower() {
        isPoweredOn.toggle()
        
        if !isPoweredOn {
            // Spegni tutto quando il walkie-talkie viene spento
            if isTransmitting {
                stopTransmitting()
            }
            
            // Disconnetti da tutti i peer
            multipeerManager.stopBrowsing()
            multipeerManager.stopAdvertising()
            
            // Ferma l'audio se in modalità radio
            if isRadioMode {
                radioManager.stopRadio()
            }
            
            // Ferma l'audio delle frequenze
            audioManager.stopFrequencyAudio()
            
            // Ferma il rumore bianco/audio di sottofondo
            audioManager.stopBackgroundAudio()
        } else {
            // Riaccendi le funzionalità quando viene riacceso
            multipeerManager.startBrowsing()
            multipeerManager.startAdvertising()
            
            // Ripristina il rumore bianco se abilitato nelle impostazioni
            audioManager.startBackgroundAudioIfNeeded()
            
            // Ripristina l'audio delle frequenze se necessario
            handleFrequencyAudio()
        }
    }
    
    private func checkMicrophonePermission() {
        if !audioManager.hasAudioPermission {
            showingPermissionAlert = true
        }
    }
    
    // MARK: - Private Methods
    
    private func setupMultipeerConnection() {
        // Verifica e richiedi permessi audio se necessario
        if !audioManager.hasAudioPermission {
            audioManager.requestAudioPermission()
        }
        
        // Richiedi permesso di rete locale prima di iniziare
        multipeerManager.requestLocalNetworkPermission()
        
        // Avvia advertising e browsing dopo un breve delay per permettere ai permessi di essere processati
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            multipeerManager.startAdvertising()
            multipeerManager.startBrowsing()
        }
    }
    
    private func startTransmitting() {
        FirstTimeEventTracker.shared.fireOnce(FirstTimeEventTracker.Events.pttPress)

        guard hasWalkieConnection else {
            multipeerManager.lastError = WalkieTalkieError.noConnectedPeers
            hapticManager.error()
            return
        }

        // Verifica permessi audio prima di iniziare la trasmissione
        guard audioManager.hasAudioPermission else {
            audioManager.requestAudioPermission()
            hapticManager.warning()
            return
        }

        hapticManager.transmissionStarted()
        isTransmitting = true
        // Avoid showing the app-open ad if the user backgrounds the app
        // while still pressing the PTT button.
        adManager.appOpen.suppressNextResume = true
        multipeerManager.startTransmitting()
        ThemeSoundManager.shared.play(.transmitStart)
    }
    
    private func stopTransmitting() {
        hapticManager.transmissionEnded()
        isTransmitting = false
        multipeerManager.stopTransmitting()
    }
    
    private func getTabTitle(_ index: Int) -> String {
        switch index {
        case 0: return "talk".localized
        case 1: return "explore".localized
        case 2: return "connections".localized
        case 3: return "settings_tab".localized
        default: return "unknown".localized
        }
    }
}

struct TabButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            if !isSelected {
                HapticManager.shared.selectionChanged()
            }
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .yellow : .white)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(isSelected ? .yellow : .white)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentView()
        .environmentObject(AdManager.shared)
}
