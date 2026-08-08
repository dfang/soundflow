# Recording System Audio Muting Design

## Goal

Reduce background media leaking from Mac speakers into the microphone by muting the current system output only while SoundFlow is recording.

## Scope

- Mute system output after microphone permission is available and immediately before audio capture starts.
- Restore the exact prior output state as soon as microphone capture stops.
- Cover confirmation, cancellation, startup failure, dismissal, and error cleanup.
- Keep media playback running silently; do not send play/pause commands to media applications.
- Do not change the ASR, post-processing, HUD, or focused-app insertion paths.

The first version applies this behavior automatically to every recording. It does not add a preference or settings UI.

## Architecture

Add a focused `SystemAudioSilencer` service that owns one recording-scoped suppression session. `SoundFlowModel` coordinates that service alongside `AudioCaptureService`; audio capture remains responsible only for microphone input.

The service depends on a small output-device controlling protocol. The production implementation uses Core Audio to locate the default output device and read or write its mute and volume properties. Tests use an in-memory controller so lifecycle behavior can be verified without changing the developer machine's audio.

## Suppression Session

Starting suppression performs these steps:

1. Resolve the current default output device.
2. Read and retain its original mute state.
3. If the device exposes a settable mute property, set mute to `true`.
4. Otherwise, read and retain the output volume and set it to zero when that property is settable.
5. If neither operation is supported, return without failing recording.

Restoring suppression is idempotent. It writes the saved value back to the same device that was changed, then clears the saved session. If the output was already muted, the service records that state and leaves it muted on restore. Calling restore without an active session is a no-op.

Changing the default output device during an active recording is outside the first-version scope. The service restores only the device it modified at recording start.

## Recording Lifecycle

`SoundFlowModel.beginRecording()` requests microphone permission first so permission UI never leaves the system unexpectedly muted. It then starts suppression before starting microphone capture.

If audio capture or ASR initialization fails, the model restores system audio before showing the error.

On confirmation or cancellation, the model stops microphone capture and immediately restores system audio. Restoration does not wait for final ASR, text post-processing, HUD dismissal, or text insertion.

Defensive cleanup also restores audio when the HUD is dismissed, the model enters an error state, or the application receives its normal termination callback. Repeated restore calls are safe. A forced process kill or crash can prevent restoration; in that case the user can unmute the output through the standard macOS sound control.

## Error Handling

System-audio suppression is best effort and must never prevent recording. Unsupported devices and Core Audio read/write failures are logged, after which SoundFlow continues with normal microphone capture.

Restoration failures are logged with the affected device ID. They do not replace an existing ASR or insertion error. The service retains no stale in-memory session after a restore attempt, preventing a later recording from applying an obsolete snapshot.

## Testing

Unit tests cover:

- an unmuted device is muted and restored to unmuted;
- an already-muted device remains muted after restoration;
- a device without settable mute falls back to zero volume and restores its original volume;
- an unsupported device leaves output unchanged and does not fail;
- repeated start or restore calls do not corrupt the saved state;
- the service clears its active session after a restore attempt so a later recording never reuses an obsolete snapshot.

The complete Swift test suite and application build must pass. Manual verification covers confirmation, cancellation, audio-start failure where practical, and normal application termination while audible media plays through Mac speakers. Sound must disappear only during microphone capture and return immediately when capture stops.
