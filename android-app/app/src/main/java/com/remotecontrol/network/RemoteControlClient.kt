package com.remotecontrol.network

import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.io.InputStream
import java.io.OutputStream
import java.net.InetSocketAddress
import java.net.Socket
import java.nio.ByteBuffer
import java.nio.ByteOrder
import javax.net.SocketFactory

class RemoteControlClient(
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.IO)
) {
    private var socket: Socket? = null
    private var inputStream: InputStream? = null
    private var outputStream: OutputStream? = null
    private var readJob: Job? = null
    private var keepAliveJob: Job? = null
    private val sendMutex = Mutex()
    private val readBuffer = ByteArray(65536)
    private var recvBuffer = ByteArray(0)

    var onVideoFrame: ((ByteArray) -> Unit)? = null
    var onConnected: (() -> Unit)? = null
    var onDisconnected: ((Exception?) -> Unit)? = null
    var onHandshakeReply: (() -> Unit)? = null
    var onScreenInfo: ((Float, Float) -> Unit)? = null
    var onKeepAlive: (() -> Unit)? = null
    var onAuthResult: ((Boolean) -> Unit)? = null

    private var pendingScreenW = 0f
    private var pendingScreenH = 0f
    private var authLogin = ""
    private var authPassword = ""

    val isConnected: Boolean get() = socket?.isConnected == true && !socket!!.isClosed

    fun connect(host: String, port: Int, login: String = "", password: String = "") {
        authLogin = login
        authPassword = password
        readJob = scope.launch {
            try {
                val sock = Socket()
                sock.connect(InetSocketAddress(host, port), 5000)
                sock.tcpNoDelay = true
                socket = sock
                inputStream = sock.getInputStream()
                outputStream = sock.getOutputStream()

                send(Message.handshake())

                startKeepAlive()
                readLoop()
            } catch (e: Exception) {
                onDisconnected?.invoke(e)
            }
        }
    }

    fun disconnect() {
        keepAliveJob?.cancel()
        readJob?.cancel()
        try {
            socket?.close()
        } catch (_: Exception) {}
        socket = null
    }

    private suspend fun readLoop() {
        val stream = inputStream ?: return
        try {
            while (true) {
                val bytesRead = stream.read(readBuffer)
                if (bytesRead == -1) break

                val data = recvBuffer + readBuffer.copyOfRange(0, bytesRead)
                recvBuffer = ByteArray(0)

                var offset = 0
                while (offset < data.size) {
                    val remaining = data.copyOfRange(offset, data.size)
                    val result = Message.deserialize(remaining) ?: break
                    val (msg, consumed) = result
                    offset += consumed
                    handleMessage(msg)
                }
                if (offset < data.size) {
                    recvBuffer = data.copyOfRange(offset, data.size)
                }
            }
        } catch (e: Exception) {
            onDisconnected?.invoke(e)
        }
    }

    private fun handleMessage(msg: Message) {
        when (msg.type) {
            MessageType.VIDEO_FRAME -> onVideoFrame?.invoke(msg.payload)
            MessageType.HANDSHAKE -> send(Message.handshakeReply())
            MessageType.HANDSHAKE_REPLY -> {
                if (msg.payload.size >= 8) {
                    val bb = ByteBuffer.wrap(msg.payload).order(ByteOrder.BIG_ENDIAN)
                    val w = bb.getFloat()
                    val h = bb.getFloat()
                    val authReq = msg.payload.size >= 9 && bb.get() == 1.toByte()
                    if (authReq) {
                        pendingScreenW = w
                        pendingScreenH = h
                        send(Message.auth(authLogin, authPassword))
                    } else {
                        onScreenInfo?.invoke(w, h)
                        onHandshakeReply?.invoke()
                        onConnected?.invoke()
                    }
                }
            }
            MessageType.AUTH_RESULT -> {
                val ok = msg.payload.isNotEmpty() && msg.payload[0] == 1.toByte()
                if (ok) {
                    onScreenInfo?.invoke(pendingScreenW, pendingScreenH)
                    onHandshakeReply?.invoke()
                    onConnected?.invoke()
                }
                onAuthResult?.invoke(ok)
            }
            MessageType.KEEP_ALIVE -> onKeepAlive?.invoke()
            else -> {}
        }
    }

    private fun startKeepAlive() {
        keepAliveJob = scope.launch {
            try {
                while (true) {
                    kotlinx.coroutines.delay(10_000)
                    send(Message.keepAlive())
                }
            } catch (_: kotlinx.coroutines.CancellationException) {
                // job cancelled
            }
        }
    }

    fun send(message: Message) {
        scope.launch {
            sendMutex.withLock {
                try {
                    val data = message.serialize()
                    Log.d("RemoteControl", "SEND type=${message.type} payload=${message.payload.size} bytes")
                    outputStream?.write(data)
                    outputStream?.flush()
                } catch (e: Exception) {
                    Log.e("RemoteControl", "SEND error", e)
                }
            }
        }
    }

    fun sendMouseMove(dx: Float, dy: Float) {
        send(Message.mouseMove(dx, dy))
    }

    fun sendMouseMoveAbsolute(x: Float, y: Float) {
        send(Message.mouseMoveAbsolute(x, y))
    }

    fun sendMouseDown(button: Int = 0) {
        send(Message.mouseDown(button))
    }

    fun sendMouseUp(button: Int = 0) {
        send(Message.mouseUp(button))
    }

    fun sendScroll(dx: Float, dy: Float) {
        send(Message.scroll(dx, dy))
    }

    fun sendKeyDown(keyCode: UShort) {
        send(Message.keyDown(keyCode))
    }

    fun sendKeyUp(keyCode: UShort) {
        send(Message.keyUp(keyCode))
    }

    fun sendCharInput(text: String) {
        send(Message.charInput(text))
    }
}
