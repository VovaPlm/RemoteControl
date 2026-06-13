package com.remotecontrol.ui.theme

import android.app.Activity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

private val BinanceDarkColorScheme = darkColorScheme(
    primary = BinancePrimary,
    onPrimary = BinanceOnPrimary,
    primaryContainer = BinanceYellow20,
    onPrimaryContainer = BinancePrimary,
    secondary = BinanceTextSecondary,
    onSecondary = BinanceTextPrimary,
    background = BinanceBackground,
    onBackground = BinanceTextPrimary,
    surface = BinanceSurface,
    onSurface = BinanceTextPrimary,
    surfaceVariant = BinanceSurfaceVariant,
    onSurfaceVariant = BinanceTextSecondary,
    outline = BinanceBorder,
    error = BinanceDanger,
    onError = BinanceTextPrimary,
)

@Composable
fun RemoteControlTheme(
    content: @Composable () -> Unit
) {
    val colorScheme = BinanceDarkColorScheme
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = BinanceBackground.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = false
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        content = content
    )
}
