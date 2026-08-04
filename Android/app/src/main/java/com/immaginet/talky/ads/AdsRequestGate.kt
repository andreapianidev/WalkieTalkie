package com.immaginet.talky.ads

import java.util.concurrent.atomic.AtomicBoolean

class AdsRequestGate {
    private val opened = AtomicBoolean(false)

    fun tryOpen(
        consentInformationRequested: Boolean,
        canRequestAds: Boolean
    ): Boolean = consentInformationRequested &&
        canRequestAds &&
        opened.compareAndSet(false, true)
}
