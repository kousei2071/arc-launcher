import CoreGraphics
import Foundation

let windowSize: CGFloat = 540
let defaultOrbitRadius: CGFloat = 178
let iconTileSize: CGFloat = 58
let centerHubSize: CGFloat = 72
let centerDeadZone: CGFloat = 30
let slotHitRadius: CGFloat = 44

struct LauncherGeometry {
    let itemCount: Int
    let center: CGPoint
    let orbitRadius: CGFloat

    init(itemCount: Int, size: CGSize = CGSize(width: windowSize, height: windowSize), orbitRadius: CGFloat = defaultOrbitRadius) {
        self.itemCount = itemCount
        self.center = CGPoint(x: size.width / 2, y: size.height / 2)
        self.orbitRadius = orbitRadius
    }

    func slotPosition(index: Int) -> CGPoint {
        guard itemCount > 0 else { return center }
        let angle = (2 * CGFloat.pi * CGFloat(index) / CGFloat(itemCount)) - (CGFloat.pi / 2)
        return CGPoint(
            x: center.x + orbitRadius * cos(angle),
            y: center.y + orbitRadius * sin(angle)
        )
    }

    func index(at point: CGPoint, glows: [CGFloat], nativeUI: Bool) -> Int? {
        guard itemCount > 0 else { return nil }

        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = hypot(dx, dy)
        if distance < centerDeadZone {
            return nil
        }

        var bestIndex: Int?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for index in 0..<itemCount {
            let slot = slotPosition(index: index)
            let slotDistance = hypot(point.x - slot.x, point.y - slot.y)
            let glow = index < glows.count ? glows[index] : 0.4
            let hitRadius = nativeUI ? slotHitRadius + (glow - 0.4) * 8 : 36 + (glow - 0.4) * 12
            if slotDistance < hitRadius, slotDistance < bestDistance {
                bestDistance = slotDistance
                bestIndex = index
            }
        }
        if let bestIndex {
            return bestIndex
        }

        if distance < orbitRadius * 0.48 || distance > orbitRadius * 1.38 {
            return nil
        }

        let mouseAngle = atan2(dy, dx)
        var bestAngleDiff = CGFloat.greatestFiniteMagnitude
        for index in 0..<itemCount {
            let slotAngle = (2 * CGFloat.pi * CGFloat(index) / CGFloat(itemCount)) - (CGFloat.pi / 2)
            let diff = abs(atan2(sin(mouseAngle - slotAngle), cos(mouseAngle - slotAngle)))
            if diff < bestAngleDiff {
                bestAngleDiff = diff
                bestIndex = index
            }
        }

        return bestAngleDiff < (CGFloat.pi / CGFloat(itemCount)) * 1.08 ? bestIndex : nil
    }
}
