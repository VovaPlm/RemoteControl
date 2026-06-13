import Foundation
import Network

extension Data {
    var hex: String { map { String(format: "%02x", $0) }.joined() }
}

let server = Server(port: 9090)
let input = InputController()
var screenCapture: ScreenCapture?
var connectedClients = Set<UUID>()

// MARK: - Server Events

server.onConnection = { id in
    connectedClients.insert(id)
    print("📱 Client connected: \(id.uuidString.prefix(8))...")

    server.send(Message.handshake(), to: id)
}

server.onDisconnection = { id in
    connectedClients.remove(id)
    print("📱 Client disconnected: \(id.uuidString.prefix(8))...")

    if connectedClients.isEmpty {
        screenCapture?.stop()
        screenCapture = nil
        print("🛑 No clients — capture stopped")
    }
}

server.onMessage = { msg, id in
    switch msg.type {
    case .handshake:
        print("📩 handshake")
        let videoSize = ScreenCapture.videoSize()
        input.videoWidth = videoSize.width
        input.videoHeight = videoSize.height
        server.send(Message.handshakeReply(screenWidth: Float(videoSize.width), screenHeight: Float(videoSize.height)), to: id)
        startCaptureIfNeeded()

    case .handshakeReply:
        print("📩 handshakeReply")
        startCaptureIfNeeded()

    case .mouseMove:
        if let (dx, dy) = msg.parseMouseMove() {
            print("🖱 mouseMove dx=\(dx) dy=\(dy)")
            input.mouseMove(dx: dx, dy: dy)
        } else {
            print("⚠️ mouseMove parse failed (payload=\(msg.payload.count) bytes)")
        }

    case .mouseMoveAbsolute:
        if let (x, y) = msg.parseMouseMoveAbsolute() {
            input.mouseMoveAbsolute(x: x, y: y)
        } else {
            print("⚠️ mouseMoveAbsolute parse failed (payload=\(msg.payload.count) bytes: \(msg.payload.hex))")
        }

    case .mouseDown:
        if let btn = msg.parseMouseButton() {
            input.mouseDown(button: btn)
        }

    case .mouseUp:
        if let btn = msg.parseMouseButton() {
            input.mouseUp(button: btn)
        }

    case .scroll:
        if let (dx, dy) = msg.parseScroll() {
            print("📜 scroll dx=\(dx) dy=\(dy)")
            input.scroll(dx: dx, dy: dy)
        }

    case .keyDown:
        if let code = msg.parseKeyCode() {
            input.keyDown(code)
        }

    case .keyUp:
        if let code = msg.parseKeyCode() {
            input.keyUp(code)
        }

    case .charInput:
        if let text = msg.parseCharInput() {
            input.charInput(text)
        }

    case .keepAlive:
        break

    default:
        print("❓ unknown message type=\(msg.type.rawValue) payload=\(msg.payload.count) bytes")
        break
    }
}

// MARK: - Screen Capture

func startCaptureIfNeeded() {
    guard screenCapture == nil else { return }
    let cap = ScreenCapture()
    cap.onEncodedFrame = { data in
        guard !connectedClients.isEmpty else { return }
        server.broadcast(Message.videoFrame(data))
    }
    cap.start()
    screenCapture = cap
    print("🎬 Screen capture started")
}

// MARK: - Keep Alive Timer

Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
    guard !connectedClients.isEmpty else { return }
    server.broadcast(Message.keepAlive())
}

// MARK: - Start

do {
    try server.start()

    let tailscaleIP = server.getIPAddress() ?? "N/A"
    let localIP = server.getLocalIP() ?? "N/A"

    print("┌──────────────────────────────────────────┐")
    print("│      RemoteControl Agent v1              │")
    print("├──────────────────────────────────────────┤")
    print("│  Tailscale: \(tailscaleIP.padding(toLength: 16, withPad: " ", startingAt: 0)):9090       │")
    print("│  Local:     \(localIP.padding(toLength: 16, withPad: " ", startingAt: 0)):9090       │")
    print("│  Bonjour:   _remotecontrol._tcp          │")
    print("└──────────────────────────────────────────┘")
    print("Waiting for connections...")

    dispatchMain()
} catch {
    print("❌ Failed to start server: \(error)")
    exit(1)
}
