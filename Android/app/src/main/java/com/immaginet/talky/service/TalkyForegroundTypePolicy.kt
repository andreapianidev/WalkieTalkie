package com.immaginet.talky.service

import android.content.pm.ServiceInfo

object TalkyForegroundTypePolicy {
    fun types(isTransmitting: Boolean, isRadioActive: Boolean): Int {
        var types = ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
        if (isRadioActive) {
            types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
        }
        if (isTransmitting) {
            types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        }
        return types
    }
}
