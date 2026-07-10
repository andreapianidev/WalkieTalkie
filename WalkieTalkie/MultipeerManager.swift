//creato da Andrea Piani - Immaginet Srl - 12/07/25 - https://www.andreapiani.com - MultipeerManager.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 12/07/25.
//

import Foundation
import MultipeerConnectivity
import AVFoundation
import Combine
import os.log

class MultipeerManager: NSObject, ObservableObject {
    private let serviceType = "walkie-talkie"
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)

    /// Identificatore univoco di questa istanza (per-lancio). Serve a decidere in modo
    /// DETERMINISTICO chi invita chi quando due device si scoprono a vicenda: solo il peer
    /// con `instanceID` minore invia l'invito. Evita il doppio-invito incrociato che
    /// causava sessioni in conflitto e connessioni bloccate in "connecting".
    /// (Non si può usare il solo displayName: da iOS 16 `UIDevice.current.name` ritorna
    /// spesso "iPhone" generico → collisioni.)
    private let instanceID = UUID().uuidString

    /// Istanza condivisa: viene popolata dalla prima `init()` chiamata (tipicamente in ContentView).
    /// Usata da `PrivateChannelManager` per riavviare advertising/browsing al cambio canale.
    /// È weak per evitare retain cycle con il proprietario reale (`@StateObject` in ContentView).
    static weak var shared: MultipeerManager?

    // Proprietà pubblica per accedere al peer ID
    var localPeerID: MCPeerID {
        return myPeerID
    }
    
    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser
    private var browser: MCNearbyServiceBrowser
    
    @Published var connectedPeers: [MCPeerID] = []
    @Published var discoveredPeers: [MCPeerID] = []
    @Published var isAdvertising = false
    @Published var isBrowsing = false
    @Published var isReceiving = false
    /// Nome (peer displayName) di chi sta trasmettendo in questo momento.
    /// `nil` quando nessuno parla. Mostrato nella Live Activity walkie.
    @Published var currentTalkerName: String?
    @Published var receivedInvitation: (MCPeerID, MCSession)?
    private var pendingInvitationHandler: ((Bool, MCSession?) -> Void)?
    @Published var lastError: WalkieTalkieError?
    @Published var connectionStatus: String = "Disconnesso"
    
    // MARK: - Connection Management Properties
    private var connectionTimeout: TimeInterval = 15.0 // Timeout personalizzabile
    private var maxRetryAttempts = 3
    private var retryAttempts: [MCPeerID: Int] = [:]
    private var heartbeatTimer: Timer?
    private var reconnectionTimer: Timer?
    private var disconnectedPeers: Set<MCPeerID> = []
    private var lastHeartbeatSent: Date = Date()
    
    // MARK: - High Traffic Optimization Properties
    private var declinedPeers: Set<MCPeerID> = []
    private let declineCooldown: TimeInterval = 120 // 2 min cooldown after user declines
    private var connectionThrottle: [MCPeerID: Date] = [:]
    private let throttleInterval: TimeInterval = 2.0 // Minimum time between connection attempts
    private var maxConcurrentConnections = 8 // Limit for high traffic scenarios
    private var connectionQueue = DispatchQueue(label: "connection.queue", qos: .userInitiated)
    private var audioDataCache = NSCache<NSString, NSData>()
    private var lastMemoryWarning: Date?
    private let memoryWarningCooldown: TimeInterval = 30.0
    
    // MARK: - Performance Monitoring
    private let performanceMonitor = PerformanceMonitor.shared
    
    private var heartbeatInterval: TimeInterval {
        return powerManager.getOptimizedHeartbeatInterval()
    }
    
    private let logger = Logger.shared
    private let audioManager = AudioManager.shared
    private let notificationManager = NotificationManager.shared
    private let powerManager = PowerManager.shared
    private let hapticManager = HapticManager.shared
    private let firebaseManager = FirebaseManager.shared
    
    // Audio
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFormat: AVAudioFormat?
    private var recordedAudioData = Data()
    
    override init() {
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .optional)

        // Discovery info: include il canale corrente (pubblico oppure hash della password)
        // così che il browsing possa filtrare per canale al volo.
        let initialChannel = UserDefaults.standard.string(forKey: "private_channel_id") ?? "public"
        let discoveryInfo = [
            "deviceName": UIDevice.current.name,
            "channel": initialChannel,
            "uid": instanceID
        ]
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: discoveryInfo, serviceType: serviceType)
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)

        super.init()

        // Registrazione dell'istanza condivisa per il bridge con PrivateChannelManager
        MultipeerManager.shared = self

        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self

        // Richiedi permessi audio
        audioManager.requestAudioPermission()
        
        setupAudio()
        setupHighTrafficOptimizations()
        TalkyCrossPlatformManager.shared.start()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopHeartbeat()
        reconnectionTimer?.invalidate()
        session.disconnect()
        stopAdvertising()
        stopBrowsing()
    }
    
    // MARK: - Public Methods
    
    func requestLocalNetworkPermission() {
        // Forza la richiesta del permesso di rete locale
        // Avvia brevemente advertising e browsing per triggerare il prompt
        let tempAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: ["temp": "permission"], serviceType: serviceType)
        let tempBrowser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        
        tempAdvertiser.startAdvertisingPeer()
        tempBrowser.startBrowsingForPeers()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            tempAdvertiser.stopAdvertisingPeer()
            tempBrowser.stopBrowsingForPeers()
        }
    }
    
    func startAdvertising() {
        guard !isAdvertising else {
            logger.logNetworkDebug("Advertising già attivo")
            return
        }

        logger.logNetworkInfo("Avvio advertising per peer: \(myPeerID.displayName)")
        advertiser.startAdvertisingPeer()
        // SwiftUI views observe `isAdvertising` — mutations of @Published must
        // happen on main to avoid "Publishing changes from background threads"
        // warnings if a future caller invokes this from a non-main context.
        runOnMain {
            self.isAdvertising = true
            self.connectionStatus = "In advertising"
        }
    }

    func stopAdvertising() {
        guard isAdvertising else {
            logger.logNetworkDebug("Advertising già inattivo")
            return
        }

        logger.logNetworkInfo("Arresto advertising")
        advertiser.stopAdvertisingPeer()
        runOnMain {
            self.isAdvertising = false
            self.connectionStatus = self.connectedPeers.isEmpty ? "Disconnesso" : "Connesso"
        }
    }

    func startBrowsing() {
        guard !isBrowsing else {
            logger.logNetworkDebug("Browsing già attivo")
            return
        }

        logger.logNetworkInfo("Avvio ricerca peer...")
        browser.startBrowsingForPeers()
        runOnMain {
            self.isBrowsing = true
            self.connectionStatus = "Ricerca in corso"
        }
    }

    func stopBrowsing() {
        guard isBrowsing else {
            logger.logNetworkDebug("Browsing già inattivo")
            return
        }

        logger.logNetworkInfo("Arresto ricerca peer")
        browser.stopBrowsingForPeers()
        runOnMain {
            self.isBrowsing = false
            self.connectionStatus = self.connectedPeers.isEmpty ? "Disconnesso" : "Connesso"
        }
    }

    /// Esegue un blocco sul main thread: sincronamente se siamo già su main,
    /// asincronamente altrimenti. Usato per garantire che le mutazioni @Published
    /// siano sempre dispatchate dal main senza introdurre re-entry inutili.
    private func runOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
    
    func invitePeer(_ peerID: MCPeerID) {
        guard !declinedPeers.contains(peerID) else {
            logger.logNetworkDebug("Saltato invito: il peer \(peerID.displayName) è stato appena rifiutato dall'utente")
            return
        }

        // High traffic optimization: Check connection limits
        guard connectedPeers.count < maxConcurrentConnections else {
            logger.logNetworkWarning("Limite massimo connessioni raggiunto (\(maxConcurrentConnections))")
            return
        }
        
        // Throttling: Check if enough time has passed since last attempt
        if let lastAttempt = connectionThrottle[peerID] {
            let timeSinceLastAttempt = Date().timeIntervalSince(lastAttempt)
            guard timeSinceLastAttempt >= throttleInterval else {
                logger.logNetworkDebug("Throttling connessione a \(peerID.displayName) - attesa \(String(format: "%.1f", throttleInterval - timeSinceLastAttempt))s")
                return
            }
        }
        
        let currentAttempts = retryAttempts[peerID] ?? 0
        guard currentAttempts < maxRetryAttempts else {
            logger.logNetworkError(WalkieTalkieError.peerInvitationFailed(peerName: peerID.displayName), context: "Massimo numero di tentativi raggiunto")
            retryAttempts.removeValue(forKey: peerID)
            connectionThrottle.removeValue(forKey: peerID)
            return
        }
        
        // Use connection queue for high traffic scenarios
        connectionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let inviteStartTime = Date()
            self.connectionThrottle[peerID] = inviteStartTime
            // Il canale corrente viaggia nel context dell'invito: il ricevente lo valida
            // così senza dipendere da `discoveredPeers` (che era una race condition).
            let contextData = self.currentChannelID.data(using: .utf8)
            self.browser.invitePeer(peerID, to: self.session, withContext: contextData, timeout: self.connectionTimeout)
            self.retryAttempts[peerID] = currentAttempts + 1
            
            DispatchQueue.main.async {
                let connectionTime = Date().timeIntervalSince(inviteStartTime)
                self.performanceMonitor.recordConnectionTime(connectionTime)
                self.performanceMonitor.startLatencyTest(to: peerID.displayName)
                
                self.logger.logNetworkInfo("Invito inviato a: \(peerID.displayName) (tempo: \(String(format: "%.2f", connectionTime))s)")
            }

            // NESSUN retry automatico in uscita: ri-invitare in loop ogni
            // (timeout+2s) faceva comparire un nuovo prompt di connessione sul
            // device ricevente ad ogni tentativo → utenti "spammati di richieste"
            // / "prompted endlessly to connect to the same device" (recensioni
            // App Store). L'invito è ora un'azione esplicita dell'utente da
            // Explore (ExploreView → invitePeer); se fallisce, basta ri-toccare.
            // La riconnessione dei peer GIÀ connessi e poi caduti resta gestita
            // da `scheduleReconnection(for:)`, che è il caso legittimo.
        }
    }
    
    func acceptInvitation() {
        guard let handler = pendingInvitationHandler else { return }
        handler(true, session)
        receivedInvitation = nil
        pendingInvitationHandler = nil
    }
    
    func declineInvitation() {
        guard let handler = pendingInvitationHandler else { return }
        if let declinedPeer = receivedInvitation?.0 {
            declinedPeers.insert(declinedPeer)
            DispatchQueue.main.asyncAfter(deadline: .now() + declineCooldown) { [weak self] in
                self?.declinedPeers.remove(declinedPeer)
            }
        }
        handler(false, nil)
        receivedInvitation = nil
        pendingInvitationHandler = nil
    }
    
    // MARK: - Simulator Detection

    private var isRunningOnSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    // MARK: - Connection Management Methods
    
    func setConnectionTimeout(_ timeout: TimeInterval) {
        connectionTimeout = max(5.0, min(timeout, 60.0)) // Limite tra 5 e 60 secondi
        logger.logNetworkInfo("Timeout connessione impostato a \(connectionTimeout) secondi")
    }
    
    private func startHeartbeat() {
        stopHeartbeat()
        let interval = heartbeatInterval
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
        logger.logNetworkInfo("Heartbeat avviato con intervallo di \(interval) secondi")
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    private func sendHeartbeat() {
        guard !connectedPeers.isEmpty else { return }
        
        guard let heartbeatData = "HEARTBEAT".data(using: .utf8) else { return }
        lastHeartbeatSent = Date()
        
        for peer in connectedPeers {
            do {
                try session.send(heartbeatData, toPeers: [peer], with: .reliable)
            } catch {
                logger.logNetworkError(WalkieTalkieError.audioTransmissionFailed(underlying: error), context: "Errore invio heartbeat a \(peer.displayName): \(error.localizedDescription)")
                handlePeerDisconnection(peer)
            }
        }
    }
    
    private func handlePeerDisconnection(_ peer: MCPeerID) {
        disconnectedPeers.insert(peer)
        scheduleReconnection(for: peer)
    }
    
    private func scheduleReconnection(for peer: MCPeerID) {
        let reconnectDelay: TimeInterval = 5.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + reconnectDelay) { [weak self] in
            guard let self = self else { return }
            
            if self.disconnectedPeers.contains(peer) && self.discoveredPeers.contains(peer) {
                self.logger.logNetworkInfo("Tentativo riconnessione automatica a \(peer.displayName)")
                self.disconnectedPeers.remove(peer)
                // NON resettare retryAttempts qui: azzerarlo rendeva inefficace il
                // cap maxRetryAttempts e trasformava la riconnessione in un loop
                // infinito di inviti (un prompt sul remoto a ogni giro). Il contatore
                // si azzera già in session(_:peer:didChange:) alla connessione riuscita.
                self.invitePeer(peer)
            }
        }
    }
    
    // MARK: - Private Channel Support

    /// Restituisce l'ID del canale corrente leggendo direttamente da UserDefaults.
    /// Usato per filtrare i peer scoperti e impostare il discoveryInfo.
    /// Lo storage è in UserDefaults così non dipendiamo dall'isolamento @MainActor di PrivateChannelManager.
    private var currentChannelID: String {
        UserDefaults.standard.string(forKey: "private_channel_id") ?? "public"
    }

    /// Riavvia advertising e browsing con il nuovo discoveryInfo (cambio canale).
    /// Cambiare canale invalida le connessioni esistenti: le svuotiamo.
    func restartWithCurrentChannel() {
        logger.logNetworkInfo("Riavvio Multipeer su canale: \(currentChannelID)")

        let wasAdvertising = isAdvertising
        let wasBrowsing = isBrowsing

        // Stop di tutto
        if isAdvertising {
            advertiser.stopAdvertisingPeer()
        }
        if isBrowsing {
            browser.stopBrowsingForPeers()
        }
        // Ferma l'heartbeat: i peer del vecchio canale non sono più validi e il
        // timer verrà riavviato automaticamente alla connessione sul nuovo canale.
        stopHeartbeat()
        session.disconnect()

        // Pulizia stato + flag advertising/browsing: tutto sul main per consistenza
        // delle mutazioni @Published. Le connessioni del vecchio canale non sono più valide.
        runOnMain {
            self.isAdvertising = false
            self.isBrowsing = false
            self.connectedPeers.removeAll()
            self.discoveredPeers.removeAll()
            self.disconnectedPeers.removeAll()
            self.retryAttempts.removeAll()
            self.connectionThrottle.removeAll()
            self.connectionStatus = "Disconnesso"
        }

        // Ricrea advertiser con il nuovo discoveryInfo (browser non richiede ricreazione)
        let discoveryInfo = [
            "deviceName": UIDevice.current.name,
            "channel": currentChannelID,
            "uid": instanceID
        ]
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: discoveryInfo, serviceType: serviceType)
        advertiser.delegate = self

        // Riavvia se erano attivi prima
        if wasAdvertising {
            advertiser.startAdvertisingPeer()
            runOnMain { self.isAdvertising = true }
        }
        if wasBrowsing {
            browser.startBrowsingForPeers()
            runOnMain { self.isBrowsing = true }
        }

        logger.logNetworkInfo("Multipeer riavviato (advertising: \(wasAdvertising), browsing: \(wasBrowsing))")
    }

    // MARK: - Live Activity glue

    /// Mantiene la Live Activity walkie allineata allo stato corrente.
    /// Chiamato da peer connect/disconnect e dalle transizioni di trasmissione.
    /// Sicuro da chiamare ovunque — gated a iOS 16.2+ e no-op se LA disabilitato.
    func syncWalkieLiveActivity() {
        guard #available(iOS 16.2, *) else { return }
        let manager = LiveActivityManager.shared
        if connectedPeers.isEmpty {
            manager.endWalkie()
            return
        }
        let names = connectedPeers.map { $0.displayName }
        manager.startOrUpdateWalkie(
            connectedPeerCount: connectedPeers.count,
            peerNames: names,
            channelName: liveActivityChannelDisplayName,
            talkerName: currentTalkerName
        )
    }

    /// Etichetta canale leggibile dall'utente, usata nella Live Activity.
    private var liveActivityChannelDisplayName: String {
        Self.makeLiveActivityChannelDisplayName()
    }

    /// Versione esposta per altri moduli (LiveActivityManager) — stessa logica.
    var liveActivityChannelDisplayNamePublic: String {
        Self.makeLiveActivityChannelDisplayName()
    }

    private static func makeLiveActivityChannelDisplayName() -> String {
        let raw = UserDefaults.standard.string(forKey: "private_channel_id") ?? "public"
        return raw == "public" ? "Pubblico" : "Privato"
    }

    func disconnect() {
        session.disconnect()
        browser.stopBrowsingForPeers()
        advertiser.stopAdvertisingPeer()

        // Cleanup connection management
        stopHeartbeat()
        reconnectionTimer?.invalidate()
        reconnectionTimer = nil

        // Mutazioni @Published e LA sync sempre da main.
        runOnMain {
            self.connectedPeers.removeAll()
            self.discoveredPeers.removeAll()
            self.disconnectedPeers.removeAll()
            self.retryAttempts.removeAll()
            self.currentTalkerName = nil
            self.isAdvertising = false
            self.isBrowsing = false
            self.connectionStatus = "Disconnesso"
            self.syncWalkieLiveActivity()
        }

        logger.logNetworkInfo("Disconnesso da tutti i peer")
    }
    
    // MARK: - Memory Management
    
    // MARK: - Performance Optimization

    /// Restituisce i dati audio invariati: il PCM viene già inviato come messaggio
    /// reliable singolo da Multipeer e il framework si occupa di chunking/MTU.
    /// La precedente "compressione" stride-skipping corrompeva il waveform (Float32
    /// interleaved trattato come byte stream) producendo rumore su >4 peer.
    /// Lo strato di caching basato su `Data.hashValue` era anch'esso fragile
    /// (hash randomizzato per processo + collisioni → audio scambiato fra
    /// utterance diverse). Una vera compressione audio richiede Opus/AAC.
    func optimizeBandwidth(for audioData: Data) -> Data {
        return audioData
    }
    
    func getConnectionQuality(for peer: MCPeerID) -> String {
        if connectedPeers.contains(peer) {
            let retryCount = retryAttempts[peer] ?? 0
            switch retryCount {
            case 0: return "Eccellente"
            case 1: return "Buona"
            case 2: return "Discreta"
            default: return "Scarsa"
            }
        }
        return "Disconnesso"
    }
    
    // MARK: - Public Configuration Methods
    
    func setMaxRetryAttempts(_ attempts: Int) {
        maxRetryAttempts = max(1, min(attempts, 10)) // Limite tra 1 e 10
        logger.logNetworkInfo("Massimo tentativi impostato a \(maxRetryAttempts)")
    }
    
    func getNetworkStatistics() -> [String: Any] {
        return [
            "connectedPeers": connectedPeers.count,
            "discoveredPeers": discoveredPeers.count,
            "disconnectedPeers": disconnectedPeers.count,
            "activeRetries": retryAttempts.count,
            "heartbeatActive": heartbeatTimer != nil,
            "connectionTimeout": connectionTimeout,
            "lastHeartbeat": lastHeartbeatSent
        ]
    }
    
    func forceReconnectAll() {
        logger.logNetworkInfo("Forzando riconnessione a tutti i peer scoperti")
        
        for peer in discoveredPeers {
            if !connectedPeers.contains(peer) {
                retryAttempts.removeValue(forKey: peer)
                invitePeer(peer)
            }
        }
    }
    
    // MARK: - Audio Methods
    
    private func setupAudio() {
        logger.logAudioInfo("Inizializzazione sistema audio...")
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Configura categoria audio con parametri specifici
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            logger.logAudioDebug("Categoria audio configurata: playAndRecord")
            
            // Configura parametri audio specifici per assicurare compatibilità hardware
            try audioSession.setPreferredSampleRate(48000.0)
            try audioSession.setPreferredInputNumberOfChannels(1)
            try audioSession.setPreferredIOBufferDuration(0.02) // 20ms buffer
            
            // Attiva sessione audio
            try audioSession.setActive(true)
            logger.logAudioDebug("Sessione audio attivata con parametri: SR=\(audioSession.sampleRate), CH=\(audioSession.inputNumberOfChannels)")
            
            // Inizializza audio engine
            audioEngine = AVAudioEngine()
            guard let audioEngine = audioEngine else {
                let error = WalkieTalkieError.audioEngineNotAvailable
                logger.logAudioError(error, context: "Inizializzazione audio engine")
                DispatchQueue.main.async {
                    self.lastError = error
                }
                return
            }
            
            // Configura input node
            let inputNode = audioEngine.inputNode
            self.inputNode = inputNode
            
            // Usa il formato nativo dell'input node direttamente
            let nativeFormat = inputNode.outputFormat(forBus: 0)
            
            // Usa il formato nativo per evitare problemi di conversione
            audioFormat = nativeFormat
            
            guard audioFormat != nil else {
                let error = WalkieTalkieError.invalidAudioFormat
                logger.logAudioError(error, context: "Configurazione formato audio")
                DispatchQueue.main.async {
                    self.lastError = error
                }
                return
            }
            
            logger.logAudioInfo("Sistema audio inizializzato correttamente")
            
        } catch {
            let walkieError = WalkieTalkieError.audioSetupFailed(underlying: error)
            logger.logAudioError(walkieError, context: "Setup audio")
            DispatchQueue.main.async {
                self.lastError = walkieError
            }
        }
    }
    
    private var transmissionStartTime: Date?
    
    func startTransmitting() {
        logger.logAudioInfo("Avvio trasmissione audio...")


        guard !connectedPeers.isEmpty || TalkyCrossPlatformManager.shared.connectedPeerCount > 0 else {
            lastError = WalkieTalkieError.noConnectedPeers
            return
        }

        guard audioManager.hasAudioPermission else {
            lastError = WalkieTalkieError.audioPermissionDenied
            return
        }
        
        // Registra l'inizio della trasmissione per il tracking
        transmissionStartTime = Date()

        // Ferma e resetta l'audio engine se già attivo
        if let audioEngine = audioEngine, audioEngine.isRunning {
            inputNode?.removeTap(onBus: 0)
            audioEngine.stop()
        }
        
        setupAudio()

        guard let audioEngine = audioEngine, let inputNode = inputNode, let audioFormat = audioFormat else {
            lastError = WalkieTalkieError.audioEngineNotAvailable
            return
        }

        do {
            recordedAudioData = Data()

            // Validazione formato prima di installare tap
            guard audioFormat.sampleRate > 0 && audioFormat.channelCount > 0 else {
                let error = WalkieTalkieError.invalidAudioFormat
                logger.logAudioError(error, context: "Formato audio non valido: SR=\(audioFormat.sampleRate), CH=\(audioFormat.channelCount)")
                DispatchQueue.main.async {
                    self.lastError = error
                }
                return
            }

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: audioFormat) { [weak self] buffer, _ in
                self?.accumulateAudioData(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()
            audioManager.lowerBackgroundVolumeForVoice()
            logger.logAudioInfo("Trasmissione audio avviata.")
        } catch {
            lastError = WalkieTalkieError.audioTransmissionFailed(underlying: error)
        }
    }

    func stopTransmitting() {
        logger.logAudioInfo("Arresto trasmissione audio...")

        guard let audioEngine = audioEngine, let inputNode = inputNode else { return }

        inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        if !recordedAudioData.isEmpty {
            sendAccumulatedAudio()
        }
        
        // Traccia l'uso del walkie talkie in Firebase
        if let startTime = transmissionStartTime {
            let duration = Date().timeIntervalSince(startTime)
            firebaseManager.trackWalkieTalkieUsage(duration: duration)
            transmissionStartTime = nil
        }

        audioManager.restoreBackgroundVolume()
        logger.logAudioInfo("Trasmissione audio arrestata.")
    }
    


    
    private func bufferToData(_ buffer: AVAudioPCMBuffer) -> Data {
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        guard let mData = audioBuffer.mData else {
            logger.logAudioError(WalkieTalkieError.audioTransmissionFailed(underlying: NSError(domain: "AudioBuffer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Audio buffer mData is nil"])), context: "Buffer audio vuoto")
            return Data()
        }
        let data = Data(bytes: mData, count: Int(audioBuffer.mDataByteSize))
        return data
    }
    
    private func accumulateAudioData(_ buffer: AVAudioPCMBuffer) {
        guard buffer.frameLength > 0 else {
            logger.logAudioDebug("Buffer audio vuoto, skip accumulo")
            return
        }
        
        let audioData = bufferToData(buffer)
        recordedAudioData.append(audioData)
        logger.logAudioDebug("Audio accumulato: \(audioData.count) bytes, totale: \(recordedAudioData.count) bytes")
    }
    

    
    private func sendAccumulatedAudio() {
        let hasApplePeers = !connectedPeers.isEmpty
        let hasCrossPlatformPeers = TalkyCrossPlatformManager.shared.connectedPeerCount > 0

        guard hasApplePeers || hasCrossPlatformPeers else {
            logger.logAudioDebug("Nessun peer connesso per l'invio audio accumulato")
            recordedAudioData = Data() // Reset
            return
        }
        
        guard !recordedAudioData.isEmpty else {
            logger.logAudioDebug("Nessun audio da inviare")
            return
        }
        
        let optimizedData = optimizeBandwidth(for: recordedAudioData)
        logger.logAudioInfo("Invio messaggio audio completo: \(optimizedData.count) bytes a \(connectedPeers.count) peer Apple e \(TalkyCrossPlatformManager.shared.connectedPeerCount) peer cross-platform")

        if hasApplePeers {
            do {
                try session.send(optimizedData, toPeers: connectedPeers, with: .reliable)
                logger.logAudioInfo("Messaggio audio inviato a tutti i peer Apple.")
            } catch {
                lastError = WalkieTalkieError.audioTransmissionFailed(underlying: error)
                logger.logAudioError(lastError!, context: "Errore invio audio accumulato")
            }
        }

        // Pro recording: salva una copia dell'audio trasmesso (no-op se non Pro).
        // Eseguito DOPO l'invio ai peer e PRIMA del reset del buffer.
        let snapshot = recordedAudioData
        TalkyCrossPlatformManager.shared.sendAudio(floatPCM: snapshot)
        DispatchQueue.main.async {
            RecordingsManager.shared.saveTransmittedAudio(snapshot)
        }

        // Reset dei dati dopo l'invio
         recordedAudioData = Data()
    }
    
    
    // MARK: - High Traffic Optimization Methods
    
    private func setupHighTrafficOptimizations() {
        // Configure cache for audio data
        audioDataCache.countLimit = 50 // Limit cache size
        audioDataCache.totalCostLimit = 10 * 1024 * 1024 // 10MB limit
        
        // Setup memory warning observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        logger.logNetworkInfo("Ottimizzazioni traffico elevato configurate")
    }
    
    @objc private func handleMemoryWarning() {
        let now = Date()
        
        // Throttle memory warning handling
        if let lastWarning = lastMemoryWarning,
           now.timeIntervalSince(lastWarning) < memoryWarningCooldown {
            return
        }
        
        lastMemoryWarning = now
        logger.logNetworkWarning("Memory warning ricevuto - pulizia cache")
        
        // Clear audio cache
        audioDataCache.removeAllObjects()
        
        // Clear connection throttle for old entries
        let cutoffTime = now.addingTimeInterval(-throttleInterval * 5)
        connectionThrottle = connectionThrottle.filter { $0.value > cutoffTime }
        
        // Reduce max connections temporarily
        let originalMax = maxConcurrentConnections
        maxConcurrentConnections = max(2, maxConcurrentConnections / 2)
        
        // Restore after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self] in
            self?.maxConcurrentConnections = originalMax
            self?.logger.logNetworkInfo("Limite connessioni ripristinato a \(originalMax)")
        }
    }
    
    func setMaxConcurrentConnections(_ limit: Int) {
        maxConcurrentConnections = max(1, min(limit, 20)) // Between 1 and 20
        logger.logNetworkInfo("Limite massimo connessioni impostato a \(maxConcurrentConnections)")
    }
    
    func getHighTrafficStatistics() -> [String: Any] {
        return [
            "maxConcurrentConnections": maxConcurrentConnections,
            "currentConnections": connectedPeers.count,
            "throttledPeers": connectionThrottle.count,
            "cacheSize": audioDataCache.countLimit,
            "cacheUsage": audioDataCache.totalCostLimit,
            "lastMemoryWarning": lastMemoryWarning?.timeIntervalSinceNow ?? 0
        ]
    }
    
    func optimizeForHighTraffic() {
        logger.logNetworkInfo("Attivazione modalità traffico elevato")
        
        // Reduce connection timeout for faster cycling
        setConnectionTimeout(8.0)
        
        // Reduce max connections to ensure stability
        setMaxConcurrentConnections(6)
        
        // Clear old throttle entries
        let cutoffTime = Date().addingTimeInterval(-throttleInterval * 2)
        connectionThrottle = connectionThrottle.filter { $0.value > cutoffTime }
        
        // Optimize audio cache
        audioDataCache.countLimit = 30
        audioDataCache.totalCostLimit = 5 * 1024 * 1024 // 5MB
        
        logger.logNetworkInfo("Ottimizzazioni traffico elevato applicate")
    }
}

