import AppKit
import Carbon
import SwiftUI

@MainActor
final class SoundFlowModel: ObservableObject {
    static let shared = SoundFlowModel(runtime: .default)

    @Published private(set) var phase: RecordingPhase = .idle
    @Published private(set) var previewText = "Press Right Control to start speaking."
    @Published private(set) var audioLevel = 0.0
    @Published private(set) var lastCommittedText = ""
    @Published private(set) var errorMessage: String?
    @Published private(set) var isHUDVisible = false
    @Published private(set) var asrBackendName: String
    @Published private(set) var postProcessorName: String
    @Published private(set) var asrModelName: String
    @Published private(set) var asrModelSource: String
    @Published private(set) var postProcessorModelName: String

    private let permissionManager = PermissionManager()
    private let audioCaptureService = AudioCaptureService()
    private let textOutputService = TextOutputService()
    private let runtime: AppRuntime
    private let transcriptionService: any TranscriptionService
    private let postProcessor: any TextPostProcessing

    private var hotKeyService: GlobalHotKeyService?
    private var hudController: HUDWindowController?
    private var keyMonitor: Any?
    private var didBootstrap = false
    private var targetApplication: NSRunningApplication?

    private init(runtime: AppRuntime) {
        self.runtime = runtime
        self.transcriptionService = runtime.transcriptionService
        self.postProcessor = runtime.postProcessor
        self.asrBackendName = runtime.configuration.asrBackend.rawValue
        self.postProcessorName = runtime.configuration.postProcessorBackend.rawValue
        self.asrModelName = runtime.configuration.selectedASRModel.displayName
        self.asrModelSource = runtime.configuration.selectedASRModel.source.displayName
        self.postProcessorModelName = runtime.configuration.selectedPostProcessorModel.displayName

        audioCaptureService.onLevel = { [weak self] level in
            self?.audioLevel = level
        }

        audioCaptureService.onSamples = { [weak self] samples, sampleRate in
            self?.transcriptionService.appendAudio(samples: samples, sampleRate: sampleRate)
        }

        transcriptionService.onPreview = { [weak self] text in
            self?.previewText = text
        }
    }

    func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true

        hudController = HUDWindowController(model: self)
        installKeyMonitor()

