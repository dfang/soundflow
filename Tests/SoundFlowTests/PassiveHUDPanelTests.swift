import AppKit
import XCTest
@testable import SoundFlow

final class PassiveHUDPanelTests: XCTestCase {
    func testPanelCannotActivateOrBecomeKey() {
        let panel = PassiveHUDPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
    }
}
