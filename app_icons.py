"""macOS アプリケーションアイコンの取得。"""

from __future__ import annotations

import os
import subprocess
from functools import lru_cache

from PyQt6.QtCore import QFileInfo, Qt
from PyQt6.QtGui import QPixmap
from PyQt6.QtWidgets import QFileIconProvider

_provider = QFileIconProvider()


@lru_cache(maxsize=64)
def mac_app_bundle_path(app_name: str) -> str | None:
    try:
        result = subprocess.run(
            ["osascript", "-e", f'POSIX path of (path to application "{app_name}")'],
            capture_output=True,
            text=True,
            timeout=5,
        )
        path = result.stdout.strip().rstrip("/")
        if path.endswith(".app") and os.path.isdir(path):
            return path
    except (OSError, subprocess.SubprocessError):
        pass

    for base in ("/Applications", "/System/Applications", os.path.expanduser("~/Applications")):
        candidate = os.path.join(base, f"{app_name}.app")
        if os.path.isdir(candidate):
            return candidate
    return None


def load_mac_app_icon(app_name: str, size: int = 128) -> QPixmap:
    path = mac_app_bundle_path(app_name)
    if path:
        pixmap = _provider.icon(QFileInfo(path)).pixmap(size, size)
        if not pixmap.isNull():
            return pixmap
    return _fallback_icon(size)


def _fallback_icon(size: int) -> QPixmap:
    for name in ("Computer", "Desktop", "Drive"):
        icon_type = getattr(QFileIconProvider.IconType, name, None)
        if icon_type is None:
            continue
        pixmap = _provider.icon(icon_type).pixmap(size, size)
        if not pixmap.isNull():
            return pixmap
    pm = QPixmap(size, size)
    pm.fill(Qt.GlobalColor.transparent)
    return pm
