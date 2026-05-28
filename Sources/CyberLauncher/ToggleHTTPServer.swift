import Darwin
import Foundation

let togglePort: UInt16 = 39281

final class ToggleHTTPServer: @unchecked Sendable {
    private let toggle: @MainActor () -> Void
    private var serverSocket: CInt = -1
    private var readSource: DispatchSourceRead?

    init(toggle: @escaping @MainActor () -> Void) {
        self.toggle = toggle
        start()
    }

    private func start() {
        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            print("  HTTP トグル: 起動失敗 (socket)")
            return
        }

        var reuse: CInt = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<CInt>.size))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = togglePort.bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                bind(serverSocket, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult == 0, listen(serverSocket, SOMAXCONN) == 0 else {
            print("  HTTP トグル: 起動失敗 (bind/listen)")
            close(serverSocket)
            serverSocket = -1
            return
        }

        let source = DispatchSource.makeReadSource(fileDescriptor: serverSocket, queue: .main)
        source.setEventHandler { [weak self] in
            self?.acceptPendingConnections()
        }
        source.setCancelHandler { [serverSocket] in
            close(serverSocket)
        }
        source.resume()
        readSource = source
        print("  HTTP トグル: http://127.0.0.1:\(togglePort)/toggle")
    }

    private func acceptPendingConnections() {
        let client = accept(serverSocket, nil, nil)
        if client >= 0 {
            handle(client: client)
        }
    }

    private func handle(client: CInt) {
        var buffer = [UInt8](repeating: 0, count: 4096)
        let count = read(client, &buffer, buffer.count)
        if count > 0 {
            let request = String(decoding: buffer.prefix(count), as: UTF8.self)
            if request.contains("GET /toggle") || request.hasPrefix("GET /") {
                let toggle = toggle
                Task { @MainActor in
                    toggle()
                }
                let response = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok"
                _ = response.withCString { pointer in
                    write(client, pointer, strlen(pointer))
                }
            }
        }
        close(client)
    }

    deinit {
        readSource?.cancel()
        if serverSocket >= 0, readSource == nil {
            close(serverSocket)
        }
    }
}
