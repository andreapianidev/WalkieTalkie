package com.immaginet.talky.ads

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AdsRequestGateTest {

    @Test
    fun `ads stay blocked until consent information request completes`() {
        val gate = AdsRequestGate()

        assertFalse(
            gate.tryOpen(
                consentInformationRequested = false,
                canRequestAds = true
            )
        )
        assertFalse(
            gate.tryOpen(
                consentInformationRequested = true,
                canRequestAds = false
            )
        )
    }

    @Test
    fun `ads gate opens exactly once after UMP permits requests`() {
        val gate = AdsRequestGate()

        assertTrue(
            gate.tryOpen(
                consentInformationRequested = true,
                canRequestAds = true
            )
        )
        assertFalse(
            gate.tryOpen(
                consentInformationRequested = true,
                canRequestAds = true
            )
        )
    }
}
