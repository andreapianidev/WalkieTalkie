package com.immaginet.talky.protocol

object PeerConnectionPolicy {
    fun isSameConnection(activeConnectionId: Long, expectedConnectionId: Long): Boolean =
        activeConnectionId == expectedConnectionId
}
