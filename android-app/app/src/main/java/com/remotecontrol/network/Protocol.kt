package com.remotecontrol.network

import java.io.DataInputStream
import java.io.DataOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

enum class MessageType(val id: UByte) {
    MOUSE_MOVE(0x01u),
    MOUSE_DOWN(0x02u),
    MOUSE_UP(0x03u),
    SCROLL(0x04u),
    KEY_DOWN(0x05u),
    KEY_UP(0x06u),
    VIDEO_FRAME(0x07u),
    KEEP_ALIVE(0x08u),
    HANDSHAKE(0x09u),
    HANDSHAKE_REPLY(0x0Au),
    MOUSE_MOVE_ABSOLUTE(0x0Bu),
    CHAR_INPUT(0x0Cu);

    companion object {
        private val map = entries.associateBy { it.id }
        fun fromId(id: UByte) = map[id]
    }
}

data class Message(
    val type: MessageType,
    val payload: ByteArray
) {
    fun serialize(): ByteArray {
        val buf = ByteBuffer.allocate(5 + payload.size)
        buf.order(ByteOrder.BIG_ENDIAN)
        buf.putInt(payload.size)
        buf.put(type.id.toByte())
        buf.put(payload)
        return buf.array()
    }

    companion object {
        fun deserialize(data: ByteArray): Pair<Message, Int>? {
            if (data.size < 5) return null
            val buf = ByteBuffer.wrap(data)
            buf.order(ByteOrder.BIG_ENDIAN)
            val length = buf.getInt()
            if (data.size < 5 + length) return null
            val typeId = buf.get().toUByte()
            val type = MessageType.fromId(typeId) ?: return null
            val payload = ByteArray(length)
            buf.get(payload)
            return Message(type, payload) to (5 + length)
        }

        fun handshake() = Message(MessageType.HANDSHAKE, "RemoteControl v1".toByteArray())

        fun handshakeReply() = Message(MessageType.HANDSHAKE_REPLY, "OK".toByteArray())

        fun keepAlive() = Message(MessageType.KEEP_ALIVE, ByteArray(0))

        fun charInput(text: String) = Message(MessageType.CHAR_INPUT, text.toByteArray())

        fun mouseMove(dx: Float, dy: Float): Message {
            val buf = ByteBuffer.allocate(8).order(ByteOrder.BIG_ENDIAN)
            buf.putFloat(dx)
            buf.putFloat(dy)
            return Message(MessageType.MOUSE_MOVE, buf.array())
        }

        fun mouseDown(button: Int = 0): Message {
            return Message(MessageType.MOUSE_DOWN, byteArrayOf(button.toByte()))
        }

        fun mouseUp(button: Int = 0): Message {
            return Message(MessageType.MOUSE_UP, byteArrayOf(button.toByte()))
        }

        fun mouseMoveAbsolute(x: Float, y: Float): Message {
            val buf = ByteBuffer.allocate(8).order(ByteOrder.BIG_ENDIAN)
            buf.putFloat(x)
            buf.putFloat(y)
            return Message(MessageType.MOUSE_MOVE_ABSOLUTE, buf.array())
        }

        fun scroll(dx: Float, dy: Float): Message {
            val buf = ByteBuffer.allocate(8).order(ByteOrder.BIG_ENDIAN)
            buf.putFloat(dx)
            buf.putFloat(dy)
            return Message(MessageType.SCROLL, buf.array())
        }

        fun keyDown(keyCode: UShort): Message {
            val buf = ByteBuffer.allocate(2).order(ByteOrder.BIG_ENDIAN)
            buf.putShort(keyCode.toShort())
            return Message(MessageType.KEY_DOWN, buf.array())
        }

        fun keyUp(keyCode: UShort): Message {
            val buf = ByteBuffer.allocate(2).order(ByteOrder.BIG_ENDIAN)
            buf.putShort(keyCode.toShort())
            return Message(MessageType.KEY_UP, buf.array())
        }
    }
}
