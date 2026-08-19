# SoundFlow

<p align="center">
  <strong>🔥 The Ultimate Local Voice Input Tool for Vibe Coding & Blazing-Fast Thought on macOS</strong>
</p>

<p align="center">
  <em>Typing too slow to keep up with your brainstorms? Tired of waiting for cloud AI tools to "Thinking..." and hitting monthly word limits?</em><br>
  <strong>Words appear as you speak with real-time live preview — let your thoughts flow directly into code.</strong>
</p>

<p align="center">
  <a href="./README.md">简体中文</a> | <a href="./README_EN.md">English</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2014.0%2B-blue?logo=apple" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Architecture-Apple%20Silicon%20(arm64)-black" alt="Apple Silicon">
  <img src="https://img.shields.io/badge/RAM%20Usage-~1%20Browser%20Tab-brightgreen" alt="RAM Usage">
  <img src="https://img.shields.io/badge/Model%20Size-~300MB%20(Quantized)-blue" alt="Model Size">
  <img src="https://img.shields.io/badge/Preview-Realtime%20Streaming-orange" alt="Realtime Streaming">
  <img src="https://img.shields.io/badge/Status-100%25%20Offline%20%26%20Unlimited-success" alt="Offline & Unlimited">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License">
</p>

---

## ⚡ Why SoundFlow?

In the era of **Vibe Coding**, the bottleneck in software development is no longer typing code — it is **the speed at which you can express your thoughts to AI**.

Existing cloud-based AI voice tools (like Typeless and others) suffer from critical drawbacks:
- ⏳ **Black-Box Waiting & Flow Breakers**: Blank screen while speaking, followed by several seconds of a spinning "Thinking..." animation;
- 💸 **Subscription Traps**: Harsh monthly word/token limits unless you pay expensive recurring subscriptions;
- ☁️ **Privacy Hazards**: Streaming your private business logic, proprietary code, and prompts to third-party servers;
- 🛑 **Focus Stealing**: UI popups that hijack window focus and misplace your active editor cursor.

### 🚀 SoundFlow Changes the Game:

| Feature | Traditional Cloud Voice Tools (Typeless, etc.) | **SoundFlow** |
| :--- | :--- | :--- |
| **Live Preview** | ❌ Black-box recording; nothing shows until done | ⚡ **Real-time streaming text as you speak** — what you say is what you see |
| **Response Speed** | 🐢 Uploads to cloud, multi-second "Thinking..." delay | 🚀 **Pure local sub-second response**, text is ready the instant you finish |
| **Memory Footprint** | ☁️ Heavy background process / electron overhead | 🪶 **Ultra-lightweight, RAM usage roughly equals just ~1 browser tab** |
| **Model Size** | ☁️ Heavy server-side dependencies | 📦 **Quantized to only ~300MB**, minimal disk and battery usage |
| **Usage Cost** | 💳 Strict monthly word caps, pricey subscriptions | 🆓 **100% Free Forever, Unlimited Words, Zero Token Anxiety** |
| **Privacy & Security** | ⚠️ Audio & sensitive code sent to external cloud | 🔒 **100% On-Device & Offline**, your voice never leaves your Mac |
| **Flow State** | ❌ Steals window focus, interrupts coding rhythm | ✅ **Non-activating floating HUD**, smoothly injects into any editor |

---

## 🎯 Built for the Vibe Coding Experience

- 🌊 **Words As You Speak (Real-time Live Preview)**: **The ultimate game-changer!** Words stream onto the bottom floating HUD in real-time as you speak. No more guessing or blind recording.
- 🪶 **Featherweight RAM Footprint**: The quantized model is only ~300MB, and runtime RAM consumption is **comparable to just a single browser tab**. It quietly runs in the background without fighting your IDE, Docker, or compilers for RAM.
- 🎙️ **Speak Prompts at Full Speed**: Instantly dictate complex prompts into Cursor, Windsurf, VS Code, or terminal without taking your hands off the keyboard.
- 🖥️ **Non-Intrusive Floating HUD**: A discreet bottom waveform and streaming live preview that never steals focus from your active coding window.
- ⌨️ **Instant Keystroke Injection**: Press hotkey to speak, hit `Enter` / `Right Ctrl` to instantly insert text at the cursor, or tap `Esc` to cancel.
- 📖 **Developer-Tuned Dictionary**: Smart mixed English/Chinese and tech term corrections for camelCase, code symbols, and jargon.

---

## 🔄 Core Pipeline

```text
[ 🎙️ Microphone Capture ]
        │
        ▼
[ ⚡ Lightweight VAD (Voice Activity Detection) ]
        │
        ▼
[ 🚀 sherpa-onnx + SenseVoice (Quantized Model ~300MB) ]
        │
        ▼ (Live text streaming as you speak ⚡)
[ 🖥️ Non-Activating Floating HUD (Streaming Preview) ]
        │ (Press Enter / Right Ctrl to commit)
        ▼
[ 🛠️ Developer Dictionary & Smart Gating ] ─── (Optional Local Gemma / DeepSeek Refinement)
        │
        ▼
[ 🎯 Direct Keystroke Injection at Cursor (Cursor / VS Code / Terminal) ]
```

---

## 📋 System Requirements

- **OS**: macOS 14.0 (Sonoma) or newer
- **Architecture**: Apple Silicon (M1 / M2 / M3 / M4 chips)
- **Permissions**:
  - 🎤 **Microphone Access**: For local audio capture.
  - ♿ **Accessibility Permission**: For listening to global hotkeys and injecting text at your cursor.

---

## 🚀 Quick Start in 30 Seconds

### 1. One-Click Build & Install

Make sure Xcode Command Line Tools and Swift are installed:

```bash
# 1. Clone repo
git clone https://github.com/dfang/soundflow.git
cd soundflow

# 2. Build and install to /Applications
./scripts/install.sh
```

Launch SoundFlow:
```bash
open /Applications/SoundFlow.app
```

### 2. First-Run Setup

A setup wizard will guide you through:
1. Granting **Microphone** and **Accessibility** permissions.
2. Confirming the built-in quantized SenseVoice model is ready.
3. Choosing your preferred hotkey (defaults to `Right Option`).

### 3. Start Coding with Your Voice

1. Focus on any editor (**Cursor**, **VS Code**, **Terminal**, etc.).
2. Hold or press your global hotkey and speak your prompt.
3. Watch the floating HUD **transcribe live as you speak**; press `Enter` or `Right Ctrl` to inject!

---

## 🛠️ Development & Building

```bash
# Run tests
swift test

# Build Release App Bundle (output to dist/SoundFlow.app)
./scripts/build_app.sh

# Package DMG installer
./scripts/package_dmg.sh

# Code format and lint
swiftformat .
swiftlint
```

---

## ⚙️ Preferences

Access settings via the menu bar icon:
- **General**: Launch at login, sound feedback.
- **Audio**: Microphone selection, recording-time system muting.
- **Hotkeys**: Custom trigger keys and confirmation modes.
- **Models**: Local SenseVoice configuration and optional post-processors.
- **Dictionary**: Custom developer terminology and homophone mapping rules.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
