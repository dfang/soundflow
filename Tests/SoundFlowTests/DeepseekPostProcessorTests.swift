import Foundation
import XCTest
@testable import SoundFlow

final class DeepseekPostProcessorTests: XCTestCase {
    private let apiKeyName = "deepseekApiKey"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: apiKeyName)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: apiKeyName)
        super.tearDown()
    }

    func testMissingAPIKeyPreservesChineseTextWithoutTerminalPunctuation() async {
        let processor = DeepseekPostProcessor(model: ModelCatalog.defaultPostProcessorModel)

        let result = await processor.process("这是需要直接输入的文本")

        XCTAssertEqual(result, "这是需要直接输入的文本")
    }

    func testMissingAPIKeyPreservesEnglishTextWithoutTerminalPunctuation() async {
        let processor = DeepseekPostProcessor(model: ModelCatalog.defaultPostProcessorModel)

        let result = await processor.process("send this to the current app")

        XCTAssertEqual(result, "send this to the current app")
    }

    func testMissingAPIKeyPreservesExistingPunctuation() async {
        let processor = DeepseekPostProcessor(model: ModelCatalog.defaultPostProcessorModel)

        let result = await processor.process("这个版本可以吗？")

        XCTAssertEqual(result, "这个版本可以吗？")
    }

    func testPromptForbidsRoutineTerminalPunctuation() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let repositoryRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repositoryRoot.appendingPathComponent("Sources/DeepseekPostProcessor.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("Add punctuation only when omitting it would create clear ambiguity"))
        XCTAssertTrue(source.contains("Do not automatically add sentence-ending punctuation"))
    }
}
