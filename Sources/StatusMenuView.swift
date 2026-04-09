import AppKit
import SwiftUI

struct StatusMenuView: View {
    @ObservedObject var model: SoundFlowModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SoundFlow")
                    .font(.headline)
                Text(model.phaseLabel)
                    .font(.subheadline)
                    .foregroundStyle(model.phaseColor)
            }

            Divider()

            Button(model.phase == .recording ? "Confirm Current Input" : "Start Recording") {
                if model.phase == .recording {
                    model.commitRecordingFromUI()
                } else {
                    model.beginRecordingFromUI()
                }
            }

            Button("Cancel") {
                model.cancelRecordingFromUI()
            }
            .disabled(model.phase != .recording)

            Divider()

            SettingsLink {
                Text("Settings")
            }

            Button("Quit SoundFlow") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, 4)
        .frame(width: 240)
    }
}
