package com.immaginet.talky.protocol

import java.io.ByteArrayOutputStream
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

    private fun escape(value: String): String = buildString {
        value.toByteArray(StandardCharsets.UTF_8).forEach { signedByte ->
            val byte = signedByte.toInt() and 0xff
            if (isUnreserved(byte)) {
                append(byte.toChar())
            } else {
                append('%')
                append(HEX_DIGITS[byte ushr 4])
                append(HEX_DIGITS[byte and 0x0f])
            }
        }
    }

    private fun unescape(value: String): String {
        val output = ByteArrayOutputStream(value.length)
        var index = 0
        while (index < value.length) {
            if (value[index] == '%' && index + 2 < value.length) {
                val high = value[index + 1].digitToIntOrNull(16)
                val low = value[index + 2].digitToIntOrNull(16)
                if (high != null && low != null) {
                    output.write((high shl 4) or low)
                    index += 3
                    continue
                }
            }

            val codePoint = value.codePointAt(index)
            val rawBytes = String(Character.toChars(codePoint)).toByteArray(StandardCharsets.UTF_8)
            output.write(rawBytes)
            index += Character.charCount(codePoint)
        }
        return output.toByteArray().toString(StandardCharsets.UTF_8)
    }

    private fun isUnreserved(byte: Int): Boolean =
        byte in 'A'.code..'Z'.code ||
            byte in 'a'.code..'z'.code ||
            byte in '0'.code..'9'.code ||
            byte == '-'.code || byte == '.'.code || byte == '_'.code || byte == '~'.code

    private const val HEX_DIGITS = "0123456789ABCDEF"
}
