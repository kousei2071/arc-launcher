import AppKit

final class LauncherView: NSView {
    private let items: [LauncherItem]
    private var hoverIndex: Int?
    private var pulse: CGFloat = 0
    private var orbitRotation: CGFloat = 0
    private var slotGlow: [CGFloat]
    private var slotGlowTarget: [CGFloat]
    private var timer: Timer?
    var glassMode: GlassMode = .none
    weak var launcherWindow: CircularLauncherWindow?

    init(items: [LauncherItem]) {
        self.items = items
        self.slotGlow = Array(repeating: 0.4, count: items.count)
        self.slotGlowTarget = Array(repeating: 0.4, count: items.count)
        super.init(frame: NSRect(x: 0, y: 0, width: windowSize, height: windowSize))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self
        ))
        timer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickAnimation()
            }
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    private var geometry: LauncherGeometry {
        LauncherGeometry(itemCount: items.count, size: bounds.size)
    }

    private var nativeUI: Bool {
        glassMode == .liquid || glassMode == .vibrancy
    }

    private func tickAnimation() {
        pulse = (pulse + 0.035).truncatingRemainder(dividingBy: 2 * .pi)
        orbitRotation = (orbitRotation + 0.4).truncatingRemainder(dividingBy: 360)
        for index in slotGlowTarget.indices {
            let current = slotGlow[index]
            let target = slotGlowTarget[index]
            if abs(current - target) > 0.008 {
                slotGlow[index] = current + (target - current) * 0.22
            }
        }
        needsDisplay = true
    }

    private func index(at point: CGPoint) -> Int? {
        geometry.index(at: point, glows: slotGlow, nativeUI: nativeUI)
    }

    private func setHover(index: Int?) {
        guard index != hoverIndex else { return }
        for slot in slotGlowTarget.indices {
            slotGlowTarget[slot] = slot == index ? 1.0 : 0.4
        }
        hoverIndex = index
        NSCursor.pop()
        (index == nil ? NSCursor.arrow : NSCursor.pointingHand).push()
    }

    override func mouseMoved(with event: NSEvent) {
        setHover(index: index(at: convert(event.locationInWindow, from: nil)))
    }

    override func mouseExited(with event: NSEvent) {
        setHover(index: nil)
        super.mouseExited(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        if let index = index(at: convert(event.locationInWindow, from: nil)) {
            items[index].open()
            launcherWindow?.dismiss()
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            launcherWindow?.dismiss()
        } else {
            super.keyDown(with: event)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)

        let center = geometry.center
        paintBackdrop(context: context, center: center)
        paintOrbitGuides(context: context, center: center)
        paintCenterHub(context: context, center: center)

        for (index, item) in items.enumerated() {
            paintSlot(
                context: context,
                item: item,
                position: geometry.slotPosition(index: index),
                glow: slotGlow[index],
                hovered: index == hoverIndex,
                index: index
            )
        }
    }

    private func paintBackdrop(context: CGContext, center: CGPoint) {
        let platePulse = 0.98 + 0.02 * sin(pulse)
        let radius = defaultOrbitRadius * 1.18 * platePulse
        let emphasis: CGFloat = glassMode == .none ? 0.78 : (glassMode == .vibrancy ? 0.68 : 0.62)
        paintPremiumGlassPlate(context: context, center: center, radius: radius, emphasis: emphasis)
    }

    private func paintPremiumGlassPlate(context: CGContext, center: CGPoint, radius: CGFloat, emphasis: CGFloat) {
        for index in stride(from: 6, through: 1, by: -1) {
            context.setFillColor(NSColor.black.withAlpha(CGFloat(6 + index * 6) / 255 * emphasis).cgColor)
            context.fillEllipse(in: ellipseRect(center: center, radiusX: radius + CGFloat(index) * 3, radiusY: radius + CGFloat(index) * 2.85))
        }

        drawRadialGradient(
            context: context,
            center: center,
            radius: radius * 1.2,
            colors: [
                NSColor.white.withAlpha(72 / 255 * emphasis),
                NSColor(calibratedRed: 240 / 255, green: 248 / 255, blue: 1, alpha: 48 / 255 * emphasis),
                NSColor(calibratedRed: 220 / 255, green: 230 / 255, blue: 1, alpha: 28 / 255 * emphasis),
                NSColor(calibratedRed: 200 / 255, green: 180 / 255, blue: 1, alpha: 14 / 255 * emphasis),
                NSColor.white.withAlpha(0)
            ],
            locations: [0, 0.25, 0.55, 0.82, 1]
        )

        drawLinearGradient(
            context: context,
            rect: ellipseRect(center: center, radiusX: radius * 0.97, radiusY: radius * 0.95),
            start: CGPoint(x: center.x - radius * 0.75, y: center.y - radius),
            end: CGPoint(x: center.x + radius * 0.4, y: center.y + radius * 0.35),
            colors: [
                NSColor.white.withAlpha(95 / 255 * emphasis),
                NSColor(calibratedRed: 200 / 255, green: 240 / 255, blue: 1, alpha: 35 / 255 * emphasis),
                NSColor.white.withAlpha(0)
            ],
            locations: [0, 0.35, 1]
        )

        for (index, color) in [accentCyan, accentViolet, accentPink, accentCyan].enumerated() {
            context.setStrokeColor(color.withAlpha(CGFloat(35 + index * 12) / 255 * emphasis).cgColor)
            context.setLineWidth(1.8 - CGFloat(index) * 0.25)
            context.strokeEllipse(in: ellipseRect(center: center, radiusX: radius + 1.5 - CGFloat(index) * 0.4, radiusY: radius + 1.5 - CGFloat(index) * 0.4))
        }

        context.setStrokeColor(NSColor.white.withAlpha(150 / 255 * emphasis).cgColor)
        context.setLineWidth(1.2)
        context.strokeEllipse(in: ellipseRect(center: center, radiusX: radius, radiusY: radius))

        drawArc(context: context, center: center, radius: radius, startDegrees: 160 - orbitRotation, sweepDegrees: 55, color: NSColor.white.withAlpha(65 / 255 * emphasis), width: 2)
        drawArc(context: context, center: center, radius: radius, startDegrees: 340 - orbitRotation * 0.7, sweepDegrees: 40, color: NSColor(calibratedRed: 180 / 255, green: 220 / 255, blue: 1, alpha: 40 / 255 * emphasis), width: 1)
    }

    private func paintOrbitGuides(context: CGContext, center: CGPoint) {
        let platePulse = 0.98 + 0.02 * sin(pulse)
        let radius = defaultOrbitRadius * platePulse

        for (ratio, alpha): (CGFloat, CGFloat) in [(0.58, 18), (0.78, 28), (0.92, 38), (1.06, 22)] {
            context.setStrokeColor(NSColor.white.withAlpha(alpha / 255).cgColor)
            context.setLineWidth(0.6 + ratio * 0.4)
            context.strokeEllipse(in: ellipseRect(center: center, radiusX: radius * ratio, radiusY: radius * ratio))
        }

        let glowPulse = 0.65 + 0.35 * sin(pulse * 1.3)
        context.setStrokeColor(accentCyan.withAlpha(90 / 255 * glowPulse).cgColor)
        context.setLineWidth(2)
        context.strokeEllipse(in: ellipseRect(center: center, radiusX: radius, radiusY: radius))
        context.setStrokeColor(NSColor.white.withAlpha(50 / 255 * glowPulse).cgColor)
        context.setLineWidth(0.8)
        context.strokeEllipse(in: ellipseRect(center: center, radiusX: radius * 0.98, radiusY: radius * 0.98))

        for segment in 0..<16 where segment.isMultiple(of: 2) {
            drawArc(
                context: context,
                center: center,
                radius: radius,
                startDegrees: CGFloat(segment) * 22.5 - orbitRotation,
                sweepDegrees: -16,
                color: slotAccents[segment % slotAccents.count].withAlpha(55 / 255),
                width: 1.8
            )
        }

        for tick in 0..<72 {
            let angle = degreesToRadians(CGFloat(tick) * 5 + orbitRotation)
            let major = tick.isMultiple(of: 6)
            let inner = radius * (major ? 1.02 : 1.01)
            let outer = radius * (major ? 1.09 : 1.045)
            let color = major ? accentCyan.withAlpha(90 / 255) : NSColor.white.withAlpha(35 / 255)
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(major ? 1.6 : 0.5)
            context.move(to: CGPoint(x: center.x + inner * cos(angle), y: center.y + inner * sin(angle)))
            context.addLine(to: CGPoint(x: center.x + outer * cos(angle), y: center.y + outer * sin(angle)))
            context.strokePath()
        }

        for index in items.indices {
            let position = geometry.slotPosition(index: index)
            let hovered = index == hoverIndex
            let accent = slotAccents[index % slotAccents.count]
            context.setStrokeColor(NSColor.white.withAlpha(hovered ? 45 / 255 : 22 / 255).cgColor)
            context.setLineWidth(hovered ? 1 : 0.65)
            context.move(to: center)
            context.addLine(to: position)
            context.strokePath()

            let angle = (2 * CGFloat.pi * CGFloat(index) / CGFloat(items.count)) - (CGFloat.pi / 2)
            let marker = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            drawRadialGradient(
                context: context,
                center: marker,
                radius: hovered ? 9.9 : 6.3,
                colors: [
                    NSColor.white.withAlpha(hovered ? 200 / 255 : 100 / 255),
                    accent.withAlpha(hovered ? 120 / 255 : 50 / 255),
                    accent.withAlpha(0)
                ],
                locations: [0, 0.5, 1]
            )
        }

        drawRadialGradient(
            context: context,
            center: center,
            radius: defaultOrbitRadius * 0.21,
            colors: [
                NSColor.white.withAlpha(50 / 255),
                accentCyan.withAlpha(30 / 255),
                NSColor.white.withAlpha(0)
            ],
            locations: [0, 0.5, 1]
        )
        context.setStrokeColor(NSColor.white.withAlpha(55 / 255).cgColor)
        context.setLineWidth(0.9)
        let cross = defaultOrbitRadius * 0.119
        context.move(to: CGPoint(x: center.x - cross, y: center.y))
        context.addLine(to: CGPoint(x: center.x + cross, y: center.y))
        context.move(to: CGPoint(x: center.x, y: center.y - cross))
        context.addLine(to: CGPoint(x: center.x, y: center.y + cross))
        context.strokePath()
    }

    private func paintCenterHub(context: CGContext, center: CGPoint) {
        let hubPulse = 0.92 + 0.08 * sin(pulse * 2)
        if hoverIndex == nil {
            paintIconPedestal(context: context, center: center, radius: 22 * hubPulse, accent: accentCyan, glow: 0.55, hovered: false)
            return
        }

        guard let hoverIndex else { return }
        let item = items[hoverIndex]
        let accent = slotAccents[hoverIndex % slotAccents.count]
        let hubRadius = centerHubSize * 0.48 * hubPulse
        paintIconPedestal(context: context, center: center, radius: hubRadius + 8, accent: accent, glow: 1, hovered: true)
        for index in stride(from: 5, through: 1, by: -1) {
            context.setFillColor(accent.withAlpha(CGFloat(30 / index) / 255).cgColor)
            context.fillEllipse(in: ellipseRect(center: center, radiusX: hubRadius + CGFloat(index) * 5, radiusY: hubRadius + CGFloat(index) * 5))
        }
        paintIconTile(context: context, center: center, icon: item.icon, size: centerHubSize * hubPulse, hovered: true, accent: accent, glow: 1)
        drawLabel(text: item.appName, rect: CGRect(x: center.x - 95, y: center.y + centerHubSize * 0.52 + 14, width: 190, height: 24), prominent: true)
    }

    private func paintSlot(context: CGContext, item: LauncherItem, position: CGPoint, glow: CGFloat, hovered: Bool, index: Int) {
        let accent = slotAccents[index % slotAccents.count]
        paintIconTile(context: context, center: position, icon: item.icon, size: iconTileSize + (glow - 0.4) * 12, hovered: hovered, accent: accent, glow: glow)
        drawLabel(text: item.appName, rect: CGRect(x: position.x - 54, y: position.y + iconTileSize * 0.55 + 6, width: 108, height: 18), prominent: hovered)
    }

    private func paintIconTile(context: CGContext, center: CGPoint, icon: NSImage, size: CGFloat, hovered: Bool, accent: NSColor, glow: CGFloat) {
        let scale = 1 + (glow - 0.4) * 0.22
        let side = size * scale
        let pedestalRadius = side * 0.52
        paintIconPedestal(context: context, center: center, radius: pedestalRadius, accent: accent, glow: glow, hovered: hovered)

        if hovered {
            for index in stride(from: 4, through: 1, by: -1) {
                context.setFillColor(accent.withAlpha(CGFloat(25 / index) / 255).cgColor)
                context.fillEllipse(in: ellipseRect(center: center, radiusX: pedestalRadius + CGFloat(index) * 4, radiusY: pedestalRadius + CGFloat(index) * 4))
            }
        }

        let rect = CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
        icon.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
    }

    private func paintIconPedestal(context: CGContext, center: CGPoint, radius: CGFloat, accent: NSColor, glow: CGFloat, hovered: Bool) {
        let pedestalRadius = radius * (1.05 + (glow - 0.4) * 0.12)
        for index in stride(from: 3, through: 1, by: -1) {
            context.setStrokeColor(accent.withAlpha(CGFloat(8 + index * 6) / 255 * glow).cgColor)
            context.setLineWidth(1.2 + (glow - 0.4))
            context.strokeEllipse(in: ellipseRect(center: center, radiusX: pedestalRadius + CGFloat(index) * 2.5, radiusY: pedestalRadius + CGFloat(index) * 2.5))
        }

        drawRadialGradient(
            context: context,
            center: center,
            radius: pedestalRadius,
            colors: [
                NSColor.white.withAlpha((hovered ? 45 / 255 : 28 / 255) * glow),
                accent.withAlpha(18 / 255 * glow),
                NSColor.white.withAlpha(0)
            ],
            locations: [0, 0.7, 1]
        )

        context.setStrokeColor(NSColor.white.withAlpha(130 / 255 * glow).cgColor)
        context.setLineWidth(hovered ? 1.3 : 0.9)
        context.strokeEllipse(in: ellipseRect(center: center, radiusX: pedestalRadius, radiusY: pedestalRadius))
    }

    private func drawLabel(text: String, rect: CGRect, prominent: Bool) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let font = NSFont.systemFont(ofSize: prominent ? 11 : 9, weight: prominent ? .medium : .regular)
        let shadowAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black.withAlpha(120 / 255),
            .paragraphStyle: paragraph
        ]
        text.draw(in: rect.offsetBy(dx: 0, dy: 1), withAttributes: shadowAttributes)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: prominent ? NSColor.white.withAlpha(245 / 255) : NSColor(calibratedRed: 230 / 255, green: 240 / 255, blue: 1, alpha: 210 / 255),
            .paragraphStyle: paragraph
        ]
        text.draw(in: rect, withAttributes: attributes)
    }
}

