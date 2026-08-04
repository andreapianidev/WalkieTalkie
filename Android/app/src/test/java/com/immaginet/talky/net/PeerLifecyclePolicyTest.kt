package com.immaginet.talky.net

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PeerLifecyclePolicyTest {
    @Test
    fun `service loss matches stable NSD identity rather than display name`() {
        assertTrue(
            PeerLifecyclePolicy.matchesLostService(
                peerServiceName = "Talky Android abcd",
                lostServiceName = "Talky Android abcd"
            )
        )
        assertFalse(
            PeerLifecyclePolicy.matchesLostService(
                peerServiceName = "Talky Android abcd",
                lostServiceName = "Google Pixel 10 Pro"
            )
        )
        assertFalse(
            PeerLifecyclePolicy.matchesLostService(
                peerServiceName = null,
                lostServiceName = "Talky Android abcd"
            )
        )
    }

    @Test
    fun `reconnect delay backs off and remains bounded`() {
        assertEquals(1_000L, PeerLifecyclePolicy.reconnectDelayMillis(attempt = 1))
        assertEquals(2_000L, PeerLifecyclePolicy.reconnectDelayMillis(attempt = 2))
        assertEquals(8_000L, PeerLifecyclePolicy.reconnectDelayMillis(attempt = 4))
        assertEquals(30_000L, PeerLifecyclePolicy.reconnectDelayMillis(attempt = 20))
    }
}
