import Foundation
import CryptoKit

struct AuthConfig: Codable {
    let login: String
    let passwordHash: String
}

enum AuthManager {
    static var configDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".remotecontrol")
    }

    static var configFile: URL {
        configDir.appendingPathComponent("auth.json")
    }

    static func isAuthEnabled() -> Bool {
        FileManager.default.fileExists(atPath: configFile.path)
    }

    static func validate(login: String, password: String) -> Bool {
        guard let data = try? Data(contentsOf: configFile),
              let config = try? JSONDecoder().decode(AuthConfig.self, from: data)
        else { return false }
        return login == config.login && sha256(password) == config.passwordHash
    }

    static func setup(login: String, password: String) throws {
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        let config = AuthConfig(login: login, passwordHash: sha256(password))
        let data = try JSONEncoder().encode(config)
        try data.write(to: configFile, options: .atomic)
    }

    static func clear() throws {
        guard isAuthEnabled() else { return }
        try FileManager.default.removeItem(at: configFile)
    }

    private static func sha256(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
