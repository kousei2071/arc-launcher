import AppKit

let accentCyan = NSColor(calibratedRed: 80 / 255, green: 220 / 255, blue: 1, alpha: 1)
let accentViolet = NSColor(calibratedRed: 180 / 255, green: 100 / 255, blue: 1, alpha: 1)
let accentPink = NSColor(calibratedRed: 1, green: 120 / 255, blue: 200 / 255, alpha: 1)

let slotAccents: [NSColor] = [
    accentCyan,
    NSColor(calibratedRed: 100 / 255, green: 180 / 255, blue: 1, alpha: 1),
    accentViolet,
    NSColor(calibratedRed: 200 / 255, green: 140 / 255, blue: 1, alpha: 1),
    accentPink,
    NSColor(calibratedRed: 120 / 255, green: 1, blue: 220 / 255, alpha: 1),
    NSColor(calibratedRed: 1, green: 200 / 255, blue: 120 / 255, alpha: 1),
    NSColor(calibratedRed: 160 / 255, green: 220 / 255, blue: 1, alpha: 1)
]

extension NSColor {
    func withAlpha(_ alpha: CGFloat) -> NSColor {
        withAlphaComponent(alpha)
    }
}
