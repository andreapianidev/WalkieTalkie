package com.immaginet.talky.permissions

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WalkiePermissionPolicyTest {
    @Test
    fun deniedMicrophoneStillAllowsReceive() {
        val policy = WalkiePermissionPolicy(
            microphoneGranted = false,
            networkGranted = true
        )

        assertTrue(policy.canReceive)
        assertFalse(policy.canTransmit)
    }

    @Test
    fun deniedNetworkBlocksReceiveAndTransmit() {
        val policy = WalkiePermissionPolicy(
            microphoneGranted = true,
            networkGranted = false
        )

        assertFalse(policy.canReceive)
        assertFalse(policy.canTransmit)
    }

    @Test
    fun allRequiredPermissionsAllowReceiveAndTransmit() {
        val policy = WalkiePermissionPolicy(
            microphoneGranted = true,
            networkGranted = true
        )

        assertTrue(policy.canReceive)
        assertTrue(policy.canTransmit)
    }
}
