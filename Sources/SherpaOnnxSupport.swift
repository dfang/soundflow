import CSherpaOnnx
import Foundation

enum SherpaOnnxError: LocalizedError {
    case recognizerCreationFailed
    case resamplerCreationFailed
    case resamplingFailed
    case streamCreationFailed
    case resultUnavailable
    case vadCreationFailed

    var errorDescription: String? {
        switch self {
        case .recognizerCreationFailed:
            return "Failed to create sherpa-onnx recognizer."
        case .resamplerCreationFailed:
            return "Failed to create sherpa-onnx audio resampler."
        case .resamplingFailed:
            return "sherpa-onnx failed to resample audio."
        case .streamCreationFailed:
            return "Failed to create sherpa-onnx offline stream."
        case .resultUnavailable:
            return "sherpa-onnx did not return a recognition result."
        case .vadCreationFailed:
            return "Failed to create sherpa-onnx voice activity detector."
        }
    }
}

protocol OfflineSpeechRecognizing: AnyObject, Sendable {
    func transcribe(samples: [Float], sampleRate: Int) throws -> String
}

protocol VoiceActivityDetecting: AnyObject, Sendable {
    func acceptWaveform(samples: [Float])
    func isSpeechDetected() -> Bool
    func isEmpty() -> Bool
    func reset()
    func clear()
    func flush()
}

func sherpaToCPointer(_ string: String) -> UnsafePointer<Int8>! {
    let cString = (string as NSString).utf8String
    return UnsafePointer<Int8>(cString)
}

func sherpaOnnxFeatureConfig(
    sampleRate: Int = 16000,
    featureDim: Int = 80
) -> SherpaOnnxFeatureConfig {
    SherpaOnnxFeatureConfig(
        sample_rate: Int32(sampleRate),
        feature_dim: Int32(featureDim)
    )
}

func sherpaOnnxOfflineSenseVoiceModelConfig(
    model: String,
    language: String = "",
    useInverseTextNormalization: Bool = true
) -> SherpaOnnxOfflineSenseVoiceModelConfig {
    SherpaOnnxOfflineSenseVoiceModelConfig(
        model: sherpaToCPointer(model),
        language: sherpaToCPointer(language),
        use_itn: useInverseTextNormalization ? 1 : 0
    )
}

func sherpaOnnxOfflineLMConfig(
    model: String = "",
    scale: Float = 1.0
) -> SherpaOnnxOfflineLMConfig {
    SherpaOnnxOfflineLMConfig(
        model: sherpaToCPointer(model),
        scale: scale
    )
}

func sherpaOnnxHomophoneReplacerConfig(
    dictDir: String = "",
    lexicon: String = "",
    ruleFsts: String = ""
) -> SherpaOnnxHomophoneReplacerConfig {
    SherpaOnnxHomophoneReplacerConfig(
        dict_dir: sherpaToCPointer(dictDir),
        lexicon: sherpaToCPointer(lexicon),
        rule_fsts: sherpaToCPointer(ruleFsts)
    )
}

func sherpaOnnxSileroVadModelConfig(
    model: String,
    threshold: Float = 0.5,
    minSilenceDuration: Float = 0.25,
    minSpeechDuration: Float = 0.12,
    windowSize: Int = 512,
    maxSpeechDuration: Float = 30.0
) -> SherpaOnnxSileroVadModelConfig {
    SherpaOnnxSileroVadModelConfig(
        model: sherpaToCPointer(model),
        threshold: threshold,
        min_silence_duration: minSilenceDuration,
        min_speech_duration: minSpeechDuration,
        window_size: Int32(windowSize),
        max_speech_duration: maxSpeechDuration
    )
}

func sherpaOnnxTenVadModelConfig(
    model: String = "",
    threshold: Float = 0.5,
    minSilenceDuration: Float = 0.25,
    minSpeechDuration: Float = 0.12,
    windowSize: Int = 256,
    maxSpeechDuration: Float = 30.0
) -> SherpaOnnxTenVadModelConfig {
    SherpaOnnxTenVadModelConfig(
        model: sherpaToCPointer(model),
        threshold: threshold,
        min_silence_duration: minSilenceDuration,
        min_speech_duration: minSpeechDuration,
        window_size: Int32(windowSize),
        max_speech_duration: maxSpeechDuration
    )
}

func sherpaOnnxVadModelConfig(
    sileroVad: SherpaOnnxSileroVadModelConfig,
    sampleRate: Int32 = 16000,
    numThreads: Int = 1,
    provider: String = "cpu",
    debug _: Int = 0,
    tenVad: SherpaOnnxTenVadModelConfig = sherpaOnnxTenVadModelConfig()
) -> SherpaOnnxVadModelConfig {
    SherpaOnnxVadModelConfig(
        silero_vad: sileroVad,
        sample_rate: sampleRate,
        num_threads: Int32(numThreads),
        provider: sherpaToCPointer(provider),
        debug: 0,
        ten_vad: tenVad
    )
}

