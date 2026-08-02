package com.immaginet.talky.net

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import com.immaginet.talky.audio.AudioManager
import com.immaginet.talky.protocol.PeerChannelPolicy
import com.immaginet.talky.protocol.PeerConnectionPolicy
import com.immaginet.talky.protocol.TalkyMessage
import com.immaginet.talky.protocol.TalkyMessageType
import com.immaginet.talky.protocol.TalkyProtocol
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.Closeable
import java.io.DataInputStream
import java.io.DataOutputStream
import java.net.ServerSocket
import java.net.InetSocketAddress
import java.net.Socket
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

data class CrossPlatformPeer(
    val uid: String,
    val name: String,
    val host: String,
    val port: Int,
    val channel: String
)

private data class PeerConnection(
    val socket: Socket,
    val output: DataOutputStream,
    val peer: CrossPlatformPeer,
    val connectionId: Long,
    val channelGeneration: Long,
    val readerJob: Job
) : Closeable {
    override fun close() {
        readerJob.cancel()
        runCatching { output.close() }
        runCatching { socket.close() }
    }
}

sealed interface TransmissionStartResult {
    data object Started : TransmissionStartResult
    data object NoPeer : TransmissionStartResult
    data object PermissionDenied : TransmissionStartResult
    data object AlreadyTransmitting : TransmissionStartResult
}

