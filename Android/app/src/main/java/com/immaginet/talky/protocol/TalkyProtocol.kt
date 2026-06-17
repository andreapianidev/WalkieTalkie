package com.immaginet.talky.protocol

import java.net.URLDecoder
import java.net.URLEncoder
import java.nio.charset.StandardCharsets

enum class TalkyMessageType {
    HELLO,
    HEARTBEAT,
    INVITE,
    ACCEPT,
    AUDIO_META
}

data class TalkyMessage(
    val type: TalkyMessageType,
    val fields: Map<String, String> = emptyMap()
) {
    companion object {
        fun hello(uid: String, name: String, channel: String): TalkyMessage =
            TalkyMessage(
                type = TalkyMessageType.HELLO,
                fields = mapOf(
                    TalkyProtocol.Keys.UID to uid,
                    TalkyProtocol.Keys.NAME to name,
                    TalkyProtocol.Keys.CHANNEL to channel
                )
            )

        fun heartbeat(): TalkyMessage =
            TalkyMessage(type = TalkyMessageType.HEARTBEAT)

        fun audioMeta(
            byteCount: Int,
            sampleRate: Int,
            channels: Int,
            encoding: String
        ): TalkyMessage =
            TalkyMessage(
                type = TalkyMessageType.AUDIO_META,
                fields = mapOf(
                    TalkyProtocol.Keys.BYTE_COUNT to byteCount.toString(),
                    TalkyProtocol.Keys.SAMPLE_RATE to sampleRate.toString(),
                    TalkyProtocol.Keys.CHANNELS to channels.toString(),
                    TalkyProtocol.Keys.ENCODING to encoding
                )
            )
    }
}

object TalkyProtocol {
    const val VERSION = "TALKY1"
    const val SERVICE_TYPE = "_walkie-talkie._tcp."
    const val TXT_PROTOCOL_KEY = "proto"
    const val TXT_PROTOCOL_VALUE = "talky1"
    const val DEFAULT_CHANNEL = "public"
    const val PCM_ENCODING = "pcm_s16le"
    const val SAMPLE_RATE = 48000
    const val CHANNELS = 1

    object Keys {
        const val UID = "uid"
        const val NAME = "name"
        const val CHANNEL = "channel"
        const val BYTE_COUNT = "byteCount"
        const val SAMPLE_RATE = "sampleRate"
        const val CHANNELS = "channels"
        const val ENCODING = "encoding"
    }

    fun encodeLine(message: TalkyMessage): String {
        val fields = message.fields.entries.joinToString(separator = "|") { (key, value) ->
            "${escape(key)}=${escape(value)}"
        }

        return if (fields.isEmpty()) {
            "$VERSION|${message.type.name}\n"
        } else {
            "$VERSION|${message.type.name}|$fields\n"
        }
    }

    fun decodeLine(rawLine: String): TalkyMessage? {
        val line = rawLine.trimEnd('\n', '\r')
        val parts = line.split("|")
        if (parts.size < 2 || parts[0] != VERSION) return null

        val type = runCatching { TalkyMessageType.valueOf(parts[1]) }.getOrNull() ?: return null
        val fields = parts
            .drop(2)
            .mapNotNull { part ->
                val equalsIndex = part.indexOf('=')
                if (equalsIndex <= 0) {
                    null
                } else {
                    val key = unescape(part.substring(0, equalsIndex))
                    val value = unescape(part.substring(equalsIndex + 1))
                    key to value
                }
            }
            .toMap()

        return TalkyMessage(type = type, fields = fields)
    }

    private fun escape(value: String): String =
        URLEncoder.encode(value, StandardCharsets.UTF_8.name())

    private fun unescape(value: String): String =
        URLDecoder.decode(value, StandardCharsets.UTF_8.name())
}
