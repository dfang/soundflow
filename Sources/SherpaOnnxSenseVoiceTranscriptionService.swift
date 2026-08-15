import Foundation
import os

final class SherpaOnnxSenseVoiceTranscriptionService: TranscriptionService, @unchecked Sendable {
    private struct ResamplerState {
        let inputSampleRate: Int
        let resampler: SherpaOnnxLinearResamplerWrapper
    }

    private static let processingSampleRate = 16000

    private let logger = AppLogger.logger(for: .transcription)
    let displayName = ASRBackend.sherpaSenseVoice.rawValue
    let model: ModelDescriptor
    var onPreview: ((String) -> Void)?

    private let lock = NSLock()
    private let decodeQueue = DispatchQueue(label: "app.soundflow.asr.decode")
    private var bufferedSamples: [Float] = []
    private var sessionID: UInt64 = 0
    private var latestPreviewText = ""
    private var lastPreviewSampleCount = 0
    private var previewDecodeInFlight = false
    private var speechDetected = false
    private var isAcceptingAudio = false
    private var resamplerState: ResamplerState?
    private var recognizer: (any OfflineSpeechRecognizing)?
    private var vad: (any VoiceActivityDetecting)?
    private let recognizerFactory: @Sendable () throws -> any OfflineSpeechRecognizing
    private let vadFactory: @Sendable () throws -> any VoiceActivityDetecting

    private let minimumPreviewDuration: TimeInterval = 0.2
    private let previewStrideDuration: TimeInterval = 0.1

    init(model: ModelDescriptor) {
        self.model = model
        recognizerFactory = { try Self.makeDefaultRecognizer() }
        vadFactory = { try Self.makeDefaultVAD() }
    }

    init(
        model: ModelDescriptor,
        recognizerFactory: @escaping @Sendable () throws -> any OfflineSpeechRecognizing,
        vadFactory: @escaping @Sendable () throws -> any VoiceActivityDetecting
    ) {
        self.model = model
        self.recognizerFactory = recognizerFactory
        self.vadFactory = vadFactory
    }

    func start() throws {
        _ = try prepareRecognizerIfNeeded()
        _ = try prepareVADIfNeeded()

        lock.lock()
        resetSessionState(keepingBufferCapacity: true)
        isAcceptingAudio = true
        lock.unlock()

        AppLogger.info("Transcription started", category: .transcription)
    }

    func appendAudio(samples: [Float], sampleRate: Int) {
        guard !samples.isEmpty, sampleRate > 0 else { return }

        var snapshot: [Float] = []
        var snapshotSessionID: UInt64 = 0

        lock.lock()
        guard isAcceptingAudio else {
            lock.unlock()
            return
        }
        let processedSamples: [Float]
        do {
            processedSamples = try resampleForProcessing(
                samples: samples,
                inputSampleRate: sampleRate
            )
        } catch {
            lock.unlock()
            AppLogger.error("Audio resampling failed: \(error.localizedDescription)", category: .transcription)
            return
        }

        guard !processedSamples.isEmpty else {
            lock.unlock()
            return
        }

        bufferedSamples.append(contentsOf: processedSamples)
        let vad = vad
        vad?.acceptWaveform(samples: processedSamples)
        refreshSpeechDetection()

        guard speechDetected else {
            lock.unlock()
            return
        }

        let bufferedDuration = TimeInterval(bufferedSamples.count) / TimeInterval(Self.processingSampleRate)
        let undecodedDuration = TimeInterval(bufferedSamples.count - lastPreviewSampleCount)
            / TimeInterval(Self.processingSampleRate)
        let enoughAudio = bufferedDuration >= minimumPreviewDuration
        let enoughDelta = undecodedDuration >= previewStrideDuration
        if enoughAudio, enoughDelta, !previewDecodeInFlight {
            previewDecodeInFlight = true
            snapshot = bufferedSamples
            snapshotSessionID = sessionID
        }
        lock.unlock()

        guard !snapshot.isEmpty else { return }
        requestPreviewDecode(samples: snapshot, sessionID: snapshotSessionID)
    }

    func stop() async throws -> String {
        let samples = try finishAudioSession()

        guard !samples.isEmpty else { return "" }

        let rawText = try await decode(samples: samples)

        return Self.normalize(rawText)
    }

    func cancel() {
        lock.lock()
        resetSessionState(keepingBufferCapacity: false)
        lock.unlock()
    }
}

private extension SherpaOnnxSenseVoiceTranscriptionService {
    private func prepareRecognizerIfNeeded() throws -> any OfflineSpeechRecognizing {
        lock.lock()
        if let recognizer {
            lock.unlock()
            return recognizer
        }
        lock.unlock()

        let recognizer = try recognizerFactory()

        lock.lock()
        if self.recognizer == nil {
            self.recognizer = recognizer
        }
        let resolved = self.recognizer ?? recognizer
        lock.unlock()

        return resolved
    }

    private static func makeDefaultRecognizer() throws -> any OfflineSpeechRecognizing {
        let modelPaths = try ModelPathResolver.resolveSenseVoiceSmallPaths()
        let senseVoiceConfig = sherpaOnnxOfflineSenseVoiceModelConfig(
            model: modelPaths.model.path,
            useInverseTextNormalization: true
        )
        let modelConfig = sherpaOnnxOfflineModelConfig(
            tokens: modelPaths.tokens.path,
            senseVoice: senseVoiceConfig
        )
        let featureConfig = sherpaOnnxFeatureConfig(sampleRate: 16000, featureDim: 80)
        var config = sherpaOnnxOfflineRecognizerConfig(
            featConfig: featureConfig,
            modelConfig: modelConfig
        )
        return try SherpaOnnxOfflineRecognizerWrapper(config: &config)
    }

