import SwiftUI

struct HUDView: View {
    @ObservedObject var model: SoundFlowModel
    @State private var commitFlash = false
    @State private var hudScale: CGFloat = 1.0
    @State private var hudOpacity: CGFloat = 1.0

    private let bottomAnchorID = "hud-preview-bottom"
    private let hudCornerRadius: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Label(model.phaseLabel, systemImage: model.menuBarSymbol)
                        .font(.headline)
                        .foregroundStyle(model.phaseColor)

                    processingOverlay
                }

                Spacer()

                Text("Right Ctrl")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.12), in: Capsule())
            }

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    Text(model.previewText)
                        .font(.system(size: 21, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .textSelection(.enabled)

                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchorID)
                }
                .frame(maxWidth: .infinity, minHeight: 74, maxHeight: 118, alignment: .topLeading)
                .onAppear {
                    proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                }
                .onChange(of: model.previewText) { _, _ in
                    withAnimation(.easeOut(duration: 0.16)) {
                        proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                    }
                }
            }

            HStack {
                Text(model.phase == .recording ? "Enter confirm, Esc cancel" : model.postProcessingStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(model.secondaryActionTitle) {
                    if model.phase == .recording {
                        model.cancelRecordingFromUI()
                    } else {
                        model.dismissHUD()
                    }
                }
                .keyboardShortcut(.cancelAction)

                Button(model.primaryActionTitle) {
                    if model.phase == .recording {
                        model.commitRecordingFromUI()
                    } else {
                        model.dismissHUD()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.phase != .recording && model.phase != .error)
            }
        }
        .padding(20)
        .frame(width: 620)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: hudCornerRadius, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: hudCornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 28, x: 0, y: 16)
        .scaleEffect(hudScale)
        .opacity(hudOpacity)
        .overlay(successOverlay)
        .onChange(of: model.commitFeedbackToken) { _, _ in
            animateCommitFeedback()
        }
        .onChange(of: model.showSuccess) { _, showSuccess in
            withAnimation(.easeInOut(duration: 0.18)) {
                hudOpacity = showSuccess ? 0.92 : 1.0
                hudScale = showSuccess ? 0.985 : 1.0
            }
        }
    }

    @ViewBuilder
    private var processingOverlay: some View {
        if model.phase == .processing || model.phase == .committing {
            Circle()
                .trim(from: 0, to: 0.3)
                .stroke(model.phaseColor, lineWidth: 2)
                .frame(width: 14, height: 14)
                .rotationEffect(.degrees(commitFlash ? 360 : 0))
                .onAppear {
                    withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                        commitFlash = true
                    }
                }
                .onDisappear {
                    commitFlash = false
                }
        }
    }

    @ViewBuilder
    private var successOverlay: some View {
        if model.showSuccess {
            ZStack {
                Color.black.opacity(0.4)
                    .clipShape(RoundedRectangle(cornerRadius: hudCornerRadius, style: .continuous))

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            }
            .allowsHitTesting(false)
        }
    }

    private func animateCommitFeedback() {
        withAnimation(.easeInOut(duration: 0.12)) {
            hudScale = 1.012
            hudOpacity = 0.97
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeInOut(duration: 0.12)) {
                hudScale = 1.0
                if !model.showSuccess {
                    hudOpacity = 1.0
                }
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.13, blue: 0.18),
                Color(red: 0.14, green: 0.17, blue: 0.23)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