class CrossPlatformWalkieManager(
    context: Context
) : Closeable {
    private val appContext = context.applicationContext
    private val nsdManager = appContext.getSystemService(Context.NSD_SERVICE) as NsdManager
    private val wifiManager = appContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
    private val executor: ExecutorService = Executors.newCachedThreadPool()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val isClosed = AtomicBoolean(false)
    private val channelGeneration = AtomicLong(0)
    private val connectionSequence = AtomicLong(0)
    private val channelLock = Any()
    private val uid = UUID.randomUUID().toString()
    private val deviceName = "${Build.MANUFACTURER} ${Build.MODEL}".trim()
    private var serverSocket: ServerSocket? = null
    private var registrationListener: NsdManager.RegistrationListener? = null
    private var discoveryListener: NsdManager.DiscoveryListener? = null
    private var multicastLock: WifiManager.MulticastLock? = null
    private val peerConnections = ConcurrentHashMap<String, PeerConnection>()
    private var heartbeatJob: Job? = null

    val audioManager = AudioManager(context)
    private var audioStreamingJob: Job? = null
    private var onTransmissionStateChanged: ((Boolean) -> Unit)? = null

    var currentChannel by mutableStateOf(TalkyProtocol.DEFAULT_CHANNEL)

    var status by mutableStateOf("Pronto")
        private set

    var localEndpoint by mutableStateOf("")
        private set

    var isConnected by mutableStateOf(false)
        private set

    var remoteAudioActive by mutableStateOf(false)
        private set

    var transmissionError by mutableStateOf<String?>(null)
        private set

    val discoveredPeers = mutableStateListOf<CrossPlatformPeer>()
    val events = mutableStateListOf<String>()

    fun start() {
        if (isClosed.get()) return
        if (serverSocket != null) return

        acquireMulticastLock()
        startServer()
        registerService()
        startDiscovery()
        startHeartbeat()
        addEvent("TALKY1 avviato su canale $currentChannel")
    }

    fun restart() {
        stopTransmitting()
        invalidateConnections()
        stopNetwork()
        start()
    }

    fun setChannel(newChannel: String) {
        if (newChannel == currentChannel) return
        stopTransmitting()
        synchronized(channelLock) {
            currentChannel = newChannel
            channelGeneration.incrementAndGet()
            disconnectAllPeers()
            discoveredPeers.clear()
        }
        addEvent("Canale cambiato: $newChannel")
        stopNetwork()
        start()
    }

    fun suspendNetwork() {
        stopTransmitting()
        invalidateConnections()
        stopNetwork()
    }

    fun setTransmissionStateListener(listener: ((Boolean) -> Unit)?) {
        onTransmissionStateChanged = listener
    }

    fun startTransmitting(): TransmissionStartResult {
        if (ContextCompat.checkSelfPermission(appContext, Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            transmissionError = "Permesso microfono non concesso"
            addEvent(transmissionError.orEmpty())
            return TransmissionStartResult.PermissionDenied
        }

        if (peerConnections.isEmpty()) {
            addEvent("Nessun peer connesso per trasmettere")
            return TransmissionStartResult.NoPeer
        }

        if (audioStreamingJob?.isActive == true) {
            addEvent("Già in trasmissione")
            return TransmissionStartResult.AlreadyTransmitting
        }

        transmissionError = null
        onTransmissionStateChanged?.invoke(true)
        audioStreamingJob = scope.launch {
            try {
                addEvent("Inizio trasmissione audio")

                val metaMsg = TalkyMessage.audioMeta(
                    byteCount = AudioManager.BUFFER_SIZE_FRAMES * 2,
                    sampleRate = AudioManager.SAMPLE_RATE,
                    channels = AudioManager.CHANNELS,
                    encoding = TalkyProtocol.PCM_ENCODING
                )
                broadcastMessage(metaMsg)

                audioManager.startCapturing().collect { pcmData ->
                    broadcastRawAudio(pcmData)
                }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Exception) {
                transmissionError = error.localizedMessage ?: "Acquisizione microfono non disponibile"
                addEvent("Trasmissione audio fallita: $transmissionError")
            } finally {
                audioManager.stopCapturing()
                addEvent("Fine trasmissione audio")
                onTransmissionStateChanged?.invoke(false)
            }
        }

        return TransmissionStartResult.Started
    }

    fun stopTransmitting() {
        audioManager.stopCapturing()
        audioStreamingJob?.cancel()
        audioStreamingJob = null
        onTransmissionStateChanged?.invoke(false)
    }

    fun isTransmitting(): Boolean = audioStreamingJob?.isActive == true

    override fun close() {
        if (isClosed.compareAndSet(false, true)) {
            stopTransmitting()
            audioManager.close()
            stopNetwork()
            invalidateConnections()
            scope.cancel()
            executor.shutdownNow()
        }
    }

    private fun startServer() {
        val socket = ServerSocket(0)
        serverSocket = socket
        localEndpoint = "Locale: ${socket.localPort} / ${TalkyProtocol.SERVICE_TYPE}"
        status = "Advertising + discovery attivi"

        executor.execute {
            while (!socket.isClosed && !isClosed.get()) {
                runCatching {
                    val client = socket.accept()
                    handleIncomingConnection(client)
                }.onFailure { error ->
                    if (!socket.isClosed) addEvent("Server TCP: ${error.localizedMessage}")
                }
            }
        }
    }

    private fun handleIncomingConnection(socket: Socket) {
        val host = socket.inetAddress.hostAddress ?: socket.inetAddress.hostName
        val port = socket.port

        runCatching {
            socket.soTimeout = HANDSHAKE_TIMEOUT_MS
            val (channelSnapshot, generationSnapshot) = channelSnapshot()
            val output = DataOutputStream(BufferedOutputStream(socket.getOutputStream()))
            val input = DataInputStream(BufferedInputStream(socket.getInputStream()))

            val helloLine = TalkyProtocol.encodeLine(
                TalkyMessage.hello(uid = uid, name = deviceName, channel = channelSnapshot)
            )
            writeFrame(output, helloLine.toByteArray())

            val firstFrame = readFrame(input) ?: run {
                socket.close()
                return
            }

            val firstText = firstFrame.toString(Charsets.UTF_8)
            val message = TalkyProtocol.decodeLine(firstText) ?: run {
                addEvent("Frame non-TALKY1 da $host")
                socket.close()
                return
            }

            if (message.type != TalkyMessageType.HELLO) {
                socket.close()
                return
            }

            val peerUid = message.fields[TalkyProtocol.Keys.UID] ?: "$host:$port"
            val peerName = message.fields[TalkyProtocol.Keys.NAME] ?: host
            val peerChannel = message.fields[TalkyProtocol.Keys.CHANNEL]
                ?: TalkyProtocol.DEFAULT_CHANNEL

            if (!PeerChannelPolicy.matchesSnapshot(
                    currentChannel,
                    channelGeneration.get(),
                    peerChannel,
                    generationSnapshot
                )
            ) {
                addEvent("Canale incompatibile da $peerName: $peerChannel")
                socket.close()
                return
            }

            val peer = CrossPlatformPeer(
                uid = peerUid,
                name = peerName,
                host = host,
                port = port,
                channel = peerChannel
            )

            // Apple peers receive heartbeats but do not send them. Keep connected reads
            // unbounded after the bounded handshake so idle iOS/macOS links stay alive.
            socket.soTimeout = 0
            val connectionId = connectionSequence.incrementAndGet()
            val readerJob = scope.launch(start = CoroutineStart.LAZY) {
                readPeerFrames(peer, generationSnapshot, connectionId, input)
            }

            val connection = PeerConnection(
                socket,
                output,
                peer,
                connectionId,
                generationSnapshot,
                readerJob
            )
            if (installConnection(connection)) {
                readerJob.start()
                addEvent("Connesso con ${peer.name}")
            } else {
                connection.close()
            }
        }.onFailure { error ->
            addEvent("Handshake fallito $host: ${error.localizedMessage}")
            runCatching { socket.close() }
        }
    }

    private fun registerService() {
        val port = serverSocket?.localPort ?: return
        val serviceInfo = NsdServiceInfo().apply {
            serviceName = "Talky Android ${uid.take(4)}"
            serviceType = TalkyProtocol.SERVICE_TYPE
            setPort(port)
            setAttribute(TalkyProtocol.TXT_PROTOCOL_KEY, TalkyProtocol.TXT_PROTOCOL_VALUE)
            setAttribute(TalkyProtocol.Keys.UID, uid)
            setAttribute(TalkyProtocol.Keys.NAME, deviceName)
            setAttribute(TalkyProtocol.Keys.CHANNEL, currentChannel)
        }

        registrationListener = object : NsdManager.RegistrationListener {
            override fun onServiceRegistered(info: NsdServiceInfo) {
                addEvent("Bonjour registrato: ${info.serviceName}:${info.port}")
            }

            override fun onRegistrationFailed(info: NsdServiceInfo, errorCode: Int) {
                addEvent("Registrazione Bonjour fallita: $errorCode")
            }

            override fun onServiceUnregistered(info: NsdServiceInfo) {
                addEvent("Bonjour fermato")
            }

            override fun onUnregistrationFailed(info: NsdServiceInfo, errorCode: Int) {
                addEvent("Stop Bonjour fallito: $errorCode")
            }
        }

        nsdManager.registerService(
            serviceInfo,
            NsdManager.PROTOCOL_DNS_SD,
            registrationListener
        )
    }

    private fun startDiscovery() {
        discoveryListener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(serviceType: String) {
                addEvent("Discovery avviata: $serviceType")
            }

            override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                if (serviceInfo.serviceType != TalkyProtocol.SERVICE_TYPE) return
                if (serviceInfo.serviceName.startsWith("Talky Android ${uid.take(4)}")) return
                resolveService(serviceInfo)
            }

            override fun onServiceLost(serviceInfo: NsdServiceInfo) {
                discoveredPeers.removeAll { it.name == serviceInfo.serviceName }
                addEvent("Peer perso: ${serviceInfo.serviceName}")
            }

            override fun onDiscoveryStopped(serviceType: String) {
                addEvent("Discovery fermata")
            }

            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                addEvent("Discovery fallita: $errorCode")
                nsdManager.stopServiceDiscovery(this)
            }

            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
                addEvent("Stop discovery fallito: $errorCode")
            }
        }

        nsdManager.discoverServices(
            TalkyProtocol.SERVICE_TYPE,
            NsdManager.PROTOCOL_DNS_SD,
            discoveryListener
        )
    }

    private fun resolveService(serviceInfo: NsdServiceInfo) {
        nsdManager.resolveService(
            serviceInfo,
            object : NsdManager.ResolveListener {
                override fun onResolveFailed(info: NsdServiceInfo, errorCode: Int) {
                    addEvent("Resolve fallito ${info.serviceName}: $errorCode")
                }

                override fun onServiceResolved(info: NsdServiceInfo) {
                    val (channelSnapshot, generationSnapshot) = channelSnapshot()
                    val host = info.host?.hostAddress ?: return
                    val proto = info.attributes[TalkyProtocol.TXT_PROTOCOL_KEY]
                        ?.toString(Charsets.UTF_8)
                    if (proto != TalkyProtocol.TXT_PROTOCOL_VALUE) {
                        addEvent("Ignoro servizio non TALKY1: ${info.serviceName}")
                        return
                    }

                    val peerUid = info.attributes[TalkyProtocol.Keys.UID]
                        ?.toString(Charsets.UTF_8) ?: info.serviceName

                    val peerChannel = info.attributes[TalkyProtocol.Keys.CHANNEL]
                        ?.toString(Charsets.UTF_8)
                    if (!PeerChannelPolicy.matches(channelSnapshot, peerChannel)) {
                        discoveredPeers.removeAll { it.uid == peerUid }
                        addEvent("Ignoro ${info.serviceName}: canale ${peerChannel ?: "public"}")
                        return
                    }

                    if (peerConnections.containsKey(peerUid)) return

                    val peer = CrossPlatformPeer(
                        uid = peerUid,
                        name = info.attributes[TalkyProtocol.Keys.NAME]?.toString(Charsets.UTF_8)
                            ?: info.serviceName,
                        host = host,
                        port = info.port,
                        channel = peerChannel ?: TalkyProtocol.DEFAULT_CHANNEL
                    )
                    val stillCurrent = synchronized(channelLock) {
                        if (!PeerChannelPolicy.matchesSnapshot(
                                currentChannel,
                                channelGeneration.get(),
                                peer.channel,
                                generationSnapshot
                            )
                        ) {
                            false
                        } else {
                            upsertPeer(peer)
                            true
                        }
                    }
                    if (!stillCurrent) return
                    connectToPeer(peer)
                }
            }
        )
    }

    private fun connectToPeer(peer: CrossPlatformPeer) {
        val (channelSnapshot, generationSnapshot) = channelSnapshot()
        if (!PeerChannelPolicy.matches(channelSnapshot, peer.channel)) return
        executor.execute {
            var pendingSocket: Socket? = null
            runCatching {
                val socket = Socket().apply {
                    connect(InetSocketAddress(peer.host, peer.port), HANDSHAKE_TIMEOUT_MS)
                    soTimeout = HANDSHAKE_TIMEOUT_MS
                }.also { pendingSocket = it }
                val output = DataOutputStream(BufferedOutputStream(socket.getOutputStream()))
                val input = DataInputStream(BufferedInputStream(socket.getInputStream()))

                val helloLine = TalkyProtocol.encodeLine(
                    TalkyMessage.hello(uid = uid, name = deviceName, channel = channelSnapshot)
                )
                writeFrame(output, helloLine.toByteArray())

                val firstFrame = readFrame(input) ?: run {
                    socket.close()
                    return@execute
                }

                val firstText = firstFrame.toString(Charsets.UTF_8)
                val message = TalkyProtocol.decodeLine(firstText)
                if (message?.type != TalkyMessageType.HELLO) {
                    socket.close()
                    return@execute
                }

                val helloChannel = message.fields[TalkyProtocol.Keys.CHANNEL]
                if (!PeerChannelPolicy.matchesSnapshot(
                        currentChannel,
                        channelGeneration.get(),
                        helloChannel,
                        generationSnapshot
                    )
                ) {
                    addEvent("Handshake rifiutato ${peer.name}: canale ${helloChannel ?: "public"}")
                    socket.close()
                    return@execute
                }

                val validatedPeer = peer.copy(
                    uid = message.fields[TalkyProtocol.Keys.UID] ?: peer.uid,
                    name = message.fields[TalkyProtocol.Keys.NAME] ?: peer.name,
                    channel = helloChannel ?: TalkyProtocol.DEFAULT_CHANNEL
                )

                socket.soTimeout = 0
                val connectionId = connectionSequence.incrementAndGet()
                val readerJob = scope.launch(start = CoroutineStart.LAZY) {
                    readPeerFrames(validatedPeer, generationSnapshot, connectionId, input)
                }

                val connection = PeerConnection(
                    socket,
                    output,
                    validatedPeer,
                    connectionId,
                    generationSnapshot,
                    readerJob
                )
                if (installConnection(connection)) {
                    readerJob.start()
                    addEvent("Connesso con ${validatedPeer.name}")
                } else {
                    connection.close()
                }
            }.onFailure { error ->
                runCatching { pendingSocket?.close() }
                addEvent("Connessione fallita ${peer.name}: ${error.localizedMessage}")
            }
        }
    }

    private suspend fun readPeerFrames(
        peer: CrossPlatformPeer,
        connectionGeneration: Long,
        connectionId: Long,
        input: DataInputStream
    ) {
        try {
            while (isClosed.get().not()) {
                val frame = readFrame(input) ?: break
                if (!isConnectionCurrent(peer.channel, connectionGeneration)) break
                val text = frame.toString(Charsets.UTF_8)

                val message = TalkyProtocol.decodeLine(text)
                if (message != null) {
                    handleProtocolMessage(peer, connectionGeneration, connectionId, message)
                } else {
                    handleAudioFrame(peer, connectionGeneration, frame)
                }
            }
        } catch (e: Exception) {
            if (isClosed.get().not()) {
                addEvent("Peer ${peer.name} disconnesso: ${e.message}")
            }
        } finally {
            disconnectPeer(peer.uid, connectionId)
            isConnected = peerConnections.isNotEmpty()
        }
    }

    private fun handleProtocolMessage(
        peer: CrossPlatformPeer,
        connectionGeneration: Long,
        connectionId: Long,
        message: TalkyMessage
    ) {
        if (!isConnectionCurrent(peer.channel, connectionGeneration)) {
            disconnectPeer(peer.uid, connectionId)
            return
        }
        when (message.type) {
            TalkyMessageType.HELLO -> {
                val helloChannel = message.fields[TalkyProtocol.Keys.CHANNEL]
                if (!PeerChannelPolicy.matches(currentChannel, helloChannel)) {
                    addEvent("HELLO rifiutato ${peer.name}: canale ${helloChannel ?: "public"}")
                    disconnectPeer(peer.uid, connectionId)
                } else {
                    addEvent("HELLO da ${peer.name}")
                }
            }
            TalkyMessageType.HEARTBEAT -> {
            }
            TalkyMessageType.INVITE -> {
                addEvent("INVITE da ${peer.name}")
                val acceptMsg = TalkyMessage(type = TalkyMessageType.ACCEPT)
                sendMessageToPeer(peer.uid, acceptMsg)
            }
            TalkyMessageType.ACCEPT -> {
                addEvent("ACCEPT da ${peer.name}")
            }
            TalkyMessageType.AUDIO_META -> {
                synchronized(channelLock) {
                    if (!isConnectionCurrent(peer.channel, connectionGeneration)) return
                    addEvent("Audio in arrivo da ${peer.name}")
                    prepareForIncomingAudio()
                }
            }
        }
    }

    private fun handleAudioFrame(
        peer: CrossPlatformPeer,
        connectionGeneration: Long,
        frame: ByteArray
    ) {
        synchronized(channelLock) {
            if (!isConnectionCurrent(peer.channel, connectionGeneration)) return
            if (remoteAudioActive.not()) {
                remoteAudioActive = true
            }
            audioManager.writeAudio(frame)
        }
    }

    private fun prepareForIncomingAudio() {
        remoteAudioActive = true
        audioManager.prepareTrack()
    }

    private fun startHeartbeat() {
        heartbeatJob?.cancel()
        heartbeatJob = scope.launch {
            while (isClosed.get().not()) {
                delay(10_000)
                broadcastMessage(TalkyMessage.heartbeat())
            }
        }
    }

    private fun broadcastMessage(message: TalkyMessage) {
        val line = TalkyProtocol.encodeLine(message)
        val data = line.toByteArray()
        peerConnections.values
            .filter(::isConnectionCurrent)
            .forEach { conn ->
            runCatching {
                writeFrame(conn.output, data)
            }
        }
    }

    private fun sendMessageToPeer(peerUid: String, message: TalkyMessage) {
        val conn = peerConnections[peerUid] ?: return
        if (!isConnectionCurrent(conn)) return
        val line = TalkyProtocol.encodeLine(message)
        runCatching {
            writeFrame(conn.output, line.toByteArray())
        }
    }

    private fun broadcastRawAudio(pcmData: ByteArray) {
        peerConnections.values
            .filter(::isConnectionCurrent)
            .forEach { conn ->
            runCatching {
                writeFrame(conn.output, pcmData)
            }
        }
    }

    private fun writeFrame(output: DataOutputStream, data: ByteArray) {
        output.writeInt(data.size)
        output.write(data)
        output.flush()
    }

    private fun readFrame(input: DataInputStream): ByteArray? {
        return try {
            val length = input.readInt()
            if (length <= 0 || length > 1024 * 1024) return null
            val data = ByteArray(length)
            input.readFully(data)
            data
        } catch (e: Exception) {
            null
        }
    }

    private fun disconnectPeer(peerUid: String, expectedConnectionId: Long? = null) {
        val connection = peerConnections[peerUid] ?: return
        if (expectedConnectionId != null && !PeerConnectionPolicy.isSameConnection(
                activeConnectionId = connection.connectionId,
                expectedConnectionId = expectedConnectionId
            )
        ) {
            return
        }
        if (peerConnections.remove(peerUid, connection)) {
            connection.close()
        }
        if (peerConnections.isEmpty()) {
            remoteAudioActive = false
            audioManager.stopPlayback()
        }
    }

    private fun disconnectAllPeers() {
        peerConnections.keys.forEach { disconnectPeer(it) }
        peerConnections.clear()
        isConnected = false
        remoteAudioActive = false
    }

    private fun invalidateConnections() {
        synchronized(channelLock) {
            channelGeneration.incrementAndGet()
            disconnectAllPeers()
            discoveredPeers.clear()
        }
    }

    private fun channelSnapshot(): Pair<String, Long> = synchronized(channelLock) {
        currentChannel to channelGeneration.get()
    }

    private fun isConnectionCurrent(connection: PeerConnection): Boolean =
        isConnectionCurrent(connection.peer.channel, connection.channelGeneration)

    private fun isConnectionCurrent(peerChannel: String, connectionGeneration: Long): Boolean =
        PeerChannelPolicy.matchesSnapshot(
            currentChannel,
            channelGeneration.get(),
            peerChannel,
            connectionGeneration
        )

    private fun installConnection(connection: PeerConnection): Boolean =
        synchronized(channelLock) {
            if (!isConnectionCurrent(connection)) return@synchronized false
            disconnectPeer(connection.peer.uid)
            peerConnections[connection.peer.uid] = connection
            upsertPeer(connection.peer)
            isConnected = true
            true
        }

    private fun upsertPeer(peer: CrossPlatformPeer) {
        discoveredPeers.removeAll { it.uid == peer.uid }
        discoveredPeers.add(peer)
    }

    private fun stopNetwork() {
        heartbeatJob?.cancel()
        heartbeatJob = null

        discoveryListener?.let { listener ->
            runCatching { nsdManager.stopServiceDiscovery(listener) }
        }
        discoveryListener = null

        registrationListener?.let { listener ->
            runCatching { nsdManager.unregisterService(listener) }
        }
        registrationListener = null

        runCatching { serverSocket?.close() }
        serverSocket = null
        localEndpoint = ""
        status = "Fermo"
        releaseMulticastLock()
    }

    private fun acquireMulticastLock() {
        if (multicastLock?.isHeld == true) return
        multicastLock = wifiManager.createMulticastLock("talky-mdns").apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    private fun releaseMulticastLock() {
        multicastLock?.let { lock ->
            if (lock.isHeld) lock.release()
        }
        multicastLock = null
    }

    private fun addEvent(message: String) {
        events.add(message)
        if (events.size > 80) events.removeRange(0, events.size - 80)
    }

    private companion object {
        const val HANDSHAKE_TIMEOUT_MS = 10_000
    }
}
