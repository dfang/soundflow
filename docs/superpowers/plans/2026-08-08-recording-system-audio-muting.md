# Recording System Audio Muting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Mute the current macOS output device only while SoundFlow captures microphone audio, then restore the exact prior output state on every stop and cleanup path.

**Architecture:** Add a stateful `SystemAudioSilencer` whose testable policy is separated from a Core Audio device controller. `SoundFlowModel` starts and restores the shared silencer at the microphone-capture boundary, while `AppDelegate` performs final restoration during normal application termination.

**Tech Stack:** Swift 5.10, macOS 14+, CoreAudio, AudioToolbox, AppKit, XCTest

## Global Constraints

- Keep media playback running silently; do not send play/pause commands.
- System-audio suppression is best effort and must never prevent recording.
- Restore the device and value captured at recording start; never toggle mute blindly.
- Do not add a setting, dependency, ASR change, post-processing change, or HUD change.
- Do not create commits; leave the plan, implementation, and tests uncommitted for user review.

---

### Task 1: Testable System Audio Silencer

**Files:**
- Create: `Sources/SystemAudioSilencer.swift`
- Create: `Tests/SoundFlowTests/SystemAudioSilencerTests.swift`

**Interfaces:**
- Produces: `protocol SystemAudioDeviceControlling`
- Produces: `final class SystemAudioSilencer` with `static let shared`, `init(controller:log:)`, `silence()`, and `restore()`
- Produces: `struct CoreAudioSystemAudioController: SystemAudioDeviceControlling`
- Consumes: `AppLogger.warning(_:category:)` for best-effort failure logging

- [x] **Step 1: Write failing behavior tests**

Create `SystemAudioSilencerTests.swift` with an in-memory controller and tests whose observable output is the controller's mute or volume state:

```swift
import CoreAudio
@testable import SoundFlow
import XCTest

@MainActor
final class SystemAudioSilencerTests: XCTestCase {
    func testUnmutedOutputIsMutedAndRestored() {
        let controller = FakeSystemAudioController(muted: false)
        let silencer = SystemAudioSilencer(controller: controller, log: { _ in })

        silencer.silence()
        XCTAssertTrue(controller.muted)

        silencer.restore()
        XCTAssertFalse(controller.muted)
    }

    func testAlreadyMutedOutputRemainsMutedAfterRestore() {
        let controller = FakeSystemAudioController(muted: true)
        let silencer = SystemAudioSilencer(controller: controller, log: { _ in })

        silencer.silence()
        silencer.restore()

        XCTAssertTrue(controller.muted)
    }

    func testVolumeFallbackRestoresOriginalVolume() {
        let controller = FakeSystemAudioController(
            muteSettable: false,
            volumeSettable: true,
            volume: 0.65
        )
        let silencer = SystemAudioSilencer(controller: controller, log: { _ in })

        silencer.silence()
        XCTAssertEqual(controller.volume, 0, accuracy: 0.0001)

        silencer.restore()
        XCTAssertEqual(controller.volume, 0.65, accuracy: 0.0001)
    }

    func testUnsupportedOutputIsLeftUnchanged() {
        let controller = FakeSystemAudioController(
            muteSettable: false,
            volumeSettable: false,
            muted: false,
            volume: 0.4
        )
        let silencer = SystemAudioSilencer(controller: controller, log: { _ in })

        silencer.silence()
        silencer.restore()

        XCTAssertFalse(controller.muted)
        XCTAssertEqual(controller.volume, 0.4, accuracy: 0.0001)
    }

    func testRepeatedSilenceDoesNotReplaceOriginalSnapshot() {
        let controller = FakeSystemAudioController(muted: false)
        let silencer = SystemAudioSilencer(controller: controller, log: { _ in })

        silencer.silence()
        silencer.silence()
        silencer.restore()

        XCTAssertFalse(controller.muted)
    }

    func testRepeatedRestoreDoesNotApplyAnObsoleteSnapshot() {
        let controller = FakeSystemAudioController(muted: false)
        let silencer = SystemAudioSilencer(controller: controller, log: { _ in })

        silencer.silence()
        silencer.restore()
        controller.muted = true
        silencer.restore()

        XCTAssertTrue(controller.muted)
    }

    func testFailedRestoreClearsTheSnapshot() {
        let controller = FakeSystemAudioController(muted: false)
        let silencer = SystemAudioSilencer(controller: controller, log: { _ in })

        silencer.silence()
        controller.failMuteWrites = true
        silencer.restore()
        controller.failMuteWrites = false
        silencer.restore()

        XCTAssertTrue(controller.muted)
    }

    func testFailedSuppressionDoesNotKeepASnapshot() {
        let controller = FakeSystemAudioController(muted: false)
        controller.failMuteWrites = true
        let silencer = SystemAudioSilencer(controller: controller, log: { _ in })

        silencer.silence()
        controller.failMuteWrites = false
        controller.muted = true
        silencer.restore()

        XCTAssertTrue(controller.muted)
    }

    func testRestoreFailureLogIncludesDeviceID() {
        let controller = FakeSystemAudioController(muted: false)
        var messages: [String] = []
        let silencer = SystemAudioSilencer(controller: controller) {
            messages.append($0)
        }

        silencer.silence()
        controller.failMuteWrites = true
        silencer.restore()

        XCTAssertTrue(messages.contains { $0.contains("device 73") })
    }
}

private final class FakeSystemAudioController: SystemAudioDeviceControlling {
    let deviceID: AudioDeviceID = 73
    var muteSettable: Bool
    var volumeSettable: Bool
    var muted: Bool
    var volume: Float32
    var failMuteWrites = false

    init(
        muteSettable: Bool = true,
        volumeSettable: Bool = false,
        muted: Bool = false,
        volume: Float32 = 1
    ) {
        self.muteSettable = muteSettable
        self.volumeSettable = volumeSettable
        self.muted = muted
        self.volume = volume
    }

    func defaultOutputDeviceID() throws -> AudioDeviceID { deviceID }
    func canSetMute(for _: AudioDeviceID) -> Bool { muteSettable }
    func muteState(for _: AudioDeviceID) throws -> Bool { muted }

    func setMuted(_ muted: Bool, for _: AudioDeviceID) throws {
        if failMuteWrites { throw TestError.writeFailed }
        self.muted = muted
    }

    func canSetVolume(for _: AudioDeviceID) -> Bool { volumeSettable }
    func volume(for _: AudioDeviceID) throws -> Float32 { volume }
    func setVolume(_ volume: Float32, for _: AudioDeviceID) throws { self.volume = volume }
}

private enum TestError: Error {
    case writeFailed
}
```

