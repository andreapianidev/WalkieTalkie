//creato da Andrea Piani - 12/07/25 - https://www.andreapiani.com - MultipeerManager.swift
//  WalkieTalkie
//
//  Created by Andrea Piani on 12/07/25.
//

import Foundation
import MultipeerConnectivity
import AVFoundation
import Combine
import CryptoKit
import Security
import os.log

class MultipeerManager: NSObject, ObservableObject {
    private let serviceType = "walkie-talkie"
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)

    /// Id di questo avvio, annunciato come "uid" nel discoveryInfo e uguale a
    /// quello TALKY1: serve al ponte per sapere a chi un messaggio e' gia'
    /// arrivato. Cambia a ogni avvio; chi ci ha gia' accettato ci riconosce dal
    /// segreto della coppia (`CoppieFidate`), che non passa mai dalla ricerca.
    private let instanceID = Ponte.shared.uidLocale

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
    @Published var lastError: WalkieTalkieError?
    @Published var connectionStatus: String = "status.disconnected".localized
    
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
    /// Chi e' stato rifiutato non deve tornare a chiedere subito: per dieci
    /// minuti i suoi inviti si declinano senza mostrare niente.
    private let declineCooldown: TimeInterval = 600
    private var connectionThrottle: [MCPeerID: Date] = [:]
    private let throttleInterval: TimeInterval = 2.0 // Minimum time between connection attempts
    private var maxConcurrentConnections = 8 // Limit for high traffic scenarios
    private var connectionQueue = DispatchQueue(label: "connection.queue", qos: .userInitiated)
    private var audioDataCache = NSCache<NSString, NSData>()
    private var lastMemoryWarning: Date?
    private let memoryWarningCooldown: TimeInterval = 30.0
    
    // MARK: - Inviti e ponte (tutto sul main)

    /// uid di ogni peer, dal discoveryInfo o dall'intestazione del ponte.
    private var uidPerPeer: [MCPeerID: String] = [:]
    /// Peer che annunciano il ponte: capiscono l'uid nel context dell'invito.
    private var peerConPonte: Set<MCPeerID> = []
    /// Inviti partiti da qui e non ancora conclusi. Un secondo tocco non manda
    /// un'altra richiesta, e se nel frattempo l'altro invita noi si accetta da solo.
    private var invitiInVolo: [MCPeerID: Date] = [:]
    /// Inviti accettati (a mano o da soli) e non ancora collegati.
    private var accettatiInAttesa: Set<MCPeerID> = []
    /// Accettati in questo avvio: le versioni vecchie cambiano uid a ogni avvio,
    /// ma nello stesso avvio una riconnessione non deve richiedere conferma.
    private var fidatiInSessione: Set<MCPeerID> = []
    /// Inviti ricevuti che aspettano una risposta: il primo e' quello a schermo.
    /// In coda e non uno alla volta, perche' declinare in silenzio il precedente
    /// faceva fallire chi aveva chiesto per primo.
    private var invitiInCoda: [(id: UUID, peer: MCPeerID, arrivato: Date, handler: (Bool, MCSession?) -> Void)] = []
    /// Chi invita aspetta `connectionTimeout`, 15 s da sempre: oltre, un si'
    /// non collega piu' niente. Un secondo di margine per il viaggio.
    private let durataInvito: TimeInterval = 14
    /// Accettati a mano qui: a collegamento fatto gli si manda il segreto della coppia.
    private var daAccoppiare: Set<MCPeerID> = []
    /// Collegati con un invito partito da qui: solo da loro si accetta un segreto,
    /// cosi' nessuno puo' farsi ricordare senza che l'utente abbia toccato.
    private var invitatiDaNoi: Set<MCPeerID> = []

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
            "uid": Ponte.shared.uidLocale,
            "ponte": "1"
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
        // Le build 141 e 142 si fidavano di un uid annunciato in chiaro: via.
        UserDefaults.standard.removeObject(forKey: "multipeer_trusted_devices")
        // Quello che arriva intero da un Android o da un Mac passa anche agli
        // iPhone collegati qui, e viceversa: l'iPhone e' il ponte fra i trasporti.
        TalkyCrossPlatformManager.shared.daInoltrare = { [weak self] trasmissione, audio, da in
            self?.inoltra(trasmissione.perIlPonte(arrivataDa: da), audio: audio, tranneUID: da)
        }
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
            self.connectionStatus = "status.advertising".localized
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
            self.connectionStatus = self.connectedPeers.isEmpty ? "status.disconnected".localized : "status.connected".localized
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
            self.connectionStatus = "status.searching".localized
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
            self.connectionStatus = self.connectedPeers.isEmpty ? "status.disconnected".localized : "status.connected".localized
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
    
    /// `daUtente` e' il tocco in Esplora: vale piu' di un rifiuto dato prima,
    /// che altrimenti terrebbe il peer fuori per dieci minuti senza dire niente.
    func invitePeer(_ peerID: MCPeerID, daUtente: Bool = true) {
        // Mai una seconda richiesta mentre la prima e' ancora a schermo dall'altra parte.
        if let inviato = invitiInVolo[peerID], Date().timeIntervalSince(inviato) < connectionTimeout + 2 {
            logger.logNetworkDebug("Invito a \(peerID.displayName) gia' in corso")
            return
        }
        if daUtente { declinedPeers.remove(peerID) }

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
        
        invitiInVolo[peerID] = Date()
        // Il canale corrente viaggia nel context dell'invito: il ricevente lo valida
        // così senza dipendere da `discoveredPeers` (che era una race condition).
        // A chi ha il ponte seguono altre righe (vedi `contestoInvito`). Le
        // versioni vecchie confrontano il context intero con il loro canale,
        // quindi a loro va il canale e basta.
        let contesto = contestoInvito(per: peerID)

        // Use connection queue for high traffic scenarios
        connectionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let inviteStartTime = Date()
            self.connectionThrottle[peerID] = inviteStartTime
            let contextData = contesto.data(using: .utf8)
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
    
    /// Il tocco vale solo per la domanda che l'utente ha davanti: se nel
    /// frattempo e' scaduta, non deve finire sull'invito successivo.
    private var invitoAScermoValido: Bool {
        guard let mostrato = receivedInvitation?.0 else { return false }
        return invitiInCoda.first?.peer == mostrato
    }

    func acceptInvitation() {
        guard invitoAScermoValido else { return }
        let invito = invitiInCoda.removeFirst()
        invito.handler(true, session)
        accettatiInAttesa.insert(invito.peer)
        fidatiInSessione.insert(invito.peer)
        // Solo chi ha il ponte sa leggere il segreto: a una versione vecchia
        // arriverebbe come audio.
        if peerConPonte.contains(invito.peer) { daAccoppiare.insert(invito.peer) }
        mostraProssimoInvito()
    }

    func declineInvitation() {
        guard invitoAScermoValido else { return }
        let invito = invitiInCoda.removeFirst()
        invito.handler(false, nil)
        let declinedPeer = invito.peer
        declinedPeers.insert(declinedPeer)
        DispatchQueue.main.asyncAfter(deadline: .now() + declineCooldown) { [weak self] in
            self?.declinedPeers.remove(declinedPeer)
        }
        mostraProssimoInvito()
    }

    /// Toglie la domanda a schermo e, se c'e', mostra la prossima. La pausa
    /// lascia chiudere l'alert: ripresentarlo nello stesso istante in cui
    /// SwiftUI lo sta togliendo non lo fa ricomparire.
    private func mostraProssimoInvito() {
        receivedInvitation = nil
        // Oltre il timeout di chi ha invitato, dall'altra parte e' gia' scaduto.
        let scadenza = Date().addingTimeInterval(-durataInvito)
        while let primo = invitiInCoda.first, primo.arrivato < scadenza {
            invitiInCoda.removeFirst().handler(false, nil)
        }
        guard let prossimo = invitiInCoda.first?.id else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, let primo = self.invitiInCoda.first, primo.id == prossimo else { return }
            self.mostraInvito(primo.id, peer: primo.peer, arrivato: primo.arrivato)
        }
    }

    /// Mette a schermo il primo invito della coda e lo toglie quando scade
    /// dall'altra parte: un si' dato dopo non collegherebbe niente.
    private func mostraInvito(_ id: UUID, peer: MCPeerID, arrivato: Date) {
        receivedInvitation = (peer, session)
        let restano = max(0, durataInvito - Date().timeIntervalSince(arrivato))
        DispatchQueue.main.asyncAfter(deadline: .now() + restano) { [weak self] in
            guard let self, self.invitiInCoda.first?.id == id else { return }
            self.logger.logNetworkInfo("Invito di \(peer.displayName) scaduto senza risposta")
            self.invitiInCoda.removeFirst().handler(false, nil)
            self.mostraProssimoInvito()
        }
    }

    private func declinaTuttiGliInviti() {
        invitiInCoda.forEach { $0.handler(false, nil) }
        invitiInCoda.removeAll()
        receivedInvitation = nil
    }

    /// Righe dopo il canale, solo verso chi ha il ponte: il nostro uid di
    /// questo avvio e, se lo abbiamo gia' accettato, le firme della coppia.
    /// Le build 141 e 142 leggono solo la riga "uid=" e ignorano il resto.
    private func contestoInvito(per peerID: MCPeerID) -> String {
        guard peerConPonte.contains(peerID) else { return currentChannelID }
        var righe = [currentChannelID, "uid=\(instanceID)"]
        if let suo = uidPerPeer[peerID] {
            let quando = Int(Date().timeIntervalSince1970)
            let firme = CoppieFidate.firme(per: peerID.displayName, invitato: suo, quando: quando)
            if !firme.isEmpty {
                righe.append("ts=\(quando)")
                righe += firme.map { "t=\($0)" }
            }
        }
        return righe.joined(separator: "\n")
    }

    /// Perche' un invito si accetta senza chiedere, nil se va chiesto. Sul canale
    /// pubblico uno sconosciuto si puo' sempre rifiutare: si accetta da solo
    /// solo chi e' gia' stato accettato o chi stiamo invitando noi.
    private func motivoAccettazioneAutomatica(_ peerID: MCPeerID, coppia: Bool) -> String? {
        // Canale privato: chi c'e' conosce gia' la password.
        if currentChannelID != "public" { return "canale privato" }
        if fidatiInSessione.contains(peerID) { return "gia' accettato in questo avvio" }
        if coppia { return "gia' accettato" }
        if let inviato = invitiInVolo[peerID], Date().timeIntervalSince(inviato) < connectionTimeout + 2 {
            return "invito incrociato"
        }
        return nil
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
                self.invitePeer(peer, daUtente: false)
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
            self.invitiInVolo.removeAll()
            self.accettatiInAttesa.removeAll()
            self.daAccoppiare.removeAll()
            self.invitatiDaNoi.removeAll()
            self.declinaTuttiGliInviti()
            self.connectionStatus = "status.disconnected".localized
        }

        // Ricrea advertiser con il nuovo discoveryInfo (browser non richiede ricreazione)
        let discoveryInfo = [
            "deviceName": UIDevice.current.name,
            "channel": currentChannelID,
            "uid": instanceID,
            "ponte": "1"
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
        // Anche le connessioni con Android e Mac sono del canale vecchio: con il
        // ponte porterebbero la voce del gruppo fuori dalla stanza.
        TalkyCrossPlatformManager.shared.riavvia()
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
            self.invitiInVolo.removeAll()
            self.accettatiInAttesa.removeAll()
            self.daAccoppiare.removeAll()
            self.invitatiDaNoi.removeAll()
            self.declinaTuttiGliInviti()
            self.currentTalkerName = nil
            self.isAdvertising = false
            self.isBrowsing = false
            self.connectionStatus = "status.disconnected".localized
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
                invitePeer(peer, daUtente: false)
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

        // Da qui e fino a fine trasmissione nessun paywall può aprirsi: un
        // walkie-talkie che interrompe chi sta parlando per vendergli qualcosa
        // è esattamente il motivo per cui si prendono le stelle singole.
        Task { @MainActor in
            PaywallTriggerManager.shared.isConversationActive = true
        }

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

        // Una trasmissione conclusa CON almeno un peer connesso è l'unico momento
        // in cui abbiamo la prova che l'app ha fatto il suo mestiere. È lì, e solo
        // lì, che ha senso chiedere una recensione: il conteggio dei peer viene
        // letto adesso perché dopo il teardown potrebbe già essere cambiato.
        let peersAtEndOfTransmission = connectedPeers.count
        Task { @MainActor in
            ReviewPromptManager.shared.recordTransmission(connectedPeerCount: peersAtEndOfTransmission)
            // La conversazione è finita: da qui il paywall può tornare a parlare.
            // Va rilasciato prima di registrare la trasmissione, altrimenti il
            // traguardo delle 20 scatterebbe con il flag ancora alzato e verrebbe
            // scartato da solo.
            PaywallTriggerManager.shared.isConversationActive = false
            PaywallTriggerManager.shared.registerTransmission(connectedPeerCount: peersAtEndOfTransmission)
        }

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
        guard !recordedAudioData.isEmpty else {
            logger.logAudioDebug("Nessun audio da inviare")
            return
        }
        let audio = optimizeBandwidth(for: recordedAudioData)
        recordedAudioData = Data()

        let trasmissione = Trasmissione.nuova(nome: myPeerID.displayName)
        // Se ci torna indietro da un ponte non va suonato a chi l'ha detto.
        Ponte.shared.segna(trasmissione.id)
        let invio = inoltra(trasmissione, audio: audio)

        if let errore = invio.errore {
            lastError = WalkieTalkieError.audioTransmissionFailed(underlying: errore)
            logger.logAudioError(lastError!, context: "Errore invio audio accumulato")
        }
        guard invio.mandati > 0 || invio.errore != nil else {
            logger.logAudioDebug("Nessun peer connesso per l'invio audio accumulato")
            return
        }
        if invio.mandati > 0 {
            Funnel.once(Funnel.transmissionSuccess, ["peer_count": invio.mandati])
        }
        logger.logAudioInfo("Messaggio audio inviato a \(invio.mandati) peer: \(audio.count) bytes")

        // Pro recording: salva una copia dell'audio trasmesso (no-op se non Pro).
        DispatchQueue.main.async {
            RecordingsManager.shared.saveTransmittedAudio(audio)
        }
    }

    /// Manda un messaggio a chi non l'ha ancora, su Multipeer e su TALKY1:
    /// tutti i peer collegati tranne quello da cui e' arrivato e quelli che
    /// l'avevano gia' ricevuto direttamente. Sul main.
    @discardableResult
    private func inoltra(_ trasmissione: Trasmissione,
                         audio: Data,
                         tranneMultipeer: MCPeerID? = nil,
                         tranneUID: String? = nil) -> (mandati: Int, errore: Error?) {
        func giaServito(_ uid: String?) -> Bool {
            guard let uid else { return false }
            return uid == tranneUID || trasmissione.raggiunti.contains(Ponte.idCorto(uid))
        }
        let viaMultipeer = connectedPeers.filter { $0 != tranneMultipeer && !giaServito(uidPerPeer[$0]) }
        let viaTalky1 = TalkyCrossPlatformManager.shared.connectedPeerIDs.filter { !giaServito($0) }
        guard !viaMultipeer.isEmpty || !viaTalky1.isEmpty else { return (0, nil) }

        // Chi lo riceve da qui non deve riceverlo di nuovo da un altro ponte.
        var uscita = trasmissione
        uscita.raggiunti.formUnion(viaMultipeer.compactMap { uidPerPeer[$0] }.map(Ponte.idCorto))
        uscita.raggiunti.formUnion(viaTalky1.map(Ponte.idCorto))

        var mandati = 0
        var errore: Error?
        if !viaMultipeer.isEmpty {
            do {
                try session.send(IntestazioneMultipeer.impacchetta(uscita, audio: audio), toPeers: viaMultipeer, with: .reliable)
                mandati += viaMultipeer.count
            } catch {
                errore = error
                logger.logNetworkError(error, context: "Invio Multipeer (ttl \(uscita.ttl))")
            }
        }
        if !viaTalky1.isEmpty {
            TalkyCrossPlatformManager.shared.sendAudio(floatPCM: audio, trasmissione: uscita, a: viaTalky1)
            mandati += viaTalky1.count
        }
        if tranneMultipeer != nil || tranneUID != nil {
            logger.logAudioInfo("Ponte: ritrasmesso a \(mandati) peer (ttl \(uscita.ttl))")
        }
        return (mandati, errore)
    }

    /// Suona un messaggio ricevuto e aggiorna indicatori e cronologia. Sul main.
    private func riproduci(_ audio: Data, talker: String) {
        isReceiving = true
        currentTalkerName = talker
        syncWalkieLiveActivity()
        FirstTimeEventTracker.shared.fireOnce(FirstTimeEventTracker.Events.reception)
        TransmissionHistoryManager.shared.recordReception(peerName: talker, dataSize: audio.count)
        // Privacy: NON salviamo l'audio ricevuto da altri peer (GDPR + App Store review).
        // Solo metadata (peer, timestamp, durata stimata) finiscono nella cronologia.
        notificationManager.sendIncomingTransmissionNotification()

        DispatchQueue.global(qos: .userInitiated).async {
            self.audioManager.playReceivedAudio(audio)

            // Reset stato ricezione dopo un delay per mostrare l'indicatore
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.isReceiving = false
                self.currentTalkerName = nil
                self.syncWalkieLiveActivity()
            }
        }
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
                    self.firebaseManager.trackDeviceConnection()

                    // Feedback aptico e notifica per connessione
                    self.hapticManager.connectionEstablished()
                    self.notificationManager.sendConnectionEstablishedNotification(deviceName: peerID.displayName)
                    Funnel.once(Funnel.connectionEstablished, ["transport": "multipeer"])
                }
                if self.invitiInVolo.removeValue(forKey: peerID) != nil {
                    self.invitatiDaNoi.insert(peerID)
                }
                self.accettatiInAttesa.remove(peerID)
                if self.daAccoppiare.remove(peerID) != nil {
                    self.mandaSegretoCoppia(a: peerID)
                }
                self.disconnectedPeers.remove(peerID)
                self.retryAttempts.removeValue(forKey: peerID) // Reset retry counter on successful connection
                self.connectionStatus = String(format: "status.connected_count".localized, self.connectedPeers.count)

                // Avvia heartbeat quando si connette il primo peer
                if self.connectedPeers.count == 1 {
                    self.startHeartbeat()
                }

                self.syncWalkieLiveActivity()

            case .notConnected:
                let wasConnected = self.connectedPeers.contains(peerID)
                self.connectedPeers.removeAll { $0 == peerID }
                self.daAccoppiare.remove(peerID)
                self.invitatiDaNoi.remove(peerID)
                self.logger.logNetworkInfo("Peer \(peerID.displayName) disconnesso. Totale connessi: \(self.connectedPeers.count)")
                self.connectionStatus = self.connectedPeers.isEmpty ? "status.disconnected".localized : String(format: "status.connected_count".localized, self.connectedPeers.count)
                
                // Aggiorna il monitoraggio delle performance
                self.performanceMonitor.updateConnectionCount(self.connectedPeers.count)
                
                // Feedback aptico e notifica per disconnessione solo se era precedentemente connesso
                if wasConnected {
                    // Traccia disconnessione in Firebase
                    self.firebaseManager.trackDeviceDisconnection()
                    
                    self.hapticManager.connectionLost()
                    self.notificationManager.sendConnectionLostNotification(deviceName: peerID.displayName)
                } else if let motivo = self.motivoFallimento(peerID) {
                    Funnel.log(Funnel.connectionFailed, ["reason": motivo, "transport": "multipeer"])
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
                self.connectionStatus = "status.connecting".localized
                
            @unknown default:
                self.logger.logNetworkWarning("Stato sconosciuto per peer \(peerID.displayName): \(state.rawValue)")
            }
        }
    }
    
    /// Perche' non si e' arrivati al collegamento, nil se non c'era un tentativo
    /// nostro in corso. Multipeer non dice se l'altro ha rifiutato o non ha
    /// risposto: un no arriva subito, un silenzio allo scadere del timeout.
    private func motivoFallimento(_ peerID: MCPeerID) -> String? {
        let negato = LocalNetworkGuard.shared.isDenied
        if let inviato = invitiInVolo.removeValue(forKey: peerID) {
            if negato { return "permission" }
            return Date().timeIntervalSince(inviato) < connectionTimeout - 1 ? "declined" : "timeout"
        }
        if accettatiInAttesa.remove(peerID) != nil {
            return negato ? "permission" : "handshake"
        }
        return nil
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            // Gestisci messaggi heartbeat
            if let message = String(data: data, encoding: .utf8), message == "HEARTBEAT" {
                self.logger.logNetworkDebug("Heartbeat ricevuto da \(peerID.displayName)")
                return
            }
            guard !data.isEmpty else {
                self.logger.logAudioDebug("Dati vuoti ricevuti da \(peerID.displayName)")
                return
            }

            // Versione vecchia: Float32 nudo, si suona e basta (senza id non si
            // puo' sapere se altrove e' gia' arrivato, quindi non si ritrasmette).
            guard let pacchetto = IntestazioneMultipeer.spacchetta(data) else {
                self.logger.logAudioInfo("Messaggio audio ricevuto da \(peerID.displayName): \(data.count) bytes")
                self.riproduci(data, talker: peerID.displayName)
                return
            }
            self.peerConPonte.insert(peerID)

            let trasmissione: Trasmissione
            var audio: Data
            switch pacchetto {
            case .coppia(let segreto):
                // Solo da chi abbiamo invitato noi, e una volta: e' la sua
                // risposta al nostro tocco, non qualcosa che un peer qualsiasi
                // possa piantare.
                if self.invitatiDaNoi.remove(peerID) != nil {
                    CoppieFidate.salva(segreto, nome: peerID.displayName)
                    self.logger.logNetworkInfo("Coppia ricordata con \(peerID.displayName)")
                } else {
                    self.logger.logNetworkWarning("Segreto di coppia non richiesto da \(peerID.displayName), ignorato")
                }
                return
            case .trasmissione(let t, let a):
                trasmissione = t
                audio = a
            }

            // Con tutte le tratte intatte l'ha detto proprio questo peer: e' il suo uid.
            if trasmissione.ttl == Trasmissione.ttlIniziale, !trasmissione.origine.isEmpty {
                self.uidPerPeer[peerID] = trasmissione.origine
            }
            guard Ponte.shared.primaVolta(trasmissione.id) else {
                self.logger.logAudioDebug("Ponte: doppione da \(peerID.displayName) scartato")
                return
            }
            let nome = trasmissione.nomeOrigine.isEmpty ? peerID.displayName : trasmissione.nomeOrigine
            self.logger.logAudioInfo("Messaggio audio ricevuto da \(peerID.displayName) (ttl \(trasmissione.ttl)): \(audio.count) bytes")
            self.riproduci(audio, talker: nome)

            if trasmissione.ttl > 1 {
                if audio.count > Trasmissione.Limite.audioPonte {
                    audio = audio.prefix(Trasmissione.Limite.audioPonte)
                }
                let da = self.uidPerPeer[peerID]
                self.inoltra(trasmissione.perIlPonte(arrivataDa: da), audio: audio, tranneMultipeer: peerID, tranneUID: da)
            }
        }
    }

    /// Il segreto della coppia, generato da chi ha accettato a mano e mandato
    /// una volta dentro la sessione: da qui in poi i due telefoni si
    /// riconoscono negli inviti senza chiedere. Sul main.
    private func mandaSegretoCoppia(a peerID: MCPeerID) {
        let segreto = CoppieFidate.nuova(nome: peerID.displayName)
        do {
            try session.send(IntestazioneMultipeer.impacchettaCoppia(segreto: segreto), toPeers: [peerID], with: .reliable)
            logger.logNetworkInfo("Coppia proposta a \(peerID.displayName)")
        } catch {
            CoppieFidate.dimentica(segreto)
            logger.logNetworkError(error, context: "Invio segreto di coppia")
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
        // Prima riga: il canale del mittente (context nil = versione molto vecchia, "public").
        // Dalle versioni con il ponte, altre righe "chiave=valore" (vedi `contestoInvito`).
        let righe = context.flatMap { String(data: $0, encoding: .utf8) }?.components(separatedBy: "\n") ?? []
        let invitedChannel = righe.first ?? "public"
        func valori(_ chiave: String) -> [String] {
            righe.dropFirst().filter { $0.hasPrefix(chiave + "=") }.map { String($0.dropFirst(chiave.count + 1)) }
        }
        let uidNelContesto = valori("uid").first
        let quando = valori("ts").first.flatMap(Int.init)
        let firme = Array(valori("t").prefix(CoppieFidate.firmePerInvito))
        let haPonte = righe.count > 1
        guard invitedChannel == currentChannelID else {
            logger.logNetworkError(WalkieTalkieError.invalidPeer, context: "Invito da canale diverso: '\(invitedChannel)' ≠ '\(currentChannelID)'")
            invitationHandler(false, nil)
            return
        }

        DispatchQueue.main.async {
            if let uidNelContesto { self.uidPerPeer[peerID] = uidNelContesto }
            if haPonte { self.peerConPonte.insert(peerID) }

            if self.declinedPeers.contains(peerID) {
                self.logger.logNetworkInfo("Invito di \(peerID.displayName) declinato: rifiutato da poco")
                invitationHandler(false, nil)
                return
            }

            // "64 clicks to accept for one 8 person call" (recensione App Store):
            // chi e' gia' stato accettato, chi e' sul nostro canale privato e chi
            // stiamo invitando noi entra senza domande.
            let coppia = quando.map {
                CoppieFidate.riconosce(firme: firme, quando: $0, invitato: self.instanceID, nome: peerID.displayName)
            } ?? false
            if let motivo = self.motivoAccettazioneAutomatica(peerID, coppia: coppia) {
                self.logger.logNetworkInfo("Invito auto-accettato (\(motivo)) da \(peerID.displayName)")
                self.accettatiInAttesa.insert(peerID)
                invitationHandler(true, self.session)
                return
            }

            // Lo stesso dispositivo richiede mentre la domanda e' ancora a
            // schermo: resta la stessa domanda, cambia solo l'invito a cui
            // risponde (il piu' recente, che non e' ancora scaduto dall'altra parte).
            let invito = (id: UUID(), peer: peerID, arrivato: Date(), handler: invitationHandler)
            if let i = self.invitiInCoda.firstIndex(where: { $0.peer == peerID }) {
                self.invitiInCoda[i].handler(false, nil)
                self.invitiInCoda[i] = invito
                if i == 0 { self.mostraInvito(invito.id, peer: peerID, arrivato: invito.arrivato) }
                return
            }

            self.invitiInCoda.append(invito)
            if self.invitiInCoda.count == 1 {
                self.mostraInvito(invito.id, peer: peerID, arrivato: invito.arrivato)
            }
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
            if let uid = info?["uid"] { self.uidPerPeer[peerID] = uid }
            if info?["ponte"] == "1" { self.peerConPonte.insert(peerID) }
            Funnel.once(Funnel.peerFound, ["transport": "multipeer"])
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

// MARK: - Coppie fidate

/// Chi e' stato accettato a mano una volta rientra senza domanda. Non lo si
/// riconosce da qualcosa che si vede nella ricerca dei vicini (nome, uid), che
/// chiunque puo' copiare: alla prima accettazione i due telefoni si scambiano
/// dentro la sessione un segreto casuale, e negli inviti successivi chi invita
/// porta una firma di quel segreto legata all'uid di questo avvio di chi riceve
/// e all'ora. Il segreto non viaggia mai: una firma copiata vale solo per
/// quell'avvio, per pochi minuti e una volta.
///
/// Nel Portachiavi, non in UserDefaults: e' una chiave, non una preferenza.
/// Sul main, come gli inviti.
enum CoppieFidate {
    /// Al massimo tante firme in un invito: con il nome "iPhone" (da iOS 16
    /// quasi tutti) i segreti con lo stesso nome possono essere piu' d'uno.
    static let firmePerInvito = 8
    private static let massimo = 200
    /// Scarto fra gli orologi dei due telefoni accettato per una firma.
    private static let finestra: TimeInterval = 120
    private static let servizio = "talky.coppie.multipeer"
    private static let account = "v1"

    private struct Coppia: Codable {
        var segreto: Data
        var nome: String
        var usata: Date
    }

    /// Firme gia' viste: la stessa non apre due volte.
    private static var usate: [String: Date] = [:]

    static func nuova(nome: String) -> Data {
        var byte = [UInt8](repeating: 0, count: 32)
        if SecRandomCopyBytes(kSecRandomDefault, byte.count, &byte) != errSecSuccess {
            byte = (0..<32).map { _ in UInt8.random(in: .min ... .max) }
        }
        let segreto = Data(byte)
        salva(segreto, nome: nome)
        return segreto
    }

    static func salva(_ segreto: Data, nome: String) {
        var tutte = leggi().filter { $0.segreto != segreto }
        tutte.append(Coppia(segreto: segreto, nome: nome, usata: Date()))
        scrivi(Array(tutte.sorted { $0.usata < $1.usata }.suffix(massimo)))
    }

    static func dimentica(_ segreto: Data) {
        scrivi(leggi().filter { $0.segreto != segreto })
    }

    /// Le firme da mettere nell'invito a un peer con questo nome, dalla coppia
    /// usata piu' di recente. Vuoto se non lo abbiamo mai accettato.
    static func firme(per nome: String, invitato: String, quando: Int) -> [String] {
        leggi()
            .filter { $0.nome == nome }
            .sorted { $0.usata > $1.usata }
            .prefix(firmePerInvito)
            .map { firma($0.segreto, invitato: invitato, quando: quando) }
    }

    /// Vero se una delle firme viene da un segreto che abbiamo, e' per questo
    /// avvio, e' di adesso e non e' gia' stata usata.
    static func riconosce(firme: [String], quando: Int, invitato: String, nome: String) -> Bool {
        let adesso = Date()
        guard !firme.isEmpty,
              abs(adesso.timeIntervalSince1970 - TimeInterval(quando)) <= finestra else { return false }
        usate = usate.filter { adesso.timeIntervalSince($0.value) < finestra * 2 }
        let nuove = firme.filter { usate[$0] == nil }
        guard !nuove.isEmpty else { return false }

        var tutte = leggi()
        for i in tutte.indices {
            let attesa = firma(tutte[i].segreto, invitato: invitato, quando: quando)
            guard nuove.contains(attesa) else { continue }
            usate[attesa] = adesso
            tutte[i].usata = adesso
            // Il nome serve solo a scegliere quali firme mandare: se l'altro ha
            // rinominato il telefono lo si aggiorna, il segreto resta quello.
            tutte[i].nome = nome
            scrivi(tutte)
            return true
        }
        return false
    }

    private static func firma(_ segreto: Data, invitato: String, quando: Int) -> String {
        let messaggio = Data("talky-invito|\(invitato)|\(quando)".utf8)
        let codice = HMAC<SHA256>.authenticationCode(for: messaggio, using: SymmetricKey(data: segreto))
        return Data(codice).prefix(16).base64EncodedString()
    }

    private static var interrogazione: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: servizio,
         kSecAttrAccount as String: account]
    }

    private static func leggi() -> [Coppia] {
        var q = interrogazione
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var risultato: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &risultato) == errSecSuccess,
              let dati = risultato as? Data else { return [] }
        return (try? JSONDecoder().decode([Coppia].self, from: dati)) ?? []
    }

    private static func scrivi(_ coppie: [Coppia]) {
        guard let dati = try? JSONEncoder().encode(coppie) else { return }
        let stato = SecItemUpdate(interrogazione as CFDictionary, [kSecValueData as String: dati] as CFDictionary)
        guard stato == errSecItemNotFound else { return }
        var nuovo = interrogazione
        nuovo[kSecValueData as String] = dati
        // Dopo il primo sblocco: gli inviti arrivano anche a schermo spento.
        // Senza "ThisDeviceOnly", cosi' le coppie tornano con il backup.
        nuovo[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(nuovo as CFDictionary, nil)
    }
}
