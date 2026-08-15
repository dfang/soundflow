import Foundation
import XCTest
@testable import SoundFlow

final class OptimizationTests: XCTestCase {
    func testMergedProgrammingDictionaryTerms() {
        let text1 = "用fastapi和nextjs开发应用"
        let result1 = TextDictionaries.applyDictionaries(to: text1)
        XCTAssertEqual(result1, "用FastAPI和Next.js开发应用")

        let text2 = "跑一下docker compose拉取最新镜像"
        let result2 = TextDictionaries.applyDictionaries(to: text2)
        XCTAssertEqual(result2, "跑一下docker-compose拉取最新镜像")

        let text3 = "帮我切瑞皮克这个commit"
        let result3 = TextDictionaries.applyDictionaries(to: text3)
        XCTAssertEqual(result3, "帮我cherry-pick这个commit")

        let text4 = "切换到新的work tree目录"
        let result4 = TextDictionaries.applyDictionaries(to: text4)
        XCTAssertEqual(result4, "切换到新的worktree目录")

        let text5 = "用沃克崔创建分支"
        let result5 = TextDictionaries.applyDictionaries(to: text5)
        XCTAssertEqual(result5, "用worktree创建分支")

        let text6 = "现在流行歪伯coding和mcp工具调用"
        let result6 = TextDictionaries.applyDictionaries(to: text6)
        XCTAssertEqual(result6, "现在流行vibe coding和MCP工具调用")

        let text7 = "切到新的白兰奇并切客奥特"
        let result7 = TextDictionaries.applyDictionaries(to: text7)
        XCTAssertEqual(result7, "切到新的branch并checkout")

        let text8 = "把改动先死太许一下然后抹机 妹恩分支"
        let result8 = TextDictionaries.applyDictionaries(to: text8)
        XCTAssertEqual(result8, "把改动先stash一下然后merge main分支")

        let text9 = "T交PR并合并到主分制"
        let result9 = TextDictionaries.applyDictionaries(to: text9)
        XCTAssertEqual(result9, "提交PR并合并到主分支")
    }

    func testChineseHomophoneDictionaryReplacement() {
        let text1 = "把代码可密特一下"
        let result1 = TextDictionaries.applyDictionaries(to: text1)
        XCTAssertEqual(result1, "把代码commit一下")

        let text2 = "帮我review这个批二"
        let result2 = TextDictionaries.applyDictionaries(to: text2)
        XCTAssertEqual(result2, "帮我review这个PR")

        let text3 = "用热杯子合并分支"
        let result3 = TextDictionaries.applyDictionaries(to: text3)
        XCTAssertEqual(result3, "用rebase合并分支")
    }

    func testDictionaryDoesNotRewriteOrdinaryChineseHomophones() {
        let text = "我是摩羯座，会把这段话默记下来，也喜欢泰格·伍兹"

        let result = TextDictionaries.applyDictionaries(to: text)

        XCTAssertEqual(result, text)
    }

    func testSmartPostProcessorKeepsShortDeveloperTextOnFastPath() async {
        let smart = SmartPostProcessor(wrapping: SentinelPostProcessor())

        let devCommands = [
            "git push",
            "review pr",
            "写个get接口",
            "加个router",
            "重构handler",
            "async await",
        ]

        for cmd in devCommands {
            let result = await smart.process(cmd)
            XCTAssertEqual(result, cmd, "Command \(cmd) should stay on the fast path")
        }
    }

    func testSmartPostProcessorPreservesExistingPeriodWhenProcessing() async {
        let smart = SmartPostProcessor(wrapping: EchoPostProcessor())

        let result = await smart.process("嗯，已经完成。")

        XCTAssertEqual(result, "嗯，已经完成。")
    }

    func testSherpaSenseVoiceInitialization() throws {
        guard (try? ModelPathResolver.resolveSenseVoiceSmallPaths()) != nil,
              (try? ModelPathResolver.resolveVADModelPaths()) != nil else
        {
            throw XCTSkip("SenseVoice or VAD model is not installed")
        }
        let service = SherpaOnnxSenseVoiceTranscriptionService(model: ModelCatalog.defaultASRModel)
        XCTAssertNoThrow(try service.start())
        service.cancel()
    }
}

private struct SentinelPostProcessor: TextPostProcessing {
    let displayName = "Sentinel"
    let model = ModelCatalog.defaultPostProcessorModel

    func process(_: String) async -> String {
        "processed"
    }

    func processStream(rawText _: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield("processed")
            continuation.finish()
        }
    }
}

private struct EchoPostProcessor: TextPostProcessing {
    let displayName = "Echo"
    let model = ModelCatalog.defaultPostProcessorModel

    func process(_ text: String) async -> String {
        text
    }

    func processStream(rawText: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(rawText)
            continuation.finish()
        }
    }
}