The break each test catches is respectively: missing restore, blind unmute, missing volume fallback, unsupported-device mutation, overwritten snapshot, non-idempotent restore, stale-session reuse after restore failure, stale-session reuse after suppression failure, and an unactionable restore-failure log.

- [x] **Step 2: Verify RED**

Run:

```bash
swift test --filter SystemAudioSilencerTests
```

Expected: compilation fails because `SystemAudioSilencer` and `SystemAudioDeviceControlling` do not exist.

- [x] **Step 3: Implement the policy and Core Audio controller**

Create `Sources/SystemAudioSilencer.swift` with:

```swift
import AudioToolbox
import CoreAudio
import Foundation

protocol SystemAudioDeviceControlling {
    func defaultOutputDeviceID() throws -> AudioDeviceID
    func canSetMute(for deviceID: AudioDeviceID) -> Bool
    func muteState(for deviceID: AudioDeviceID) throws -> Bool
    func setMuted(_ muted: Bool, for deviceID: AudioDeviceID) throws
    func canSetVolume(for deviceID: AudioDeviceID) -> Bool
    func volume(for deviceID: AudioDeviceID) throws -> Float32
    func setVolume(_ volume: Float32, for deviceID: AudioDeviceID) throws
}

@MainActor
final class SystemAudioSilencer {
    static let shared = SystemAudioSilencer()

    private enum Snapshot {
        case mute(deviceID: AudioDeviceID, wasMuted: Bool)
        case volume(deviceID: AudioDeviceID, value: Float32)

        var deviceID: AudioDeviceID {
            switch self {
            case let .mute(deviceID, _), let .volume(deviceID, _):
                return deviceID
            }
        }
    }

    private let controller: any SystemAudioDeviceControlling
    private let log: (String) -> Void
    private var snapshot: Snapshot?

    init(
        controller: any SystemAudioDeviceControlling = CoreAudioSystemAudioController(),
        log: @escaping (String) -> Void = {
            AppLogger.warning($0, category: .audio)
        }
    ) {
        self.controller = controller
        self.log = log
    }

    func silence() {
        guard snapshot == nil else { return }

        do {
            let deviceID = try controller.defaultOutputDeviceID()
            if controller.canSetMute(for: deviceID) {
                let wasMuted = try controller.muteState(for: deviceID)
                snapshot = .mute(deviceID: deviceID, wasMuted: wasMuted)
                if !wasMuted { try controller.setMuted(true, for: deviceID) }
            } else if controller.canSetVolume(for: deviceID) {
                let volume = try controller.volume(for: deviceID)
                snapshot = .volume(deviceID: deviceID, value: volume)
                if volume != 0 { try controller.setVolume(0, for: deviceID) }
            } else {
                log("Default output device does not support software mute or volume")
            }
        } catch {
            snapshot = nil
            log("Failed to silence system audio: \(error.localizedDescription)")
        }
    }

    func restore() {
        guard let snapshot else { return }
        self.snapshot = nil

        do {
            switch snapshot {
            case let .mute(deviceID, wasMuted):
                try controller.setMuted(wasMuted, for: deviceID)
            case let .volume(deviceID, value):
                try controller.setVolume(value, for: deviceID)
            }
        } catch {
            log("Failed to restore system audio for device \(snapshot.deviceID): \(error.localizedDescription)")
        }
    }
}
```