private func ellipseRect(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat) -> CGRect {
    CGRect(x: center.x - radiusX, y: center.y - radiusY, width: radiusX * 2, height: radiusY * 2)
}

private func drawRadialGradient(context: CGContext, center: CGPoint, radius: CGFloat, colors: [NSColor], locations: [CGFloat]) {
    guard let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors.map(\.cgColor) as CFArray,
        locations: locations
    ) else { return }
    context.saveGState()
    context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [.drawsAfterEndLocation])
    context.restoreGState()
}

private func drawLinearGradient(context: CGContext, rect: CGRect, start: CGPoint, end: CGPoint, colors: [NSColor], locations: [CGFloat]) {
    guard let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors.map(\.cgColor) as CFArray,
        locations: locations
    ) else { return }
    context.saveGState()
    context.addEllipse(in: rect)
    context.clip()
    context.drawLinearGradient(gradient, start: start, end: end, options: [])
    context.restoreGState()
}

private func drawArc(context: CGContext, center: CGPoint, radius: CGFloat, startDegrees: CGFloat, sweepDegrees: CGFloat, color: NSColor, width: CGFloat) {
    context.setStrokeColor(color.cgColor)
    context.setLineWidth(width)
    let start = degreesToRadians(startDegrees)
    let end = degreesToRadians(startDegrees + sweepDegrees)
    context.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: sweepDegrees < 0)
    context.strokePath()
}

private func degreesToRadians(_ degrees: CGFloat) -> CGFloat {
    degrees * .pi / 180
}
