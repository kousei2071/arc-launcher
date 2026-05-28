import XCTest
@testable import CyberLauncher

final class LauncherGeometryTests: XCTestCase {
    func testTopSlotIsFirstItem() {
        let geometry = LauncherGeometry(itemCount: 8)
        let point = geometry.slotPosition(index: 0)

        XCTAssertEqual(geometry.index(at: point, glows: Array(repeating: 0.4, count: 8), nativeUI: true), 0)
    }

    func testCenterDeadZoneDoesNotSelectItem() {
        let geometry = LauncherGeometry(itemCount: 8)

        XCTAssertNil(geometry.index(at: geometry.center, glows: Array(repeating: 0.4, count: 8), nativeUI: true))
    }

    func testSectorHitSelectsNearestSlot() {
        let geometry = LauncherGeometry(itemCount: 8)
        let point = CGPoint(x: geometry.center.x + defaultOrbitRadius, y: geometry.center.y)

        XCTAssertEqual(geometry.index(at: point, glows: Array(repeating: 0.4, count: 8), nativeUI: false), 2)
    }
}
