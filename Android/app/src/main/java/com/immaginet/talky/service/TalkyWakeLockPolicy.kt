package com.immaginet.talky.service

object TalkyWakeLockPolicy {
    fun shouldHold(
        walkieReady: Boolean,
        radioActive: Boolean,
        isTransmitting: Boolean
    ): Boolean = walkieReady || radioActive || isTransmitting
}
