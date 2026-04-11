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
    @Published private(set) var showSuccess = false
    @Published private(set) var commitFeedbackToken = 0
    @Published private(set) var asrBackendName: String
    @Published private(set) var postProcessorName: String
    @Published private(set) var asrModelName: String
    @Published private(set) var asrModelSource: String
    @Published private(set) var postProcessorModelName: String
    @Published private(set) var postProcessingStatus = "Idle"

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
    private var pendingCommitWorkItem: DispatchWorkItem?
    private var postProcessingObserver: Any?

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

        postProcessingObserver = NotificationCenter.default.addObserver(
            forName: .postProcessingDecisionDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let decision = notification.userInfo?["decision"] as? String ?? "Unknown"
            let reason = notification.userInfo?["reason"] as? String ?? "n/a"
            Task { @MainActor [weak self] in
                self?.postProcessingStatus = "\(decision): \(reason)"
            }
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
        requestCommitWithFeedback()
    }

    func cancelRecordingFromUI() {
        cancelRecording()
    }

    func dismissHUD() {
        cancelPendingCommit()
        setPhase(.idle)
        errorMessage = nil
        showSuccess = false
        targetApplication = nil
        hideHUD()
        previewText = "Press Right Control to start speaking."
        postProcessingStatus = "Idle"
    }

    private func beginRecording() async {
        cancelPendingCommit()
        errorMessage = nil
        lastCommittedText = ""
        showSuccess = false
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
        postProcessingStatus = "Idle"
        setPhase(.recording)
        showHUD()
    }

    private func commitRecording() {
        guard phase == .recording else { return }
        cancelPendingCommit()

        setPhase(.processing)
        postProcessingStatus = "正在整理文本..."
        audioCaptureService.stop()

        Task {
            do {
                let rawText = try await transcriptionService.stop()

                await MainActor.run {
                    self.previewText = "AI 正在润色..."
                    self.postProcessingStatus = "AI 正在润色..."
                    self.setPhase(.committing)
                }

                let stream = postProcessor.processStream(rawText: rawText)
                var optimizedText = ""
                for try await token in stream {
                    optimizedText += token
                    let snapshot = optimizedText
                    await MainActor.run {
                        if !snapshot.isEmpty {
                            self.previewText = snapshot
                        }
                    }
                }

                let finalText = optimizedText.trimmingCharacters(in: .whitespacesAndNewlines)

                await MainActor.run {
                    guard !finalText.isEmpty else {
                        self.setError("No speech detected.")
                        self.scheduleHUDDismiss(after: 1.4)
                        return
                    }

                    let result = self.textOutputService.output(
                        finalText,
                        targetApplication: self.targetApplication,
                        promptForAccessibility: true
                    )

                    switch result {
                    case .inserted:
                        self.finishCommitStatusOnly(with: finalText)
                    case .accessibilityUnavailable:
                        self.setError("Accessibility permission is required before inserting text.")
                        self.scheduleHUDDismiss(after: 2.0)
                    case .injectionFailed:
                        self.setError("Direct text injection failed for the focused field.")
                        self.scheduleHUDDismiss(after: 2.0)
                    }
                }
            } catch {
                await MainActor.run {
                    self.setError("ASR failed: \(error.localizedDescription)")
                    self.scheduleHUDDismiss(after: 2.0)
                }
            }
        }
    }

    private func finishCommitStatusOnly(with text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        setPhase(.committing)
        lastCommittedText = trimmed
        previewText = trimmed
        showSuccess = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            self.hideHUD()
            self.showSuccess = false
            self.setPhase(.idle)
            self.previewText = "Press Right Control to start speaking."
            self.postProcessingStatus = "Idle"
            self.errorMessage = nil
            self.targetApplication = nil
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

        // Only handle success HUD state, paste logic now handled in commitRecording
        showSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            self.hideHUD()
            self.showSuccess = false
            self.setPhase(.idle)
            self.previewText = "Press Right Control to start speaking."
            self.postProcessingStatus = "Idle"
            self.errorMessage = nil
            self.targetApplication = nil
        }
    }

    private func cancelRecording() {
        cancelPendingCommit()
        if phase == .recording {
            audioCaptureService.stop()
            transcriptionService.cancel()
        }

        setPhase(.idle)
        showSuccess = false
        previewText = "Cancelled."
        postProcessingStatus = "Idle"
        audioLevel = 0
        scheduleHUDDismiss(after: 0.2)
    }

    private func setError(_ message: String) {
        cancelPendingCommit()
        errorMessage = message
        showSuccess = false
        previewText = message
        postProcessingStatus = "Idle"
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
                self.postProcessingStatus = "Idle"
                self.errorMessage = nil
            }
        }
    }

    private func requestCommitWithFeedback() {
        guard phase == .recording else { return }
        self.commitRecording()
    }

    private func cancelPendingCommit() {
        pendingCommitWorkItem?.cancel()
        pendingCommitWorkItem = nil
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
                    self.requestCommitWithFeedback()
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
