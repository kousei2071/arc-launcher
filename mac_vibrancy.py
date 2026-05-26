"""
macOS すりガラス — NSWindow 背面の壁紙ぼかし + Qt 透明合成。
"""

from __future__ import annotations

import os
import sys
from ctypes import c_void_p
from typing import TYPE_CHECKING, Literal

if TYPE_CHECKING:
    from PyQt6.QtWidgets import QWidget

GlassMode = Literal["liquid", "vibrancy", "none"]

_installed_windows: set[int] = set()
PREFER_LIQUID = os.environ.get("CYBER_LAUNCHER_LIQUID", "0") == "1"


def is_pyobjc_available() -> bool:
    if sys.platform != "darwin":
        return False
    try:
        import objc  # noqa: F401
        from AppKit import NSColor  # noqa: F401

        return True
    except ImportError:
        return False


def is_liquid_glass_available() -> bool:
    if not is_pyobjc_available():
        return False
    try:
        from AppKit import NSGlassEffectView  # noqa: F401

        return True
    except ImportError:
        return False


def is_vibrancy_available() -> bool:
    if not is_pyobjc_available():
        return False
    try:
        from Cocoa import NSVisualEffectView  # noqa: F401

        return True
    except ImportError:
        return False


def is_available() -> bool:
    return is_vibrancy_available() or is_liquid_glass_available()


def raise_qt_content_above_glass(widget: QWidget) -> None:
    """NSVisualEffectView 再合成後に Qt 描画レイヤーを前面へ戻す。"""
    if sys.platform != "darwin" or int(widget.winId()) == 0:
        return

    try:
        import objc
        from ctypes import c_void_p

        ns_view = objc.objc_object(c_void_p=int(widget.winId()))
        if ns_view is not None:
            _raise_qt_above_glass(ns_view)
    except Exception:
        pass


def apply_mac_window_presentation(widget: QWidget) -> None:
    """デスクトップ／他アプリ操作後も前面に出すための NSWindow 設定。"""
    if sys.platform != "darwin" or int(widget.winId()) == 0:
        return

    try:
        import objc
        from ctypes import c_void_p
        from AppKit import (
            NSApp,
            NSFloatingWindowLevel,
            NSWindowCollectionBehaviorCanJoinAllSpaces,
            NSWindowCollectionBehaviorFullScreenAuxiliary,
        )

        NSApp.activateIgnoringOtherApps_(True)

        ns_view = objc.objc_object(c_void_p=int(widget.winId()))
        if ns_view is None:
            return

        ns_window = ns_view.window()
        if ns_window is None:
            return

        ns_window.setLevel_(NSFloatingWindowLevel)
        behavior = int(ns_window.collectionBehavior())
        behavior |= int(NSWindowCollectionBehaviorCanJoinAllSpaces)
        behavior |= int(NSWindowCollectionBehaviorFullScreenAuxiliary)
        ns_window.setCollectionBehavior_(behavior)
        ns_window.orderFrontRegardless()
        raise_qt_content_above_glass(widget)
    except Exception:
        pass


def apply_mac_transparency(widget: QWidget) -> None:
    if sys.platform != "darwin" or int(widget.winId()) == 0:
        return

    try:
        import objc
        from AppKit import NSColor

        ns_view = objc.objc_object(c_void_p=int(widget.winId()))
        if ns_view is None:
            return

        ns_window = ns_view.window()
        if ns_window is not None:
            ns_window.setOpaque_(False)
            ns_window.setBackgroundColor_(NSColor.clearColor())
            ns_window.setHasShadow_(True)
            try:
                from AppKit import NSWindowStyleMaskFullSizeContentView

                mask = ns_window.styleMask()
                ns_window.setStyleMask_(mask | NSWindowStyleMaskFullSizeContentView)
                ns_window.setTitlebarAppearsTransparent_(True)
            except Exception:
                pass

        ns_view.setWantsLayer_(True)
        layer = ns_view.layer()
        if layer is not None:
            layer.setOpaque_(False)
            layer.setBackgroundColor_(NSColor.clearColor().CGColor())
    except Exception:
        pass


