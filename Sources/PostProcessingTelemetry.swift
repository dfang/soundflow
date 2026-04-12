import Foundation

enum PostProcessingDecision: String {
    case skipped = "Skipped"
    case triggered = "Triggered"
    case fallback = "Fallback"
}

extension Notification.Name {
    static let postProcessingDecisionDidChange = Notification.Name("postProcessingDecisionDidChange")
}

enum PostProcessingTelemetry {
    static func record(_ decision: PostProcessingDecision, reason: String) {
        NotificationCenter.default.post(
            name: .postProcessingDecisionDidChange,
            object: nil,
            userInfo: [
                "decision": decision.rawValue,
                "reason": reason
            ]
        )
    }
}
