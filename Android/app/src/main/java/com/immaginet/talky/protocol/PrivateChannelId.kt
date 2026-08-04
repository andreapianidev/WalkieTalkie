package com.immaginet.talky.protocol

import java.security.MessageDigest

object PrivateChannelId {
    const val MIN_PASSWORD_LENGTH = 4

    fun fromPassword(password: String): String {
        require(password.length >= MIN_PASSWORD_LENGTH) {
            "Private channel password must contain at least four characters"
        }
        return MessageDigest.getInstance("SHA-256")
            .digest(password.toByteArray(Charsets.UTF_8))
            .joinToString(separator = "") { byte ->
                "%02x".format(byte.toInt() and 0xff)
            }
            .take(16)
    }
}
