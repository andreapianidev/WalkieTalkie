package com.immaginet.talky.service

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TalkyWakeLockPolicyTest {
    @Test
    fun idleServiceWithoutNetworkDoesNotKeepCpuAwake() {
        assertFalse(
            TalkyWakeLockPolicy.shouldHold(
                walkieReady = false,
                radioActive = false,
                isTransmitting = false
            )
        )
    }

    @Test
    fun activeAudioOrWalkieWorkKeepsCpuAwake() {
        assertTrue(TalkyWakeLockPolicy.shouldHold(true, false, false))
        assertTrue(TalkyWakeLockPolicy.shouldHold(false, true, false))
        assertTrue(TalkyWakeLockPolicy.shouldHold(false, false, true))
    }
}
