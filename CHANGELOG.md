# Changelog

All notable changes to this project will be documented in this file.

## [0.3] - 2026-08-19

### 🚀 Features

- Add dictionary-based text post-processing as LLM fallback
- Add debug logging and graphify tooling
- Add global HUD key command monitor
- Mute system audio while recording
- Improve mixed-language speech recognition

### 🐛 Bug Fixes

- Enable streaming output from LLM post-processor
- Allow Right Ctrl to confirm recording like Enter
- Correct swiftlint rule names and sections
- Avoid routine punctuation in post-processing
- Discard partial DeepSeek output on failure
- Require DeepSeek completion marker
- Strip trailing period from SenseVoice output
- Keep input focus while HUD is visible
- Preserve focused target during HUD commit
- Normalize SenseVoice audio pipeline

### 💼 Other

- Split app bundle build into shared script, add one-click install
- Sign app with Apple Development certificate

### 📚 Documentation

- Define conservative punctuation behavior
- Add conservative punctuation implementation plan
- Design passive HUD focus behavior
- Plan passive HUD focus implementation
- Design recording-time system audio muting

### 🎨 Styling

- Sort passive HUD test imports
## [0.2] - 2026-04-12

### 🚀 Features

- Optimize post-processing latency with stream-based processing
- Optimize post-processing latency with stream-based processing
- *(ui)* 重构设置界面为卡片布局 (#4)

### 🐛 Bug Fixes

- Fix .swiftformat and lock swiftformat and swiftlint versions via mise

### 💼 Other

- Fix HUD corner clipping
- Improve HUD preview responsiveness by lowering VAD and preview thresholds
- Gate post-processing to avoid unnecessary model calls
- Show post-processing decisions in the HUD

### 🚜 Refactor

- Improve Deepseek post-processor examples with better diversity

### ⚙️ Miscellaneous Tasks

- Add packaging scripts and update gitignore for build output
- Add release workflow for DMG builds on tag push (#3)
## [0.1] - 2026-04-09

### 🚀 Features

- Add sherpa-onnx SenseVoice transcription infrastructure
- Implement HUD UI and transcription infrastructure

### 💼 Other

- Build macOS MVP app scaffold
