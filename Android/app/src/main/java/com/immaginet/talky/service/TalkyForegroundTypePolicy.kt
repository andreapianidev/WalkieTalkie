package com.immaginet.talky.service

import android.content.pm.ServiceInfo

object TalkyForegroundTypePolicy {
    fun types(isTransmitting: Boolean): Int {
        val baseTypes = ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE or
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
        return if (isTransmitting) {
            baseTypes or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        } else {
            baseTypes
        }
    }
}
