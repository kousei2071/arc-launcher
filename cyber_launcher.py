#!/usr/bin/env python3
"""
円形デスクトップランチャー — macOS Liquid Glass / ビブランシー UI。

- macOS 26+: NSGlassEffectView（Liquid Glass）
- それ以前: NSVisualEffectView
- フォールバック: 手描き Liquid Glass 風
"""

from __future__ import annotations

import math
import subprocess
import sys
from dataclasses import dataclass
from typing import Callable

from PyQt6.QtCore import QPointF, QRectF, Qt, QTimer, pyqtSlot, QEvent
from PyQt6.QtGui import (
    QBitmap,
    QBrush,
    QColor,
    QCursor,
    QFont,
    QGuiApplication,
    QLinearGradient,
    QPainter,
    QPainterPath,
    QPen,
    QPixmap,
    QRadialGradient,
)
from PyQt6.QtWidgets import QApplication, QWidget

from app_icons import load_mac_app_icon
from mac_vibrancy import apply_mac_transparency
from mac_vibrancy import apply_mac_window_presentation
from mac_vibrancy import dismiss_mac_window
from mac_vibrancy import is_available as native_glass_available
from mac_vibrancy import raise_qt_content_above_glass
from mac_vibrancy import schedule_mac_glass
from mac_vibrancy import start_outside_click_dismiss
from mac_vibrancy import stop_outside_click_dismiss

WINDOW_SIZE = 540
ORBIT_RADIUS = 178
ICON_TILE = 58
SQUIRCLE_RADIUS = 15
CENTER_HUB_SIZE = 72
CENTER_DEAD_ZONE = 30
SLOT_HIT_RADIUS = 44

# アクセント（ガラス縁の虹色）
ACCENT_CYAN = QColor(80, 220, 255)
ACCENT_VIOLET = QColor(180, 100, 255)
ACCENT_PINK = QColor(255, 120, 200)
SLOT_ACCENTS = (
    ACCENT_CYAN,
    QColor(100, 180, 255),
    ACCENT_VIOLET,
    QColor(200, 140, 255),
    ACCENT_PINK,
    QColor(120, 255, 220),
    QColor(255, 200, 120),
    QColor(160, 220, 255),
)

LABEL_COLOR = QColor(255, 255, 255, 245)
LABEL_SHADOW = QColor(0, 0, 0, 120)
LABEL_SUB = QColor(230, 240, 255, 210)
GLASS_BORDER = QColor(255, 255, 255, 140)
GLASS_BORDER_DIM = QColor(255, 255, 255, 85)


@dataclass(frozen=True)
class LauncherItem:
    app_name: str
    icon: QPixmap
    action: Callable[[], None]


