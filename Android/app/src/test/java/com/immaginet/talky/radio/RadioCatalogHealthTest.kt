package com.immaginet.talky.radio

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RadioCatalogHealthTest {
    private val radioSource = sequenceOf(
        File("app/src/main/java/com/immaginet/talky/radio/RadioManager.kt"),
        File("src/main/java/com/immaginet/talky/radio/RadioManager.kt")
    ).first { it.isFile }.readText()

    @Test
    fun catalogKeepsStableCountAndUsesVerifiedReplacementStreams() {
        assertEquals(343, Regex("RadioStation\\(").findAll(radioSource).count())

        VERIFIED_STREAMS.forEach { url ->
            assertTrue("Missing verified stream $url", radioSource.contains(url))
        }
        RETIRED_STREAMS.forEach { url ->
            assertFalse("Retired stream still present $url", radioSource.contains(url))
        }
    }

    private companion object {
        val VERIFIED_STREAMS = listOf(
            "https://playerservices.streamtheworld.com/api/livestream-redirect/JOSEQUAVO_S01.m3u8",
            "https://muste.latvijasradio.lv/shoutcast/mp4:lr2a.stream/playlist.m3u8",
            "https://icecast.rtl2.fr/rtl2-1-44-128",
            "https://deephouse-radio.com/api/stream/free",
            "https://icecast.funradio.fr/fun-1-44-128",
            "https://usest-mcp1.golivestream.net:19360/lamega981fm/lamega981fm.m3u8"
        )

        val RETIRED_STREAMS = listOf(
            "https://mediaworks.streamguys1.com/magic_net_icy",
            "http://lr2mp1.latvijasradio.lv:8002/",
            "http://streamer-02.rtl.fr/rtl2-1-44-128",
            "http://62.210.105.16:7000/stream",
            "http://streaming.radio.funradio.fr/fun-1-44-128",
            "https://www.streaming507.net:8152/stream"
        )
    }
}
