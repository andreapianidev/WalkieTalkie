package com.immaginet.talky.service

import android.content.pm.ServiceInfo
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TalkyForegroundTypePolicyTest {
    @Test
    fun idleServiceUsesConnectedDeviceAndMediaPlaybackWithoutMicrophone() {
        val types = TalkyForegroundTypePolicy.types(isTransmitting = false)

        assertTrue(types and ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE != 0)
        assertTrue(types and ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK != 0)
        assertFalse(types and ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE != 0)
    }

    @Test
    fun transmittingServiceAddsMicrophoneWithoutDroppingBaseTypes() {
        val baseTypes = TalkyForegroundTypePolicy.types(isTransmitting = false)
        val transmittingTypes = TalkyForegroundTypePolicy.types(isTransmitting = true)

        assertEquals(baseTypes, transmittingTypes and baseTypes)
        assertTrue(transmittingTypes and ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE != 0)
    }
}
