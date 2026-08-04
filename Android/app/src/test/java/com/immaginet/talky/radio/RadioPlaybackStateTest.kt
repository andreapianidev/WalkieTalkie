package com.immaginet.talky.radio

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RadioPlaybackStateTest {
    private val station = RadioStation(
        id = 7,
        name = "Radio Test",
        country = "Italia",
        frequency = "100.0",
        streamUrl = "https://example.com/live.mp3",
        genre = "Pop"
    )

    @Test
    fun `stop while buffering clears every active playback flag`() {
        val buffering = RadioPlaybackState.idle().beginBuffering(station)

        assertTrue(buffering.isBuffering)
        assertEquals(7, buffering.stationId)

        val stopped = buffering.stopped()

        assertFalse(stopped.isPlaying)
        assertFalse(stopped.isBuffering)
        assertEquals(-1, stopped.stationId)
        assertEquals("", stopped.stationName)
        assertEquals("", stopped.stationCountry)
        assertNull(stopped.error)
    }

    @Test
    fun `stream error clears playback and preserves useful error`() {
        val failed = RadioPlaybackState.idle()
            .beginBuffering(station)
            .playing(station)
            .failed("stream offline")

        assertFalse(failed.isPlaying)
        assertFalse(failed.isBuffering)
        assertEquals(-1, failed.stationId)
        assertEquals("stream offline", failed.error)
    }

    @Test
    fun `buffering updates preserve current station identity`() {
        val playing = RadioPlaybackState.idle().playing(station)
        val rebuffering = playing.withBuffering(true)

        assertTrue(rebuffering.isPlaying)
        assertTrue(rebuffering.isBuffering)
        assertEquals("Radio Test", rebuffering.stationName)
    }
}
