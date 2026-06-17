package com.immaginet.talky.protocol

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TalkyProtocolTest {
    @Test
    fun helloRoundTripPreservesEscapedFields() {
        val message = TalkyMessage.hello(
            uid = "android-123",
            name = "Pixel | Andrea",
            channel = "public"
        )

        val decoded = TalkyProtocol.decodeLine(TalkyProtocol.encodeLine(message))

        assertEquals(TalkyMessageType.HELLO, decoded?.type)
        assertEquals("android-123", decoded?.fields?.get(TalkyProtocol.Keys.UID))
        assertEquals("Pixel | Andrea", decoded?.fields?.get(TalkyProtocol.Keys.NAME))
        assertEquals("public", decoded?.fields?.get(TalkyProtocol.Keys.CHANNEL))
    }

    @Test
    fun heartbeatUsesStableWireLine() {
        val line = TalkyProtocol.encodeLine(TalkyMessage.heartbeat())

        assertEquals("TALKY1|HEARTBEAT\n", line)
    }

    @Test
    fun audioMetadataRoundTripIncludesPcmShapeAndByteCount() {
        val decoded = TalkyProtocol.decodeLine(
            TalkyProtocol.encodeLine(
                TalkyMessage.audioMeta(
                    byteCount = 4096,
                    sampleRate = 48000,
                    channels = 1,
                    encoding = "pcm_s16le"
                )
            )
        )

        assertEquals(TalkyMessageType.AUDIO_META, decoded?.type)
        assertEquals("4096", decoded?.fields?.get(TalkyProtocol.Keys.BYTE_COUNT))
        assertEquals("48000", decoded?.fields?.get(TalkyProtocol.Keys.SAMPLE_RATE))
        assertEquals("1", decoded?.fields?.get(TalkyProtocol.Keys.CHANNELS))
        assertEquals("pcm_s16le", decoded?.fields?.get(TalkyProtocol.Keys.ENCODING))
    }

    @Test
    fun decodeRejectsUnknownVersion() {
        val decoded = TalkyProtocol.decodeLine("TALKY2|HEARTBEAT\n")

        assertNull(decoded)
    }
}
