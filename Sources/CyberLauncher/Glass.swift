import AppKit

enum GlassMode: String {
    case liquid
    case vibrancy
    case none
}

func nativeGlassAvailable() -> Bool {
    NSClassFromString("NSVisualEffectView") != nil || NSClassFromString("NSGlassEffectView") != nil
}

func liquidGlassAvailable() -> Bool {
    NSClassFromString("NSGlassEffectView") != nil
}

@MainActor
func configureTransparentWindow(_ window: NSWindow) {
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = true
    window.titlebarAppearsTransparent = true
}

@MainActor
func applyCircularMask(to view: NSView) {
    view.wantsLayer = true
    view.layer?.backgroundColor = NSColor.clear.cgColor
    view.layer?.cornerRadius = min(view.bounds.width, view.bounds.height) / 2
    view.layer?.masksToBounds = true
}

@MainActor
func installGlass(in window: NSWindow, contentView: NSView) -> GlassMode {
    guard nativeGlassAvailable() else {
        return .none
    }

    contentView.subviews
        .filter { $0 is NSVisualEffectView || String(describing: type(of: $0)).contains("GlassEffect") }
        .forEach { $0.removeFromSuperview() }

    if ProcessInfo.processInfo.environment["CYBER_LAUNCHER_LIQUID"] == "1", liquidGlassAvailable() {
        if #available(macOS 26.0, *) {
            let glassView = NSGlassEffectView(frame: contentView.bounds)
            glassView.autoresizingMask = [.width, .height]
            glassView.style = .regular
            applyCircularMask(to: glassView)
            contentView.addSubview(glassView, positioned: .below, relativeTo: nil)
            configureTransparentWindow(window)
            return .liquid
        }
    }

    let effectView = NSVisualEffectView(frame: contentView.bounds)
    effectView.autoresizingMask = [.width, .height]
    effectView.material = .underWindowBackground
    effectView.blendingMode = .behindWindow
    effectView.state = .active
    applyCircularMask(to: effectView)
    contentView.addSubview(effectView, positioned: .below, relativeTo: nil)
    configureTransparentWindow(window)
    return .vibrancy
}
