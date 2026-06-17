package com.remotecontrol.ui.screens

import android.app.Activity
import android.graphics.SurfaceTexture
import android.os.Build
import android.util.Log
import android.view.Surface
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.TextureView
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.remotecontrol.ui.theme.BinanceDanger
import com.remotecontrol.ui.theme.BinanceSuccess
import com.remotecontrol.ui.theme.BinanceSurface
import com.remotecontrol.ui.theme.BinanceTextPrimary
import com.remotecontrol.ui.theme.BinanceTextSecondary
import com.remotecontrol.viewmodel.MainViewModel

@Composable
fun RemoteScreen(
    viewModel: MainViewModel
) {
    var showKeyboard by remember { mutableStateOf(false) }
    var showMenu by remember { mutableStateOf(false) }

    var lastTapTime by remember { mutableStateOf(0L) }
    var dragMode by remember { mutableStateOf(false) }

    // Immersive mode — скрываем шторку уведомлений Samsung
    val context = LocalContext.current
    DisposableEffect(Unit) {
        val window = (context as? Activity)?.window ?: return@DisposableEffect onDispose {}
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.hide(
                WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars()
            )
            window.insetsController?.systemBarsBehavior =
                WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
            )
        }
        onDispose {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                window.insetsController?.show(
                    WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars()
                )
            } else {
                @Suppress("DEPRECATION")
                window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE
            }
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        // Video centered (main content)
        BoxWithConstraints(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            val videoAspect = viewModel.screenWidth / viewModel.screenHeight
            val boxW: Dp
            val boxH: Dp
            if (maxWidth / maxHeight > videoAspect) {
                boxW = maxHeight * videoAspect
                boxH = maxHeight
            } else {
                boxW = maxWidth
                boxH = maxWidth / videoAspect
            }
            Box(
                modifier = Modifier
                    .width(boxW)
                    .height(boxH)
            ) {
                AndroidView(
                    factory = { ctx ->
                        TextureView(ctx).apply {
                            isOpaque = false
                            surfaceTextureListener = object : TextureView.SurfaceTextureListener {
                                override fun onSurfaceTextureAvailable(
                                    surface: SurfaceTexture, width: Int, height: Int
                                ) {
                                    viewModel.setupCodec(Surface(surface))
                                }
                                override fun onSurfaceTextureSizeChanged(
                                    surface: SurfaceTexture, width: Int, height: Int
                                ) {}
                                override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean {
                                    viewModel.releaseCodec()
                                    return true
                                }
                                override fun onSurfaceTextureUpdated(surface: SurfaceTexture) {}
                            }
                        }
                    },
                    modifier = Modifier.fillMaxSize()
                )

                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .pointerInput(Unit) {
                            val doubleTapMs = 400L
                            detectTapGestures(
                                onTap = {
                                    val vw = viewModel.screenWidth
                                    val vh = viewModel.screenHeight
                                    val ax = (it.x / size.width) * vw
                                    val ay = (it.y / size.height) * vh
                                    Log.d("RemoteControl", "tap overlay=$it size=${size.width}x${size.height} → video=${ax.toInt()}x${ay.toInt()}")
                                    viewModel.sendMouseMoveAbsolute(ax, ay)
                                    val now = System.currentTimeMillis()
                                    if (now - lastTapTime < doubleTapMs) {
                                        dragMode = !dragMode
                                        if (dragMode) {
                                            viewModel.sendMouseDown()
                                            Log.d("RemoteControl", "dragMode ON")
                                        } else {
                                            viewModel.sendMouseUp()
                                            Log.d("RemoteControl", "dragMode OFF")
                                        }
                                        lastTapTime = 0L
                                    } else {
                                        lastTapTime = now
                                        if (!dragMode) {
                                            viewModel.sendMouseDown()
                                            viewModel.sendMouseUp()
                                        }
                                    }
                                }
                            )
                        }
                        .pointerInput(Unit) {
                            detectDragGestures(
                                onDragEnd = {
                                    if (!dragMode) viewModel.sendMouseUp()
                                },
                                onDragCancel = {
                                    if (!dragMode) viewModel.sendMouseUp()
                                },
                                onDrag = { change, _ ->
                                    change.consume()
                                    val vw = viewModel.screenWidth
                                    val vh = viewModel.screenHeight
                                    val ax = (change.position.x / size.width) * vw
                                    val ay = (change.position.y / size.height) * vh
                                    Log.d("RemoteControl", "drag pos=${change.position} size=${size.width}x${size.height} → video=${ax.toInt()}x${ay.toInt()}")
                                    viewModel.sendMouseMoveAbsolute(ax, ay)
                                },
                                onDragStart = {
                                    val vw = viewModel.screenWidth
                                    val vh = viewModel.screenHeight
                                    val ax = (it.x / size.width) * vw
                                    val ay = (it.y / size.height) * vh
                                    Log.d("RemoteControl", "dragStart offset=$it size=${size.width}x${size.height} → video=${ax.toInt()}x${ay.toInt()}")
                                    viewModel.sendMouseMoveAbsolute(ax, ay)
                                    if (!dragMode) viewModel.sendMouseDown()
                                }
                            )
                        }
                )

                if (viewModel.connectionState != com.remotecontrol.viewmodel.ConnectionState.CONNECTED) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(Color.Black.copy(alpha = 0.7f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "Reconnecting...",
                            color = BinanceTextSecondary,
                            fontSize = 16.sp
                        )
                    }
                }
            }
        }

        // Live indicator
        Row(
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(6.dp)
                .background(BinanceSurface.copy(alpha = 0.8f), RoundedCornerShape(4.dp))
                .padding(horizontal = 6.dp, vertical = 3.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(6.dp)
                    .clip(CircleShape)
                    .background(BinanceSuccess)
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(
                text = "Live",
                fontSize = 10.sp,
                color = BinanceSuccess
            )
        }

        // Menu button
        Box(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(12.dp)
                .clickable { showMenu = true }
                .background(BinanceSurface.copy(alpha = 0.9f), CircleShape)
                .size(40.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "⋮",
                color = BinanceTextPrimary,
                fontSize = 20.sp
            )
        }

        // Keyboard capture (tiny strip at bottom, invisible, grabs IME focus)
        Box(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .height(1.dp)
        ) {
            if (showKeyboard) {
                AndroidView(
                    factory = { ctx ->
                        KeyboardCaptureView(ctx).apply {
                            onKeyDown = { code -> viewModel.sendKeyDown(code) }
                            onKeyUp = { code -> viewModel.sendKeyUp(code) }
                            onCharInput = { text -> viewModel.sendCharInput(text) }
                        }
                    },
                    modifier = Modifier.fillMaxSize()
                )
            }
        }
    }

    // Menu dialog
    if (showMenu) {
        AlertDialog(
            onDismissRequest = { showMenu = false },
            title = { Text("Menu", color = BinanceTextPrimary) },
            text = {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    val scope = rememberCoroutineScope()
                    TextButton(
                        onClick = {
                            if (!showKeyboard) {
                                showKeyboard = true
                            } else {
                                showKeyboard = false
                                scope.launch {
                                    kotlinx.coroutines.delay(100)
                                    showKeyboard = true
                                }
                            }
                            showMenu = false
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Keyboard", color = BinanceTextPrimary)
                    }
                    TextButton(
                        onClick = {
                            viewModel.sendMouseDown(1)
                            viewModel.sendMouseUp(1)
                            showMenu = false
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Right Click", color = BinanceTextPrimary)
                    }
                    TextButton(
                        onClick = {
                            viewModel.sendMouseDown(2)
                            viewModel.sendMouseUp(2)
                            showMenu = false
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Middle Click", color = BinanceTextPrimary)
                    }
                    TextButton(
                        onClick = {
                            viewModel.disconnect()
                            showMenu = false
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Disconnect", color = BinanceDanger)
                    }
                }
            },
            confirmButton = {},
            containerColor = BinanceSurface,
            titleContentColor = BinanceTextPrimary,
            textContentColor = BinanceTextPrimary
        )
    }
}