        do {
            let hotKeyService = GlobalHotKeyService()
            hotKeyService.onTrigger = { [weak self] in
                DispatchQueue.main.async {
                    self?.handleHotKey()
                }
            }
            try hotKeyService.start()
            self.hotKeyService = hotKeyService
        } catch {
            setError("Failed to register Right Control hotkey: \(error.localizedDescription)")
        }
    }

    var menuBarTitle: String {
        switch phase {
        case .idle:
            return "SoundFlow"
        case .recording:
            return "Recording"
        case .processing:
            return "Processing"
        case .committing:
            return "Committing"
        case .error:
            return "Error"
        }
    }

    var menuBarSymbol: String {
        switch phase {
        case .idle:
            return "waveform"
        case .recording:
            return "mic.fill"
        case .processing, .committing:
            return "hourglass"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    var phaseLabel: String {
        switch phase {
        case .idle:
            return "Idle"
        case .recording:
            return "Listening"
        case .processing:
            return "Finalizing ASR"
        case .committing:
            return "Cleaning Up Text"
        case .error:
            return "Needs Attention"
        }
    }

    var phaseColor: Color {
        switch phase {
        case .idle:
            return .secondary
        case .recording:
            return .green
        case .processing:
            return .orange
        case .committing:
            return .blue
        case .error:
            return .red
        }
    }

    var primaryActionTitle: String {
        phase == .recording ? "Confirm" : "Close"
    }

    var secondaryActionTitle: String {
        phase == .recording ? "Cancel" : "Dismiss"
    }

    var shouldShowAudioMeter: Bool {
        phase == .recording
    }

    var runtimeSummary: String {
        "\(asrBackendName) -> \(postProcessorName)"
    }

    func handleHotKey() {
        switch phase {
        case .idle, .error:
            Task {
                await beginRecording()
            }
        case .recording:
            commitRecording()
        case .processing, .committing:
            break
        }
    }

    func beginRecordingFromUI() {
        Task {
            await beginRecording()
        }
    }

    func commitRecordingFromUI() {
        commitRecording()
    }

    func cancelRecordingFromUI() {
        cancelRecording()
    }

    func dismissHUD() {
        setPhase(.idle)
        errorMessage = nil
        targetApplication = nil
        hideHUD()
        previewText = "Press Right Control to start speaking."
    }

    private func beginRecording() async {
        errorMessage = nil
        lastCommittedText = ""
        targetApplication = captureCurrentTargetApplication()

        let microphoneGranted = await permissionManager.requestMicrophonePermission()
        guard microphoneGranted else {
            setError("Microphone permission is required before recording.")
            return
        }

        do {
            try audioCaptureService.start()
        } catch {
            setError("Failed to start audio capture: \(error.localizedDescription)")
            return
        }

        do {
            try transcriptionService.start()
        } catch {
            audioCaptureService.stop()
            setError("Failed to initialize ASR: \(error.localizedDescription)")
            return
        }

        previewText = "Listening..."
        audioLevel = 0
        setPhase(.recording)
        showHUD()
    }

    private func commitRecording() {
        guard phase == .recording else { return }

        setPhase(.processing)
        audioCaptureService.stop()

        Task {
            do {
                let rawText = try await transcriptionService.stop()
                let processedText = await postProcessor.process(rawText)
                await MainActor.run {
                    self.finishCommit(with: processedText)
                }
            } catch {
                await MainActor.run {
                    self.setError("ASR failed: \(error.localizedDescription)")
                    self.scheduleHUDDismiss(after: 2.0)
                }
            }
        }
    }

    private func finishCommit(with text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            setError("No speech detected.")
            scheduleHUDDismiss(after: 1.4)
            return
        }

        setPhase(.committing)
        lastCommittedText = trimmed
        previewText = trimmed

        hideHUD()

        let result = textOutputService.output(
            trimmed,
            targetApplication: targetApplication,
            promptForAccessibility: true
        )

        switch result {
        case .pasted:
            setPhase(.idle)
            previewText = "Press Right Control to start speaking."
            errorMessage = nil
            targetApplication = nil
        case .copiedToClipboard:
            setError("Copied to clipboard. Grant Accessibility permission to auto-paste.")
            scheduleHUDDismiss(after: 2.0)
        }
    }

    private func cancelRecording() {
        if phase == .recording {
            audioCaptureService.stop()
            transcriptionService.cancel()
        }

        setPhase(.idle)
        previewText = "Cancelled."
        audioLevel = 0
        scheduleHUDDismiss(after: 0.2)
    }

    private func setError(_ message: String) {
        errorMessage = message
        previewText = message
        setPhase(.error)
        showHUD()
    }

    private func setPhase(_ newPhase: RecordingPhase) {
        phase = newPhase
        if newPhase != .recording {
            audioLevel = 0
        }
    }

    private func showHUD() {
        isHUDVisible = true
        hudController?.show()
    }

    private func hideHUD() {
        isHUDVisible = false
        hudController?.hide()
    }

    private func captureCurrentTargetApplication() -> NSRunningApplication? {
        let app = NSWorkspace.shared.frontmostApplication
        guard app != .current else { return nil }
        return app
    }

    private func scheduleHUDDismiss(after delay: TimeInterval) {
        showHUD()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            self.hideHUD()
            if self.phase == .idle {
                self.previewText = "Press Right Control to start speaking."
                self.errorMessage = nil
            }
        }
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isHUDVisible else { return event }

            switch Int(event.keyCode) {
            case Int(kVK_Escape):
                self.cancelRecording()
                return nil
            case Int(kVK_Return), Int(kVK_ANSI_KeypadEnter):
                if self.phase == .recording {
                    self.commitRecording()
                    return nil
                }
                if self.phase == .error {
                    self.dismissHUD()
                    return nil
                }
                return event
            default:
                return event
            }
        }
    }
}

enum RecordingPhase: String {
    case idle
    case recording
    case processing
    case committing
    case error
}
