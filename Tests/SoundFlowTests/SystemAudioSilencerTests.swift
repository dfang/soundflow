import CoreAudio
import XCTest
@testable import SoundFlow

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

    func defaultOutputDeviceID() throws -> AudioDeviceID {
        deviceID
    }

    func canSetMute(for _: AudioDeviceID) -> Bool {
        muteSettable
    }

    func muteState(for _: AudioDeviceID) throws -> Bool {
        muted
    }

    func setMuted(_ muted: Bool, for _: AudioDeviceID) throws {
        if failMuteWrites { throw TestError.writeFailed }
        self.muted = muted
    }

    func canSetVolume(for _: AudioDeviceID) -> Bool {
        volumeSettable
    }

    func volume(for _: AudioDeviceID) throws -> Float32 {
        volume
    }

    func setVolume(_ volume: Float32, for _: AudioDeviceID) throws {
        self.volume = volume
    }
}

private enum TestError: Error {
    case writeFailed
}
