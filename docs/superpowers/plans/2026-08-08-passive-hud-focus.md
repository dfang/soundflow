# Passive HUD Focus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the original macOS text field focused while SoundFlow's HUD is visible or clicked, while consuming only Escape and Enter as recording commands.

**Architecture:** Replace the activating/key HUD with a nonactivating, non-key `NSPanel`. Move Escape and Enter handling out of the application-local event monitor into a focused `CGEventTap` service whose pure key-code router is unit-tested; ordinary events pass through unchanged. Capture the output target when confirmation begins and skip target activation when that application is already frontmost.

**Tech Stack:** Swift 5.10, AppKit/SwiftUI, Core Graphics event taps, Carbon virtual key codes, XCTest, Swift Package Manager, graphify.

## Global Constraints

- Main platform remains macOS 14+ on Apple Silicon.
- The HUD must never call `NSApp.activate(ignoringOtherApps:)` or become key/main.
- Preview text is display-only and cannot be selected or edited.
- Escape and Return/keypad Enter are consumed only while recording; all other keys pass through.
- No new dependency is added.
- Settings/setup window activation, ASR, audio capture, post-processing, and HUD visuals remain unchanged.

## File Map

- Create `Sources/HUDKeyCommandMonitor.swift`: pure key-code routing plus the Core Graphics event-tap lifecycle.
- Create `Tests/SoundFlowTests/HUDKeyCommandMonitorTests.swift`: command routing regression tests.
- Modify `Sources/SoundFlowModel.swift`: replace the local monitor with the new recording-scoped monitor and capture the target at confirmation.
- Modify `Sources/HUDWindowController.swift`: configure and present a passive `NSPanel`.
- Modify `Sources/HUDView.swift`: remove focus-requiring preview selection and keyboard shortcuts; display degraded keyboard-control guidance.
- Create `Tests/SoundFlowTests/PassiveHUDPanelTests.swift`: verify the panel style and key/main eligibility.
- Modify `Sources/TextOutputService.swift`: short-circuit application activation when the target is already frontmost.
- Create `Tests/SoundFlowTests/TextOutputServiceTests.swift`: verify the activation decision.

---

### Task 1: Global HUD Key Command Router and Event Tap

**Files:**
- Create: `Sources/HUDKeyCommandMonitor.swift`
- Create: `Tests/SoundFlowTests/HUDKeyCommandMonitorTests.swift`

**Interfaces:**
- Produces: `enum HUDKeyCommand: Equatable { case cancel, confirm }`
- Produces: `HUDKeyCommandRouter.command(for keyCode: CGKeyCode) -> HUDKeyCommand?`
- Produces: `HUDKeyCommandMonitor.onCommand: ((HUDKeyCommand) -> Void)?`
- Produces: `HUDKeyCommandMonitor.start() -> Bool` and `HUDKeyCommandMonitor.stop()`

- [ ] **Step 1: Write failing command-routing tests**

Create `Tests/SoundFlowTests/HUDKeyCommandMonitorTests.swift`:

```swift
import Carbon
import XCTest
@testable import SoundFlow

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
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
swift test --filter HUDKeyCommandMonitorTests
```

Expected: compilation fails because `HUDKeyCommandRouter` and `HUDKeyCommand` do not exist.

- [ ] **Step 3: Implement the pure router and active event tap**

Create `Sources/HUDKeyCommandMonitor.swift` with:

```swift
import Carbon
import CoreGraphics

enum HUDKeyCommand: Equatable {
    case cancel
    case confirm
}

enum HUDKeyCommandRouter {
    static func command(for keyCode: CGKeyCode) -> HUDKeyCommand? {
        switch Int(keyCode) {
        case Int(kVK_Escape):
            return .cancel
        case Int(kVK_Return), Int(kVK_ANSI_KeypadEnter):
            return .confirm
        default:
            return nil
        }
    }
}

final class HUDKeyCommandMonitor {
    var onCommand: ((HUDKeyCommand) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask = CGEventMask(1) << CGEventType.keyDown.rawValue
        let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: Self.eventTapCallback,
            userInfo: opaqueSelf
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        runLoopSource = nil
        eventTap = nil
    }

    deinit {
        stop()
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let monitor = Unmanaged<HUDKeyCommandMonitor>.fromOpaque(userInfo).takeUnretainedValue()

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = monitor.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else { return Unmanaged.passUnretained(event) }
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        guard let command = HUDKeyCommandRouter.command(for: keyCode) else {
            return Unmanaged.passUnretained(event)
        }

        DispatchQueue.main.async {
            monitor.onCommand?(command)
        }
        return nil
    }
}
```

If the installed Swift SDK spells any imported Core Graphics callback type differently, preserve the same behavior: default (filtering) tap, return `nil` only for routed commands, return the original event otherwise, and re-enable disabled taps.

- [ ] **Step 4: Run focused tests and build to verify GREEN**

Run:

```bash
swift test --filter HUDKeyCommandMonitorTests
swift build
```

