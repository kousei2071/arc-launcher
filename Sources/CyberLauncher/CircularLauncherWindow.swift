import AppKit

final class CircularLauncherWindow: NSWindow {
    private let launcherView: LauncherView
    private var shown = false
    private let macGlassEnabled: Bool

    init(items: [LauncherItem] = defaultItems()) {
        self.launcherView = LauncherView(items: items)
        self.macGlassEnabled = ProcessInfo.processInfo.environment["CYBER_LAUNCHER_NATIVE_GLASS", default: "1"] == "1" && nativeGlassAvailable()
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: windowSize, height: windowSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        title = "Cyber Launcher"
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isReleasedWhenClosed = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        configureTransparentWindow(self)

        contentView = NSView(frame: NSRect(x: 0, y: 0, width: windowSize, height: windowSize))
        if let contentView {
            applyCircularMask(to: contentView)
        }
        launcherView.launcherWindow = self
        launcherView.frame = contentView?.bounds ?? .zero
        launcherView.autoresizingMask = [.width, .height]
        contentView?.addSubview(launcherView)
    }

    func toggleVisibility() {
        shown ? dismiss() : present()
    }

    func dismiss() {
        orderOut(nil)
        shown = false
    }

    func present() {
        moveToCursor()
        if macGlassEnabled, launcherView.glassMode == .none, let contentView {
            launcherView.glassMode = installGlass(in: self, contentView: contentView)
        }
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
        makeFirstResponder(launcherView)
        shown = true
        launcherView.needsDisplay = true
    }

    private func moveToCursor() {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main else {
            return
        }
        let mouse = NSEvent.mouseLocation
        let visible = screen.visibleFrame
        var x = mouse.x - frame.width / 2
        var y = mouse.y - frame.height / 2
        x = max(visible.minX, min(x, visible.maxX - frame.width))
        y = max(visible.minY, min(y, visible.maxY - frame.height))
        setFrameOrigin(CGPoint(x: x, y: y))
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
