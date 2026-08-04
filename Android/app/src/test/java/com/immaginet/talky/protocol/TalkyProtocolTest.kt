package com.immaginet.talky.protocol

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TalkyProtocolTest {
    @Test
    fun appleWireEncodingUsesPercent20ForSpaces() {
        val line = TalkyProtocol.encodeLine(
            TalkyMessage.hello(
                uid = "android-123",
                name = "Google Pixel 10 Pro",
                channel = "public"
            )
        )

        assertTrue(line.contains("name=Google%20Pixel%2010%20Pro"))
        assertFalse(line.contains("Google+Pixel"))
    }

    @Test
    fun literalPlusRoundTripsWithoutBecomingSpace() {
        val decoded = TalkyProtocol.decodeLine(
            "TALKY1|HELLO|uid=android-123|name=C%2B%2B%20Phone|channel=public\n"
        )

        assertEquals("C++ Phone", decoded?.fields?.get(TalkyProtocol.Keys.NAME))
    }

    @Test
    fun unicodeAndProtocolDelimitersRoundTrip() {
        val original = "Andréa | Pixel=Pro +"
        val decoded = TalkyProtocol.decodeLine(
            TalkyProtocol.encodeLine(TalkyMessage.hello("android-123", original, "public"))
        )

        assertEquals(original, decoded?.fields?.get(TalkyProtocol.Keys.NAME))
    }

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
    fun audioEndUsesStableWireLine() {
        val line = TalkyProtocol.encodeLine(TalkyMessage.audioEnd())

        assertEquals("TALKY1|AUDIO_END\n", line)
        assertEquals(TalkyMessageType.AUDIO_END, TalkyProtocol.decodeLine(line)?.type)
    }

    @Test
    fun decodeRejectsUnknownVersion() {
        val decoded = TalkyProtocol.decodeLine("TALKY2|HEARTBEAT\n")

        assertNull(decoded)
    }
}
