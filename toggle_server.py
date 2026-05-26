"""localhost HTTP でトグル（ショートカット連携用）。"""

from __future__ import annotations

from PyQt6.QtCore import QObject, QTimer
from PyQt6.QtNetwork import QHostAddress, QTcpServer

PORT = 39281


class ToggleHttpServer(QObject):
    def __init__(self, toggle_callback) -> None:
        super().__init__()
        self._toggle = toggle_callback
        self._server = QTcpServer(self)
        self._server.newConnection.connect(self._on_connection)
        addr = QHostAddress("127.0.0.1")
        if not self._server.listen(addr, PORT):
            err = self._server.errorString()
            print(f"  HTTP トグル: 起動失敗 ({err})", flush=True)
            return
        print(f"  HTTP トグル: http://127.0.0.1:{PORT}/toggle", flush=True)

    def _on_connection(self) -> None:
        socket = self._server.nextPendingConnection()
        if socket is None:
            return

        def _read() -> None:
            data = bytes(socket.readAll()).decode("utf-8", errors="ignore")
            if "GET /toggle" in data or data.startswith("GET /"):
                QTimer.singleShot(0, self._toggle)
                socket.write(
                    b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok"
                )
            socket.disconnectFromHost()

        socket.readyRead.connect(_read)
