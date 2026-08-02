package com.immaginet.talky.protocol

object PeerChannelPolicy {
    fun matches(currentChannel: String, peerChannel: String?): Boolean {
        if (currentChannel.isBlank()) return false
        val normalizedPeerChannel = peerChannel ?: TalkyProtocol.DEFAULT_CHANNEL
        return normalizedPeerChannel.isNotBlank() && normalizedPeerChannel == currentChannel
    }

    fun matchesSnapshot(
        currentChannel: String,
        currentGeneration: Long,
        peerChannel: String?,
        connectionGeneration: Long
    ): Boolean = currentGeneration == connectionGeneration && matches(currentChannel, peerChannel)
}
