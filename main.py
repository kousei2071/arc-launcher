#!/usr/bin/env python3
"""Mac 用円形デスクトップランチャー — エントリポイント。"""

from __future__ import annotations

import os
import sys

from PyQt6.QtCore import Qt
from PyQt6.QtGui import QAction, QSurfaceFormat
from PyQt6.QtWidgets import QApplication, QMenu, QStyle, QSystemTrayIcon

from cyber_launcher import CircularLauncherWindow, apply_cyber_theme
from hotkey import DEFAULT_HOTKEY, GlobalHotkeyService
from mac_vibrancy import is_available as mac_glass_available
from mac_vibrancy import is_liquid_glass_available
from toggle_trigger import ToggleFileWatcher
from toggle_server import ToggleHttpServer

START_VISIBLE = os.environ.get("CYBER_LAUNCHER_START_VISIBLE", "1") == "1"
USE_MAC_GLASS = os.environ.get("CYBER_LAUNCHER_NATIVE_GLASS", "1") == "1"


def _hotkey_display(hotkey: str) -> str:
    return (
        hotkey.replace("<cmd>", "⌘")
        .replace("<shift>", "Shift")
        .replace("<alt>", "⌥")
        .replace("+", " + ")
    )


def _print_usage(hotkey: str) -> None:
    display = _hotkey_display(hotkey)
    print("Cyber Launcher 起動しました")
    print(f"  表示/非表示: {display}")
    print("  メニューバーアイコン … クリックでも表示")
    print("  マウスをアイコンへ動かしてクリックで起動")
    print("  Esc … 非表示 | Ctrl+C … 終了")
    if sys.platform == "darwin":
        if USE_MAC_GLASS and mac_glass_available():
            print("  背景: 壁紙ぼかし + フロストガラス（NSVisualEffectView）")
            if is_liquid_glass_available():
                print("  Liquid Glass: CYBER_LAUNCHER_LIQUID=1 で有効化")
        elif is_liquid_glass_available():
            print("  背景: 手描きガラス")
        elif mac_glass_available():
            print("  背景: 手描き（CYBER_LAUNCHER_NATIVE_GLASS=1 でネイティブ化）")
        else:
            print("  背景: 手描き Liquid Glass 風（pip install pyobjc-framework-Cocoa）")
        print()
        print("  ※ ショートカットが効かない場合:")
        print("     ./scripts/install-macos-shortcut.sh を実行し")
        print("     システム設定 → キーボード → ショートカット → サービス で ⌘+Shift+L を設定")
    print()


def _setup_tray(app: QApplication, window: CircularLauncherWindow) -> QSystemTrayIcon:
    tray = QSystemTrayIcon(app)
    tray.setIcon(app.style().standardIcon(QStyle.StandardPixmap.SP_ComputerIcon))
    tray.setToolTip("Cyber Launcher")

    menu = QMenu()
    show_action = QAction("ランチャーを表示", menu)
    show_action.triggered.connect(window.present)
    toggle_action = QAction("表示 / 非表示", menu)
    toggle_action.triggered.connect(window.toggle_visibility)
    quit_action = QAction("終了", menu)
    quit_action.triggered.connect(app.quit)

    menu.addAction(show_action)
    menu.addAction(toggle_action)
    menu.addSeparator()
    menu.addAction(quit_action)
    tray.setContextMenu(menu)

    def _on_activated(reason: QSystemTrayIcon.ActivationReason) -> None:
        if reason in (
            QSystemTrayIcon.ActivationReason.Trigger,
            QSystemTrayIcon.ActivationReason.DoubleClick,
        ):
            window.toggle_visibility()

    tray.activated.connect(_on_activated)
    tray.show()
    return tray


def main() -> int:
    fmt = QSurfaceFormat()
    fmt.setAlphaBufferSize(8)
    QSurfaceFormat.setDefaultFormat(fmt)

    QApplication.setHighDpiScaleFactorRoundingPolicy(
        Qt.HighDpiScaleFactorRoundingPolicy.PassThrough
    )
    app = QApplication(sys.argv)
    app.setApplicationName("Cyber Launcher")
    app.setQuitOnLastWindowClosed(False)
    apply_cyber_theme(app)

    window = CircularLauncherWindow()
    if not USE_MAC_GLASS:
        window._mac_glass_enabled = False

    tray = _setup_tray(app, window) if QSystemTrayIcon.isSystemTrayAvailable() else None
    window._toggle_watcher = ToggleFileWatcher(window.toggle_visibility)
    window._toggle_server = ToggleHttpServer(window.toggle_visibility)
    GlobalHotkeyService(DEFAULT_HOTKEY, window, "toggle_visibility").start()

    _print_usage(DEFAULT_HOTKEY)

    if START_VISIBLE:
        window.present()
    else:
        window.hide()

    if tray is not None:
        print("  メニューバーアイコンからも開けます。")

    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
