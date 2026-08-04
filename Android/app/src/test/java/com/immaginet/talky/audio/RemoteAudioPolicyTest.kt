package com.immaginet.talky.audio

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RemoteAudioPolicyTest {

    @Test
    fun `legacy receive remains active only inside inactivity window`() {
        val lastFrameAtMillis = 1_000L

        assertTrue(
            RemoteAudioPolicy.isActive(
                lastFrameAtMillis = lastFrameAtMillis,
                nowMillis = lastFrameAtMillis + RemoteAudioPolicy.INACTIVITY_TIMEOUT_MS - 1
            )
        )
        assertFalse(
            RemoteAudioPolicy.isActive(
                lastFrameAtMillis = lastFrameAtMillis,
                nowMillis = lastFrameAtMillis + RemoteAudioPolicy.INACTIVITY_TIMEOUT_MS
            )
        )
    }

    @Test
    fun `PTT is blocked while remote audio is active`() {
        assertFalse(RemoteAudioPolicy.canStartTransmission(remoteAudioActive = true))
        assertTrue(RemoteAudioPolicy.canStartTransmission(remoteAudioActive = false))
    }

    @Test
    fun `late audio end from another peer does not stop the active speaker`() {
        assertFalse(
            RemoteAudioPolicy.shouldFinish(
                activePeerUid = "peer-b",
                endingPeerUid = "peer-a"
            )
        )
        assertTrue(
            RemoteAudioPolicy.shouldFinish(
                activePeerUid = "peer-b",
                endingPeerUid = "peer-b"
            )
        )
    }
}
