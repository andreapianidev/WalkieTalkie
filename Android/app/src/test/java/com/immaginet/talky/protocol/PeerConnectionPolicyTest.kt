package com.immaginet.talky.protocol

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PeerConnectionPolicyTest {
    @Test
    fun staleReaderCannotDisconnectReplacementOnSameChannelGeneration() {
        assertTrue(PeerConnectionPolicy.isSameConnection(42, 42))
        assertFalse(PeerConnectionPolicy.isSameConnection(43, 42))
    }
}
