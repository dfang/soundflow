import Foundation
import os

// MARK: - Log Category

enum LogCategory: String {
    case audio = "Audio"
    case transcription = "Transcription"
    case postProcessing = "PostProcessing"
    case system = "System"
}

// MARK: - Log Level

enum SFLogLevel: Int {
    case trace = 0
    case info = 1
    case warning = 2
    case error = 3

    var osLogType: OSLogType {
        switch self {
        case .trace: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }

    var label: String {
        switch self {
        case .trace: return "TRACE"
        case .info: return "INFO"
        case .warning: return "WARN"
        case .error: return "ERROR"
        }
    }
}

// MARK: - Debug Mode Manager

final class DebugModeManager: @unchecked Sendable {
    static let shared = DebugModeManager()

    private let lock = NSLock()
    private var _enabled = false

    var enabled: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _enabled
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _enabled = newValue
        }
    }

    private init() {}
}

// MARK: - File Logger

final class FileLogger: @unchecked Sendable {
    static let shared = FileLogger()

    private let queue = DispatchQueue(label: "app.soundflow.logger", qos: .utility)
    private let maxFileSize = 5 * 1024 * 1024 // 5MB
    private let maxFileCount = 5
    private var currentFileHandle: FileHandle?
    private var currentFileSize = 0

    private var logsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("SoundFlow/Logs", isDirectory: true)
    }

    private var currentLogFile: URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return logsDirectory.appendingPathComponent("soundflow-\(dateFormatter.string(from: Date())).log")
    }

    private init() {}

    func log(level: SFLogLevel, category: LogCategory, message: String, file: String = #file, line: Int = #line) {
        queue.async { [weak self] in
            guard let self else { return }
            print("FileLogger: about to write, handle=\(currentFileHandle != nil)")
            write(level: level, category: category, message: message, file: file, line: line)
            print("FileLogger: write done, handle=\(currentFileHandle != nil)")
        }
    }

    private func write(level: SFLogLevel, category: LogCategory, message: String, file: String, line: Int) {
        print("FileLogger.write: dir=\(logsDirectory.path)")
        ensureDirectoryExists()

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let lineStr = "[\(timestamp)] [\(level.label)] [\(category.rawValue)] [\(fileName):\(line)] \(message)\n"

        print(
            "FileLogger.write: lineStr.count=\(lineStr.utf8.count), currentSize=\(currentFileSize), max=\(maxFileSize)"
        )

        if let handle = currentFileHandle, currentFileSize + lineStr.utf8.count <= maxFileSize {
            print("FileLogger.write: appending to existing handle")
            currentFileSize += lineStr.utf8.count
            try? handle.write(contentsOf: Data(lineStr.utf8))
        } else {
            print("FileLogger.write: calling rotateAndOpenNew")
            rotateAndOpenNew()
            print("FileLogger.write: after rotate, handle=\(currentFileHandle != nil)")
            try? currentFileHandle?.write(contentsOf: Data(lineStr.utf8))
            currentFileSize = lineStr.utf8.count
        }
    }

    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
    }

    private func rotateAndOpenNew() {
        try? currentFileHandle?.close()
        currentFileHandle = nil
        currentFileSize = 0

        let newFile = currentLogFile
        if !FileManager.default.fileExists(atPath: newFile.path) {
            FileManager.default.createFile(atPath: newFile.path, contents: nil)
        }
        currentFileHandle = try? FileHandle(forWritingTo: newFile)
        currentFileHandle?.seekToEndOfFile()

        pruneOldLogs()
    }

    private func pruneOldLogs() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: logsDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        let logFiles: [(URL, Date)] = files
            .filter { $0.pathExtension == "log" }
            .compactMap { url -> (URL, Date)? in
                let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                let date = attrs?[.creationDate] as? Date ?? Date.distantPast
                return (url, date)
            }
            .sorted { $0.1 > $1.1 }

        let oldFiles = logFiles.suffix(from: Swift.min(maxFileCount, logFiles.count))
        for (url, _) in oldFiles {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - App Logger

enum AppLogger {
    static let subsystem = "com.soundflow.app"

    static func logger(for category: LogCategory) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }

    /// Logs at the current debug level (info if debug mode on, warning otherwise).
    static func log(
        level: SFLogLevel,
        category: LogCategory,
        message: String,
        file: String = #file,
        line: Int = #line
    ) {
        let effectiveLevel = DebugModeManager.shared.enabled ? SFLogLevel.info : SFLogLevel.warning
        guard level.rawValue >= effectiveLevel.rawValue else { return }

        // Always write to file (async, non-blocking)
        FileLogger.shared.log(level: level, category: category, message: message, file: file, line: line)

        // Emit to os.log / Console.app (works in .app bundle, no-op in SPM)
        let osLogger = logger(for: category)
        osLogger.log(level: level.osLogType, "\(message)")
    }

    // Convenience methods for common levels

    static func trace(_ message: String, category: LogCategory = .system, file: String = #file, line: Int = #line) {
        log(level: .trace, category: category, message: message, file: file, line: line)
    }

    static func info(_ message: String, category: LogCategory = .system, file: String = #file, line: Int = #line) {
        log(level: .info, category: category, message: message, file: file, line: line)
    }

    static func warning(_ message: String, category: LogCategory = .system, file: String = #file, line: Int = #line) {
        log(level: .warning, category: category, message: message, file: file, line: line)
    }

    static func error(_ message: String, category: LogCategory = .system, file: String = #file, line: Int = #line) {
        log(level: .error, category: category, message: message, file: file, line: line)
    }
}