    private func prepareVADIfNeeded() throws -> any VoiceActivityDetecting {
        lock.lock()
        if let vad {
            lock.unlock()
            return vad
        }
        lock.unlock()

        let vad = try vadFactory()

        lock.lock()
        if self.vad == nil {
            self.vad = vad
        }
        let resolved = self.vad ?? vad
        lock.unlock()

        return resolved
    }

    private static func makeDefaultVAD() throws -> any VoiceActivityDetecting {
        let vadPaths = try ModelPathResolver.resolveVADModelPaths()
        let sileroConfig = sherpaOnnxSileroVadModelConfig(
            model: vadPaths.model.path,
            threshold: 0.12,
            minSilenceDuration: 0.08,
            minSpeechDuration: 0.03,
            windowSize: 512,
            maxSpeechDuration: 30.0
        )
        var config = sherpaOnnxVadModelConfig(
            sileroVad: sileroConfig,
            sampleRate: 16000,
            numThreads: 1,
            provider: "cpu",
            debug: 0
        )
        return try SherpaOnnxVoiceActivityDetectorWrapper(config: &config)
    }

    private func finishAudioSession() throws -> [Float] {
        lock.lock()
        defer { lock.unlock() }

        isAcceptingAudio = false
        do {
            try flushResampler()
            flushPendingSpeech()
            let samples = bufferedSamples
            resetSessionState(keepingBufferCapacity: false)
            return samples
        } catch {
            resetSessionState(keepingBufferCapacity: false)
            throw error
        }
    }

    private func resampleForProcessing(samples: [Float], inputSampleRate: Int) throws -> [Float] {
        var processedSamples: [Float] = []

        if let state = resamplerState, state.inputSampleRate != inputSampleRate {
            processedSamples = try state.resampler.resample(samples: [], flush: true)
            resamplerState = nil
        }

        guard inputSampleRate != Self.processingSampleRate else {
            processedSamples.append(contentsOf: samples)
            return processedSamples
        }

        if resamplerState == nil {
            let resampler = try SherpaOnnxLinearResamplerWrapper(
                inputSampleRate: inputSampleRate,
                outputSampleRate: Self.processingSampleRate
            )
            resamplerState = ResamplerState(
                inputSampleRate: inputSampleRate,
                resampler: resampler
            )
        }

        guard let resamplerState else { return [] }
        let resampledSamples = try resamplerState.resampler.resample(samples: samples, flush: false)
        processedSamples.append(contentsOf: resampledSamples)
        return processedSamples
    }

    private func flushResampler() throws {
        guard let resamplerState else { return }
        let finalSamples = try resamplerState.resampler.resample(samples: [], flush: true)
        self.resamplerState = nil

        guard !finalSamples.isEmpty else { return }
        bufferedSamples.append(contentsOf: finalSamples)
        vad?.acceptWaveform(samples: finalSamples)
        refreshSpeechDetection()
    }

    private func flushPendingSpeech() {
        guard !speechDetected else { return }
        vad?.flush()
        refreshSpeechDetection()
    }

    private func refreshSpeechDetection() {
        guard !speechDetected else { return }
        speechDetected = (vad?.isSpeechDetected() == true) || (vad?.isEmpty() == false)
    }

    private func resetSessionState(keepingBufferCapacity: Bool) {
        sessionID &+= 1
        bufferedSamples.removeAll(keepingCapacity: keepingBufferCapacity)
        latestPreviewText = ""
        lastPreviewSampleCount = 0
        previewDecodeInFlight = false
        speechDetected = false
        isAcceptingAudio = false
        resamplerState = nil
        vad?.reset()
        vad?.clear()
    }

    private func requestPreviewDecode(samples: [Float], sessionID: UInt64) {
        decodeQueue.async { [weak self] in
            guard let self else { return }

            let previewText: String
            do {
                let text = try decodeSynchronously(samples: samples)
                previewText = Self.normalize(text)
            } catch {
                previewText = ""
            }

            lock.lock()
            defer { self.lock.unlock() }

            guard self.sessionID == sessionID else { return }

            previewDecodeInFlight = false
            lastPreviewSampleCount = max(lastPreviewSampleCount, samples.count)

            guard !previewText.isEmpty, previewText != latestPreviewText else { return }
            latestPreviewText = previewText

            DispatchQueue.main.async { [weak self] in
                self?.onPreview?(previewText)
            }
        }
    }

    private func decode(samples: [Float]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            decodeQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: "")
                    return
                }

                do {
                    let text = try decodeSynchronously(samples: samples)
                    continuation.resume(returning: text)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func decodeSynchronously(samples: [Float]) throws -> String {
        let recognizer = try prepareRecognizerIfNeeded()
        return try recognizer.transcribe(samples: samples, sampleRate: Self.processingSampleRate)
    }

    private static func normalize(_ text: String) -> String {
        var result = text
            .replacingOccurrences(of: "<\\|[^|]+\\|>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // SenseVoice predicts sentence-ending punctuation; drop a trailing period
        // so the committed text does not end with an unwanted "。".
        while let last = result.last, last == "。" || last == "." {
            result.removeLast()
        }
        return result
    }
}
