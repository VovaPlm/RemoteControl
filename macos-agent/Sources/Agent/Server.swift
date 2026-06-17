import Foundation
import Network

final class Server {
    private let port: UInt16
    private var listener: NWListener?
    private var connections: [UUID: NWConnection] = [:]
    private let queue = DispatchQueue(label: "server.queue", qos: .userInitiated)
    private var listeners: [UUID: Data] = [:]

    var onMessage: ((Message, UUID) -> Void)?
    var onConnection: ((UUID) -> Void)?
    var onDisconnection: ((UUID) -> Void)?

    init(port: UInt16 = 9090) {
        self.port = port
    }

    var connectionCount: Int { connections.count }
    var isRunning: Bool { listener != nil }

    func start() throws {
        let params = NWParameters.tcp
        listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        listener?.service = .init(type: "_remotecontrol._tcp", txtRecord: nil)

        listener?.newConnectionHandler = { [weak self] conn in
            guard let self = self else { return }
            let id = UUID()
            conn.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }
                if case .failed = state {
                    self.connections.removeValue(forKey: id)
                    self.listeners.removeValue(forKey: id)
                    self.onDisconnection?(id)
                }
                if case .cancelled = state {
                    self.connections.removeValue(forKey: id)
                    self.listeners.removeValue(forKey: id)
                    self.onDisconnection?(id)
                }
            }
            conn.start(queue: self.queue)
            self.connections[id] = conn
            self.listeners[id] = Data()
            self.onConnection?(id)
            self.receive(on: conn, id: id)
        }

        listener?.start(queue: queue)
    }

    func stop() {
        for (_, conn) in connections {
            conn.cancel()
        }
        connections.removeAll()
        listeners.removeAll()
        listener?.cancel()
        listener = nil
    }

    private func receive(on conn: NWConnection, id: UUID) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let data = data, !data.isEmpty {
                self.listeners[id]?.append(data)
                self.processBuffer(for: id)
            }

            if isComplete || error != nil {
                conn.cancel()
            } else {
                self.receive(on: conn, id: id)
            }
        }
    }

    private func processBuffer(for id: UUID) {
        guard var buffer = listeners[id] else { return }

        while true {
            guard let (msg, consumed) = Message.deserialize(from: buffer) else { break }
            buffer = Data(buffer[consumed...])
            onMessage?(msg, id)
        }

        listeners[id] = buffer
    }

    func send(_ message: Message, to id: UUID) {
        guard let conn = connections[id] else { return }
        let data = message.serialize()
        conn.send(content: data, completion: .idempotent)
    }

    func disconnect(_ id: UUID) {
        connections[id]?.cancel()
        connections.removeValue(forKey: id)
        listeners.removeValue(forKey: id)
    }

    func broadcast(_ message: Message) {
        let data = message.serialize()
        for (_, conn) in connections {
            conn.send(content: data, completion: .idempotent)
        }
    }

    func getIPAddress() -> String? {
        var addrList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrList) == 0, let list = addrList else { return nil }
        defer { freeifaddrs(addrList) }

        var ptr = list
        while true {
            let addr = ptr.pointee
            let family = addr.ifa_addr.pointee.sa_family
            let name = String(cString: addr.ifa_name)

            if name.hasPrefix("tailscale") || name.hasPrefix("utun") {
                if family == UInt8(AF_INET) || family == UInt8(AF_INET6) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        addr.ifa_addr,
                        socklen_t(addr.ifa_addr.pointee.sa_len),
                        &hostname, socklen_t(hostname.count),
                        nil, 0,
                        family == UInt8(AF_INET) ? NI_NUMERICHOST : NI_NUMERICHOST | NI_NUMERICSERV
                    )
                    let ip = String(cString: hostname)
                    if ip.hasPrefix("100.") || ip.hasPrefix("fd7a:") {
                        if family == UInt8(AF_INET6) { continue }
                        return ip
                    }
                }
            }
            guard let next = addr.ifa_next else { break }
            ptr = next
        }
        return nil
    }

    func getLocalIP() -> String? {
        var addrList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrList) == 0, let list = addrList else { return nil }
        defer { freeifaddrs(addrList) }

        var ptr = list
        while true {
            let addr = ptr.pointee
            if addr.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: addr.ifa_name)
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        addr.ifa_addr,
                        socklen_t(addr.ifa_addr.pointee.sa_len),
                        &hostname, socklen_t(hostname.count),
                        nil, 0,
                        NI_NUMERICHOST
                    )
                    return String(cString: hostname)
                }
            }
            guard let next = addr.ifa_next else { break }
            ptr = next
        }
        return nil
    }
}
