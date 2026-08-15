import Foundation
import XCTest
@testable import SoundFlow

final class SenseVoiceAudioPipelineTests: XCTestCase {
    func testStopDecodesSamplesAppendedAfterLatestPreview() async throws {
        let recognizer = RecordingSpeechRecognizer { samples, _ in
            samples.count == 3200 ? "preview" : "complete tail"
        }
        let vad = AlwaysSpeechVoiceActivityDetector()
        let service = makeService(recognizer: recognizer, vad: vad)
        let previewReceived = expectation(description: "preview decoded")
        service.onPreview = { text in
            if text == "preview" {
                previewReceived.fulfill()
            }
        }

        try service.start()
        service.appendAudio(samples: samples(count: 3200), sampleRate: 16000)
        await fulfillment(of: [previewReceived], timeout: 1.0)
        service.appendAudio(samples: samples(count: 800), sampleRate: 16000)

        let result = try await service.stop()

        XCTAssertEqual(result, "complete tail")
        XCTAssertEqual(recognizer.calls.map(\.samples.count), [3200, 4000])
        XCTAssertEqual(recognizer.calls.map(\.sampleRate), [16000, 16000])
    }

    func testCommonInputRatesAreNormalizedBeforeVADAndFinalDecode() async throws {
        for inputSampleRate in [16000, 44100, 48000] {
            let recognizer = RecordingSpeechRecognizer { samples, sampleRate in
                "\(sampleRate):\(samples.count)"
            }
            let vad = AlwaysSpeechVoiceActivityDetector()
            let service = makeService(recognizer: recognizer, vad: vad)

            try service.start()
            appendInChunks(
                samples: samples(count: inputSampleRate),
                sampleRate: inputSampleRate,
                to: service
            )

            let result = try await service.stop()

            XCTAssertEqual(result, "16000:16000", "input sample rate: \(inputSampleRate)")
            XCTAssertEqual(recognizer.calls.last?.sampleRate, 16000)
            XCTAssertEqual(recognizer.calls.last?.samples.count, 16000)
            XCTAssertEqual(vad.acceptedSampleCount, 16000)
        }
    }

    func testCancelDropsBufferedResamplerState() async throws {
        let recognizer = RecordingSpeechRecognizer { samples, sampleRate in
            "\(sampleRate):\(samples.count)"
        }
        let vad = AlwaysSpeechVoiceActivityDetector()
        let service = makeService(recognizer: recognizer, vad: vad)

        try service.start()
        service.appendAudio(
            samples: samples(count: 24000, value: 1),
            sampleRate: 48000
        )
        service.cancel()

        try service.start()
        appendInChunks(
            samples: samples(count: 48000, value: 0),
            sampleRate: 48000,
            to: service
        )
        _ = try await service.stop()

        let finalCall = try XCTUnwrap(recognizer.calls.last)
        XCTAssertEqual(finalCall.sampleRate, 16000)
        XCTAssertEqual(finalCall.samples.count, 16000)
        XCTAssertEqual(finalCall.samples.map(abs).max(), 0)
    }

    func testInputSampleRateChangeRecreatesResampler() async throws {
        let recognizer = RecordingSpeechRecognizer { samples, sampleRate in
            "\(sampleRate):\(samples.count)"
        }
        let vad = AlwaysSpeechVoiceActivityDetector()
        let service = makeService(recognizer: recognizer, vad: vad)

        try service.start()
        service.appendAudio(samples: samples(count: 24000, value: -0.5), sampleRate: 48000)
        service.appendAudio(samples: samples(count: 22050, value: 0.5), sampleRate: 44100)
        _ = try await service.stop()

        let finalCall = try XCTUnwrap(recognizer.calls.last)
        XCTAssertEqual(finalCall.sampleRate, 16000)
        XCTAssertEqual(finalCall.samples.count, 16000)
        XCTAssertLessThan(finalCall.samples[4000], -0.45)
        XCTAssertGreaterThan(finalCall.samples[12000], 0.45)
        XCTAssertEqual(vad.acceptedSampleCount, finalCall.samples.count)
    }

    func testAudioAppendedAfterStopBeginsIsIgnored() async throws {
        let decodeStarted = expectation(description: "final decode started")
        let recognizer = BlockingSpeechRecognizer {
            decodeStarted.fulfill()
        }
        let vad = AlwaysSpeechVoiceActivityDetector()
        let service = SherpaOnnxSenseVoiceTranscriptionService(
            model: ModelCatalog.defaultASRModel,
            recognizerFactory: { recognizer },
            vadFactory: { vad }
        )

        try service.start()
        service.appendAudio(samples: samples(count: 1000), sampleRate: 16000)
        let stopTask = Task {
            try await service.stop()
        }
        await fulfillment(of: [decodeStarted], timeout: 1.0)

        service.appendAudio(samples: samples(count: 500), sampleRate: 16000)

        XCTAssertEqual(vad.acceptedSampleCount, 1000)
        recognizer.resume()
        let result = try await stopTask.value
        XCTAssertEqual(result, "final")
    }

