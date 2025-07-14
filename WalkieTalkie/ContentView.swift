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
    @State private var isTransmitting = false
    @State private var frequency = "428.283"
    @State private var showingPermissionAlert = false
    @State private var isRadioMode = false
    @State private var frequencyChangeAnimation = false
    
    // Frequenze realistiche per walkie-talkie
    private let availableFrequencies = [
        "428.283", "428.325", "428.367", "428.409", "428.451",
        "428.493", "428.535", "428.577", "428.619", "428.661",
        "428.703", "428.745", "428.787", "428.829", "428.871",
        "429.913", "429.955", "429.997", "430.039", "430.081"
    ]
    @State private var currentFrequencyIndex = 0
    @State private var selectedTab = 0
    @State private var showingConnectionAlert = false
    @State private var showingErrorAlert = false
    @State private var isPoweredOn = true
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Sfondo giallo
                Color(red: 1.0, green: 0.84, blue: 0.0)
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
                        .frame(height: 100)
                }
                
                // Tab bar fissa in basso
                VStack {
                    Spacer()
                    tabBarView
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            // Toggle modalità Walkie/Radio
            Button(action: {
                isRadioMode.toggle()
                if isRadioMode {
                    // Ferma walkie-talkie e avvia radio
                    multipeerManager.stopTransmitting()
                    if let firstStation = radioManager.radioStations.first {
                        radioManager.playStation(firstStation)
                    }
                    // Ferma il rumore bianco in modalità FM
                    audioManager.updateBackgroundAudioForMode(isRadioMode: true)
                } else {
                    // Ferma radio
                    radioManager.stopRadio()
                    // Riavvia il rumore bianco in modalità walkie-talkie
                    audioManager.updateBackgroundAudioForMode(isRadioMode: false)
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: isRadioMode ? "radio" : "antenna.radiowaves.left.and.right")
                        .foregroundColor(.black)
                        .font(.title3)
                    Text(isRadioMode ? "FM" : "WT")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
            
            VStack {
                Text(isRadioMode ? "radio_fm".localized : "frequency_owner".localized)
                    .font(.caption)
                    .foregroundColor(.black)
                Text(isRadioMode ? (radioManager.currentStation?.name ?? "radio_fm".localized) : "walkie_talkie".localized)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
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
    
    private var connectionStatusView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if isRadioMode {
                    // Modalità FM - Mostra info stazione radio
                    HStack {
                        Text("station".localized + ": \(radioManager.currentStation?.name ?? "no_station".localized)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                        
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
                        .foregroundColor(.black.opacity(0.8))
                    
                    Text("country".localized + ": \(radioManager.currentStation?.country ?? "--")")
                        .font(.caption2)
                        .foregroundColor(.black.opacity(0.6))
                } else {
                    // Modalità Walkie-Talkie - Mostra info connessione
                    HStack {
                        Text("device".localized + ": \(multipeerManager.localPeerID.displayName)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                        
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
                    
                    Text("status".localized + ": \(multipeerManager.connectionStatus)")
                        .font(.caption)
                        .foregroundColor(multipeerManager.connectedPeers.isEmpty ? .red : .green)
                    
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
                .fill(isRadioMode ? (radioManager.isPlaying ? Color.green : Color.orange) : (multipeerManager.connectedPeers.isEmpty ? Color.red : Color.green))
                .frame(width: 12, height: 12)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.3))
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
                    .frame(height: 100)
                
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
                    
                    Text("\(multipeerManager.connectedPeers.count)")
                        .foregroundColor(.white)
                        .font(.caption)
                    
                    Image(systemName: multipeerManager.connectedPeers.count > 0 ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                        .foregroundColor(.white)
                        .font(.caption)
                }
                .padding(.horizontal, 15)
                .padding(.top, -25)
                
                // Frequenza principale o info radio
                if isRadioMode {
                    VStack(spacing: 4) {
                        Text(radioManager.currentStation?.frequency ?? "---.--")
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
        }
        .padding(.top, 20)
    }
    
    private var playbackControlsView: some View {
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
                
                // Previous station
                Button(action: {
                    radioManager.previousStation()
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
                
                // Next station
                Button(action: {
                    radioManager.nextStation()
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
        .padding(.top, 20)
    }
    
    private var speakerAreaView: some View {
        VStack(spacing: 30) {
            // Griglia di punti per simulare speaker - aumentata
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                ForEach(0..<88, id: \.self) { _ in
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
                        .frame(width: 140, height: 140)
                    
                    // Cerchio interno
                    Circle()
                        .fill(isRadioMode ? Color.gray.opacity(0.3) : Color.white)
                        .frame(width: 120, height: 120)
                    
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
                            .frame(width: 140, height: 140)
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
                    if multipeerManager.connectedPeers.isEmpty {
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
                            Text("\(multipeerManager.connectedPeers.count) " + "devices_connected".localized)
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
        .padding(.vertical, 20)
    }
    
    private var tabBarView: some View {
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
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.black)
        )
        .padding(.horizontal, 20)
         .padding(.bottom, 30)
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
        .onAppear {
            // Inizializza l'indice della frequenza corrente
            if let index = availableFrequencies.firstIndex(of: frequency) {
                currentFrequencyIndex = index
            }
            
            // Controlla i permessi all'avvio
            checkMicrophonePermission()
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
    }
    
    private func nextFrequency() {
        currentFrequencyIndex = (currentFrequencyIndex + 1) % availableFrequencies.count
        frequency = availableFrequencies[currentFrequencyIndex]
        
        // Feedback realistico per cambio frequenza
        playFrequencyChangeSound()
        showFrequencyChangeIndicator()
        
        // Gestione audio per frequenze non-home
        handleFrequencyAudio()
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
        guard !multipeerManager.connectedPeers.isEmpty else {
            multipeerManager.lastError = WalkieTalkieError.noConnectedPeers
            hapticManager.error()
            return
        }
        
        // Verifica permessi audio prima di iniziare la trasmissione
        guard audioManager.hasAudioPermission else {
            checkMicrophonePermission()
            hapticManager.warning()
            return
        }
        
        hapticManager.transmissionStarted()
        isTransmitting = true
        multipeerManager.startTransmitting()
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
}

