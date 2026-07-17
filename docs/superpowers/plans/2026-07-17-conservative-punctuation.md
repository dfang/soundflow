# Conservative Punctuation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make DeepSeek post-processing preserve unpunctuated input by default and add punctuation only when it resolves clear ambiguity.

**Architecture:** Keep the existing `DictionaryPostProcessor -> SmartPostProcessor -> DeepseekPostProcessor` pipeline. Change only DeepSeek's failure fallback and system prompt: failures return trimmed input unchanged, while the prompt explicitly prohibits routine terminal punctuation.

**Tech Stack:** Swift 5.10, Swift Package Manager, XCTest, macOS 14+

## Global Constraints

- Preserve existing punctuation from ASR output.
- Add punctuation only when omission creates clear ambiguity.
- Do not automatically append `。` or `.`.
- Do not change SenseVoice, inverse text normalization, SmartPostProcessor gating, dictionary replacement, streaming preview, or text insertion.
- Add no dependencies.

---

## File Structure

- Modify `Package.swift` to add the first `SoundFlowTests` XCTest target.
- Create `Tests/SoundFlowTests/DeepseekPostProcessorTests.swift` for fallback and prompt regression coverage.
- Modify `Sources/DeepseekPostProcessor.swift` to preserve input on failure and constrain punctuation generation.

### Task 1: Preserve Input During DeepSeek Fallback

**Files:**
- Modify: `Package.swift`
- Create: `Tests/SoundFlowTests/DeepseekPostProcessorTests.swift`
- Modify: `Sources/DeepseekPostProcessor.swift:19-26,29-99,102-133`

**Interfaces:**
- Consumes: `DeepseekPostProcessor.process(_:) async -> String` and `UserDefaults.standard` key `deepseekApiKey`.
- Produces: unchanged, trimmed text from every DeepSeek failure path; a conservative DeepSeek system prompt.

- [ ] **Step 1: Add the XCTest target and failing regression tests**

Add this target after the existing executable target in `Package.swift`:

```swift
.testTarget(
    name: "SoundFlowTests",
    dependencies: ["SoundFlow"],
    path: "Tests/SoundFlowTests"
),
```

Create `Tests/SoundFlowTests/DeepseekPostProcessorTests.swift`:

```swift
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
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
swift test --filter DeepseekPostProcessorTests
```

Expected: the target builds, the existing-punctuation test passes, and the other three tests fail because current fallback adds terminal punctuation and the prompt lacks the conservative rules.

- [ ] **Step 3: Replace the punctuation-adding fallback with identity fallback**

In `Sources/DeepseekPostProcessor.swift`, replace:

```swift
private func fallback(_ text: String) async -> String {
    await MockPostProcessor(model: model).process(text)
}
```

with:

```swift
private func fallback(_ text: String) -> String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
}
```

Update the non-streaming catch from:

```swift
return await fallback(trimmed)
```

to:

```swift
return fallback(trimmed)
```

At all four streaming fallback sites, replace:

```swift
await continuation.yield(fallback(trimmed))
```

with:

```swift
continuation.yield(fallback(trimmed))
```

These sites cover missing credentials, non-2xx responses, empty streams, and thrown errors.

- [ ] **Step 4: Make the system prompt conservative about punctuation**

Replace the prompt rule:

```text
- Only fix: missing punctuation, incorrect words that are obvious ASR mistakes, capitalization
```

with:

```text
- Preserve the input's existing punctuation by default
- Add punctuation only when omitting it would create clear ambiguity
- Do not automatically add sentence-ending punctuation
- Only fix obvious ASR mistakes, capitalization, spacing, and ambiguity-resolving punctuation
```

Replace the punctuation-heavy example:

```text
Input: "今天天气真好啊我们出去玩吧"
Output: "今天天气真好啊，我们出去玩吧。"
```

with an ambiguity-only example that does not append terminal punctuation:

```text
Input: "如果你明天有空我们一起开会"
Output: "如果你明天有空，我们一起开会"
```

- [ ] **Step 5: Run the focused tests and verify GREEN**

Run:

```bash
swift test --filter DeepseekPostProcessorTests
```

Expected: `4 tests passed`, with no failures.

- [ ] **Step 6: Run project verification**

Run:

```bash
swift test
swift build
mise exec -- swiftformat --lint Sources Tests Package.swift
mise exec -- swiftlint lint --strict Sources Tests
git diff --check
```

Expected: tests and build exit 0; format and lint report no violations; `git diff --check` prints nothing.

- [ ] **Step 7: Update the knowledge graph**

Run:

```bash
graphify update .
```

Expected: AST extraction completes and updates ignored files under `graphify-out/` without errors.

- [ ] **Step 8: Commit the implementation**

```bash
git add Package.swift Sources/DeepseekPostProcessor.swift Tests/SoundFlowTests/DeepseekPostProcessorTests.swift
git commit -m "fix: avoid routine punctuation in post-processing"
```

Expected: pre-commit hooks pass and the commit contains only the test target, regression tests, and DeepSeek behavior change.
