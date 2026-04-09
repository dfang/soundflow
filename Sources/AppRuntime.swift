import Foundation

struct AppRuntime {
    let configuration: RuntimeConfiguration
    let transcriptionService: any TranscriptionService
    let postProcessor: any TextPostProcessing

    static let `default` = makeDefault()

    private static func makeDefault() -> AppRuntime {
        let configuration = RuntimeConfiguration(
            asrBackend: .sherpaSenseVoice,
            postProcessorBackend: .mockGemma,
            selectedASRModel: ModelCatalog.defaultASRModel,
            selectedPostProcessorModel: ModelCatalog.defaultPostProcessorModel
        )

        return AppRuntime(
            configuration: configuration,
            transcriptionService: ServiceFactory.makeTranscriptionService(for: configuration),
            postProcessor: ServiceFactory.makePostProcessor(for: configuration)
        )
    }
}

struct RuntimeConfiguration {
    let asrBackend: ASRBackend
    let postProcessorBackend: PostProcessorBackend
    let selectedASRModel: ModelDescriptor
    let selectedPostProcessorModel: ModelDescriptor
}

enum ASRBackend: String {
    case mockSenseVoice = "Mock SenseVoice"
    case sherpaSenseVoice = "Sherpa-ONNX SenseVoice"
}

enum PostProcessorBackend: String {
    case mockGemma = "Mock Gemma"
    case mlxGemma = "MLX Gemma"
}

enum ServiceFactory {
    static func makeTranscriptionService(for configuration: RuntimeConfiguration) -> any TranscriptionService {
        switch configuration.asrBackend {
        case .mockSenseVoice:
            return MockTranscriptionService(model: configuration.selectedASRModel)
        case .sherpaSenseVoice:
            return SherpaOnnxSenseVoiceTranscriptionService(model: configuration.selectedASRModel)
        }
    }

    static func makePostProcessor(for configuration: RuntimeConfiguration) -> any TextPostProcessing {
        switch configuration.postProcessorBackend {
        case .mockGemma:
            return MockPostProcessor(model: configuration.selectedPostProcessorModel)
        case .mlxGemma:
            return PlaceholderGemmaPostProcessor(model: configuration.selectedPostProcessorModel)
        }
    }
}
