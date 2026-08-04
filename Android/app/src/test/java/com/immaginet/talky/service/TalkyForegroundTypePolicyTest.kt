package com.immaginet.talky.service

import android.content.pm.ServiceInfo
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TalkyForegroundTypePolicyTest {
    @Test
    fun `idle walkie service uses connected device only`() {
        val types = TalkyForegroundTypePolicy.types(
            isTransmitting = false,
            isRadioActive = false
        )

        assertTrue(types and ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE != 0)
        assertFalse(types and ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK != 0)
        assertFalse(types and ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE != 0)
    }

    @Test
    fun `radio playback adds media type without microphone`() {
        val types = TalkyForegroundTypePolicy.types(
            isTransmitting = false,
            isRadioActive = true
        )

        assertTrue(types and ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE != 0)
        assertTrue(types and ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK != 0)
        assertFalse(types and ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE != 0)
    }

    @Test
    fun `microphone type is present only during transmission`() {
        val transmittingTypes = TalkyForegroundTypePolicy.types(
            isTransmitting = true,
            isRadioActive = false
        )

        assertTrue(transmittingTypes and ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE != 0)
        assertFalse(transmittingTypes and ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK != 0)
        assertTrue(transmittingTypes and ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE != 0)
    }
}
