import Foundation
import Network

let togglePort: UInt16 = 39281

final class ToggleHTTPServer: @unchecked Sendable {
    private let listener: NWListener?
    private let toggle: () -> Void

    init(toggle: @escaping () -> Void) {
        self.toggle = toggle
        do {
            let parameters = NWParameters.tcp
            parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: togglePort)!)
            self.listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: togglePort)!)
        } catch {
            self.listener = nil
            print("  HTTP トグル: 起動失敗 (\(error.localizedDescription))")
            return
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }
        listener?.start(queue: .main)
        print("  HTTP トグル: http://127.0.0.1:\(togglePort)/toggle")
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: .main)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, _ in
            guard let self else {
                connection.cancel()
                return
            }

            let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            if request.contains("GET /toggle") || request.hasPrefix("GET /") {
                DispatchQueue.main.async {
                    self.toggle()
                }
                let response = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok"
                connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                    connection.cancel()
                })
            } else {
                connection.cancel()
            }
        }
    }
}
