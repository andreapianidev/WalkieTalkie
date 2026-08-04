package com.immaginet.talky.service

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TalkyWakeLockPolicyTest {
    @Test
    fun `idle discovery and platform-managed playback do not hold a manual CPU lock`() {
        assertFalse(TalkyWakeLockPolicy.shouldHold(isTransmitting = false))
    }

    @Test
    fun `active microphone capture keeps CPU awake`() {
        assertTrue(TalkyWakeLockPolicy.shouldHold(isTransmitting = true))
    }
}
