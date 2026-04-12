import Foundation

struct SenseVoiceModelPaths {
    let directory: URL
    let model: URL
    let tokens: URL
}

struct VADModelPaths {
    let model: URL
}

enum ModelPathResolverError: LocalizedError {
    case modelDirectoryNotFound([String])
    case compatibleModelNotFound([String])
    case vadModelNotFound([String])
    case missingFile(URL)

    var errorDescription: String? {
        switch self {
        case let .modelDirectoryNotFound(candidates):
            return "SenseVoice model not found. Checked: \(candidates.joined(separator: ", "))"
        case let .compatibleModelNotFound(candidates):
            return "Found SenseVoice files, but not a sherpa-onnx compatible model package. Put the official sherpa-onnx SenseVoice model under one of: \(candidates.joined(separator: ", "))"
        case let .vadModelNotFound(candidates):
            return "VAD model not found. Put silero_vad.onnx under one of: \(candidates.joined(separator: ", "))"
        case let .missingFile(url):
            return "Missing required model file: \(url.path)"
        }
    }
}

enum ModelPathResolver {
    static func resolveSenseVoiceSmallPaths() throws -> SenseVoiceModelPaths {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser

        let candidates = [
            home.appendingPathComponent("Library/Application Support/SoundFlow/models/sensevoice-small"),
            home
                .appendingPathComponent(
                    "Library/Application Support/SoundFlow/models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17"
                )
        ]

        let existingCandidates = candidates.filter { fileManager.fileExists(atPath: $0.path) }
        guard !existingCandidates.isEmpty else {
            throw ModelPathResolverError.modelDirectoryNotFound(candidates.map(\.path))
        }

        for directory in existingCandidates {
            if let compatible = compatiblePaths(in: directory) {
                return compatible
            }
        }

        throw ModelPathResolverError.compatibleModelNotFound(existingCandidates.map(\.path))
    }

    static func resolveVADModelPaths() throws -> VADModelPaths {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser

        let candidates = [
            home.appendingPathComponent("Library/Application Support/SoundFlow/models/silero_vad.onnx")
        ]

        guard let model = candidates.first(where: { fileManager.fileExists(atPath: $0.path) }) else {
            throw ModelPathResolverError.vadModelNotFound(candidates.map(\.path))
        }

        return VADModelPaths(model: model)
    }

    private static func compatiblePaths(in directory: URL) -> SenseVoiceModelPaths? {
        let fileManager = FileManager.default
        let modelCandidates = [
            directory.appendingPathComponent("model.int8.onnx"),
            directory.appendingPathComponent("model.onnx")
        ]
        let tokenCandidates = [
            directory.appendingPathComponent("tokens.txt")
        ]

        guard let model = modelCandidates.first(where: { fileManager.fileExists(atPath: $0.path) }),
              let tokens = tokenCandidates.first(where: { fileManager.fileExists(atPath: $0.path) }) else {
            return nil
        }

        let modelName = model.lastPathComponent.lowercased()
        let directoryName = directory.lastPathComponent.lowercased()
        let looksCompatible = modelName.contains(".int8.") || directoryName.contains("sherpa-onnx")
        guard looksCompatible else {
            return nil
        }

        return SenseVoiceModelPaths(directory: directory, model: model, tokens: tokens)
    }
}
