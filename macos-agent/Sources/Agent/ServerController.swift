import Foundation
import Combine
import AppKit
import SwiftUI

final class ServerController: ObservableObject {
    @Published var isRunning = false
    @Published var clientCount = 0
    @Published var authEnabled = false
    @Published var tailscaleIP = "N/A"
    @Published var localIP = "N/A"
    @Published var statusMessage = "Ready"
    @Published var hasInputPermission = false
    @Published var hasScreenPermission = false

    private var server: Server?
    private var screenCapture: ScreenCapture?
    private let input = InputController()
    private var pendingAuth = Set<UUID>()
    private var keepAliveTimer: Timer?

    init() {
        authEnabled = AuthManager.isAuthEnabled()
        tailscaleIP = Server.getIPAddress() ?? "N/A"
        localIP = Server.getLocalIP() ?? "N/A"
        hasInputPermission = InputController.hasPermission
        hasScreenPermission = ScreenCapture.hasPermission
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.start()
        }
    }

    func start() {
        guard !isRunning else { return }

        let s = Server(port: 9090)
        s.onConnection = { [weak self] id in
            guard let self else { return }
            s.send(Message.handshake(), to: id)
            DispatchQueue.main.async { self.clientCount += 1 }
        }
        s.onDisconnection = { [weak self] id in
            guard let self else { return }
            self.pendingAuth.remove(id)
            DispatchQueue.main.async {
                self.clientCount -= 1
                if self.clientCount <= 0 {
                    self.clientCount = 0
                    self.screenCapture?.stop()
                    self.screenCapture = nil
                }
            }
        }
        s.onMessage = { [weak self] msg, id in
            self?.handleMessage(msg, from: id, server: s)
        }

        do {
            try s.start()
            server = s
            isRunning = true
            statusMessage = "Running on port 9090"
            startKeepAlive()
        } catch {
            statusMessage = "Failed: \(error.localizedDescription)"
        }
    }

    func stop() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
        screenCapture?.stop()
        screenCapture = nil
        server?.stop()
        server = nil
        pendingAuth.removeAll()
        isRunning = false
        clientCount = 0
        statusMessage = "Stopped"
    }

    private func startKeepAlive() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            guard let self, self.clientCount > 0 else { return }
            self.server?.broadcast(Message.keepAlive())
        }
    }

    // MARK: - Messages

    private func handleMessage(_ msg: Message, from id: UUID, server: Server) {
        switch msg.type {
        case .handshake:
            let videoSize = ScreenCapture.videoSize()
            input.videoWidth = videoSize.width
            input.videoHeight = videoSize.height
            let authReq = authEnabled
            server.send(Message.handshakeReply(
                screenWidth: Float(videoSize.width),
                screenHeight: Float(videoSize.height),
                authRequired: authReq
            ), to: id)
            if authReq {
                pendingAuth.insert(id)
            } else {
                startCaptureIfNeeded(server: server)
            }

        case .handshakeReply:
            if !pendingAuth.contains(id) {
                startCaptureIfNeeded(server: server)
            }

        case .auth:
            if let (login, password) = msg.parseAuth() {
                let ok = AuthManager.validate(login: login, password: password)
                server.send(Message.authResult(success: ok), to: id)
                if ok {
                    pendingAuth.remove(id)
                    startCaptureIfNeeded(server: server)
                    print("🔐 Client authenticated: \(login)")
                } else {
                    print("🔐 Auth FAILED for login=\(login)")
                    server.disconnect(id)
                }
            }

        case .mouseMove:
            if let (dx, dy) = msg.parseMouseMove() {
                input.mouseMove(dx: dx, dy: dy)
            }

        case .mouseMoveAbsolute:
            if let (x, y) = msg.parseMouseMoveAbsolute() {
                input.mouseMoveAbsolute(x: x, y: y)
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
            break
        }
    }

    // MARK: - Capture

    private func startCaptureIfNeeded(server: Server) {
        guard screenCapture == nil else { return }
        let cap = ScreenCapture()
        cap.onEncodedFrame = { [weak self] data in
            guard let self, self.clientCount > 0 else { return }
            server.broadcast(Message.videoFrame(data))
        }
        cap.start()
        screenCapture = cap
        print("🎬 Screen capture started")
    }

    // MARK: - Auth

    func showAuthWindow() {
        let alert = NSAlert()
        alert.messageText = "Authentication Setup"
        alert.informativeText = "Set login and password for remote access"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let loginField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 22))
        loginField.placeholderString = "Login"
        let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 22))
        passwordField.placeholderString = "Password"

        let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 200, height: 56))
        stack.orientation = .vertical
        stack.spacing = 8
        stack.addArrangedSubview(loginField)
        stack.addArrangedSubview(passwordField)
        alert.accessoryView = stack
        alert.window.initialFirstResponder = loginField

        NSApplication.shared.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            setupAuth(login: loginField.stringValue, password: passwordField.stringValue)
        }
    }

    func setupAuth(login: String, password: String) {
        do {
            try AuthManager.setup(login: login, password: password)
            authEnabled = true
            statusMessage = "Auth enabled"
        } catch {
            statusMessage = "Auth setup failed: \(error.localizedDescription)"
        }
    }

    func clearAuth() {
        do {
            try AuthManager.clear()
            authEnabled = false
            statusMessage = "Auth disabled"
        } catch {
            statusMessage = "Auth clear failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Permissions

    func refreshPermissions() {
        hasInputPermission = InputController.hasPermission
        hasScreenPermission = ScreenCapture.hasPermission
    }

    func requestInputPermission() {
        InputController.requestPermission()
    }

    func requestScreenPermission() {
        ScreenCapture.requestPermission()
    }
}