func sherpaOnnxOfflineModelConfig(
    tokens: String,
    senseVoice: SherpaOnnxOfflineSenseVoiceModelConfig,
    numThreads: Int = 2,
    provider: String = "cpu",
    debug _: Int = 0
) -> SherpaOnnxOfflineModelConfig {
    SherpaOnnxOfflineModelConfig(
        transducer: SherpaOnnxOfflineTransducerModelConfig(),
        paraformer: SherpaOnnxOfflineParaformerModelConfig(),
        nemo_ctc: SherpaOnnxOfflineNemoEncDecCtcModelConfig(),
        whisper: SherpaOnnxOfflineWhisperModelConfig(),
        tdnn: SherpaOnnxOfflineTdnnModelConfig(),
        tokens: sherpaToCPointer(tokens),
        num_threads: Int32(numThreads),
        debug: 0,
        provider: sherpaToCPointer(provider),
        model_type: sherpaToCPointer(""),
        modeling_unit: sherpaToCPointer("cjkchar"),
        bpe_vocab: sherpaToCPointer(""),
        telespeech_ctc: sherpaToCPointer(""),
        sense_voice: senseVoice,
        moonshine: SherpaOnnxOfflineMoonshineModelConfig(),
        fire_red_asr: SherpaOnnxOfflineFireRedAsrModelConfig(),
        dolphin: SherpaOnnxOfflineDolphinModelConfig(),
        zipformer_ctc: SherpaOnnxOfflineZipformerCtcModelConfig(),
        canary: SherpaOnnxOfflineCanaryModelConfig(),
        wenet_ctc: SherpaOnnxOfflineWenetCtcModelConfig(),
        omnilingual: SherpaOnnxOfflineOmnilingualAsrCtcModelConfig(),
        medasr: SherpaOnnxOfflineMedAsrCtcModelConfig(),
        funasr_nano: SherpaOnnxOfflineFunASRNanoModelConfig(),
        fire_red_asr_ctc: SherpaOnnxOfflineFireRedAsrCtcModelConfig(),
        qwen3_asr: SherpaOnnxOfflineQwen3ASRModelConfig(),
        cohere_transcribe: SherpaOnnxOfflineCohereTranscribeModelConfig()
    )
}

func sherpaOnnxOfflineRecognizerConfig(
    featConfig: SherpaOnnxFeatureConfig,
    modelConfig: SherpaOnnxOfflineModelConfig,
    lmConfig: SherpaOnnxOfflineLMConfig = sherpaOnnxOfflineLMConfig(),
    decodingMethod: String = "greedy_search",
    maxActivePaths: Int = 4,
    hotwordsFile: String = "",
    hotwordsScore: Float = 1.5,
    ruleFsts: String = "",
    ruleFars: String = "",
    blankPenalty: Float = 0,
    hr: SherpaOnnxHomophoneReplacerConfig = sherpaOnnxHomophoneReplacerConfig()
) -> SherpaOnnxOfflineRecognizerConfig {
    SherpaOnnxOfflineRecognizerConfig(
        feat_config: featConfig,
        model_config: modelConfig,
        lm_config: lmConfig,
        decoding_method: sherpaToCPointer(decodingMethod),
        max_active_paths: Int32(maxActivePaths),
        hotwords_file: sherpaToCPointer(hotwordsFile),
        hotwords_score: hotwordsScore,
        rule_fsts: sherpaToCPointer(ruleFsts),
        rule_fars: sherpaToCPointer(ruleFars),
        blank_penalty: blankPenalty,
        hr: hr
    )
}

final class SherpaOnnxOfflineRecognitionResult {
    private let result: UnsafePointer<SherpaOnnxOfflineRecognizerResult>

    init(result: UnsafePointer<SherpaOnnxOfflineRecognizerResult>) {
        self.result = result
    }

    deinit {
        SherpaOnnxDestroyOfflineRecognizerResult(result)
    }

    var text: String {
        guard let cString = result.pointee.text else { return "" }
        return String(cString: cString)
    }

    var language: String {
        guard let cString = result.pointee.lang else { return "" }
        return String(cString: cString)
    }
}

final class SherpaOnnxOfflineStreamWrapper: @unchecked Sendable {
    let stream: OpaquePointer

    init(stream: OpaquePointer) {
        self.stream = stream
    }

    deinit {
        SherpaOnnxDestroyOfflineStream(stream)
    }

    func setOption(key: String, value: String) {
        SherpaOnnxOfflineStreamSetOption(stream, sherpaToCPointer(key), sherpaToCPointer(value))
    }