// MARK: - MCSessionDelegate

extension MultipeerManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        logger.logNetworkInfo("Peer \(peerID.displayName) cambiato stato: \(state.description)")
        
        DispatchQueue.main.async {
            switch state {
            case .connected:
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                    self.logger.logNetworkInfo("Peer \(peerID.displayName) connesso. Totale connessi: \(self.connectedPeers.count)")

                    // Aggiorna il monitoraggio delle performance
                    self.performanceMonitor.updateConnectionCount(self.connectedPeers.count)

                    // Traccia connessione in Firebase
                    self.firebaseManager.trackDeviceConnection(deviceName: peerID.displayName)

                    // Feedback aptico e notifica per connessione
                    self.hapticManager.connectionEstablished()
                    self.notificationManager.sendConnectionEstablishedNotification(deviceName: peerID.displayName)
                }
                self.disconnectedPeers.remove(peerID)
                self.retryAttempts.removeValue(forKey: peerID) // Reset retry counter on successful connection
                self.connectionStatus = "Connesso (\(self.connectedPeers.count))"

                // Avvia heartbeat quando si connette il primo peer
                if self.connectedPeers.count == 1 {
                    self.startHeartbeat()
                }

                self.syncWalkieLiveActivity()

            case .notConnected:
                let wasConnected = self.connectedPeers.contains(peerID)
                self.connectedPeers.removeAll { $0 == peerID }
                self.logger.logNetworkInfo("Peer \(peerID.displayName) disconnesso. Totale connessi: \(self.connectedPeers.count)")
                self.connectionStatus = self.connectedPeers.isEmpty ? "Disconnesso" : "Connesso (\(self.connectedPeers.count))"
                
                // Aggiorna il monitoraggio delle performance
                self.performanceMonitor.updateConnectionCount(self.connectedPeers.count)
                
                // Feedback aptico e notifica per disconnessione solo se era precedentemente connesso
                if wasConnected {
                    // Traccia disconnessione in Firebase
                    self.firebaseManager.trackDeviceDisconnection(deviceName: peerID.displayName)
                    
                    self.hapticManager.connectionLost()
                    self.notificationManager.sendConnectionLostNotification(deviceName: peerID.displayName)
                }
                
                // Riconnessione automatica SOLO per peer che erano davvero connessi
                // e sono caduti. Un invito in uscita fallito (il remoto ignora o
                // declina) arriva qui come .notConnected con wasConnected == false:
                // ri-invitarlo genera un nuovo prompt sul device remoto ogni ciclo
                // → "constantly spammed with connection requests" (recensione 1★).
                if wasConnected && self.discoveredPeers.contains(peerID) {
                    self.handlePeerDisconnection(peerID)
                }
                
                // Ferma heartbeat quando non ci sono più peer connessi
                if self.connectedPeers.isEmpty {
                    self.stopHeartbeat()
                }

                self.syncWalkieLiveActivity()

            case .connecting:
                self.logger.logNetworkDebug("Connessione in corso con \(peerID.displayName)")
                self.connectionStatus = "Connessione in corso..."
                
            @unknown default:
                self.logger.logNetworkWarning("Stato sconosciuto per peer \(peerID.displayName): \(state.rawValue)")
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            // Gestisci messaggi heartbeat
            if let message = String(data: data, encoding: .utf8), message == "HEARTBEAT" {
                self.logger.logNetworkDebug("Heartbeat ricevuto da \(peerID.displayName)")
                return
            }
            
            // Gestione messaggi audio completi
            let dataSize = data.count
            if dataSize > 0 {
                self.logger.logAudioInfo("Messaggio audio completo ricevuto da \(peerID.displayName): \(dataSize) bytes")
                
                // Aggiorna stato ricezione
                DispatchQueue.main.async {
                    self.isReceiving = true
                    self.currentTalkerName = peerID.displayName
                    self.syncWalkieLiveActivity()
                    FirstTimeEventTracker.shared.fireOnce(
                        FirstTimeEventTracker.Events.reception,
                        parameters: ["peer_name": peerID.displayName]
                    )
                    TransmissionHistoryManager.shared.recordReception(peerName: peerID.displayName, dataSize: dataSize)
                    // Privacy: NON salviamo l'audio ricevuto da altri peer (GDPR + App Store review).
                    // Solo metadata (peer, timestamp, durata stimata) finiscono nella cronologia.
                    // La registrazione resta attiva solo per le trasmissioni in uscita dell'utente.
                }

                // Invia notifica di trasmissione in arrivo
                self.notificationManager.sendIncomingTransmissionNotification()

                // Ottimizzazione memoria: processa audio in background
                DispatchQueue.global(qos: .userInitiated).async {
                    self.audioManager.playReceivedAudio(data)

                    // Reset stato ricezione dopo un delay per mostrare l'indicatore
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.isReceiving = false
                        self.currentTalkerName = nil
                        self.syncWalkieLiveActivity()
                    }
                }
            } else {
                self.logger.logAudioDebug("Dati vuoti ricevuti da \(peerID.displayName)")
            }
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        logger.logNetworkWarning("Stream ricevuto non gestito: \(streamName) da \(peerID.displayName)")
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        logger.logNetworkWarning("Risorsa ricevuta non gestita: \(resourceName) da \(peerID.displayName)")
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        if let error = error {
            logger.logNetworkError(error, context: "Ricezione risorsa \(resourceName)")
        } else {
            logger.logNetworkInfo("Risorsa \(resourceName) ricevuta da \(peerID.displayName)")
        }
    }
}

