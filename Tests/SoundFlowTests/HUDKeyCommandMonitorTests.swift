import Carbon
@testable import SoundFlow
import XCTest

final class HUDKeyCommandMonitorTests: XCTestCase {
    func testEscapeMapsToCancel() {
        XCTAssertEqual(
            HUDKeyCommandRouter.command(for: CGKeyCode(kVK_Escape)),
            .cancel
        )
    }

    func testReturnKeysMapToConfirm() {
        XCTAssertEqual(HUDKeyCommandRouter.command(for: CGKeyCode(kVK_Return)), .confirm)
        XCTAssertEqual(HUDKeyCommandRouter.command(for: CGKeyCode(kVK_ANSI_KeypadEnter)), .confirm)
    }

    func testOrdinaryLetterPassesThrough() {
        XCTAssertNil(HUDKeyCommandRouter.command(for: CGKeyCode(kVK_ANSI_A)))
    }
}
