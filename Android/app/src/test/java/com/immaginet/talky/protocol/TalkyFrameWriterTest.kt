package com.immaginet.talky.protocol

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.OutputStream
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class TalkyFrameWriterTest {

    @Test
    fun `concurrent writes remain complete parseable frames`() {
        val output = HeaderInterleavingOutputStream(expectedWriters = 2)
        val writer = TalkyFrameWriter(DataOutputStream(output))
        val start = CountDownLatch(1)
        val firstPayload = "AAAA".toByteArray()
        val secondPayload = "BBBB".toByteArray()

        val threads = listOf(firstPayload, secondPayload).map { payload ->
            Thread {
                start.await()
                writer.write(payload)
            }.apply { start() }
        }

        start.countDown()
        threads.forEach { it.join(2_000) }

        val input = DataInputStream(ByteArrayInputStream(output.toByteArray()))
        val received = List(2) {
            val length = input.readInt()
            ByteArray(length).also(input::readFully)
        }

        assertEquals(
            listOf("AAAA", "BBBB"),
            received.map { it.toString(Charsets.UTF_8) }.sorted()
        )
    }

    @Test
    fun `writer rejects payloads outside TALKY1 frame bounds`() {
        val writer = TalkyFrameWriter(DataOutputStream(ByteArrayOutputStream()))

        assertThrows(IllegalArgumentException::class.java) {
            writer.write(byteArrayOf())
        }
        assertThrows(IllegalArgumentException::class.java) {
            writer.write(ByteArray(TalkyFrameWriter.MAX_PAYLOAD_BYTES + 1))
        }
    }
}

/**
 * Coaxes an unprotected writer into placing both length headers before either
 * payload. A serialized writer times out the first wait and remains valid.
 */
private class HeaderInterleavingOutputStream(expectedWriters: Int) : OutputStream() {
    private val delegate = ByteArrayOutputStream()
    private val headers = CountDownLatch(expectedWriters)
    private val headerBytesByThread = ThreadLocal.withInitial { 0 }

    override fun write(value: Int) {
        synchronized(delegate) {
            delegate.write(value)
        }
        val count = (headerBytesByThread.get() ?: 0) + 1
        headerBytesByThread.set(count)
        if (count == Int.SIZE_BYTES) {
            headers.countDown()
            headers.await(100, TimeUnit.MILLISECONDS)
        }
    }

    override fun write(buffer: ByteArray, offset: Int, length: Int) {
        synchronized(delegate) {
            delegate.write(buffer, offset, length)
        }
    }

    override fun flush() = Unit

    fun toByteArray(): ByteArray = synchronized(delegate) {
        delegate.toByteArray()
    }
}