    func testPreviewCadenceUsesCanonicalDurationsForCommonInputRates() async throws {
        for inputSampleRate in [16000, 44100, 48000] {
            let recognizer = RecordingSpeechRecognizer { samples, _ in
                "preview \(samples.count)"
            }
            let vad = AlwaysSpeechVoiceActivityDetector()
            let service = makeService(recognizer: recognizer, vad: vad)

            try service.start()
            service.appendAudio(
                samples: samples(count: inputSampleRate * 19 / 100),
                sampleRate: inputSampleRate
            )
            try await Task.sleep(for: .milliseconds(30))
            XCTAssertEqual(recognizer.calls.count, 0, "input sample rate: \(inputSampleRate)")

            service.appendAudio(
                samples: samples(count: inputSampleRate * 2 / 100),
                sampleRate: inputSampleRate
            )
            try await waitForCallCount(1, recognizer: recognizer)
            let firstPreviewCount = try XCTUnwrap(recognizer.calls.first?.samples.count)
            XCTAssertGreaterThanOrEqual(firstPreviewCount, 3350)
            XCTAssertLessThanOrEqual(firstPreviewCount, 3360)

            service.appendAudio(
                samples: samples(count: inputSampleRate * 9 / 100),
                sampleRate: inputSampleRate
            )
            try await Task.sleep(for: .milliseconds(30))
            XCTAssertEqual(recognizer.calls.count, 1, "input sample rate: \(inputSampleRate)")

            service.appendAudio(
                samples: samples(count: inputSampleRate * 2 / 100),
                sampleRate: inputSampleRate
            )
            try await waitForCallCount(2, recognizer: recognizer)
            let secondPreviewCount = recognizer.calls[1].samples.count
            XCTAssertGreaterThanOrEqual(secondPreviewCount, 5110)
            XCTAssertLessThanOrEqual(secondPreviewCount, 5120)
            service.cancel()
        }
    }

    private func makeService(
        recognizer: RecordingSpeechRecognizer,
        vad: AlwaysSpeechVoiceActivityDetector
    ) -> SherpaOnnxSenseVoiceTranscriptionService {
        SherpaOnnxSenseVoiceTranscriptionService(
            model: ModelCatalog.defaultASRModel,
            recognizerFactory: { recognizer },
            vadFactory: { vad }
        )
    }

    private func appendInChunks(
        samples: [Float],
        sampleRate: Int,
        to service: SherpaOnnxSenseVoiceTranscriptionService
    ) {
        let chunkSize = 997
        var start = 0
        while start < samples.count {
            let end = min(start + chunkSize, samples.count)
            service.appendAudio(samples: Array(samples[start ..< end]), sampleRate: sampleRate)
            start = end
        }
    }

    private func samples(count: Int, value: Float = 0.25) -> [Float] {
        Array(repeating: value, count: count)
    }

    private func waitForCallCount(
        _ expectedCount: Int,
        recognizer: RecordingSpeechRecognizer
    ) async throws {
        let deadline = ContinuousClock.now + .seconds(1)
        while recognizer.calls.count < expectedCount, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertEqual(recognizer.calls.count, expectedCount)
    }
}

private final class RecordingSpeechRecognizer: OfflineSpeechRecognizing, @unchecked Sendable {
    struct Call {
        let samples: [Float]
        let sampleRate: Int
    }

    private let lock = NSLock()
    private let response: ([Float], Int) -> String
    private var recordedCalls: [Call] = []

    init(response: @escaping ([Float], Int) -> String) {
        self.response = response
    }

    var calls: [Call] {
        lock.withLock { recordedCalls }
    }

    func transcribe(samples: [Float], sampleRate: Int) throws -> String {
        lock.withLock {
            recordedCalls.append(Call(samples: samples, sampleRate: sampleRate))
        }
        return response(samples, sampleRate)
    }
}

private final class BlockingSpeechRecognizer: OfflineSpeechRecognizing, @unchecked Sendable {
    private let onDecode: () -> Void
    private let resumeSemaphore = DispatchSemaphore(value: 0)

    init(onDecode: @escaping () -> Void) {
        self.onDecode = onDecode
    }

    func transcribe(samples _: [Float], sampleRate _: Int) throws -> String {
        onDecode()
        resumeSemaphore.wait()
        return "final"
    }

    func resume() {
        resumeSemaphore.signal()
    }
}

private final class AlwaysSpeechVoiceActivityDetector: VoiceActivityDetecting, @unchecked Sendable {
    private let lock = NSLock()
    private var acceptedSamples = 0

    var acceptedSampleCount: Int {
        lock.withLock { acceptedSamples }
    }

    func acceptWaveform(samples: [Float]) {
        lock.withLock {
            acceptedSamples += samples.count
        }
    }

    func isSpeechDetected() -> Bool {
        true
    }

    func isEmpty() -> Bool {
        true
    }

    func reset() {}

    func clear() {}

    func flush() {}
}
