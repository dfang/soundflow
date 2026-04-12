import AppKit
import Carbon
import SwiftUI

struct KeyRecorderView: View {
    @Binding var configuration: HotKeyConfiguration
    @State private var isRecording = false
    @State private var eventMonitor: Any?

    var body: some View {
        Button(action: {
            if isRecording { stopRecording() } else { startRecording() }
        }) {
            HStack(spacing: 8) {
                Text(isRecording ? "Press keys..." : configuration.displayString)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(isRecording ? .accentColor : .primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.black.opacity(0.3))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard self.isRecording else { return event }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard event.keyCode != 0 || flags.contains(.function) else { return nil }

            configuration = HotKeyConfiguration.from(event: event)
            self.stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        isRecording = false
    }
}
