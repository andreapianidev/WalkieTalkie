package com.immaginet.talky.permissions

data class WalkiePermissionPolicy(
    val microphoneGranted: Boolean,
    val networkGranted: Boolean
) {
    val canReceive: Boolean
        get() = networkGranted

    val canTransmit: Boolean
        get() = networkGranted && microphoneGranted
}
