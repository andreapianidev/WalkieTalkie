package com.immaginet.talky.net

object PeerLifecyclePolicy {
    private const val MAX_RECONNECT_DELAY_MS = 30_000L

    fun matchesLostService(peerServiceName: String?, lostServiceName: String): Boolean =
        peerServiceName != null && peerServiceName == lostServiceName

    fun reconnectDelayMillis(attempt: Int): Long {
        val exponent = (attempt - 1).coerceIn(0, 5)
        return (1_000L shl exponent).coerceAtMost(MAX_RECONNECT_DELAY_MS)
    }
}
