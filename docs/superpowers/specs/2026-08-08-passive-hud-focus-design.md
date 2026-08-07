# Passive HUD Focus Design

## Goal

Make SoundFlow's recording HUD behave like a passive voice-input overlay: showing the HUD, clicking its background, and clicking Cancel or Confirm must not activate SoundFlow or take keyboard focus from the current text field.

## Acceptance Criteria

- Showing the HUD does not change the macOS frontmost application.
- Ordinary typing while the HUD is visible continues to enter the previously focused text field.
- Clicking the HUD background, Cancel, or Confirm does not change the frontmost application or focused text field.
- Escape cancels recording and is not delivered to the focused application.
- Return and keypad Enter confirm recording and are not delivered to the focused application.
- All other keyboard events pass through unchanged.
- Settings and setup windows keep their existing activating-window behavior.

## Current Problem

`HUDWindowController.show()` calls `NSApp.activate(ignoringOtherApps:)` and `makeKeyAndOrderFront(_:)`, while `FloatingPanel.canBecomeKey` returns `true`. This intentionally makes SoundFlow active and the HUD key, so the original text field loses keyboard focus.

The current Escape and Enter behavior depends on an application-local `NSEvent` monitor and SwiftUI keyboard shortcuts. Those mechanisms only work because SoundFlow takes focus. Hiding the HUD does not restore the original focused accessibility element.

## Design

### Passive HUD Window

Create the HUD panel with the `.nonactivatingPanel` style in addition to `.borderless`. The panel cannot become key or main. Showing it uses `orderFrontRegardless()` and never calls `NSApp.activate(ignoringOtherApps:)` or `makeKeyAndOrderFront(_:)`.

The panel remains mouse-interactive, so SwiftUI Cancel and Confirm buttons continue to invoke model actions. The preview becomes display-only: remove `.textSelection(.enabled)` and the SwiftUI `.keyboardShortcut` modifiers so no HUD control requests keyboard focus.

### Global HUD Key Commands

Replace the HUD's local key-down monitor with a recording-scoped Core Graphics event tap. The tap is an active filter, not a listen-only monitor, because recognized commands must be consumed before they reach the focused application.

The event tap handles only:

- Escape: consume the event and dispatch cancellation to the main actor.
- Return or keypad Enter: consume the event and dispatch confirmation to the main actor.

Every other event is returned unchanged. The existing configurable global recording hotkey remains independent and unchanged.

Separate pure key-code routing from the event-tap lifecycle so command mapping can be unit-tested without synthesizing system input. The monitor starts when the model bootstraps and filters commands only while the HUD state permits them. If macOS disables the tap because of a timeout, it is re-enabled immediately.

### Confirmation Target

Because the passive HUD never becomes frontmost, the focused target application can be captured at confirmation time. This matches the product requirement that a user may switch applications while recording.

`TextOutputService` first checks whether the captured target is already frontmost. If so, it skips application activation and injects into the existing focused field. It retains the current activation retry only when the user changes applications during asynchronous finalization.

No accessibility focused-element restoration is needed on the normal path because SoundFlow never takes that focus.

## Data Flow

HUD presentation:

`Global hotkey -> start recording -> order passive panel front -> original app and text field remain focused`

Keyboard handling:

`Key event -> event tap -> Escape/Enter consumed and handled; every other key returned to the focused app`

Mouse confirmation:

`Click Confirm on passive panel -> capture still-frontmost target -> finalize ASR/post-processing -> inject into preserved target field`

Cancellation:

`Escape or Cancel click -> stop recording -> hide passive panel -> original field remains focused throughout`

## Error Handling

The event tap requires Accessibility permission, which SoundFlow already requires for text injection. Event-tap creation failure must not fall back to activating the HUD. The app keeps mouse Cancel/Confirm and the existing global recording hotkey available, logs the failure, and surfaces the existing Accessibility guidance rather than silently leaking Escape or Enter to the focused application.

An event-tap callback does no recording or model work directly. It schedules model actions on the main actor and returns immediately, reducing the chance that macOS disables the tap for timeout.

## Testing

Automated tests cover the smallest deterministic boundaries:

- the HUD panel has `.nonactivatingPanel` and cannot become key or main;
- Escape maps to cancel;
- Return and keypad Enter map to confirm;
- ordinary letter key codes do not map to a HUD command;
- inactive HUD states do not consume commands;
- an already-frontmost output target does not request application activation.

Tests must fail against the current implementation before production code changes. After implementation, run the focused tests, the full test suite, `swift build`, formatting/lint checks that exist in the repository, and `graphify update .`.

Manual acceptance testing uses TextEdit or another editable application:

1. Focus a text field and summon the HUD; type ordinary letters and confirm they enter the field.
2. Click HUD background, Cancel, and Confirm; confirm the macOS active application does not change.
3. Press Escape; confirm recording cancels and the focused application does not receive Escape.
4. Press Enter; confirm recording commits without inserting an extra newline.
5. Repeat after switching applications during recording.

## Non-Goals

- selectable or editable preview text;
- keyboard navigation inside the HUD;
- changing the settings or setup window activation model;
- adding accessibility-element focus restoration to compensate for a focus steal;
- changing ASR, post-processing, audio capture, or HUD visual design.