def _raise_qt_above_glass(ns_view) -> None:
    from AppKit import NSWindowAbove

    try:
        parent = ns_view.superview()
        if parent is not None:
            parent.addSubview_positioned_relativeTo_(ns_view, NSWindowAbove, None)
    except Exception:
        pass


def _clear_glass(install_target) -> None:
    from AppKit import NSGlassEffectView
    from Cocoa import NSVisualEffectView

    for sub in list(install_target.subviews() or []):
        if sub.isKindOfClass_(NSGlassEffectView) or sub.isKindOfClass_(NSVisualEffectView):
            sub.removeFromSuperview()


def _install_effect_on_content_view(widget: QWidget, effect_view) -> bool:
    import objc
    from AppKit import NSViewHeightSizable, NSViewWidthSizable, NSWindowBelow

    win_id = int(widget.winId())
    ns_view = objc.objc_object(c_void_p=win_id)
    if ns_view is None:
        return False

    ns_window = ns_view.window()
    if ns_window is None:
        return False

    content = ns_window.contentView()
    if content is None:
        content = ns_view

    _clear_glass(content)

    bounds = content.bounds()
    effect_view.setFrame_(bounds)
    effect_view.setAutoresizingMask_(NSViewWidthSizable | NSViewHeightSizable)
    content.addSubview_positioned_relativeTo_(effect_view, NSWindowBelow, None)

    _raise_qt_above_glass(ns_view)
    _installed_windows.add(int(ns_window.hash()))
    return True


def install_vibrancy_glass(widget: QWidget, *, panel_diameter: float | None = None) -> bool:
    if not is_vibrancy_available():
        return False

    if int(widget.winId()) == 0:
        return False

    try:
        from Cocoa import (
            NSVisualEffectBlendingModeBehindWindow,
            NSVisualEffectMaterialUnderWindowBackground,
            NSVisualEffectStateActive,
            NSVisualEffectView,
        )

        apply_mac_transparency(widget)

        effect = NSVisualEffectView.alloc().init()
        effect.setMaterial_(NSVisualEffectMaterialUnderWindowBackground)
        effect.setBlendingMode_(NSVisualEffectBlendingModeBehindWindow)
        effect.setState_(NSVisualEffectStateActive)

        return _install_effect_on_content_view(widget, effect)
    except Exception:
        return False


def install_liquid_glass(widget: QWidget, *, panel_diameter: float | None = None) -> bool:
    if not is_liquid_glass_available():
        return False

    if int(widget.winId()) == 0:
        return False

    try:
        from AppKit import NSGlassEffectView, NSGlassEffectViewStyleRegular

        apply_mac_transparency(widget)

        glass = NSGlassEffectView.alloc().init()
        glass.setStyle_(NSGlassEffectViewStyleRegular)
        glass.setTintColor_(None)

        return _install_effect_on_content_view(widget, glass)
    except Exception:
        return False


def install_mac_glass(widget: QWidget, *, panel_diameter: float | None = None) -> GlassMode:
    if PREFER_LIQUID and install_liquid_glass(widget, panel_diameter=panel_diameter):
        return "liquid"
    if install_vibrancy_glass(widget, panel_diameter=panel_diameter):
        return "vibrancy"
    if install_liquid_glass(widget, panel_diameter=panel_diameter):
        return "liquid"
    return "none"


def schedule_mac_glass(
    widget: QWidget,
    *,
    panel_diameter: float | None = None,
    on_result=None,
) -> None:
    if not is_available():
        if on_result:
            on_result("none")
        return

    from PyQt6.QtCore import QTimer

    def _apply() -> None:
        apply_mac_transparency(widget)
        mode = install_mac_glass(widget, panel_diameter=panel_diameter)
        apply_mac_transparency(widget)
        widget.update()
        if on_result:
            on_result(mode)

    QTimer.singleShot(0, _apply)


def schedule_native_glass(widget, *, panel_diameter=None, on_result=None) -> None:
    schedule_mac_glass(widget, panel_diameter=panel_diameter, on_result=on_result)


def native_glass_available() -> bool:
    return is_available()
