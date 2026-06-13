import Foundation

enum MessageType: UInt8 {
    case mouseMove     = 0x01
    case mouseDown     = 0x02
    case mouseUp       = 0x03
    case scroll        = 0x04
    case keyDown       = 0x05
    case keyUp         = 0x06
    case videoFrame    = 0x07
    case keepAlive     = 0x08
    case handshake     = 0x09
    case handshakeReply = 0x0A
    case mouseMoveAbsolute = 0x0B
    case charInput = 0x0C
}

struct Message {
    let type: MessageType
    let payload: Data

    func serialize() -> Data {
        var data = Data(capacity: 5 + payload.count)
        var len = UInt32(payload.count).bigEndian
        data.append(Data(bytes: &len, count: 4))
        data.append(type.rawValue)
        data.append(payload)
        return data
    }

    static func deserialize(from data: Data) -> (Message, consumed: Int)? {
        guard data.count >= 5 else { return nil }
        let length = Int(
            UInt32(bigEndian: data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0, as: UInt32.self) })
        )
        guard data.count >= 5 + length else { return nil }
        guard let type = MessageType(rawValue: data[4]) else { return nil }
        let payload = data[5..<5 + length]
        return (Message(type: type, payload: payload), consumed: 5 + length)
    }
}

// MARK: - Payload helpers

extension Message {

    static func handshake() -> Message {
        let payload = "RemoteControl v1".data(using: .utf8)!
        return Message(type: .handshake, payload: payload)
    }

    static func handshakeReply(screenWidth: Float, screenHeight: Float) -> Message {
        var data = Data(capacity: 8)
        var w = screenWidth.bitPattern.bigEndian
        var h = screenHeight.bitPattern.bigEndian
        data.append(Data(bytes: &w, count: 4))
        data.append(Data(bytes: &h, count: 4))
        return Message(type: .handshakeReply, payload: data)
    }

    static func keepAlive() -> Message {
        return Message(type: .keepAlive, payload: Data())
    }

    static func videoFrame(_ h264Data: Data) -> Message {
        return Message(type: .videoFrame, payload: h264Data)
    }

    // MARK: - Parse input messages

    func parseMouseMove() -> (dx: Float, dy: Float)? {
        guard type == .mouseMove, payload.count == 8 else { return nil }
        let dxBits = payload.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.bigEndian
        let dyBits = payload.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: UInt32.self) }.bigEndian
        return (Float(bitPattern: dxBits), Float(bitPattern: dyBits))
    }

    func parseMouseButton() -> UInt8? {
        guard (type == .mouseDown || type == .mouseUp), payload.count == 1 else { return nil }
        return payload.first
    }

    func parseScroll() -> (dx: Float, dy: Float)? {
        guard type == .scroll, payload.count == 8 else { return nil }
        let dxBits = payload.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.bigEndian
        let dyBits = payload.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: UInt32.self) }.bigEndian
        return (Float(bitPattern: dxBits), Float(bitPattern: dyBits))
    }

    func parseCharInput() -> String? {
        guard type == .charInput else { return nil }
        return String(data: payload, encoding: .utf8)
    }

    func parseKeyCode() -> UInt16? {
        guard (type == .keyDown || type == .keyUp), payload.count == 2 else { return nil }
        return UInt16(bigEndian: payload.withUnsafeBytes { $0.loadUnaligned(as: UInt16.self) })
    }

    func parseMouseMoveAbsolute() -> (x: Float, y: Float)? {
        guard type == .mouseMoveAbsolute, payload.count == 8 else { return nil }
        let xBits = payload.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.bigEndian
        let yBits = payload.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: UInt32.self) }.bigEndian
        return (Float(bitPattern: xBits), Float(bitPattern: yBits))
    }

    static func mouseMoveAbsolute(x: Float, y: Float) -> Message {
        var data = Data(capacity: 8)
        var bx = x.bitPattern.bigEndian
        var by = y.bitPattern.bigEndian
        data.append(Data(bytes: &bx, count: 4))
        data.append(Data(bytes: &by, count: 4))
        return Message(type: .mouseMoveAbsolute, payload: data)
    }
}
