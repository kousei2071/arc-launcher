import AppKit
import QuartzCore

private struct Sparkle {
    let angle: CGFloat
    let radius: CGFloat
    let speed: CGFloat
    let size: CGFloat
    let alpha: CGFloat
}

final class LauncherView: NSView {
    private let items: [LauncherItem]
    private var hoverIndex: Int?
    private var phase: CGFloat = 0
    private var slotGlow: [CGFloat]
    private var slotGlowTarget: [CGFloat]
    private var timer: Timer?
    private var slotViews: [GlassSlotView] = []
    private let centerView = GlassCenterView()
    private let sparkles: [Sparkle]
    var glassMode: GlassMode = .none
    weak var launcherWindow: CircularLauncherWindow?

    init(items: [LauncherItem]) {
        self.items = items
        self.slotGlow = Array(repeating: 0, count: items.count)
        self.slotGlowTarget = Array(repeating: 0, count: items.count)
        var generatedSparkles: [Sparkle] = []
        for index in 0..<72 {
            let angle = CGFloat(index) * CGFloat.pi * 2 / 72
            let radius = CGFloat(74 + (index * 37) % 150)
            let speed = 0.45 + CGFloat((index * 11) % 40) / 100
            let size = 1.4 + CGFloat((index * 7) % 24) / 10
            let alpha = 0.18 + CGFloat((index * 13) % 35) / 100
            generatedSparkles.append(Sparkle(angle: angle, radius: radius, speed: speed, size: size, alpha: alpha))
        }
        self.sparkles = generatedSparkles
        super.init(frame: NSRect(x: 0, y: 0, width: windowSize, height: windowSize))

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        setUpGlassControls()
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self
        ))
        timer = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { [weak self] _ in
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

    override func layout() {
        super.layout()
        layoutGlassControls(animated: false)
    }

    private func setUpGlassControls() {
        centerView.alphaValue = 0.92
        addSubview(centerView)

        slotViews = items.map { item in
            let view = GlassSlotView(item: item)
            view.alphaValue = 0.96
            addSubview(view)
            return view
        }
        layoutGlassControls(animated: false)
        updateGlassControls()
    }

    private func tickAnimation() {
        phase = (phase + 0.018).truncatingRemainder(dividingBy: .pi * 2)
        for index in slotGlow.indices {
            let current = slotGlow[index]
            let target = slotGlowTarget[index]
            slotGlow[index] = current + (target - current) * 0.18
        }
        layoutGlassControls(animated: true)
        updateGlassControls()
        needsDisplay = true
    }

    private func layoutGlassControls(animated: Bool) {
        guard !bounds.isEmpty else { return }

        let center = geometry.center
        let centerSide = hoverIndex == nil ? CGFloat(72) : CGFloat(104)
        setFrame(
            CGRect(x: center.x - centerSide / 2, y: center.y - centerSide / 2, width: centerSide, height: centerSide),
            on: centerView,
            animated: animated
        )

        for (index, view) in slotViews.enumerated() {
            let position = geometry.slotPosition(index: index)
            let float = sin(phase * 1.8 + CGFloat(index) * 0.7) * 4
            let glow = slotGlow[index]
            let side = CGFloat(74) + glow * 20
            setFrame(
                CGRect(
                    x: position.x - side / 2,
                    y: position.y - side / 2 + float,
                    width: side,
                    height: side
                ),
                on: view,
                animated: animated
            )
        }
    }

    private func setFrame(_ frame: CGRect, on view: NSView, animated: Bool) {
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                view.animator().frame = frame
            }
        } else {
            view.frame = frame
        }
    }

    private func updateGlassControls() {
        for (index, view) in slotViews.enumerated() {
            let hovered = index == hoverIndex
            view.setHoverAmount(slotGlow[index], selected: hovered)
        }

        if let hoverIndex {
            centerView.configure(item: items[hoverIndex], accent: slotAccents[hoverIndex % slotAccents.count], phase: phase)
        } else {
            centerView.configureIdle(phase: phase)
        }
    }

    private func index(at point: CGPoint) -> Int? {
        geometry.index(at: point, glows: slotGlow.map { 0.4 + $0 * 0.6 }, nativeUI: nativeUI)
    }

    private func setHover(index: Int?) {
        guard index != hoverIndex else { return }
        for slot in slotGlowTarget.indices {
            slotGlowTarget[slot] = slot == index ? 1 : 0
        }
        hoverIndex = index
        updateGlassControls()
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
        drawAmbientField(context: context, center: center)
        drawGlassRings(context: context, center: center)
        drawSparkles(context: context, center: center)
        drawPointerBeams(context: context, center: center)
    }

    private func drawAmbientField(context: CGContext, center: CGPoint) {
        drawRadialGradient(
            context: context,
            center: center,
            radius: 250,
            colors: [
                accentCyan.withAlpha(0.10),
                accentViolet.withAlpha(0.06),
                NSColor.clear
            ],
            locations: [0, 0.48, 1]
        )
    }

    private func drawGlassRings(context: CGContext, center: CGPoint) {
        for ring in 0..<5 {
            let ringPhase = phase + CGFloat(ring) * 0.72
            let radius = defaultOrbitRadius * (0.46 + CGFloat(ring) * 0.15) + sin(ringPhase * 1.6) * 5
            let alpha = 0.10 + CGFloat(ring) * 0.025
            context.setStrokeColor(NSColor.white.withAlpha(alpha).cgColor)
            context.setLineWidth(0.8 + CGFloat(ring) * 0.35)
            context.strokeEllipse(in: ellipseRect(center: center, radiusX: radius, radiusY: radius))

            drawArc(
                context: context,
                center: center,
                radius: radius + 8,
                startDegrees: radiansToDegrees(ringPhase) * (ring.isMultiple(of: 2) ? 1 : -1),
                sweepDegrees: 54 + CGFloat(ring) * 10,
                color: slotAccents[ring % slotAccents.count].withAlpha(0.26),
                width: 2.4
            )
        }
    }

    private func drawSparkles(context: CGContext, center: CGPoint) {
        for sparkle in sparkles {
            let angle = sparkle.angle + phase * sparkle.speed
            let wobble = sin(phase * 2.2 + sparkle.angle * 3) * 10
            let point = CGPoint(
                x: center.x + (sparkle.radius + wobble) * cos(angle),
                y: center.y + (sparkle.radius + wobble) * sin(angle)
            )
            let pulse = 0.45 + 0.55 * sin(phase * 3.4 + sparkle.angle * 5)
            context.setFillColor(NSColor.white.withAlpha(sparkle.alpha * pulse).cgColor)
            context.fillEllipse(in: CGRect(x: point.x - sparkle.size / 2, y: point.y - sparkle.size / 2, width: sparkle.size, height: sparkle.size))
        }
    }

    private func drawPointerBeams(context: CGContext, center: CGPoint) {
        guard let hoverIndex else { return }
        let target = geometry.slotPosition(index: hoverIndex)
        let accent = slotAccents[hoverIndex % slotAccents.count]
        for offset in 0..<4 {
            context.setStrokeColor(accent.withAlpha(0.15 - CGFloat(offset) * 0.025).cgColor)
            context.setLineWidth(6 - CGFloat(offset))
            context.move(to: center)
            context.addLine(to: target)
            context.strokePath()
        }
    }
}

