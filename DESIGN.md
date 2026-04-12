# DESIGN.md

1. Overview

This document defines the design principles, structure, and interaction patterns for the macOS application, with a focus on:
• Setup Guide UI (Onboarding / First-run experience)
• Settings UI (Persistent configuration and preferences)

The goal is to create a native-feeling, minimal, fast, and intuitive macOS experience.

⸻

2. Design Principles

2.1 Native First
• Follow macOS Human Interface Guidelines
• Prefer system components (e.g., NavigationSplitView, Form, Toggle)
• Avoid over-design (no heavy custom UI unless necessary)

2.2 Progressive Disclosure
• Show only what’s necessary at each step
• Advanced options should be hidden behind:
• “Advanced”
• “Show More”

2.3 Fast Feedback
• Every action should produce immediate feedback
• Use:
• Inline validation
• Status indicators
• Toasts / subtle alerts

2.4 Stateless UI, Stateful Model
• UI should reflect state, not manage it
• Use a centralized state model (e.g., ObservableObject / Store)

⸻

3. Information Architecture

App
├── Setup Guide (first launch or reset)
│ ├── Welcome
│ ├── Permissions
│ ├── Core Configuration
│ ├── Optional Features
│ └── Completion
│
└── Main App
├── Dashboard (optional)
└── Settings
├── General
├── Account / API
├── Features
├── Advanced
└── About

⸻

4. Setup Guide UI

4.1 Goals
• Get user from 0 → usable as fast as possible
• Avoid overwhelming users
• Ensure required dependencies are configured

⸻

4.2 Structure

Step 1: Welcome
Purpose: Orientation

Content:
• App name + short value proposition
• “What you’ll set up” (3–4 bullets)

Actions:
• Continue
• Skip (not recommended) (optional)

⸻

Step 2: Permissions
Examples:
• Microphone
• Accessibility (for input injection)
• File access

Design:
• Each permission = card/block
• Show:
• Why it’s needed
• Current status (Granted / Not Granted)

Actions:
• Grant
• Auto-refresh status

⸻

Step 3: Core Configuration
Examples:
• API Key input
• Model selection
• Default behavior

UI:
• Use Form
• Inline validation

Patterns:
• Invalid → red hint text
• Valid → subtle checkmark

⸻

Step 4: Optional Features
Examples:
• Auto-start at login
• Advanced AI features
• Experimental toggles

Design:
• Clearly labeled as optional
• Default: OFF

⸻

Step 5: Completion
Content:
• “You’re ready”
• Summary of configuration

Actions:
• Start Using App
• Open Settings

⸻

4.3 Navigation Pattern
• Horizontal step flow OR sidebar step list
• Show progress:
• Step indicator (e.g., 2/5)
• Or sidebar highlight

⸻

4.4 State Model Example

class SetupState: ObservableObject {
@Published var currentStep: Step = .welcome
@Published var permissions: PermissionsState
@Published var config: ConfigState
@Published var isComplete: Bool = false
}

⸻

5. Settings UI

5.1 Goals
• Easy to scan
• Minimal friction for frequent changes
• Logical grouping

⸻

5.2 Layout

Use macOS standard Settings style:
• Sidebar (left)
• Detail panel (right)

NavigationSplitView {
Sidebar()
} detail: {
SettingsDetailView()
}

⸻

5.3 Sections

5.3.1 General
• Launch at login
• Default behavior
• UI preferences

⸻

5.3.2 Account / API
• API keys
• Endpoint configuration
• Validation status

⸻

5.3.3 Features
• Feature toggles
• Model selection
• Behavior tuning

⸻

5.3.4 Advanced
• Debug mode
• Logs
• Experimental features

⸻

5.3.5 About
• Version
• License
• Links

⸻

5.4 Component Patterns

Toggles

Toggle("Enable Feature", isOn: $viewModel.enabled)

Input Fields
• Use placeholders
• Show validation inline

Dropdowns
• Keep options small and meaningful

Sections

Form {
Section("General") {
Toggle(...)
}
}

⸻

5.5 Persistence
• Use:
• UserDefaults (simple settings)
• Keychain (sensitive data like API keys)

Example:

@AppStorage("launchAtLogin") var launchAtLogin: Bool = false

⸻

6. Interaction Patterns

6.1 Validation
• Real-time validation preferred
• Avoid blocking “Save” unless necessary

⸻

6.2 Error Handling
• Inline > modal
• Be specific:
• ❌ “Error occurred”
• ✅ “Invalid API key format”

⸻

6.3 Feedback
• Use subtle animations
• Avoid intrusive alerts unless critical

⸻

7. Visual Design

7.1 Style
• Clean, minimal
• System fonts (SF Pro)
• Respect light/dark mode

⸻

7.2 Spacing
• Use consistent padding (8pt grid)
• Avoid dense layouts

⸻

7.3 Icons
• Use SF Symbols
• Keep meaning obvious

⸻

8. Accessibility
   • Support VoiceOver
   • Ensure:
   • Labels for all controls
   • Keyboard navigation
   • Avoid color-only signals

⸻

9. Future Extensions
   • Sync settings via cloud
   • Profiles (multiple configs)
   • Import/export configuration
   • Reset Setup Guide

⸻

10. Open Questions
    • Should setup be skippable entirely?
    • Do we support multi-account?
    • How advanced should “Advanced” be?