// MARK: - Extensions
extension MCSessionState {
    var description: String {
        switch self {
        case .notConnected: return "Non connesso"
        case .connecting: return "Connessione in corso"
        case .connected: return "Connesso"
        @unknown default: return "Stato sconosciuto (\(rawValue))"
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        logger.logNetworkInfo("Ricevuto invito da: \(peerID.displayName)")

        // Filtro canale tramite il CONTEXT dell'invito (non più tramite `discoveredPeers`).
        // Il vecchio guard `discoveredPeers.contains(peerID)` era una race condition: se il
        // nostro browser non aveva ancora scoperto il mittente, l'invito VALIDO veniva
        // rifiutato in silenzio → l'utente vedeva "non si connette" pur essendo vicino.
        // Il context contiene il channelID del mittente: accettiamo solo se combacia.
        // (context nil = peer su vecchia versione → trattato come canale "public".)
        let invitedChannel = context.flatMap { String(data: $0, encoding: .utf8) } ?? "public"
        guard invitedChannel == currentChannelID else {
            logger.logNetworkError(WalkieTalkieError.invalidPeer, context: "Invito da canale diverso: '\(invitedChannel)' ≠ '\(currentChannelID)'")
            invitationHandler(false, nil)
            return
        }

        DispatchQueue.main.async {
            // Auto-accept sui canali PRIVATI (password condivisa): chi è sullo stesso
            // canale privato si è già scambiato la password, quindi richiedere un tap
            // accept/decline per ogni peer è solo frizione ("64 clicks to accept for one
            // 8 person call" — recensione App Store). Sul canale PUBBLICO resta il prompt
            // manuale: lì chiunque vicino può inviare un invito, quindi la conferma
            // esplicita protegge da connessioni indesiderate.
            if self.currentChannelID != "public" {
                self.logger.logNetworkInfo("Invito auto-accettato (canale privato) da \(peerID.displayName)")
                invitationHandler(true, self.session)
                return
            }

            // Se c'è già un invito pendente non gestito dall'utente, declina il
            // precedente automaticamente: lasciarlo in sospeso fa scadere il timeout
            // sul peer remoto (~30s) lasciandolo bloccato in "connecting".
            if let previous = self.pendingInvitationHandler {
                previous(false, nil)
            }
            self.receivedInvitation = (peerID, self.session)
            self.pendingInvitationHandler = invitationHandler
        }
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        logger.logNetworkError(error, context: "Errore avvio advertising")
        DispatchQueue.main.async {
            self.lastError = WalkieTalkieError.networkConnectionFailed(underlying: error)
            self.connectionStatus = "check_wifi_bluetooth".localized
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        // Evita auto-invito e invita solo peer diversi
        guard peerID != myPeerID else {
            logger.logNetworkDebug("Ignorato auto-discovery del proprio peer")
            return
        }

        // Filtro per canale: il peer è visibile solo se condivide lo stesso channelID.
        // Peer senza chiave "channel" sono considerati "public" (retro-compatibilità).
        let peerChannel = info?["channel"] ?? "public"
        guard peerChannel == currentChannelID else {
            logger.logNetworkDebug("Peer \(peerID.displayName) ignorato: canale '\(peerChannel)' diverso da '\(currentChannelID)'")
            return
        }

        logger.logNetworkInfo("Trovato peer: \(peerID.displayName) (canale: \(peerChannel))")
        
        DispatchQueue.main.async {
            if !self.discoveredPeers.contains(peerID) {
                self.discoveredPeers.append(peerID)
                self.logger.logNetworkInfo("Peer aggiunto alla lista: \(peerID.displayName)")
                
                // Invia notifica di nuovo dispositivo rilevato
                self.notificationManager.sendDeviceDetectedNotification(deviceName: peerID.displayName)
            }
        }
        
        // Discovery is passive: users connect from Explore via an explicit tap.
        // Auto-inviting every found peer caused unsolicited connection prompts
        // and retry loops when several Talky users were nearby on the public channel.
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        logger.logNetworkInfo("Perso peer: \(peerID.displayName)")
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll { $0 == peerID }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        logger.logNetworkError(error, context: "Errore avvio browsing")
        DispatchQueue.main.async {
            self.lastError = WalkieTalkieError.networkConnectionFailed(underlying: error)
            self.connectionStatus = "check_wifi_bluetooth".localized
        }
    }
}