private final class GlassSlotView: NSView {
    private let glassView: NSView
    private let iconView = NSImageView()
    private let labelField = NSTextField(labelWithString: "")
    private let accent: NSColor

    init(item: LauncherItem) {
        self.glassView = makeGlassSurface()
        self.accent = slotAccents[abs(item.appName.hashValue) % slotAccents.count]
        super.init(frame: .zero)
        wantsLayer = true
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOffset = CGSize(width: 0, height: -6)
        layer?.shadowOpacity = 0.28
        layer?.shadowRadius = 18

        glassView.frame = bounds
        glassView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(glassView)

        iconView.image = item.icon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.frame = CGRect(x: 15, y: 12, width: 44, height: 44)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        labelField.stringValue = item.appName
        labelField.alignment = .center
        labelField.font = .systemFont(ofSize: 9, weight: .semibold)
        labelField.textColor = .white.withAlphaComponent(0.88)
        labelField.frame = CGRect(x: -18, y: 58, width: 110, height: 18)
        labelField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(labelField)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        setFrameIfChanged(bounds, on: glassView)
        applyCircularMask(to: glassView)
        let iconSide = min(bounds.width, bounds.height) * 0.58
        setFrameIfChanged(CGRect(x: (bounds.width - iconSide) / 2, y: (bounds.height - iconSide) / 2 - 2, width: iconSide, height: iconSide), on: iconView)
        setFrameIfChanged(CGRect(x: -22, y: bounds.height - 4, width: bounds.width + 44, height: 18), on: labelField)
    }