Expected: three routing tests pass and the application builds.

- [ ] **Step 5: Commit the command monitor**

```bash
git add Sources/HUDKeyCommandMonitor.swift Tests/SoundFlowTests/HUDKeyCommandMonitorTests.swift
git commit -m "feat: add global HUD key command monitor"
```

---

### Task 2: Passive HUD Window and Model Lifecycle

**Files:**
- Modify: `Sources/HUDWindowController.swift:4-95`
- Modify: `Sources/HUDView.swift:33-81`
- Modify: `Sources/SoundFlowModel.swift:34-469`
- Create: `Tests/SoundFlowTests/PassiveHUDPanelTests.swift`

**Interfaces:**
- Consumes: `HUDKeyCommandMonitor.start()`, `stop()`, and `onCommand`
- Produces: internal `PassiveHUDPanel: NSPanel`
- Produces: `SoundFlowModel.hudKeyboardCommandsAvailable: Bool`

- [ ] **Step 1: Write the failing passive-panel test**

Create `Tests/SoundFlowTests/PassiveHUDPanelTests.swift`:

```swift
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
```

- [ ] **Step 2: Run the passive-panel test and verify RED**

Run:

```bash
swift test --filter PassiveHUDPanelTests
```

Expected: compilation fails because `PassiveHUDPanel` does not exist.

- [ ] **Step 3: Make the HUD passive**

In `Sources/HUDWindowController.swift`:

- rename `FloatingPanel` to internal `PassiveHUDPanel`;
- construct it with `styleMask: [.borderless, .nonactivatingPanel]`;
- return `false` from both `canBecomeKey` and `canBecomeMain`;
- replace both `NSApp.activate(...)` and `makeKeyAndOrderFront(nil)` paths with `panel.orderFrontRegardless()`;
- retain status-bar level, space/full-screen behavior, mouse events, animation, positioning, and `orderOut(nil)`.

The resulting show path is:

```swift
func show() {
    positionPanel()
    guard !isVisible else {
        panel.orderFrontRegardless()
        return
    }

    isVisible = true
    panel.alphaValue = 0
    panel.orderFrontRegardless()

    NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.14
        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        panel.animator().alphaValue = 1
    }
}
```

- [ ] **Step 4: Remove focus-requiring HUD interactions**

In `Sources/HUDView.swift`:

- delete `.textSelection(.enabled)` from the preview;
- delete `.keyboardShortcut(.cancelAction)` and `.keyboardShortcut(.defaultAction)`;
- replace the recording helper string with `model.hudKeyboardHint`.

In `Sources/SoundFlowModel.swift`, add:

```swift
@Published private(set) var hudKeyboardCommandsAvailable = true

var hudKeyboardHint: String {
    guard phase == .recording else { return postProcessingStatus }
    return hudKeyboardCommandsAvailable
        ? "Enter confirm, Esc cancel"
        : "Use buttons or Right Ctrl; enable Accessibility for Enter/Esc"
}
```

- [ ] **Step 5: Replace the local key monitor with recording-scoped monitoring**

In `Sources/SoundFlowModel.swift`:

- replace `private var keyMonitor: Any?` with `private let hudKeyCommandMonitor = HUDKeyCommandMonitor()`;
- in initialization, set `onCommand` to dispatch `.cancel` to `cancelRecording()` and `.confirm` to `requestCommitWithFeedback()` on the main actor;
- delete `installKeyMonitor()` and its bootstrap call;
- after entering `.recording` and before/with showing the HUD, call a helper that attempts `hudKeyCommandMonitor.start()` and assigns its result to `hudKeyboardCommandsAvailable`;
- call `hudKeyCommandMonitor.stop()` at the beginning of `commitRecording()`, `cancelRecording()`, `dismissHUD()`, and `hideHUD()` so no command is consumed outside recording;
- retry `start()` on every recording rather than treating a prior permission failure as permanent.

Use this handler shape in the model initializer:

```swift
hudKeyCommandMonitor.onCommand = { [weak self] command in
    Task { @MainActor [weak self] in
        guard let self else { return }
        switch command {
        case .cancel:
            cancelRecording()
        case .confirm:
            requestCommitWithFeedback()
        }
    }
}
```

- [ ] **Step 6: Run focused and full tests**

Run:

```bash
swift test --filter PassiveHUDPanelTests
swift test
swift build
```

Expected: the panel test and all existing tests pass; the app builds without actor-isolation errors.

- [ ] **Step 7: Commit the passive HUD integration**

```bash
git add Sources/HUDWindowController.swift Sources/HUDView.swift Sources/SoundFlowModel.swift Tests/SoundFlowTests/PassiveHUDPanelTests.swift
git commit -m "fix: keep input focus while HUD is visible"
```

---

### Task 3: Preserve the Confirmation Target Without Redundant Activation

**Files:**
- Modify: `Sources/TextOutputService.swift:9-51`
- Modify: `Sources/SoundFlowModel.swift:226-267`
- Create: `Tests/SoundFlowTests/TextOutputServiceTests.swift`

