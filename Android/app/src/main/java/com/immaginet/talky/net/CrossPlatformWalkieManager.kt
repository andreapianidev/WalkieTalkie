package com.immaginet.talky.net

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.immaginet.talky.audio.AudioManager
import com.immaginet.talky.protocol.TalkyMessage
import com.immaginet.talky.protocol.TalkyMessageType
import com.immaginet.talky.protocol.TalkyProtocol
import kotlinx.coroutines.CoroutineScope
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
import java.net.Socket
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

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
    val readerJob: Job
) : Closeable {
    override fun close() {
        readerJob.cancel()
        runCatching { output.close() }
        runCatching { socket.close() }
    }
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
    private val uid = UUID.randomUUID().toString()
    private val deviceName = "${Build.MANUFACTURER} ${Build.MODEL}".trim()
    private val channel = TalkyProtocol.DEFAULT_CHANNEL

    private var serverSocket: ServerSocket? = null
    private var registrationListener: NsdManager.RegistrationListener? = null
    private var discoveryListener: NsdManager.DiscoveryListener? = null
    private var multicastLock: WifiManager.MulticastLock? = null
    private val peerConnections = ConcurrentHashMap<String, PeerConnection>()
    private var heartbeatJob: Job? = null

    val audioManager = AudioManager()
    private var audioStreamingJob: Job? = null

    var currentChannel by mutableStateOf(TalkyProtocol.DEFAULT_CHANNEL)

    var status by mutableStateOf("Pronto")
        private set

    var localEndpoint by mutableStateOf("")
        private set

    var isConnected by mutableStateOf(false)
        private set

    var remoteAudioActive by mutableStateOf(false)
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
        addEvent("TALKY1 avviato su canale $channel")
    }

    fun restart() {
        stopNetwork()
        start()
    }

    fun setChannel(newChannel: String) {
        if (newChannel == currentChannel) return
        currentChannel = newChannel
        addEvent("Canale cambiato: $newChannel")
        stopNetwork()
        start()
    }

    fun startTransmitting(): Boolean {
        if (peerConnections.isEmpty()) {
            addEvent("Nessun peer connesso per trasmettere")
            return false
        }

        if (audioStreamingJob?.isActive == true) {
            addEvent("Già in trasmissione")
            return false
        }

        audioStreamingJob = scope.launch {
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

            addEvent("Fine trasmissione audio")
        }

        return true
    }

    fun stopTransmitting() {
        audioManager.stopCapturing()
        audioStreamingJob?.cancel()
        audioStreamingJob = null
    }

    fun isTransmitting(): Boolean = audioStreamingJob?.isActive == true

    override fun close() {
        if (isClosed.compareAndSet(false, true)) {
            stopTransmitting()
            audioManager.close()
            stopNetwork()
            disconnectAllPeers()
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
            val output = DataOutputStream(BufferedOutputStream(socket.getOutputStream()))
            val input = DataInputStream(BufferedInputStream(socket.getInputStream()))

            val helloLine = TalkyProtocol.encodeLine(
                TalkyMessage.hello(uid = uid, name = deviceName, channel = currentChannel)
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

            val peer = CrossPlatformPeer(
                uid = peerUid,
                name = peerName,
                host = host,
                port = port,
                channel = peerChannel
            )

            val readerJob = scope.launch {
                readPeerFrames(peer, input)
            }

            val connection = PeerConnection(socket, output, peer, readerJob)
            disconnectPeer(peerUid)
            peerConnections[peerUid] = connection
            upsertPeer(peer)
            isConnected = peerConnections.isNotEmpty()
            addEvent("Connesso con ${peer.name}")
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
                    val host = info.host?.hostAddress ?: return
                    val proto = info.attributes[TalkyProtocol.TXT_PROTOCOL_KEY]
                        ?.toString(Charsets.UTF_8)
                    if (proto != TalkyProtocol.TXT_PROTOCOL_VALUE) {
                        addEvent("Ignoro servizio non TALKY1: ${info.serviceName}")
                        return
                    }

                    val peerUid = info.attributes[TalkyProtocol.Keys.UID]
                        ?.toString(Charsets.UTF_8) ?: info.serviceName

                    if (peerConnections.containsKey(peerUid)) return

                    val peer = CrossPlatformPeer(
                        uid = peerUid,
                        name = info.attributes[TalkyProtocol.Keys.NAME]?.toString(Charsets.UTF_8)
                            ?: info.serviceName,
                        host = host,
                        port = info.port,
                        channel = info.attributes[TalkyProtocol.Keys.CHANNEL]?.toString(Charsets.UTF_8)
                            ?: TalkyProtocol.DEFAULT_CHANNEL
                    )
                    upsertPeer(peer)
                    connectToPeer(peer)
                }
            }
        )
    }

    private fun connectToPeer(peer: CrossPlatformPeer) {
        executor.execute {
            runCatching {
                val socket = Socket(peer.host, peer.port)
                val output = DataOutputStream(BufferedOutputStream(socket.getOutputStream()))
                val input = DataInputStream(BufferedInputStream(socket.getInputStream()))

                val helloLine = TalkyProtocol.encodeLine(
                    TalkyMessage.hello(uid = uid, name = deviceName, channel = currentChannel)
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

                val readerJob = scope.launch {
                    readPeerFrames(peer, input)
                }

                val connection = PeerConnection(socket, output, peer, readerJob)
                disconnectPeer(peer.uid)
                peerConnections[peer.uid] = connection
                isConnected = peerConnections.isNotEmpty()
                addEvent("Connesso con ${peer.name}")
            }.onFailure { error ->
                addEvent("Connessione fallita ${peer.name}: ${error.localizedMessage}")
            }
        }
    }

    private suspend fun readPeerFrames(peer: CrossPlatformPeer, input: DataInputStream) {
        try {
            while (isClosed.get().not()) {
                val frame = readFrame(input) ?: break
                val text = frame.toString(Charsets.UTF_8)

                val message = TalkyProtocol.decodeLine(text)
                if (message != null) {
                    handleProtocolMessage(peer, message)
                } else {
                    handleAudioFrame(frame)
                }
            }
        } catch (e: Exception) {
            if (isClosed.get().not()) {
                addEvent("Peer ${peer.name} disconnesso: ${e.message}")
            }
        } finally {
            disconnectPeer(peer.uid)
            isConnected = peerConnections.isNotEmpty()
        }
    }

    private fun handleProtocolMessage(peer: CrossPlatformPeer, message: TalkyMessage) {
        when (message.type) {
            TalkyMessageType.HELLO -> {
                addEvent("HELLO da ${peer.name}")
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
                addEvent("Audio in arrivo da ${peer.name}")
                prepareForIncomingAudio()
            }
        }
    }

    private fun handleAudioFrame(frame: ByteArray) {
        if (remoteAudioActive.not()) {
            remoteAudioActive = true
        }
        audioManager.writeAudio(frame)
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
        peerConnections.values.forEach { conn ->
            runCatching {
                writeFrame(conn.output, data)
            }
        }
    }

    private fun sendMessageToPeer(peerUid: String, message: TalkyMessage) {
        val conn = peerConnections[peerUid] ?: return
        val line = TalkyProtocol.encodeLine(message)
        runCatching {
            writeFrame(conn.output, line.toByteArray())
        }
    }

    private fun broadcastRawAudio(pcmData: ByteArray) {
        peerConnections.values.forEach { conn ->
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

    private fun disconnectPeer(peerUid: String) {
        peerConnections.remove(peerUid)?.close()
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
}
