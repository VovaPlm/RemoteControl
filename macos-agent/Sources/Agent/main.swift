import Foundation
import Network

extension Data {
    var hex: String { map { String(format: "%02x", $0) }.joined() }
}

// MARK: - CLI

if CommandLine.arguments.contains("--setup-auth") {
    print("Enter login: ", terminator: "")
    let login = readLine() ?? ""
    print("Enter password: ", terminator: "")
    let password = readLine() ?? ""
    do {
        try AuthManager.setup(login: login, password: password)
        print("✅ Auth credentials saved")
    } catch {
        print("❌ Failed to save: \(error)")
    }
    exit(0)
}

if CommandLine.arguments.contains("--clear-auth") {
    do {
        try AuthManager.clear()
        print("✅ Auth config removed")
    } catch {
        print("❌ Failed to clear: \(error)")
    }
    exit(0)
}

let server = Server(port: 9090)
let input = InputController()
var screenCapture: ScreenCapture?
var connectedClients = Set<UUID>()
var pendingAuth = Set<UUID>()
let authEnabled = AuthManager.isAuthEnabled()

// MARK: - Server Events

server.onConnection = { id in
    connectedClients.insert(id)
    print("📱 Client connected: \(id.uuidString.prefix(8))...")
    if authEnabled { print("🔐 Auth required") }

    server.send(Message.handshake(), to: id)
}

server.onDisconnection = { id in
    connectedClients.remove(id)
    pendingAuth.remove(id)
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
        server.send(Message.handshakeReply(
            screenWidth: Float(videoSize.width),
            screenHeight: Float(videoSize.height),
            authRequired: authEnabled
        ), to: id)
        if authEnabled {
            pendingAuth.insert(id)
        } else {
            startCaptureIfNeeded()
        }

    case .handshakeReply:
        print("📩 handshakeReply")
        if !pendingAuth.contains(id) {
            startCaptureIfNeeded()
        }

    case .auth:
        if let (login, password) = msg.parseAuth() {
            let ok = AuthManager.validate(login: login, password: password)
            server.send(Message.authResult(success: ok), to: id)
            if ok {
                pendingAuth.remove(id)
                startCaptureIfNeeded()
                print("🔐 Client authenticated: \(login)")
            } else {
                print("🔐 Auth FAILED for login=\(login)")
                server.disconnect(id)
            }
        }

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
    print("│  Auth:      \(authEnabled ? "enabled" : "disabled")                    │")
    print("Waiting for connections...")

    dispatchMain()
} catch {
    print("❌ Failed to start server: \(error)")
    exit(1)
}
