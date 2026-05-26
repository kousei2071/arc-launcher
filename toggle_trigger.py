"""ファイルトリガーでランチャーをトグル（ショートカット用フォールバック）。"""

from __future__ import annotations

from pathlib import Path

from PyQt6.QtCore import QObject, QFileSystemWatcher, QTimer

TOGGLE_DIR = Path.home() / "Library" / "Application Support" / "CyberLauncher"
TOGGLE_FILE = TOGGLE_DIR / "toggle"


class ToggleFileWatcher(QObject):
    """`touch ~/Library/Application Support/CyberLauncher/toggle` でトグル。"""

    def __init__(self, toggle_callback) -> None:
        super().__init__()
        self._toggle = toggle_callback
        TOGGLE_DIR.mkdir(parents=True, exist_ok=True)
        if not TOGGLE_FILE.exists():
            TOGGLE_FILE.touch()

        self._watcher = QFileSystemWatcher(self)
        self._watcher.addPath(str(TOGGLE_FILE))
        self._watcher.fileChanged.connect(self._on_file_changed)

    def _on_file_changed(self, _path: str) -> None:
        self._toggle()
        QTimer.singleShot(50, self._reset)

    def _reset(self) -> None:
        try:
            TOGGLE_FILE.unlink(missing_ok=True)
        except OSError:
            pass
        TOGGLE_FILE.touch()
