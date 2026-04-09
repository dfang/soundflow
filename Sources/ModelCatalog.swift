import Foundation

struct ModelDescriptor: Identifiable, Hashable {
    let id: String
    let displayName: String
    let family: ModelFamily
    let source: ModelSource
    let localRelativePath: String
}

enum ModelFamily: String {
    case asr
    case postProcessor
}

enum ModelSource: Hashable {
    case modelScope(repository: String)
    case localBundle
    case customURL(String)

    var displayName: String {
        switch self {
        case .modelScope(let repository):
            return "ModelScope: \(repository)"
        case .localBundle:
            return "Bundled with app"
        case .customURL(let url):
            return url
        }
    }
}

enum ModelCatalog {
    static let senseVoiceSmall = ModelDescriptor(
        id: "sensevoice-small",
        displayName: "SenseVoice Small",
        family: .asr,
        source: .modelScope(repository: "iic/SenseVoiceSmall"),
        localRelativePath: "Models/SenseVoiceSmall"
    )

    static let gemma4E4B = ModelDescriptor(
        id: "gemma-4-e4b",
        displayName: "Gemma 4 E4B",
        family: .postProcessor,
        source: .localBundle,
        localRelativePath: "Models/Gemma4E4B"
    )

    static let defaultASRModel = senseVoiceSmall
    static let defaultPostProcessorModel = gemma4E4B
}
