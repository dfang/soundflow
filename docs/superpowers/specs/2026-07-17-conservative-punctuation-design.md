# Conservative Punctuation Design

## Goal

Keep SoundFlow behaving like an input tool: post-processing may add punctuation only when the unpunctuated text would otherwise be clearly ambiguous. It must not routinely append sentence-ending punctuation.

## Current Problem

The default post-processor is DeepSeek behind `SmartPostProcessor`. When DeepSeek is unavailable, errors, or returns no streamed content, `DeepseekPostProcessor` falls back to `MockPostProcessor`. That fallback always appends `。` or `.` when the input has no terminal punctuation. When DeepSeek is available, its prompt also broadly asks the model to add missing punctuation and demonstrates routine comma and full-stop insertion.

## Design

Use two complementary constraints:

1. Change the DeepSeek system prompt to preserve the input's punctuation by default. It may add punctuation only when doing so resolves clear ambiguity, and it must not automatically append terminal punctuation.
2. On missing credentials, HTTP failure, stream failure, or empty model output, return the trimmed original text. Do not route failure handling through `MockPostProcessor`.

The existing `SmartPostProcessor` gating remains unchanged. SenseVoice recognition, dictionary replacements, streaming preview, and text insertion remain unchanged.

## Data Flow

Successful model path:

`Final ASR text -> DictionaryPostProcessor -> SmartPostProcessor -> DeepSeek with conservative prompt -> Output`

Failure path:

`Final ASR text -> DictionaryPostProcessor -> SmartPostProcessor -> DeepSeek unavailable/fails -> unchanged input -> Output`

## Error Handling

Post-processing remains best-effort. Every DeepSeek failure mode returns the original trimmed text, preserving the current user input and avoiding invented punctuation or content. No new error UI or retry behavior is introduced.

## Testing

Add a Swift test target if needed and cover the behavior at the smallest practical boundary:

- fallback preserves Chinese text without adding `。`;
- fallback preserves English text without adding `.`;
- fallback preserves existing punctuation unchanged;
- the prompt explicitly prohibits routine terminal punctuation and permits additions only to resolve clear ambiguity.

Tests must fail against the current implementation before production code is changed. After the fix, run the focused tests, the full test suite, `swift build`, formatting, and lint checks.

## Non-Goals

- changing SenseVoice or inverse text normalization;
- changing SmartPostProcessor trigger thresholds;
- removing punctuation already present in ASR output;
- adding a punctuation preference setting;
- changing the real-time preview path.
