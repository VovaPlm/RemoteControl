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

            // Permissions
            HStack(spacing: 4) {
                Circle()
                    .fill(controller.hasInputPermission ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                Text(controller.hasInputPermission ? "Input: allowed" : "Input: blocked")
                    .font(.caption)
                Spacer()
                if !controller.hasInputPermission {
                    Button("Grant") { controller.requestInputPermission() }
                        .controlSize(.small)
                }
            }
            HStack(spacing: 4) {
                Circle()
                    .fill(controller.hasScreenPermission ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                Text(controller.hasScreenPermission ? "Screen: allowed" : "Screen: blocked")
                    .font(.caption)
                Spacer()
                if !controller.hasScreenPermission {
                    Button("Grant") { controller.requestScreenPermission() }
                        .controlSize(.small)
                }
            }
            if !controller.hasScreenPermission || !controller.hasInputPermission {
                Text("Grant in System Settings, then reopen app")
                    .font(.caption2).foregroundColor(.secondary)
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

            Button("Refresh Permissions") { controller.refreshPermissions() }
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .padding(.vertical, 4)
        .onAppear { controller.refreshPermissions() }
    }
}

// AuthSetupView is no longer used — AppKit-based dialog is in ServerController
