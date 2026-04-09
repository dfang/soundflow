# SoundFlow Agent Notes

## Project Goal

SoundFlow is a macOS local voice input tool.

The v1 goal is a fast, reliable voice-to-text input loop:

- global hotkey
- start recording
- bottom HUD live preview
- confirm and insert text into the current focused app

This project is an input tool first, not a writing assistant.

## Fixed Product Decisions

Unless the user explicitly changes direction, treat the following as fixed:

- main platform: macOS on Apple Silicon
- inference backend: `MLX`
- ASR model: `SenseVoice Small`
- text post-processing model: `Gemma 4 E4B`
- main interaction UI: bottom-centered floating HUD
- menu bar app is only for status and settings, not the main live interaction surface
- real-time preview must not depend on Gemma
- Gemma runs only after final ASR text is available

## Core Pipeline

Default pipeline:

`Mic -> Light VAD -> SenseVoice Small -> Final ASR Text -> Gemma 4 E4B -> Output`

Execution rules:

- real-time preview uses only `VAD + ASR`
- Gemma is used only for final text cleanup at commit time
- if Gemma fails, fall back to raw final ASR text

## Non-Goals

Do not drift the project toward these unless the user explicitly asks:

- chat assistant behavior
- heavy rewriting, expansion, summarization, translation
- cloud-first architecture
- complex settings before the core loop works
- full system input method integration

## Implementation Priorities

Prioritize work in this order:

1. global hotkey
2. microphone capture
3. local ASR
4. bottom HUD live preview
5. confirm/cancel flow
6. insert text into focused app
7. Gemma post-processing
8. optional enhancements like auto-end, settings, shortcut customization

Prefer end-to-end usability over premature abstraction.
Prefer low latency and stability over feature breadth.

## Text Post-Processing Rules

When working on Gemma post-processing:

- preserve user meaning
- prefer the smallest possible edit
- if uncertain, keep the original text
- do not invent names, numbers, dates, or intent
- do not use Gemma in the streaming preview path

Follow the local reference docs for detailed behavior.

## Local Reference Docs

The following files are local development guidance and should not be treated as committed product docs:

- [.local/prd.md](/Users/fang/code/dfang/soundflow/.local/prd.md)
- [.local/asr-postprocess-spec.md](/Users/fang/code/dfang/soundflow/.local/asr-postprocess-spec.md)
- [.local/postprocess.txt](/Users/fang/code/dfang/soundflow/.local/postprocess.txt)

Rules:

- `.local/` content is for local development reference
- do not move `.local/` docs into committed project docs unless the user asks
- do not assume `.local/` files should be staged or committed

## Editing Rules

- keep changes minimal and targeted
- avoid adding dependencies unless they materially help the core loop
- avoid broad refactors before the core product path works
- when product direction and implementation detail conflict, optimize for the v1 input loop
- if a change weakens latency or reliability, call that out explicitly
