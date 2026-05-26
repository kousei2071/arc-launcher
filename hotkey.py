"""グローバルショートカット。"""

from __future__ import annotations

import sys

from PyQt6.QtCore import QTimer, QObject

DEFAULT_HOTKEY = "<cmd>+<shift>+l"


class GlobalHotkeyService:
    def __init__(self, hotkey: str, target: QObject, slot_name: str) -> None:
        self._hotkey = hotkey
        self._target = target
        self._slot_name = slot_name
        self._listener = None
        self._active = False

    def start(self) -> None:
        callback = getattr(self._target, self._slot_name)

        if sys.platform == "darwin":
            from mac_hotkey import (
                check_accessibility,
                permission_hint,
                prompt_accessibility,
                start_global_hotkey,
            )

            if not check_accessibility():
                prompt_accessibility()

            if start_global_hotkey(callback, key="l"):
                self._active = True
                if not check_accessibility():
                    print(permission_hint())
                return

            print(permission_hint())
            self._start_pynput(callback)
            return

        self._start_pynput(callback)

    def _start_pynput(self, callback) -> None:
        from pynput import keyboard

        combo = keyboard.HotKey(keyboard.HotKey.parse(self._hotkey), lambda: QTimer.singleShot(0, callback))

        def on_press(key: keyboard.Key | keyboard.KeyCode) -> None:
            try:
                combo.press(key)
            except (AttributeError, keyboard.ListenerException):
                pass

        def on_release(key: keyboard.Key | keyboard.KeyCode) -> None:
            try:
                combo.release(key)
            except (AttributeError, keyboard.ListenerException):
                pass

        self._listener = keyboard.Listener(on_press=on_press, on_release=on_release)
        self._listener.daemon = True
        self._listener.start()
        self._active = True
        print("  ショートカット: pynput 監視（有効）")
