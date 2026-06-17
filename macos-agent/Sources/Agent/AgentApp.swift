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
            VStack(alignment: .leading, spacing: 6) {
                statusSection
                Divider()
                controlSection
                Divider()
                authSection
                Divider()
                infoSection
                Divider()
                quitSection
            }
            .padding(.vertical, 4)
        }
        .menuBarExtraStyle(.menu)

        Window("Authentication Setup", id: "auth-setup") {
            AuthSetupView(controller: controller)
        }
        .windowResizability(.contentSize)
    }

    @ViewBuilder
    private var statusSection: some View {
        HStack {
            Circle()
                .fill(controller.isRunning ? Color.green : Color.gray)
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
    }

    @ViewBuilder
    private var controlSection: some View {
        if controller.isRunning {
            Button("Stop Server") { controller.stop() }
        } else {
            Button("Start Server") { controller.start() }
        }
    }

    @Environment(\.openWindow) private var openWindow

    @ViewBuilder
    private var authSection: some View {
        Button("Setup Auth…") { openWindow(id: "auth-setup") }
        if controller.authEnabled {
            Button("Clear Auth") { controller.clearAuth() }
        }
    }

    @ViewBuilder
    private var infoSection: some View {
        Text("Tailscale: \(controller.tailscaleIP)")
            .font(.caption)
        Text("Local: \(controller.localIP)")
            .font(.caption)
    }

    @ViewBuilder
    private var quitSection: some View {
        Button("Quit") { NSApplication.shared.terminate(nil) }
    }
}

struct AuthSetupView: View {
    @ObservedObject var controller: ServerController
    @State private var login = ""
    @State private var password = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Authentication Setup")
                .font(.headline)
            TextField("Login", text: $login)
                .textFieldStyle(.roundedBorder)
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") { dismiss() }
                Button("Save") {
                    controller.setupAuth(login: login, password: password)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 280)
        .fixedSize()
    }
}
