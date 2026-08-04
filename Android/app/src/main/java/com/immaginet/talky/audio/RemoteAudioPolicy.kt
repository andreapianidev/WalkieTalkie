package com.immaginet.talky.audio

object RemoteAudioPolicy {
    const val INACTIVITY_TIMEOUT_MS = 600L

    fun isActive(lastFrameAtMillis: Long, nowMillis: Long): Boolean =
        nowMillis - lastFrameAtMillis < INACTIVITY_TIMEOUT_MS

    fun canStartTransmission(remoteAudioActive: Boolean): Boolean = !remoteAudioActive

    fun shouldFinish(activePeerUid: String?, endingPeerUid: String): Boolean =
        activePeerUid == endingPeerUid
}