Add `CoreAudioSystemAudioController` in the same file. It must use:

- `kAudioHardwarePropertyDefaultOutputDevice` on `kAudioObjectSystemObject` with global scope/main element;
- `kAudioDevicePropertyMute` on the output device with output scope/main element;
- `kAudioHardwareServiceDeviceProperty_VirtualMainVolume` on the output device with output scope/main element;
- `AudioObjectHasProperty` and `AudioObjectIsPropertySettable` before claiming a control can be set;
- `AudioObjectGetPropertyData` and `AudioObjectSetPropertyData`, throwing an error containing the operation and `OSStatus` when either fails.

- [x] **Step 4: Verify GREEN**

Run:

```bash
swift test --filter SystemAudioSilencerTests
```

Expected: all nine silencer tests pass.

- [x] **Step 5: Refactor while green**

Keep Core Audio address construction and typed read/write helpers private to `CoreAudioSystemAudioController`. Run the focused test again and leave both new files uncommitted.

---

### Task 2: Recording Lifecycle Integration

**Files:**
- Modify: `Sources/SoundFlowModel.swift:27-41,230-239,246-289,397-420`
- Modify: `Sources/AppDelegate.swift:1-7`

**Interfaces:**
- Consumes: `SystemAudioSilencer.shared.silence()` and `.restore()` from Task 1
- Produces: no new public interface; only lifecycle wiring

- [x] **Step 1: Wire the shared silencer into `SoundFlowModel`**

Add:

```swift
private let systemAudioSilencer = SystemAudioSilencer.shared
```

In `beginRecording()`, call `systemAudioSilencer.silence()` after microphone permission succeeds and before `audioCaptureService.start()`. Restore before every startup error is shown:

```swift
systemAudioSilencer.silence()
do {
    try audioCaptureService.start()
} catch {
    systemAudioSilencer.restore()
    setError("Failed to start audio capture: \(error.localizedDescription)")
    return
}

do {
    try transcriptionService.start()
} catch {
    audioCaptureService.stop()
    systemAudioSilencer.restore()
    setError("Failed to initialize ASR: \(error.localizedDescription)")
    return
}
```

Restore immediately after stopping microphone capture in `commitRecording()` and `cancelRecording()`. Also call restore defensively from `dismissHUD()` and `setError(_:)`; idempotence makes repeated cleanup safe.

- [x] **Step 2: Restore during normal application termination**

Mark `AppDelegate` as `@MainActor`, then add:

```swift
func applicationWillTerminate(_: Notification) {
    SystemAudioSilencer.shared.restore()
}
```

- [x] **Step 3: Compile and run the complete test suite**

Run:

```bash
swift test
```

Expected: the full suite passes with no compiler errors.

- [x] **Step 4: Inspect lifecycle ordering**

Review the diff and confirm all of these invariants directly in code:

- no silence call occurs before microphone permission succeeds;
- silence occurs before microphone capture starts;
- restore occurs immediately after capture stops on confirm and cancel;
- startup errors restore before presenting an error;
- ASR/post-processing never waits on or invokes the silencer;
- normal termination restores the shared instance.

Leave lifecycle changes uncommitted.

---

### Task 3: Formatting, Build, Graph, and Handoff

**Files:**
- Modify mechanically if needed: `Sources/SystemAudioSilencer.swift`, `Sources/SoundFlowModel.swift`, `Sources/AppDelegate.swift`, `Tests/SoundFlowTests/SystemAudioSilencerTests.swift`
- Update generated graph data: `graphify-out/` when an existing graph is available

**Interfaces:**
- Consumes: completed Tasks 1 and 2
- Produces: a formatted, built, tested, uncommitted working tree for user validation

- [x] **Step 1: Format changed Swift files**

Run:

```bash
swiftformat Sources/SystemAudioSilencer.swift Sources/SoundFlowModel.swift Sources/AppDelegate.swift Tests/SoundFlowTests/SystemAudioSilencerTests.swift
```

If `swiftformat` is unavailable, report that fact and do not add another formatter dependency.

- [x] **Step 2: Run fresh verification**

Run:

```bash
swift test
swift build
```

Expected: both commands exit zero and all tests pass.

- [x] **Step 3: Update graphify metadata**

Run:

```bash
graphify update .
```

If no existing graph is available, report the command's failure without initiating a full graph build.

- [x] **Step 4: Review the uncommitted handoff**

Run:

```bash
git diff --check
git status --short
git diff --stat
git diff -- Sources/SystemAudioSilencer.swift Sources/SoundFlowModel.swift Sources/AppDelegate.swift Tests/SoundFlowTests/SystemAudioSilencerTests.swift
```

Confirm that no commit was created after the design commit `9818dc8`. Report automated verification results and leave speaker-level manual validation to the user because running it changes the workstation's audible output.
