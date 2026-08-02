package com.immaginet.talky.protocol

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PeerChannelPolicyTest {
    @Test
    fun matchingChannelsAreAccepted() {
        assertTrue(PeerChannelPolicy.matches("ch3", "ch3"))
    }

    @Test
    fun mismatchingChannelsAreRejected() {
        assertFalse(PeerChannelPolicy.matches("ch3", "public"))
    }

    @Test
    fun missingChannelMeansPublicOnly() {
        assertTrue(PeerChannelPolicy.matches("public", null))
        assertFalse(PeerChannelPolicy.matches("ch3", null))
    }

    @Test
    fun blankChannelsAreRejected() {
        assertFalse(PeerChannelPolicy.matches("public", ""))
        assertFalse(PeerChannelPolicy.matches("", "public"))
    }
}