**Interfaces:**
- Produces: `TextOutputService.shouldActivateTarget(targetPID: pid_t, frontmostPID: pid_t?) -> Bool`
- Consumes: existing `captureCurrentTargetApplication() -> NSRunningApplication?`

- [ ] **Step 1: Write the failing activation-policy tests**

Create `Tests/SoundFlowTests/TextOutputServiceTests.swift`:

```swift
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
```

- [ ] **Step 2: Run activation-policy tests and verify RED**

Run:

```bash
swift test --filter TextOutputServiceTests
```

Expected: compilation fails because `shouldActivateTarget` does not exist.

- [ ] **Step 3: Add the activation short-circuit**

In `Sources/TextOutputService.swift`, add:

```swift
static func shouldActivateTarget(targetPID: pid_t, frontmostPID: pid_t?) -> Bool {
    targetPID != frontmostPID
}
```

Then change `activateTargetApplication(_:)` to return immediately when the target is already frontmost:

```swift
private func activateTargetApplication(_ targetApplication: NSRunningApplication?) -> Bool {
    guard let targetApplication, targetApplication != .current else { return true }

    let targetPID = targetApplication.processIdentifier
    let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
    guard Self.shouldActivateTarget(targetPID: targetPID, frontmostPID: frontmostPID) else {
        return true
    }

    for attempt in 0 ..< activationRetryCount {
        targetApplication.unhide()
        _ = targetApplication.activate(options: [.activateAllWindows])

        if NSWorkspace.shared.frontmostApplication?.processIdentifier == targetPID {
            return true
        }

        if attempt < activationRetryCount - 1 {
            usleep(UInt32(activationRetryDelay * 1_000_000))
        }
    }

    return false
}
```

- [ ] **Step 4: Capture the target at confirmation time**

In `Sources/SoundFlowModel.swift`:

- remove `targetApplication = captureCurrentTargetApplication()` from `beginRecording()`;
- assign it immediately after the recording guard in `commitRecording()`:

```swift
private func commitRecording() {
    guard phase == .recording else { return }
    targetApplication = captureCurrentTargetApplication()
    hudKeyCommandMonitor.stop()
    cancelPendingCommit()
    // existing finalization follows
}
```

This keeps the confirmation-time target fixed during asynchronous ASR/post-processing while allowing the user to switch applications during recording.

- [ ] **Step 5: Run focused tests, full tests, and build**

Run:

```bash
swift test --filter TextOutputServiceTests
swift test
swift build
```

Expected: activation-policy tests and the full suite pass; the app builds.

- [ ] **Step 6: Commit target preservation**

```bash
git add Sources/TextOutputService.swift Sources/SoundFlowModel.swift Tests/SoundFlowTests/TextOutputServiceTests.swift
git commit -m "fix: preserve focused target during HUD commit"
```

---

### Task 4: Repository Verification and Manual Handoff

**Files:**
- Modify via formatter only if required: files changed in Tasks 1-3
- Update generated graph: `graphify-out/`

**Interfaces:**
- Consumes: all prior tasks
- Produces: a verified build and an exact manual acceptance checklist

- [ ] **Step 1: Run repository formatting and lint hooks**

Run:

```bash
swiftformat Sources/HUDKeyCommandMonitor.swift Sources/HUDWindowController.swift Sources/HUDView.swift Sources/SoundFlowModel.swift Sources/TextOutputService.swift Tests/SoundFlowTests/HUDKeyCommandMonitorTests.swift Tests/SoundFlowTests/PassiveHUDPanelTests.swift Tests/SoundFlowTests/TextOutputServiceTests.swift
swiftlint lint --strict
```

Expected: formatter completes; SwiftLint reports no errors. If formatting changes files, rerun the tests before committing those changes.

- [ ] **Step 2: Run fresh complete verification**

Run:

```bash
swift test
swift build
git diff --check
```

Expected: zero test failures, successful debug build, and no whitespace errors.

- [ ] **Step 3: Update the project knowledge graph**

Run:

```bash
graphify update .
```

Expected: the graph update completes; generated graph changes may remain dirty as allowed by `AGENTS.md`.

- [ ] **Step 4: Inspect the final diff and commit formatter-only changes if any**

Run:

```bash
git status --short
git diff --stat HEAD~3..HEAD
git diff HEAD~3..HEAD -- Sources Tests
```

If Task 4 formatting changed tracked source/test files, commit only those files:

```bash
git add Sources Tests
git commit -m "style: format passive HUD focus changes"
```

- [ ] **Step 5: Hand off manual acceptance testing**

Ask the user to install/run the built app and verify:

1. With a TextEdit/Notes text field focused, show the HUD and type ordinary letters; they continue entering the field.
2. Click HUD background, Cancel, and Confirm; the menu-bar active application name never switches to SoundFlow.
3. Escape cancels without affecting the host app.
4. Enter confirms without inserting an extra newline before the recognized text.
5. Switch to a different application during recording, then confirm; output targets the application focused at confirmation.
