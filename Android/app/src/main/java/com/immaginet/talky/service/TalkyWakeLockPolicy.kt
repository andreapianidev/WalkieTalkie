package com.immaginet.talky.service

object TalkyWakeLockPolicy {
    fun shouldHold(isTransmitting: Boolean): Boolean = isTransmitting
}
