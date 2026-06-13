package com.remotecontrol.viewmodel

import android.annotation.SuppressLint
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Surface
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import com.remotecontrol.network.RemoteControlClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

enum class ConnectionState {
    DISCONNECTED, CONNECTING, CONNECTED, ERROR
}

class MainViewModel : ViewModel() {
    var connectionState by mutableStateOf(ConnectionState.DISCONNECTED)
    var statusMessage by mutableStateOf("")
    var serverHost by mutableStateOf("")
    var serverPort by mutableStateOf("9090")
    var errorMessage by mutableStateOf("")
    var screenWidth by mutableStateOf(1920f)
    var screenHeight by mutableStateOf(1080f)

    private val clientScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var client: RemoteControlClient? = null
    private var mediaCodec: MediaCodec? = null
    private var codecSurface: Surface? = null
    private var pendingSurface: Surface? = null
    private var codecConfigured = false

    fun connect() {
        if (serverHost.isBlank()) {
            mainHandler.post { errorMessage = "Enter server address" }
            return
        }

        mainHandler.post {
            connectionState = ConnectionState.CONNECTING
            statusMessage = "Connecting..."
            errorMessage = ""
        }

        client = RemoteControlClient(clientScope).apply {
            onConnected = {
                mainHandler.post {
                    connectionState = ConnectionState.CONNECTED
                    statusMessage = "Connected to $serverHost:$serverPort"
                }
            }
            onDisconnected = { error ->
                mainHandler.post {
                    connectionState = ConnectionState.DISCONNECTED
                    statusMessage = "Disconnected"
                    if (error != null) {
                        errorMessage = error.message ?: "Connection lost"
                    }
                    releaseCodec()
                }
            }
            onVideoFrame = { data ->
                try {
                    mainHandler.post { decodeH264Frame(data) }
                } catch (t: Throwable) {
                    android.util.Log.e("RemoteControl", "onVideoFrame error", t)
                }
            }
            onHandshakeReply = {
                mainHandler.post { statusMessage = "Handshake complete" }
            }
            onScreenInfo = { w, h ->
                mainHandler.post {
                    screenWidth = w
                    screenHeight = h
                    createCodec()
                }
            }
        }

        client?.connect(serverHost.trim(), serverPort.trim().toIntOrNull() ?: 9090)
    }

    fun disconnect() {
        client?.disconnect()
        client = null
        releaseCodec()
        connectionState = ConnectionState.DISCONNECTED
        statusMessage = "Disconnected"
    }

    @SuppressLint("InlinedApi")
    fun setupCodec(surface: Surface) {
        codecSurface = surface
        if (screenWidth > 0 && screenHeight > 0 && codecSurface != null) {
            createCodec()
        } else {
            pendingSurface = surface
        }
    }

    private fun createCodec() {
        val surface = codecSurface ?: return
        val w = screenWidth.toInt()
        val h = screenHeight.toInt()
        if (w <= 0 || h <= 0) return
        releaseCodec()
        try {
            val format = MediaFormat.createVideoFormat(
                MediaFormat.MIMETYPE_VIDEO_AVC, w, h
            )
            format.setInteger(MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            format.setInteger(MediaFormat.KEY_FRAME_RATE, 15)
            format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 2)

            val codec = MediaCodec.createDecoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
            codec.configure(format, surface, null, 0)
            codec.start()
            mediaCodec = codec
            codecConfigured = true
        } catch (e: Exception) {
            errorMessage = "Codec error: ${e.message}"
        }
    }

    fun releaseCodec() {
        try {
            mediaCodec?.stop()
            mediaCodec?.release()
        } catch (_: Throwable) {}
        mediaCodec = null
        codecConfigured = false
    }

    private fun decodeH264Frame(data: ByteArray) {
        try {
            val codec = mediaCodec ?: return
            val inputIndex = codec.dequeueInputBuffer(10_000)
            if (inputIndex < 0) return

            val inputBuffer = codec.getInputBuffer(inputIndex) ?: return
            inputBuffer.clear()
            inputBuffer.put(data)
            codec.queueInputBuffer(
                inputIndex,
                0, data.size,
                System.nanoTime() / 1000,
                0
            )

            val bufInfo = MediaCodec.BufferInfo()
            var outputIndex = codec.dequeueOutputBuffer(bufInfo, 10_000)
            while (outputIndex >= 0) {
                val doRender = bufInfo.size > 0
                codec.releaseOutputBuffer(outputIndex, doRender)
                outputIndex = codec.dequeueOutputBuffer(bufInfo, 0)
            }
        } catch (t: Throwable) {
            android.util.Log.e("RemoteControl", "decodeH264Frame error", t)
        }
    }

    // MARK: - Input

    fun sendMouseMove(dx: Float, dy: Float) {
        Log.d("RemoteControl", "VM sendMouseMove dx=$dx dy=$dy")
        client?.sendMouseMove(dx, dy)
    }

    fun sendMouseMoveAbsolute(x: Float, y: Float) {
        Log.d("RemoteControl", "VM sendMouseMoveAbsolute x=$x y=$y")
        client?.sendMouseMoveAbsolute(x, y)
    }

    fun sendMouseDown(button: Int = 0) {
        Log.d("RemoteControl", "VM sendMouseDown btn=$button")
        client?.sendMouseDown(button)
    }

    fun sendMouseUp(button: Int = 0) {
        Log.d("RemoteControl", "VM sendMouseUp btn=$button")
        client?.sendMouseUp(button)
    }

    fun sendScroll(dx: Float, dy: Float) {
        Log.d("RemoteControl", "VM sendScroll dx=$dx dy=$dy")
        client?.sendScroll(dx, dy)
    }

    fun sendKeyDown(keyCode: UShort) {
        Log.d("RemoteControl", "VM sendKeyDown code=0x${keyCode.toString(16)}")
        client?.sendKeyDown(keyCode)
    }

    fun sendKeyUp(keyCode: UShort) {
        Log.d("RemoteControl", "VM sendKeyUp code=0x${keyCode.toString(16)}")
        client?.sendKeyUp(keyCode)
    }

    fun sendCharInput(text: String) {
        Log.d("RemoteControl", "VM sendCharInput: \"$text\"")
        client?.sendCharInput(text)
    }

    override fun onCleared() {
        super.onCleared()
        disconnect()
        clientScope.cancel()
    }
}
