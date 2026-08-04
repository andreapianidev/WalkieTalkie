package com.immaginet.talky.radio

data class RadioPlaybackState(
    val isPlaying: Boolean,
    val stationId: Int,
    val stationName: String,
    val stationCountry: String,
    val isBuffering: Boolean,
    val error: String?
) {
    fun beginBuffering(station: RadioStation): RadioPlaybackState = copy(
        isPlaying = false,
        stationId = station.id,
        stationName = station.name,
        stationCountry = station.country,
        isBuffering = true,
        error = null
    )

    fun playing(station: RadioStation): RadioPlaybackState = copy(
        isPlaying = true,
        stationId = station.id,
        stationName = station.name,
        stationCountry = station.country,
        isBuffering = false,
        error = null
    )

    fun withBuffering(active: Boolean): RadioPlaybackState = copy(
        isBuffering = active,
        error = null
    )

    fun stopped(): RadioPlaybackState = idle()

    fun failed(message: String): RadioPlaybackState = idle().copy(error = message)

    companion object {
        fun idle(): RadioPlaybackState = RadioPlaybackState(
            isPlaying = false,
            stationId = -1,
            stationName = "",
            stationCountry = "",
            isBuffering = false,
            error = null
        )
    }
}
