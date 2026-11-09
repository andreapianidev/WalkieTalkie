package com.immaginet.talky.protocol

import java.io.DataOutputStream
import java.io.Closeable

/** Serializes complete TALKY1 frames for one peer connection. */
class TalkyFrameWriter(
    private val output: DataOutputStream
) : Closeable {
    private val writeLock = Any()

    fun write(payload: ByteArray) {
        require(payload.isNotEmpty()) { "TALKY1 frames cannot be empty" }
        require(payload.size <= MAX_PAYLOAD_BYTES) { "TALKY1 frame exceeds 1 MiB" }

        synchronized(writeLock) {
            output.writeInt(payload.size)
            output.write(payload)
            output.flush()
        }
    }

    /**
     * Piu' frame di seguito senza che un altro invio si infili in mezzo: un
     * AUDIO_META deve restare attaccato al suo audio, o chi riceve attribuisce
     * l'audio al messaggio sbagliato.
     */
    fun writeAll(vararg payloads: ByteArray) {
        payloads.forEach { payload ->
            require(payload.isNotEmpty()) { "TALKY1 frames cannot be empty" }
            require(payload.size <= MAX_PAYLOAD_BYTES) { "TALKY1 frame exceeds 1 MiB" }
        }

        synchronized(writeLock) {
            payloads.forEach { payload ->
                output.writeInt(payload.size)
                output.write(payload)
            }
            output.flush()
        }
    }

    override fun close() {
        synchronized(writeLock) {
            output.close()
        }
    }

    companion object {
        const val MAX_PAYLOAD_BYTES = 1024 * 1024
    }
}
