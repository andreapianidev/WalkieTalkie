package com.immaginet.talky.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val TalkyDarkScheme = darkColorScheme(
    primary = TalkyGreen,
    secondary = Color(0xFF8FA889),
    background = TalkyBackground,
    surface = TalkySurface,
    onPrimary = Color(0xFF061009),
    onSecondary = Color(0xFFEAF4D3),
    onBackground = Color(0xFFEAF4D3),
    onSurface = Color(0xFFEAF4D3)
)

@Composable
fun WalkieTalkieAndroidTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = TalkyDarkScheme,
        typography = Typography,
        content = content
    )
}