def _open_mac_app(name: str) -> None:
    subprocess.Popen(["open", "-a", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def default_items() -> list[LauncherItem]:
    app_names = [
        "Finder",
        "Dia",
        "Terminal",
        "Cursor",
        "Slack",
        "RunCat",
        "Google Chrome",
        "System Settings",
    ]
    return [
        LauncherItem(name, load_mac_app_icon(name, 128), lambda n=name: _open_mac_app(n))
        for name in app_names
    ]


# ---------------------------------------------------------------------------
# 手描きガラス（フォールバック専用）
# ---------------------------------------------------------------------------


def _paint_glass_ellipse(
    painter: QPainter,
    center: QPointF,
    radius: float,
    *,
    emphasis: float = 1.0,
    shadow: bool = True,
) -> None:
    r = radius * emphasis
    if shadow:
        for i in range(4, 0, -1):
            painter.setPen(Qt.PenStyle.NoPen)
            painter.setBrush(QColor(0, 0, 0, int(12 + i * 10)))
            spread = i * 2.2 * emphasis
            painter.drawEllipse(center, r + spread, r + spread * 0.92)

    body = QRadialGradient(center, r * 1.08)
    body.setColorAt(0.0, QColor(255, 255, 255, int(78 * emphasis)))
    body.setColorAt(0.45, QColor(255, 255, 255, int(46 * emphasis)))
    body.setColorAt(0.85, QColor(245, 248, 252, int(24 * emphasis)))
    body.setColorAt(1.0, QColor(200, 210, 225, int(18 * emphasis)))
    painter.setPen(Qt.PenStyle.NoPen)
    painter.setBrush(QBrush(body))
    painter.drawEllipse(center, r, r)

    border = GLASS_BORDER if emphasis > 1.02 else GLASS_BORDER_DIM
    pen = QPen(QColor(border.red(), border.green(), border.blue(), int(border.alpha() * emphasis)), 1.1)
    painter.setPen(pen)
    painter.setBrush(Qt.BrushStyle.NoBrush)
    painter.drawEllipse(center, r, r)


def _paint_premium_glass_plate(
    painter: QPainter,
    center: QPointF,
    radius: float,
    pulse: float,
    orbit_rotation: float,
    *,
    emphasis: float = 1.0,
) -> None:
    """多層プレミアムガラス（フロスト + 虹色リム + スペキュラ）。"""
    r = radius * pulse
    e = emphasis

    for i in range(6, 0, -1):
        painter.setPen(Qt.PenStyle.NoPen)
        painter.setBrush(QColor(0, 0, 0, int((6 + i * 6) * e)))
        painter.drawEllipse(center, r + i * 3.0, r + i * 2.85)

    body = QRadialGradient(center, r * 1.2)
    body.setColorAt(0.0, QColor(255, 255, 255, int(72 * e)))
    body.setColorAt(0.25, QColor(240, 248, 255, int(48 * e)))
    body.setColorAt(0.55, QColor(220, 230, 255, int(28 * e)))
    body.setColorAt(0.82, QColor(200, 180, 255, int(14 * e)))
    body.setColorAt(1.0, QColor(255, 255, 255, 0))
    painter.setBrush(QBrush(body))
    painter.setPen(Qt.PenStyle.NoPen)
    painter.drawEllipse(center, r, r)

    shine = QLinearGradient(
        QPointF(center.x() - r * 0.75, center.y() - r),
        QPointF(center.x() + r * 0.4, center.y() + r * 0.35),
    )
    shine.setColorAt(0.0, QColor(255, 255, 255, int(95 * e)))
    shine.setColorAt(0.35, QColor(200, 240, 255, int(35 * e)))
    shine.setColorAt(1.0, QColor(255, 255, 255, 0))
    painter.setBrush(QBrush(shine))
    painter.drawEllipse(center, r * 0.97, r * 0.95)

    for i, col in enumerate((ACCENT_CYAN, ACCENT_VIOLET, ACCENT_PINK, ACCENT_CYAN)):
        pen = QPen(QColor(col.red(), col.green(), col.blue(), int((35 + i * 12) * e)))
        pen.setWidthF(1.8 - i * 0.25)
        painter.setPen(pen)
        painter.setBrush(Qt.BrushStyle.NoBrush)
        painter.drawEllipse(center, r + 1.5 - i * 0.4, r + 1.5 - i * 0.4)

    pen = QPen(QColor(255, 255, 255, int(150 * e)))
    pen.setWidthF(1.2)
    painter.setPen(pen)
    painter.drawEllipse(center, r, r)

    spec_rect = QRectF(center.x() - r, center.y() - r, 2 * r, 2 * r)
    spec_pen = QPen(QColor(255, 255, 255, int(65 * e)))
    spec_pen.setWidthF(2.0)
    painter.setPen(spec_pen)
    painter.drawArc(spec_rect, int((160 - orbit_rotation) * 16), int(55 * 16))
    spec_pen.setColor(QColor(180, 220, 255, int(40 * e)))
    spec_pen.setWidthF(1.0)
    painter.setPen(spec_pen)
    painter.drawArc(spec_rect, int((340 - orbit_rotation * 0.7) * 16), int(40 * 16))


def _paint_icon_glass_pedestal(
    painter: QPainter,
    center: QPointF,
    radius: float,
    accent: QColor,
    glow: float,
    hovered: bool,
) -> None:
    """アイコン下のガラス台座。"""
    g = glow
    r = radius * (1.05 + (g - 0.4) * 0.12)

    for i in range(3, 0, -1):
        c = QColor(accent.red(), accent.green(), accent.blue(), int((8 + i * 6) * g))
        pen = QPen(c, 1.2 + (g - 0.4))
        painter.setPen(pen)
        painter.setBrush(Qt.BrushStyle.NoBrush)
        painter.drawEllipse(center, r + i * 2.5, r + i * 2.5)

    fill = QRadialGradient(center, r)
    fill.setColorAt(0.0, QColor(255, 255, 255, int((45 if hovered else 28) * g)))
    fill.setColorAt(0.7, QColor(accent.red(), accent.green(), accent.blue(), int(18 * g)))
    fill.setColorAt(1.0, QColor(255, 255, 255, 0))
    painter.setBrush(QBrush(fill))
    painter.setPen(Qt.PenStyle.NoPen)
    painter.drawEllipse(center, r, r)

    rim = QPen(QColor(255, 255, 255, int(130 * g)))
    rim.setWidthF(1.3 if hovered else 0.9)
    painter.setPen(rim)
    painter.setBrush(Qt.BrushStyle.NoBrush)
    painter.drawEllipse(center, r, r)


def _paint_icon_tile(
    painter: QPainter,
    center: QPointF,
    icon: QPixmap,
    *,
    size: float,
    hovered: bool,
    accent: QColor,
    glow: float = 0.4,
) -> None:
    scale = 1.0 + (glow - 0.4) * 0.22
    side = int(size * scale)
    pedestal_r = side * 0.52

    _paint_icon_glass_pedestal(painter, center, pedestal_r, accent, glow, hovered)

    if hovered:
        for i in range(4, 0, -1):
            c = QColor(accent.red(), accent.green(), accent.blue(), int(25 / i))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.setBrush(c)
            painter.drawEllipse(center, pedestal_r + i * 4, pedestal_r + i * 4)

    device = painter.device()
    dpr = device.devicePixelRatioF() if device else 1.0
    px = max(1, int(side * dpr))
    pixmap = icon.scaled(
        px,
        px,
        Qt.AspectRatioMode.KeepAspectRatio,
        Qt.TransformationMode.SmoothTransformation,
    )
    pixmap.setDevicePixelRatio(dpr)
    x = center.x() - pixmap.width() / dpr / 2
    y = center.y() - pixmap.height() / dpr / 2
    painter.drawPixmap(int(x), int(y), pixmap)


def _draw_label(
    painter: QPainter,
    rect: QRectF,
    text: str,
    *,
    prominent: bool = False,
) -> None:
    font = QFont(".AppleSystemUIFont", 11 if prominent else 9)
    font.setWeight(QFont.Weight.Medium if prominent else QFont.Weight.Normal)
    painter.setFont(font)
    painter.setPen(LABEL_SHADOW)
    painter.drawText(rect.translated(0, 1), Qt.AlignmentFlag.AlignHCenter | Qt.AlignmentFlag.AlignTop, text)
    painter.setPen(LABEL_COLOR if prominent else LABEL_SUB)
    painter.drawText(rect, Qt.AlignmentFlag.AlignHCenter | Qt.AlignmentFlag.AlignTop, text)


# ---------------------------------------------------------------------------
# ラジアルメニュー
# ---------------------------------------------------------------------------


class CursorRadialMenu(QWidget):
    def __init__(self, items: list[LauncherItem], parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._items = items
        self._hover_index: int | None = None
        self._pulse = 0.0
        self._orbit_rotation = 0.0
        self._slot_glow: list[float] = [0.4] * len(items)
        self._slot_glow_target: list[float] = [0.4] * len(items)

        self.setMouseTracking(True)
        self.setAutoFillBackground(False)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.setAttribute(Qt.WidgetAttribute.WA_OpaquePaintEvent, False)
        self.setAttribute(Qt.WidgetAttribute.WA_NoSystemBackground, True)
        self.setCursor(Qt.CursorShape.ArrowCursor)

        self._anim_timer = QTimer(self)
        self._anim_timer.timeout.connect(self._tick_animation)
        self._anim_timer.start(40)

    def _glass_mode(self) -> str:
        return getattr(self, "_glass_kind", "none")

    def _is_native_ui(self) -> bool:
        return self._glass_mode() in ("liquid", "vibrancy")

    def _is_liquid_ui(self) -> bool:
        return self._glass_mode() == "liquid"

    def _tick_animation(self) -> None:
        self._pulse = (self._pulse + 0.035) % (2 * math.pi)
        self._orbit_rotation = (self._orbit_rotation + 0.4) % 360.0
        for i, target in enumerate(self._slot_glow_target):
            g = self._slot_glow[i]
            if abs(g - target) > 0.008:
                self._slot_glow[i] = g + (target - g) * 0.22
        self.update()

    def center_point(self) -> QPointF:
        return QPointF(self.width() / 2.0, self.height() / 2.0)

    def slot_position(self, index: int) -> QPointF:
        n = len(self._items)
        cx, cy = self.center_point().x(), self.center_point().y()
        angle = (2 * math.pi * index / n) - (math.pi / 2)
        return QPointF(cx + ORBIT_RADIUS * math.cos(angle), cy + ORBIT_RADIUS * math.sin(angle))

    def _hit_radius(self, glow: float) -> float:
        if self._is_native_ui():
            return SLOT_HIT_RADIUS + (glow - 0.4) * 8
        return 36 + (glow - 0.4) * 12

    def index_at(self, pos: QPointF) -> int | None:
        cx, cy = self.center_point().x(), self.center_point().y()
        dx, dy = pos.x() - cx, pos.y() - cy
        dist = math.hypot(dx, dy)
        if dist < CENTER_DEAD_ZONE:
            return None

        best: int | None = None
        best_d = float("inf")
        for i in range(len(self._items)):
            sp = self.slot_position(i)
            d = math.hypot(pos.x() - sp.x(), pos.y() - sp.y())
            if d < self._hit_radius(self._slot_glow[i]) and d < best_d:
                best_d = d
                best = i
        if best is not None:
            return best

        if dist < ORBIT_RADIUS * 0.48 or dist > ORBIT_RADIUS * 1.38:
            return None
        mouse_angle = math.atan2(dy, dx)
        n = len(self._items)
        best_angle_diff = float("inf")
        for i in range(n):
            slot_angle = (2 * math.pi * i / n) - (math.pi / 2)
            diff = abs(
                math.atan2(
                    math.sin(mouse_angle - slot_angle),
                    math.cos(mouse_angle - slot_angle),
                )
            )
            if diff < best_angle_diff:
                best_angle_diff = diff
                best = i
        return best if best_angle_diff < (math.pi / n) * 1.08 else None

    def _set_hover(self, index: int | None) -> None:
        if index == self._hover_index:
            return
        for i in range(len(self._items)):
            self._slot_glow_target[i] = 1.0 if i == index else 0.4
        self._hover_index = index
        self.setCursor(
            Qt.CursorShape.PointingHandCursor if index is not None else Qt.CursorShape.ArrowCursor
        )

    def mouseMoveEvent(self, event) -> None:  # noqa: N802
        self._set_hover(self.index_at(event.position()))
        super().mouseMoveEvent(event)

    def leaveEvent(self, event) -> None:  # noqa: N802
        self._set_hover(None)
        super().leaveEvent(event)

    def mousePressEvent(self, event) -> None:  # noqa: N802
        if event.button() != Qt.MouseButton.LeftButton:
            super().mousePressEvent(event)
            return
        idx = self.index_at(event.position())
        w = self.window()
        dismiss = getattr(w, "_dismiss", None)
        if idx is not None:
            self._items[idx].action()
            if callable(dismiss):
                dismiss()
            return
        if callable(dismiss):
            dismiss()
            return
        super().mousePressEvent(event)

    def paintEvent(self, _event) -> None:  # noqa: N802
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform)

        cx, cy = self.center_point().x(), self.center_point().y()
        mode = self._glass_mode()

        self._paint_backdrop(painter, cx, cy, mode)
        self._paint_orbit_guides(painter, cx, cy, mode)
        self._paint_center_hub(painter, cx, cy, mode)

        for i, item in enumerate(self._items):
            pos = self.slot_position(i)
            hovered = i == self._hover_index
            self._paint_slot(painter, item, pos, self._slot_glow[i], hovered, mode, i)

        painter.end()

    def _paint_backdrop(self, painter: QPainter, cx: float, cy: float, mode: str) -> None:
        """背景プレート（軌道線は _paint_orbit_guides で描画）。"""
        pulse = 0.98 + 0.02 * math.sin(self._pulse)
        center = QPointF(cx, cy)
        plate_r = ORBIT_RADIUS * 1.18 * pulse

        emphasis = 0.78 if mode == "none" else (0.68 if mode == "vibrancy" else 0.62)
        _paint_premium_glass_plate(
            painter, center, plate_r, pulse, self._orbit_rotation, emphasis=emphasis
        )

    def _paint_orbit_guides(self, painter: QPainter, cx: float, cy: float, mode: str) -> None:
        """アイコンが並ぶ軌道円・スポーク・目盛り・スロットマーカー。"""
        pulse = 0.98 + 0.02 * math.sin(self._pulse)
        center = QPointF(cx, cy)
        n = len(self._items)
        arc_r = ORBIT_RADIUS * pulse
        arc_rect = QRectF(cx - arc_r, cy - arc_r, arc_r * 2, arc_r * 2)

        for ratio, alpha in ((0.58, 18), (0.78, 28), (0.92, 38), (1.06, 22)):
            pen = QPen(QColor(255, 255, 255, alpha))
            pen.setWidthF(0.6 + ratio * 0.4)
            painter.setPen(pen)
            painter.setBrush(Qt.BrushStyle.NoBrush)
            painter.drawEllipse(center, arc_r * ratio, arc_r * ratio)

        glow_pulse = 0.65 + 0.35 * math.sin(self._pulse * 1.3)
        track_pen = QPen(QColor(ACCENT_CYAN.red(), ACCENT_CYAN.green(), ACCENT_CYAN.blue(), int(90 * glow_pulse)))
        track_pen.setWidthF(2.0)
        painter.setPen(track_pen)
        painter.drawEllipse(center, arc_r, arc_r)
        inner_track = QPen(QColor(255, 255, 255, int(50 * glow_pulse)))
        inner_track.setWidthF(0.8)
        painter.setPen(inner_track)
        painter.drawEllipse(center, arc_r * 0.98, arc_r * 0.98)

        for seg in range(16):
            if seg % 2 != 0:
                continue
            accent = SLOT_ACCENTS[seg % len(SLOT_ACCENTS)]
            start = int((seg * 22.5 - self._orbit_rotation) * 16)
            arc_pen = QPen(QColor(accent.red(), accent.green(), accent.blue(), 55))
            arc_pen.setWidthF(1.8)
            painter.setPen(arc_pen)
            painter.drawArc(arc_rect, start, int(-16 * 16))

        tick_count = 72
        for i in range(tick_count):
            angle = math.radians(i * (360 / tick_count) + self._orbit_rotation)
            major = i % 6 == 0
            inner = arc_r * (1.02 if major else 1.01)
            outer = arc_r * (1.09 if major else 1.045)
            col = ACCENT_CYAN if major else QColor(255, 255, 255, 40)
            tick_pen = QPen(QColor(col.red(), col.green(), col.blue(), 90 if major else 35))
            tick_pen.setWidthF(1.6 if major else 0.5)
            painter.setPen(tick_pen)
            painter.drawLine(
                QPointF(cx + inner * math.cos(angle), cy + inner * math.sin(angle)),
                QPointF(cx + outer * math.cos(angle), cy + outer * math.sin(angle)),
            )

        for i in range(n):
            pos = self.slot_position(i)
            hovered = i == self._hover_index
            accent = SLOT_ACCENTS[i % len(SLOT_ACCENTS)]
            grad = QLinearGradient(center, pos)
            grad.setColorAt(0.0, QColor(accent.red(), accent.green(), accent.blue(), 70 if hovered else 35))
            grad.setColorAt(0.6, QColor(255, 255, 255, 45 if hovered else 22))
            grad.setColorAt(1.0, QColor(255, 255, 255, 15 if hovered else 8))
            spoke_pen = QPen(QBrush(grad), 1.0 if hovered else 0.65)
            painter.setPen(spoke_pen)
            painter.drawLine(center, pos)

            angle = (2 * math.pi * i / n) - (math.pi / 2)
            mx = cx + arc_r * math.cos(angle)
            my = cy + arc_r * math.sin(angle)
            mr = 5.5 if hovered else 3.5
            painter.setPen(Qt.PenStyle.NoPen)
            mg = QRadialGradient(QPointF(mx, my), mr * 1.8)
            mg.setColorAt(0.0, QColor(255, 255, 255, 200 if hovered else 100))
            mg.setColorAt(0.5, QColor(accent.red(), accent.green(), accent.blue(), 120 if hovered else 50))
            mg.setColorAt(1.0, QColor(accent.red(), accent.green(), accent.blue(), 0))
            painter.setBrush(QBrush(mg))
            painter.drawEllipse(QPointF(mx, my), mr, mr)

        hub_r = ORBIT_RADIUS * 0.14
        hub_g = QRadialGradient(center, hub_r * 1.5)
        hub_g.setColorAt(0.0, QColor(255, 255, 255, 50))
        hub_g.setColorAt(0.5, QColor(ACCENT_CYAN.red(), ACCENT_CYAN.green(), ACCENT_CYAN.blue(), 30))
        hub_g.setColorAt(1.0, QColor(255, 255, 255, 0))
        painter.setBrush(QBrush(hub_g))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawEllipse(center, hub_r, hub_r)
        cross = hub_r * 0.85
        cross_pen = QPen(QColor(255, 255, 255, 55))
        cross_pen.setWidthF(0.9)
        painter.setPen(cross_pen)
        painter.drawLine(QPointF(cx - cross, cy), QPointF(cx + cross, cy))
        painter.drawLine(QPointF(cx, cy - cross), QPointF(cx, cy + cross))

    def _paint_center_hub(self, painter: QPainter, cx: float, cy: float, mode: str) -> None:
        center = QPointF(cx, cy)
        hub_pulse = 0.92 + 0.08 * math.sin(self._pulse * 2)
        core_r = 22 * hub_pulse

        if self._hover_index is None:
            _paint_icon_glass_pedestal(painter, center, core_r, ACCENT_CYAN, 0.55, False)
            return

        item = self._items[self._hover_index]
        accent = SLOT_ACCENTS[self._hover_index % len(SLOT_ACCENTS)]
        hub_r = CENTER_HUB_SIZE * 0.48 * hub_pulse

        _paint_icon_glass_pedestal(painter, center, hub_r + 8, accent, 1.0, True)
        for i in range(5, 0, -1):
            c = QColor(accent.red(), accent.green(), accent.blue(), int(30 / i))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.setBrush(c)
            painter.drawEllipse(center, hub_r + i * 5, hub_r + i * 5)

        _paint_icon_tile(
            painter,
            center,
            item.icon,
            size=CENTER_HUB_SIZE * hub_pulse,
            hovered=True,
            accent=accent,
            glow=1.0,
        )
        _draw_label(
            painter,
            QRectF(cx - 95, cy + CENTER_HUB_SIZE * 0.52 + 14, 190, 24),
            item.app_name,
            prominent=True,
        )

    def _paint_slot(
        self,
        painter: QPainter,
        item: LauncherItem,
        pos: QPointF,
        glow: float,
        hovered: bool,
        mode: str,
        index: int,
    ) -> None:
        accent = SLOT_ACCENTS[index % len(SLOT_ACCENTS)]
        _paint_icon_tile(
            painter,
            pos,
            item.icon,
            size=ICON_TILE + (glow - 0.4) * 12,
            hovered=hovered,
            accent=accent,
            glow=glow,
        )
        label_rect = QRectF(pos.x() - 54, pos.y() + ICON_TILE * 0.55 + 6, 108, 18)
        _draw_label(painter, label_rect, item.app_name, prominent=hovered)


def _apply_circular_window_mask(widget: QWidget, margin: int = 3) -> None:
    """正方形ウィンドウの四隅を透明にし、円形ランチャーだけ表示する。"""
    size = widget.size()
    if size.width() < 8 or size.height() < 8:
        return
    bitmap = QBitmap(size)
    bitmap.fill(Qt.GlobalColor.color0)
    p = QPainter(bitmap)
    p.setRenderHint(QPainter.RenderHint.Antialiasing)
    p.setBrush(Qt.GlobalColor.color1)
    p.setPen(Qt.GlobalColor.color0)
    p.drawEllipse(margin, margin, size.width() - 2 * margin, size.height() - 2 * margin)
    p.end()
    widget.setMask(bitmap)


class CircularLauncherWindow(CursorRadialMenu):
    """ラジアルメニュー本体をトップレベルウィンドウとして表示（灰色の親ウィンドウ問題を回避）。"""

    def __init__(self, items: list[LauncherItem] | None = None) -> None:
        self._launcher_items = items or default_items()
        super().__init__(self._launcher_items)
        self._mac_glass_enabled = native_glass_available()
        self._glass_kind: str = "none"
        self._shown: bool = False
        self._setup_window()

    def _setup_window(self) -> None:
        self.setWindowTitle("Cyber Launcher")
        self.setFixedSize(WINDOW_SIZE, WINDOW_SIZE)

        flags = (
            Qt.WindowType.Window
            | Qt.WindowType.FramelessWindowHint
            | Qt.WindowType.WindowStaysOnTopHint
        )
        self.setWindowFlags(flags)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.setAttribute(Qt.WidgetAttribute.WA_NoSystemBackground, True)
        self.setStyleSheet("background: transparent;")

    def _move_to_cursor(self) -> None:
        cursor = QCursor.pos()
        screen = QGuiApplication.screenAt(cursor) or QApplication.primaryScreen()
        if screen is None:
            return
        geo = screen.availableGeometry()
        x = cursor.x() - self.width() // 2
        y = cursor.y() - self.height() // 2
        x = max(geo.x(), min(x, geo.x() + geo.width() - self.width()))
        y = max(geo.y(), min(y, geo.y() + geo.height() - self.height()))
        self.move(x, y)

    def _sync_shown_state(self) -> None:
        """最小化・非表示になったら内部フラグと監視を止める。"""
        if not self.isVisible() or self.isMinimized():
            self._shown = False
            stop_outside_click_dismiss()

    @pyqtSlot()
    def toggle_visibility(self) -> None:
        if self._shown:
            self._dismiss()
        else:
            self.present()

    def _dismiss(self) -> None:
        self._shown = False
        stop_outside_click_dismiss()
        self.clearMask()
        self.hide()
        dismiss_mac_window(self)
        if self.isVisible():
            self.setVisible(False)
            dismiss_mac_window(self)

    def present(self) -> None:
        if self.isVisible():
            dismiss_mac_window(self)
            self.hide()
        self._move_to_cursor()
        self._set_hover(None)
        apply_mac_transparency(self)
        self.showNormal()
        apply_mac_window_presentation(self)
        _apply_circular_window_mask(self)
        self.raise_()
        self.activateWindow()
        self._shown = True
        start_outside_click_dismiss(self, self._dismiss)

        if self._mac_glass_enabled and self._glass_kind == "none":
            panel = min(self.width(), self.height()) * 0.9

            def _on_glass(mode: str) -> None:
                if not self._shown:
                    return
                self._glass_kind = mode
                apply_mac_transparency(self)
                apply_mac_window_presentation(self)
                _apply_circular_window_mask(self)
                self.update()

            schedule_mac_glass(self, panel_diameter=panel, on_result=_on_glass)
        elif self._mac_glass_enabled and self._glass_kind != "none":
            raise_qt_content_above_glass(self)

        self.update()
        QTimer.singleShot(80, self._bring_to_front)
        QTimer.singleShot(250, self._bring_to_front)

    def _bring_to_front(self) -> None:
        if not self._shown:
            return
        apply_mac_window_presentation(self)
        self.raise_()
        self.activateWindow()
        self.update()

    def resizeEvent(self, event) -> None:  # noqa: N802
        _apply_circular_window_mask(self)
        super().resizeEvent(event)

    def keyPressEvent(self, event) -> None:  # noqa: N802
        if event.key() == Qt.Key.Key_Escape:
            self._dismiss()
        super().keyPressEvent(event)

    def hideEvent(self, event) -> None:  # noqa: N802
        self._shown = False
        stop_outside_click_dismiss()
        super().hideEvent(event)

    def changeEvent(self, event) -> None:  # noqa: N802
        if event.type() == QEvent.Type.WindowStateChange:
            self._sync_shown_state()
        super().changeEvent(event)


GLOBAL_QSS = "QWidget { background: transparent; }"


def apply_cyber_theme(app: QApplication) -> None:
    app.setStyleSheet(GLOBAL_QSS)
