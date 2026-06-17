import Foundation
import CoreGraphics
import ApplicationServices

final class InputController {
    var videoWidth: CGFloat = 1920
    var videoHeight: CGFloat = 1080
    private var lastAbsolutePosition = CGPoint.zero

    static var hasPermission: Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    static func requestPermission() {
        let promptOpts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(promptOpts)
    }

    // MARK: - Mouse

    func mouseMoveAbsolute(x: Float, y: Float) {
        let displayBounds = CGDisplayBounds(CGMainDisplayID())
        let sx = (CGFloat(x) / videoWidth) * displayBounds.size.width
        let sy = (CGFloat(y) / videoHeight) * displayBounds.size.height
        lastAbsolutePosition = CGPoint(x: sx, y: sy)
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: lastAbsolutePosition,
            mouseButton: .left
        ) else { print("  → CGEvent nil!"); return }
        event.post(tap: .cghidEventTap)
    }

    func mouseMove(dx: Float, dy: Float) {
        let current = CGEvent(source: nil)?.location ?? .zero
        let newX = current.x + CGFloat(dx)
        let newY = current.y + CGFloat(dy)
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: CGPoint(x: newX, y: newY),
            mouseButton: .left
        ) else { return }
        event.post(tap: .cghidEventTap)
    }

    func mouseDown(button: UInt8) {
        let btn = mouseButton(from: button)
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: buttonType(.down, button: btn),
            mouseCursorPosition: lastAbsolutePosition,
            mouseButton: btn
        ) else { print("  → CGEvent nil!"); return }
        event.post(tap: .cghidEventTap)
    }

    func mouseUp(button: UInt8) {
        let btn = mouseButton(from: button)
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: buttonType(.up, button: btn),
            mouseCursorPosition: lastAbsolutePosition,
            mouseButton: btn
        ) else { print("  → CGEvent nil!"); return }
        event.post(tap: .cghidEventTap)
    }

    func scroll(dx: Float, dy: Float) {
        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: Int32(dy), wheel2: Int32(dx), wheel3: 0) else { return }
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Keyboard

    func charInput(_ text: String) {
        let unicode = Array(text.utf16)
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else { return }
        down.keyboardSetUnicodeString(stringLength: unicode.count, unicodeString: unicode)
        down.post(tap: .cghidEventTap)

        guard let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else { return }
        up.post(tap: .cghidEventTap)
    }

    func keyDown(_ keyCode: UInt16) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else { print("  → CGEvent nil!"); return }
        event.post(tap: .cghidEventTap)
    }

    func keyUp(_ keyCode: UInt16) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else { print("  → CGEvent nil!"); return }
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Helpers

    private enum Action { case down, up }

    private func mouseButton(from id: UInt8) -> CGMouseButton {
        switch id {
        case 0:  return .left
        case 1:  return .right
        case 2:  return .center
        default: return .left
        }
    }

    private func buttonType(_ action: Action, button: CGMouseButton) -> CGEventType {
        switch (action, button) {
        case (.down, .left):   return .leftMouseDown
        case (.up, .left):     return .leftMouseUp
        case (.down, .right):  return .rightMouseDown
        case (.up, .right):    return .rightMouseUp
        case (.down, .center): return .otherMouseDown
        case (.up, .center):   return .otherMouseUp
        default:               return .leftMouseDown
        }
    }
}
