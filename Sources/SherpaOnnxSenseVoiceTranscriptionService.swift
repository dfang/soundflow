import Foundation

final class SherpaOnnxSenseVoiceTranscriptionService: TranscriptionService, @unchecked Sendable {
    let displayName = ASRBackend.sherpaSenseVoice.rawValue
    let model: ModelDescriptor
    var onPreview: ((String) -> Void)?

    private let lock = NSLock()
    private let decodeQueue = DispatchQueue(label: "app.soundflow.asr.decode")
    private var bufferedSamples: [Float] = []
    private var sampleRate = 16_000
    private var sessionID: UInt64 = 0
    private var latestPreviewText = ""
    private var lastPreviewSampleCount = 0
    private var lastQueuedPreviewSampleCount = 0
    private var previewDecodeInFlight = false
    private var speechDetected = false
    private var recognizer: SherpaOnnxOfflineRecognizerWrapper?
    private var vad: SherpaOnnxVoiceActivityDetectorWrapper?

    private let minimumPreviewSamples = 3_200
    private let previewStrideSamples = 1_600
    private let previewReuseSlackSamples = 8_000
    private let previewCoverageThreshold = 0.80
    private let previewReuseWaitMillis = 160
    private let previewReusePollMillis = 20

    init(model: ModelDescriptor) {
        self.model = model
    }

    func start() throws {
        _ = try prepareRecognizerIfNeeded()
        let vad = try prepareVADIfNeeded()

        lock.lock()
        sessionID &+= 1
        bufferedSamples.removeAll(keepingCapacity: true)
        sampleRate = 16_000
        latestPreviewText = ""
        lastPreviewSampleCount = 0
        lastQueuedPreviewSampleCount = 0
        previewDecodeInFlight = false
        speechDetected = false
        vad.reset()
        vad.clear()
        lock.unlock()

        onPreview?("Listening...")
    }

    func appendAudio(samples: [Float], sampleRate: Int) {
        guard !samples.isEmpty else { return }

        var snapshot: [Float] = []
        var snapshotRate = sampleRate
        var snapshotSessionID: UInt64 = 0

        lock.lock()
        self.sampleRate = sampleRate
        bufferedSamples.append(contentsOf: samples)
        let vad = self.vad
        vad?.acceptWaveform(samples: samples)

        if !speechDetected {
            if (vad?.isSpeechDetected() == true) || (vad?.isEmpty() == false) {
                speechDetected = true
            }
        }

        guard speechDetected else {
            lock.unlock()
            return
        }

        let enoughAudio = bufferedSamples.count >= minimumPreviewSamples
        let enoughDelta = bufferedSamples.count - lastPreviewSampleCount >= previewStrideSamples
        if enoughAudio && enoughDelta && !previewDecodeInFlight {
            previewDecodeInFlight = true
            snapshot = bufferedSamples
            snapshotRate = self.sampleRate
            snapshotSessionID = sessionID
            lastQueuedPreviewSampleCount = snapshot.count
        }
        lock.unlock()

        guard !snapshot.isEmpty else { return }
        requestPreviewDecode(samples: snapshot, sampleRate: snapshotRate, sessionID: snapshotSessionID)
    }

    func stop() async throws -> String {
        flushPendingSpeechIfNeeded()
        var payload = snapshotState()

        guard !payload.samples.isEmpty else {
            resetState()
            return ""
        }

        if payload.previewDecodeInFlight, shouldLikelyReusePreview(payload: payload) {
            let deadline = ContinuousClock.now + .milliseconds(previewReuseWaitMillis)
            while ContinuousClock.now < deadline {
                try? await Task.sleep(for: .milliseconds(previewReusePollMillis))
                payload = snapshotState()
                if !payload.previewDecodeInFlight {
                    break
                }
            }
        }

        let normalizedPreview = Self.normalize(payload.latestPreviewText)
        if shouldReusePreview(payload: payload, normalizedPreview: normalizedPreview) {
            resetState()
            return normalizedPreview
        }

        resetState()
        let rawText = try await decode(samples: payload.samples, sampleRate: payload.sampleRate)

        return Self.normalize(rawText)
    }

    func cancel() {
        lock.lock()
        sessionID &+= 1
        bufferedSamples.removeAll(keepingCapacity: false)
        sampleRate = 16_000
        latestPreviewText = ""
        lastPreviewSampleCount = 0
        lastQueuedPreviewSampleCount = 0
        previewDecodeInFlight = false
        speechDetected = false
        vad?.reset()
        vad?.clear()
        lock.unlock()
    }

    private func prepareRecognizerIfNeeded() throws -> SherpaOnnxOfflineRecognizerWrapper {
        lock.lock()
        if let recognizer {
            lock.unlock()
            return recognizer
        }
        lock.unlock()

        let modelPaths = try ModelPathResolver.resolveSenseVoiceSmallPaths()
        let senseVoiceConfig = sherpaOnnxOfflineSenseVoiceModelConfig(
            model: modelPaths.model.path,
            useInverseTextNormalization: true
        )
        let modelConfig = sherpaOnnxOfflineModelConfig(
            tokens: modelPaths.tokens.path,
            senseVoice: senseVoiceConfig
        )
        let featureConfig = sherpaOnnxFeatureConfig(sampleRate: 16_000, featureDim: 80)
        var config = sherpaOnnxOfflineRecognizerConfig(
            featConfig: featureConfig,
            modelConfig: modelConfig
        )
        let recognizer = try SherpaOnnxOfflineRecognizerWrapper(config: &config)

        lock.lock()
        if self.recognizer == nil {
            self.recognizer = recognizer
        }
        let resolved = self.recognizer ?? recognizer
        lock.unlock()

        return resolved
    }

