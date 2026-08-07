import XCTest
@testable import SoundFlow

final class TextOutputServiceTests: XCTestCase {
    func testAlreadyFrontmostTargetDoesNotNeedActivation() {
        XCTAssertFalse(TextOutputService.shouldActivateTarget(targetPID: 42, frontmostPID: 42))
    }

    func testDifferentFrontmostApplicationNeedsActivation() {
        XCTAssertTrue(TextOutputService.shouldActivateTarget(targetPID: 42, frontmostPID: 84))
        XCTAssertTrue(TextOutputService.shouldActivateTarget(targetPID: 42, frontmostPID: nil))
    }
}
