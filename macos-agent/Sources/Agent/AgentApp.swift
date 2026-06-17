import SwiftUI

@main
struct RemoteControlAgentApp: App {
    @StateObject private var controller = ServerController()

    init() {
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
    }

    var body: some Scene {
        MenuBarExtra("RemoteControl Agent", systemImage: "display") {
            MenuContentView(controller: controller)
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuContentView: View {
    @ObservedObject var controller: ServerController

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Status
            HStack {
                Circle()
                    .fill(controller.isRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(controller.statusMessage)
                    .font(.subheadline)
            }
            if controller.isRunning {
                Text("Clients: \(controller.clientCount)")
                    .font(.caption).foregroundColor(.secondary)
            }
            HStack(spacing: 4) {
                Text(controller.authEnabled ? "🔐" : "🔓")
                Text(controller.authEnabled ? "Auth enabled" : "Auth disabled")
                    .font(.caption)
            }

            Divider()

            // Controls
            if controller.isRunning {
                Button("Stop Server") { controller.stop() }
            } else {
                Button("Start Server") { controller.start() }
            }

            Divider()

            // Auth
            Button("Setup Auth…") { controller.showAuthWindow() }
            if controller.authEnabled {
                Button("Clear Auth") { controller.clearAuth() }
            }

            Divider()

            // Info
            Text("Tailscale: \(controller.tailscaleIP)")
                .font(.caption)
            Text("Local: \(controller.localIP)")
                .font(.caption)

            Divider()

            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .padding(.vertical, 4)
    }
}

struct AuthSetupView: View {
    @ObservedObject var controller: ServerController
    @State private var login = ""
    @State private var password = ""
    var onClose: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Text("Authentication Setup")
                .font(.headline)
            TextField("Login", text: $login)
                .textFieldStyle(.roundedBorder)
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") { onClose?() }
                Button("Save") {
                    controller.setupAuth(login: login, password: password)
                    onClose?()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 280)
        .fixedSize()
    }
}
