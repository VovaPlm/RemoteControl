package com.remotecontrol.ui.screens

import android.content.Context
import android.util.Log
import android.view.KeyEvent
import android.view.View
import android.view.inputmethod.BaseInputConnection
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection
import android.view.inputmethod.InputMethodManager

class KeyboardCaptureView(context: Context) : View(context) {
    var onKeyDown: ((UShort) -> Unit)? = null
    var onKeyUp: ((UShort) -> Unit)? = null
    var onCharInput: ((String) -> Unit)? = null
    private var shiftHeld = false

    companion object {
        private val MODIFIER_MACS: Set<UShort> = setOf(0x37u, 0x38u, 0x39u, 0x3Au, 0x3Bu)
    }

    init {
        isFocusable = true
        isFocusableInTouchMode = true
        isEnabled = true
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        Log.d("RemoteControl", "KeyboardCaptureView attached, requesting focus")
        requestFocus()
        postDelayed({
            val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
            imm?.showSoftInput(this, InputMethodManager.SHOW_IMPLICIT)
        }, 200L)
    }

    fun showKeyboard() {
        post {
            requestFocus()
            val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
            imm?.showSoftInput(this, InputMethodManager.SHOW_IMPLICIT)
        }
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        Log.d("RemoteControl", "KeyboardCaptureView detached")
        val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
        imm?.hideSoftInputFromWindow(windowToken, 0)
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        Log.d("RemoteControl", "KCV onKeyDown code=$keyCode event=$event")
        val mac = androidToMac(event)
        if (mac != null) {
            Log.d("RemoteControl", "KCV → mac keyDown 0x${mac.toString(16)}")
            onKeyDown?.invoke(mac)
            if (!MODIFIER_MACS.contains(mac)) {
                onKeyUp?.invoke(mac)
            }
            if (keyCode == KeyEvent.KEYCODE_SHIFT_LEFT || keyCode == KeyEvent.KEYCODE_SHIFT_RIGHT) {
                shiftHeld = true
            }
        }
        return true
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        Log.d("RemoteControl", "KCV onKeyUp code=$keyCode")
        val mac = androidToMac(event)
        if (mac != null && MODIFIER_MACS.contains(mac)) {
            onKeyUp?.invoke(mac)
        }
        if (keyCode == KeyEvent.KEYCODE_SHIFT_LEFT || keyCode == KeyEvent.KEYCODE_SHIFT_RIGHT) {
            shiftHeld = false
        }
        return true
    }

    override fun onCheckIsTextEditor(): Boolean = true

    override fun onCreateInputConnection(outAttrs: EditorInfo): InputConnection {
        Log.d("RemoteControl", "KCV onCreateInputConnection")
        outAttrs.inputType = EditorInfo.TYPE_CLASS_TEXT or EditorInfo.TYPE_TEXT_FLAG_NO_SUGGESTIONS
        outAttrs.imeOptions = EditorInfo.IME_FLAG_NO_ENTER_ACTION
        return object : BaseInputConnection(this, true) {
            private var composingText = ""

            override fun commitText(text: CharSequence, newCursorPosition: Int): Boolean {
                Log.d("RemoteControl", "KCV commitText: \"$text\"")
                composingText = ""
                for (ch in text) {
                    sendChar(ch)
                }
                return true
            }

            override fun setComposingText(text: CharSequence, newCursorPosition: Int): Boolean {
                Log.d("RemoteControl", "KCV setComposingText: \"$text\"")
                composingText = text.toString()
                return super.setComposingText(text, newCursorPosition)
            }

            override fun finishComposingText(): Boolean {
                Log.d("RemoteControl", "KCV finishComposingText: \"$composingText\"")
                if (composingText.isNotEmpty()) {
                    for (ch in composingText) {
                        sendChar(ch)
                    }
                    composingText = ""
                }
                return super.finishComposingText()
            }

            override fun sendKeyEvent(event: KeyEvent): Boolean {
                Log.d("RemoteControl", "KCV InputConnection sendKeyEvent: ${event.keyCode} action=${event.action}")
                val mac = androidToMac(event)
                if (mac != null) {
                    if (event.action == KeyEvent.ACTION_DOWN) {
                        Log.d("RemoteControl", "KCV IC → mac keyDown 0x${mac.toString(16)}")
                        onKeyDown?.invoke(mac)
                    } else {
                        Log.d("RemoteControl", "KCV IC → mac keyUp 0x${mac.toString(16)}")
                        onKeyUp?.invoke(mac)
                    }
                } else if (event.action == KeyEvent.ACTION_DOWN && event.unicodeChar != 0) {
                    sendChar(event.unicodeChar.toChar())
                } else {
                    Log.d("RemoteControl", "KCV IC unhandled keyCode=${event.keyCode}")
                }
                return true
            }

            override fun deleteSurroundingText(beforeLength: Int, afterLength: Int): Boolean {
                Log.d("RemoteControl", "KCV deleteSurroundingText before=$beforeLength after=$afterLength → backspace")
                if (beforeLength > 0) {
                    onKeyDown?.invoke(0x33u)
                    onKeyUp?.invoke(0x33u)
                }
                return true
            }
        }
    }

