package com.immaginet.talky

import org.junit.Assert.assertEquals
import org.junit.Test

class AppModePolicyTest {
    @Test
    fun activeBackgroundRadioSelectsRadioWhenUiHasNoSavedMode() {
        assertEquals(AppMode.RADIO, initialAppMode(savedMode = null, radioIsPlaying = true))
    }

    @Test
    fun savedModeWinsAcrossServiceRebind() {
        assertEquals(
            AppMode.RADIO,
            initialAppMode(savedMode = AppMode.RADIO, radioIsPlaying = false)
        )
        assertEquals(
            AppMode.WALKIE,
            initialAppMode(savedMode = AppMode.WALKIE, radioIsPlaying = true)
        )
    }
}