    func setHoverAmount(_ amount: CGFloat, selected: Bool) {
        layer?.shadowOpacity = Float(0.24 + amount * 0.32)
        layer?.shadowRadius = 14 + amount * 18
        let scale = 1 + amount * 0.12
        layer?.transform = CATransform3DMakeScale(scale, scale, 1)
        iconView.alphaValue = 0.84 + amount * 0.16
        labelField.alphaValue = selected ? 1 : 0.72
        labelField.textColor = selected ? .white : .white.withAlphaComponent(0.72)
        wantsLayer = true
        layer?.borderColor = accent.withAlpha(0.20 + amount * 0.48).cgColor
        layer?.borderWidth = 0.7 + amount * 1.2
        layer?.cornerRadius = bounds.width / 2
    }
}

private final class GlassCenterView: NSView {
    private let glassView = makeGlassSurface()
    private let iconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOffset = CGSize(width: 0, height: -8)
        layer?.shadowOpacity = 0.35
        layer?.shadowRadius = 22

        glassView.frame = bounds
        glassView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(glassView)

        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        titleField.alignment = .center
        titleField.font = .systemFont(ofSize: 12, weight: .bold)
        titleField.textColor = .white
        titleField.alphaValue = 0
        titleField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleField)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        setFrameIfChanged(bounds, on: glassView)
        applyCircularMask(to: glassView)
        let iconSide = min(bounds.width, bounds.height) * 0.58
        setFrameIfChanged(CGRect(x: (bounds.width - iconSide) / 2, y: (bounds.height - iconSide) / 2 - 6, width: iconSide, height: iconSide), on: iconView)
        setFrameIfChanged(CGRect(x: -50, y: bounds.height + 8, width: bounds.width + 100, height: 20), on: titleField)
        layer?.cornerRadius = bounds.width / 2
    }

    func configure(item: LauncherItem, accent: NSColor, phase: CGFloat) {
        iconView.image = item.icon
        titleField.stringValue = item.appName
        titleField.alphaValue = 1
        layer?.borderColor = accent.withAlpha(0.58 + 0.20 * sin(phase * 4)).cgColor
        layer?.borderWidth = 1.7
        layer?.transform = CATransform3DMakeScale(1.04 + 0.03 * sin(phase * 5), 1.04 + 0.03 * sin(phase * 5), 1)
    }

    func configureIdle(phase: CGFloat) {
        iconView.image = NSImage(systemSymbolName: "sparkle.magnifyingglass", accessibilityDescription: nil)
        titleField.alphaValue = 0
        layer?.borderColor = NSColor.white.withAlphaComponent(0.22 + 0.12 * sin(phase * 3)).cgColor
        layer?.borderWidth = 1.1
        layer?.transform = CATransform3DMakeScale(1 + 0.025 * sin(phase * 4), 1 + 0.025 * sin(phase * 4), 1)
    }
}

@MainActor
private func makeGlassSurface() -> NSView {
    if #available(macOS 26.0, *) {
        let view = NSGlassEffectView(frame: .zero)
        view.style = .regular
        return view
    }

    let view = NSVisualEffectView(frame: .zero)
    view.material = .hudWindow
    view.blendingMode = .behindWindow
    view.state = .active
    return view
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
    context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [.drawsAfterEndLocation])
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

private func radiansToDegrees(_ radians: CGFloat) -> CGFloat {
    radians * 180 / .pi
}

@MainActor
private func setFrameIfChanged(_ frame: CGRect, on view: NSView) {
    if !view.frame.equalTo(frame) {
        view.frame = frame
    }
}