    private fun sendChar(ch: Char) {
        Log.d("RemoteControl", "KCV sendChar: '$ch' (U+${ch.code.toString(16)})")
        onCharInput?.invoke(ch.toString())
    }
}

private fun charToMac(ch: Char): Pair<UShort, Boolean>? {
    val lower = ch.lowercaseChar()
    val code = when (lower) {
        'a' -> 0x00; 's' -> 0x01; 'd' -> 0x02; 'f' -> 0x03; 'h' -> 0x04
        'g' -> 0x05; 'z' -> 0x06; 'x' -> 0x07; 'c' -> 0x08; 'v' -> 0x09
        'b' -> 0x0B; 'q' -> 0x0C; 'w' -> 0x0D; 'e' -> 0x0E; 'r' -> 0x0F
        'y' -> 0x10; 't' -> 0x11; '1' -> 0x12; '2' -> 0x13; '3' -> 0x14
        '4' -> 0x15; '6' -> 0x16; '5' -> 0x17; '=' -> 0x18; '9' -> 0x19
        '7' -> 0x1A; '-' -> 0x1B; '8' -> 0x1C; '0' -> 0x1D; ']' -> 0x1E
        'o' -> 0x1F; 'u' -> 0x20; '[' -> 0x21; 'i' -> 0x22; 'p' -> 0x23
        'l' -> 0x25; 'j' -> 0x26; '\'' -> 0x27; 'k' -> 0x28; ';' -> 0x29
        '\\' -> 0x2A; ',' -> 0x2B; '/' -> 0x2C; 'n' -> 0x2D; 'm' -> 0x2E
        '.' -> 0x2F; ' ' -> 0x31; '`' -> 0x32
        else -> return null
    }.toUShort()
    val needsShift = when (ch) {
        '~', '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+',
        '{', '}', '|', ':', '"', '<', '>', '?',
        'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
        'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z' -> true
        else -> false
    }
    return Pair(code, needsShift)
}

private fun androidToMac(event: KeyEvent): UShort? {
    val code = event.keyCode
    val result = when (code) {
        KeyEvent.KEYCODE_DEL -> 0x33u
        KeyEvent.KEYCODE_FORWARD_DEL -> 0x75u
        KeyEvent.KEYCODE_ENTER -> 0x24u
        KeyEvent.KEYCODE_TAB -> 0x30u
        KeyEvent.KEYCODE_SPACE -> 0x31u
        KeyEvent.KEYCODE_ESCAPE -> 0x35u
        KeyEvent.KEYCODE_SHIFT_LEFT, KeyEvent.KEYCODE_SHIFT_RIGHT -> 0x38u
        KeyEvent.KEYCODE_ALT_LEFT, KeyEvent.KEYCODE_ALT_RIGHT -> 0x3Au
        KeyEvent.KEYCODE_CTRL_LEFT, KeyEvent.KEYCODE_CTRL_RIGHT -> 0x3Bu
        KeyEvent.KEYCODE_META_LEFT, KeyEvent.KEYCODE_META_RIGHT -> 0x37u
        KeyEvent.KEYCODE_CAPS_LOCK -> 0x39u
        KeyEvent.KEYCODE_DPAD_LEFT -> 0x7Bu
        KeyEvent.KEYCODE_DPAD_RIGHT -> 0x7Cu
        KeyEvent.KEYCODE_DPAD_DOWN -> 0x7Du
        KeyEvent.KEYCODE_DPAD_UP -> 0x7Eu
        KeyEvent.KEYCODE_F1 -> 0x7Au; KeyEvent.KEYCODE_F2 -> 0x78u
        KeyEvent.KEYCODE_F3 -> 0x63u; KeyEvent.KEYCODE_F4 -> 0x76u
        KeyEvent.KEYCODE_F5 -> 0x60u; KeyEvent.KEYCODE_F6 -> 0x61u
        KeyEvent.KEYCODE_F7 -> 0x62u; KeyEvent.KEYCODE_F8 -> 0x64u
        KeyEvent.KEYCODE_F9 -> 0x65u; KeyEvent.KEYCODE_F10 -> 0x6Du
        KeyEvent.KEYCODE_F11 -> 0x67u; KeyEvent.KEYCODE_F12 -> 0x6Fu
        else -> null
    }
    if (result != null) {
        Log.d("RemoteControl", "androidToMac: android keyCode=$code → mac 0x${result.toString(16)}")
    } else {
        Log.d("RemoteControl", "androidToMac: android keyCode=$code → no mapping")
    }
    return result?.toUShort()
}
