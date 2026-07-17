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

    func testStreamFailureAfterContentDiscardsPartialOutput() async {
        URLProtocol.registerClass(PartialFailureURLProtocol.self)
        defer { URLProtocol.unregisterClass(PartialFailureURLProtocol.self) }
        UserDefaults.standard.set("test-api-key", forKey: apiKeyName)
        let processor = DeepseekPostProcessor(model: ModelCatalog.defaultPostProcessorModel)

        var result = ""
        do {
            for try await token in processor.processStream(rawText: "  preserve this input  ") {
                result += token
            }
        } catch {
            XCTFail("DeepSeek fallback should finish without throwing: \(error)")
        }

        XCTAssertEqual(result, "preserve this input")
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

private final class PartialFailureURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "api.deepseek.com"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/event-stream"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(
            self,
            didLoad: Data("data: {\"choices\":[{\"delta\":{\"content\":\"partial output\"}}]}\n\n".utf8)
        )
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { [self] in
            client?.urlProtocol(
                self,
                didFailWithError: NSError(domain: "DeepseekPostProcessorTests", code: 1)
            )
        }
    }

    override func stopLoading() {}
}