    func acceptWaveform(samples: [Float], sampleRate: Int) {
        SherpaOnnxAcceptWaveformOffline(stream, Int32(sampleRate), samples, Int32(samples.count))
    }
}

final class SherpaOnnxOfflineRecognizerWrapper: @unchecked Sendable {
    private let recognizer: OpaquePointer

    init(config: inout SherpaOnnxOfflineRecognizerConfig) throws {
        guard let recognizer = SherpaOnnxCreateOfflineRecognizer(&config) else {
            throw SherpaOnnxError.recognizerCreationFailed
        }
        self.recognizer = recognizer
    }

    deinit {
        SherpaOnnxDestroyOfflineRecognizer(recognizer)
    }

    func createStream() throws -> SherpaOnnxOfflineStreamWrapper {
        guard let stream = SherpaOnnxCreateOfflineStream(recognizer) else {
            throw SherpaOnnxError.streamCreationFailed
        }
        return SherpaOnnxOfflineStreamWrapper(stream: stream)
    }

    func decode(samples: [Float], sampleRate: Int, language: String = "") throws -> SherpaOnnxOfflineRecognitionResult {
        let stream = try createStream()
        if !language.isEmpty {
            stream.setOption(key: "language", value: language)
        }
        stream.acceptWaveform(samples: samples, sampleRate: sampleRate)
        SherpaOnnxDecodeOfflineStream(recognizer, stream.stream)

        guard let result = SherpaOnnxGetOfflineStreamResult(stream.stream) else {
            throw SherpaOnnxError.resultUnavailable
        }

        return SherpaOnnxOfflineRecognitionResult(result: result)
    }
}

extension SherpaOnnxOfflineRecognizerWrapper: OfflineSpeechRecognizing {
    func transcribe(samples: [Float], sampleRate: Int) throws -> String {
        try decode(samples: samples, sampleRate: sampleRate).text
    }
}

final class SherpaOnnxLinearResamplerWrapper {
    private let resampler: OpaquePointer

    init(inputSampleRate: Int, outputSampleRate: Int) throws {
        let minimumSampleRate = Float(min(inputSampleRate, outputSampleRate))
        let filterCutoff = 0.99 * 0.5 * minimumSampleRate
        guard let resampler = SherpaOnnxCreateLinearResampler(
            Int32(inputSampleRate),
            Int32(outputSampleRate),
            filterCutoff,
            6
        ) else {
            throw SherpaOnnxError.resamplerCreationFailed
        }
        self.resampler = resampler
    }

    deinit {
        SherpaOnnxDestroyLinearResampler(resampler)
    }

    func resample(samples: [Float], flush: Bool) throws -> [Float] {
        let output = samples.withUnsafeBufferPointer { buffer in
            SherpaOnnxLinearResamplerResample(
                resampler,
                buffer.baseAddress,
                Int32(buffer.count),
                flush ? 1 : 0
            )
        }
        guard let output else {
            throw SherpaOnnxError.resamplingFailed
        }
        defer { SherpaOnnxLinearResamplerResampleFree(output) }

        let count = Int(output.pointee.n)
        guard count > 0 else { return [] }
        guard let outputSamples = output.pointee.samples else {
            throw SherpaOnnxError.resamplingFailed
        }
        return Array(UnsafeBufferPointer(start: outputSamples, count: count))
    }
}

final class SherpaOnnxVoiceActivityDetectorWrapper: @unchecked Sendable {
    private let vad: OpaquePointer

    init(config: inout SherpaOnnxVadModelConfig, bufferSizeInSeconds: Float = 30.0) throws {
        guard let vad = SherpaOnnxCreateVoiceActivityDetector(&config, bufferSizeInSeconds) else {
            throw SherpaOnnxError.vadCreationFailed
        }
        self.vad = vad
    }

    deinit {
        SherpaOnnxDestroyVoiceActivityDetector(vad)
    }

    func acceptWaveform(samples: [Float]) {
        guard !samples.isEmpty else { return }
        SherpaOnnxVoiceActivityDetectorAcceptWaveform(vad, samples, Int32(samples.count))
    }

    func isSpeechDetected() -> Bool {
        SherpaOnnxVoiceActivityDetectorDetected(vad) == 1
    }

    func isEmpty() -> Bool {
        SherpaOnnxVoiceActivityDetectorEmpty(vad) == 1
    }

    func reset() {
        SherpaOnnxVoiceActivityDetectorReset(vad)
    }

    func clear() {
        SherpaOnnxVoiceActivityDetectorClear(vad)
    }

    func flush() {
        SherpaOnnxVoiceActivityDetectorFlush(vad)
    }

    func popAll() {
        while !isEmpty() {
            SherpaOnnxVoiceActivityDetectorPop(vad)
        }
    }
}

extension SherpaOnnxVoiceActivityDetectorWrapper: VoiceActivityDetecting {}
