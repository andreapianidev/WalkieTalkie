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

    override fun close() {
        synchronized(writeLock) {
            output.close()
        }
    }

    companion object {
        const val MAX_PAYLOAD_BYTES = 1024 * 1024
    }
}
