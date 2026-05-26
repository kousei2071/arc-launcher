"""macOS グローバルショートカット — CGEventTap / NSEvent + Qt シグナル。"""

from __future__ import annotations

import sys
from typing import Callable

from PyQt6.QtCore import QObject, pyqtSignal

_bridge: "_HotkeyBridge | None" = None
_nsevent_monitor = None
_event_tap = None
_run_loop_source = None

_KEY_L = 37  # kVK_ANSI_L


class _HotkeyBridge(QObject):
    fired = pyqtSignal()


def _trusted_app_path() -> str:
    import os

    exe = os.path.realpath(sys.executable)
    if "/Python.app/" in exe:
        return exe
    for candidate in (
        "/opt/homebrew/opt/python@3.12/Frameworks/Python.framework/Versions/3.12/Resources/Python.app",
        "/usr/local/opt/python@3.12/Frameworks/Python.framework/Versions/3.12/Resources/Python.app",
    ):
        p = f"{candidate}/Contents/MacOS/Python"
        if os.path.isfile(p):
            return p
    return exe


def check_accessibility() -> bool:
    if sys.platform != "darwin":
        return True
    try:
        from ApplicationServices import AXIsProcessTrusted

        return bool(AXIsProcessTrusted())
    except ImportError:
        return False


def prompt_accessibility() -> None:
    if sys.platform != "darwin":
        return
    try:
        from ApplicationServices import AXIsProcessTrustedWithOptions
        from Foundation import NSDictionary

        options = NSDictionary.dictionaryWithDictionary_({"AXTrustedCheckOptionPrompt": True})
        AXIsProcessTrustedWithOptions(options)
    except ImportError:
        pass


def permission_hint() -> str:
    return (
        "  ショートカット: システム設定 → プライバシーとセキュリティ → アクセシビリティ\n"
        f"  に次を追加してオン → 再起動:\n    {_trusted_app_path()}"
    )


def _match_cg_hotkey(flags: int, keycode: int) -> bool:
    from Quartz import kCGEventFlagMaskCommand, kCGEventFlagMaskShift

    return (
        bool(flags & kCGEventFlagMaskCommand)
        and bool(flags & kCGEventFlagMaskShift)
        and keycode == _KEY_L
    )


def _match_ns_hotkey(flags: int, keycode: int) -> bool:
    from AppKit import NSEventModifierFlagCommand, NSEventModifierFlagShift

    return (
        bool(flags & NSEventModifierFlagCommand)
        and bool(flags & NSEventModifierFlagShift)
        and keycode == _KEY_L
    )


def _start_cgevent_tap(emit) -> bool:
    global _event_tap, _run_loop_source
    try:
        import Quartz.CoreGraphics as CG
        from CoreFoundation import CFRunLoopAddSource, kCFRunLoopCommonModes
        from Foundation import NSRunLoop
    except ImportError:
        return False

    def _tap_callback(proxy, event_type, event, _refcon):
        try:
            if event_type in (
                CG.kCGEventTapDisabledByTimeout,
                CG.kCGEventTapDisabledByUserInput,
            ):
                CG.CGEventTapEnable(_event_tap, True)
                return event

            if event_type != CG.kCGEventKeyDown:
                return event

            flags = CG.CGEventGetFlags(event)
            keycode = CG.CGEventGetIntegerValueField(event, CG.kCGKeyboardEventKeycode)
            if _match_cg_hotkey(flags, keycode):
                emit()
        except Exception as exc:
            print(f"[hotkey] tap: {exc}", flush=True)
        return event

    mask = CG.CGEventMaskBit(CG.kCGEventKeyDown)
    _event_tap = CG.CGEventTapCreate(
        CG.kCGSessionEventTap,
        CG.kCGHeadInsertEventTap,
        CG.kCGEventTapOptionDefault,
        mask,
        _tap_callback,
        None,
    )
    if _event_tap is None:
        return False

    _run_loop_source = CG.CFMachPortCreateRunLoopSource(None, _event_tap, 0)
    # Qt のメイン RunLoop に接続（CFRunLoopGetCurrent だと届かない）
    main_loop = NSRunLoop.mainRunLoop().getCFRunLoop()
    CFRunLoopAddSource(main_loop, _run_loop_source, kCFRunLoopCommonModes)
    CG.CGEventTapEnable(_event_tap, True)
    print("  ショートカット: CGEventTap → Qt メインループ（有効）", flush=True)
    return True


def _start_nsevent_monitor(emit) -> bool:
    global _nsevent_monitor
    try:
        from AppKit import NSEvent, NSKeyDownMask
    except ImportError:
        return False

    def _handler(event) -> None:
        try:
            if _match_ns_hotkey(event.modifierFlags(), event.keyCode()):
                emit()
        except Exception as exc:
            print(f"[hotkey] nsevent: {exc}", flush=True)

    _nsevent_monitor = NSEvent.addGlobalMonitorForEventsMatchingMask_handler_(
        NSKeyDownMask, _handler
    )
    if _nsevent_monitor is not None:
        print("  ショートカット: NSEvent グローバル監視（有効）", flush=True)
    return _nsevent_monitor is not None


def _start_local_monitor(emit) -> bool:
    """フォーカス時のローカル監視（権限不要）。"""
    try:
        from AppKit import NSEvent, NSKeyDownMask
    except ImportError:
        return False

    def _handler(event):
        try:
            if _match_ns_hotkey(event.modifierFlags(), event.keyCode()):
                emit()
                return None
        except Exception:
            pass
        return event

    NSEvent.addLocalMonitorForEventsMatchingMask_handler_(NSKeyDownMask, _handler)
    print("  ショートカット: NSEvent ローカル監視（有効）", flush=True)
    return True


def start_global_hotkey(callback: Callable[[], None], *, key: str = "l") -> bool:
    global _bridge
    if sys.platform != "darwin":
        return False

    from PyQt6.QtCore import Qt

    _bridge = _HotkeyBridge()
    _bridge.fired.connect(callback, Qt.ConnectionType.QueuedConnection)

    def _emit() -> None:
        _bridge.fired.emit()

    ok = False
    if check_accessibility():
        ok = _start_cgevent_tap(_emit) or _start_nsevent_monitor(_emit)
    else:
        prompt_accessibility()
        ok = _start_cgevent_tap(_emit) or _start_nsevent_monitor(_emit)

    _start_local_monitor(_emit)
    return ok