    private func prepareVADIfNeeded() throws -> SherpaOnnxVoiceActivityDetectorWrapper {
        lock.lock()
        if let vad {
            lock.unlock()
            return vad
        }
        lock.unlock()

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
            sampleRate: 16_000,
            numThreads: 1,
            provider: "cpu",
            debug: 0
        )
        let vad = try SherpaOnnxVoiceActivityDetectorWrapper(config: &config)

        lock.lock()
        if self.vad == nil {
            self.vad = vad
        }
        let resolved = self.vad ?? vad
        lock.unlock()

        return resolved
    }

    private func snapshotState() -> (
        samples: [Float],
        sampleRate: Int,
        latestPreviewText: String,
        lastPreviewSampleCount: Int,
        lastQueuedPreviewSampleCount: Int,
        previewDecodeInFlight: Bool
    ) {
        lock.lock()
        let payload = (
            samples: bufferedSamples,
            sampleRate: sampleRate,
            latestPreviewText: latestPreviewText,
            lastPreviewSampleCount: lastPreviewSampleCount,
            lastQueuedPreviewSampleCount: lastQueuedPreviewSampleCount,
            previewDecodeInFlight: previewDecodeInFlight
        )
        lock.unlock()
        return payload
    }

    private func flushPendingSpeechIfNeeded() {
        lock.lock()
        if !speechDetected {
            vad?.flush()
            if (vad?.isSpeechDetected() == true) || (vad?.isEmpty() == false) {
                speechDetected = true
            }
        }
        lock.unlock()
    }

    private func resetState() {
        lock.lock()
        sessionID &+= 1
        bufferedSamples.removeAll(keepingCapacity: false)
        sampleRate = 16_000
        latestPreviewText = ""
        lastPreviewSampleCount = 0
        lastQueuedPreviewSampleCount = 0
        previewDecodeInFlight = false
        speechDetected = false
        vad?.reset()
        vad?.clear()
        lock.unlock()
    }

    private func requestPreviewDecode(samples: [Float], sampleRate: Int, sessionID: UInt64) {
        decodeQueue.async { [weak self] in
            guard let self else { return }

            let previewText: String
            do {
                let text = try self.decodeSynchronously(samples: samples, sampleRate: sampleRate)
                previewText = Self.normalize(text)
            } catch {
                previewText = ""
            }

            self.lock.lock()
            defer { self.lock.unlock() }

            guard self.sessionID == sessionID else { return }

            self.previewDecodeInFlight = false
            self.lastPreviewSampleCount = max(self.lastPreviewSampleCount, samples.count)

            guard !previewText.isEmpty, previewText != self.latestPreviewText else { return }
            self.latestPreviewText = previewText

            DispatchQueue.main.async { [weak self] in
                self?.onPreview?(previewText)
            }
        }
    }

    private func decode(samples: [Float], sampleRate: Int) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            decodeQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: "")
                    return
                }

                do {
                    let text = try self.decodeSynchronously(samples: samples, sampleRate: sampleRate)
                    continuation.resume(returning: text)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func decodeSynchronously(samples: [Float], sampleRate: Int) throws -> String {
        let recognizer = try prepareRecognizerIfNeeded()
        let result = try recognizer.decode(samples: samples, sampleRate: sampleRate)
        return result.text
    }

    private func shouldLikelyReusePreview(
        payload: (
            samples: [Float],
            sampleRate: Int,
            latestPreviewText: String,
            lastPreviewSampleCount: Int,
            lastQueuedPreviewSampleCount: Int,
            previewDecodeInFlight: Bool
        )
    ) -> Bool {
        let totalSamples = max(payload.samples.count, 1)
        let queuedCoverage = Double(payload.lastQueuedPreviewSampleCount) / Double(totalSamples)
        return queuedCoverage >= previewCoverageThreshold
    }

    private func shouldReusePreview(
        payload: (
            samples: [Float],
            sampleRate: Int,
            latestPreviewText: String,
            lastPreviewSampleCount: Int,
            lastQueuedPreviewSampleCount: Int,
            previewDecodeInFlight: Bool
        ),
        normalizedPreview: String
    ) -> Bool {
        guard !normalizedPreview.isEmpty else { return false }

        let totalSamples = max(payload.samples.count, 1)
        let decodedCoverage = Double(payload.lastPreviewSampleCount) / Double(totalSamples)
        let undecodedTailSamples = max(0, payload.samples.count - payload.lastPreviewSampleCount)

        return decodedCoverage >= previewCoverageThreshold || undecodedTailSamples <= previewReuseSlackSamples
    }

    private static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "<\\|[^|]+\\|>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
