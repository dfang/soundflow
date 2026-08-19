# SoundFlow

<p align="center">
  <strong>🔥 专为 Vibe Coding 与极速思维打造的 macOS 纯本地语音输入神器</strong>
</p>

<p align="center">
  <em>打字太慢跟不上脑暴？受够了云端 AI 语音工具的漫长“Thinking...”与月度词数限制？</em><br>
  <strong>边说边出字，毫秒级流式预览，让你的思维直接流淌成代码与文本。</strong>
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

## ⚡ 为什么选择 SoundFlow？

在 **Vibe Coding** 时代，开发者的瓶颈早已不是写代码本身，而是**“向 AI 表达想法的速度”**。

市面上现有的 AI 语音输入工具（如 Typeless 等）往往存在“致命短板”：
- ⏳ **盲盒式等待 & 打断心流**：说话时屏幕一片空白，说完还要转圈“Thinking...”等好几秒，灵感瞬间蒸发；
- 💸 **订阅制刺客**：不充钱每月就给那点可怜的免费词数，随时面临配额告罄；
- ☁️ **隐私顾虑**：把你的业务代码、私有 Prompt 和语音全部上传到云端服务器；
- 🛑 **界面抢焦点**：弹窗抢夺编辑器焦点，导致代码光标错位。

### 🚀 SoundFlow 彻底颠覆这一切：

| 维度 | 传统云端语音工具 (如 Typeless 等) | **SoundFlow** |
| :--- | :--- | :--- |
| **实时预览** | ❌ 盲盒录音，录音期间无字，说完全靠猜 | ⚡ **边说边实时出字**，所说即所见，心里随时有数 |
| **响应速度** | 🐢 上传云端，每次还要“Thinking...”转圈数秒 | 🚀 **纯本地毫秒级**，话音刚落文字已就绪 |
| **内存占用** | ☁️ 臃肿客户端或后台常驻占用大 | 🪶 **极度轻量，内存占用仅约等于一个浏览器 Tab** |
| **模型体积** | ☁️ 依赖云端大集群 | 📦 **量化后仅约 300MB**，极低功耗与磁盘占用 |
| **使用成本** | 💳 每月词数限制，高昂订阅费 | 🆓 **100% 永久免费、无限词数、零 Token 焦虑** |
| **隐私安全** | ⚠️ 音频与敏感代码传至第三方云端 | 🔒 **100% 纯本地离线运行**，声音代码不出本机 |
| **心流体验** | ❌ 抢夺应用焦点，频繁打断 Coding 节奏 | ✅ **无焦点悬浮 HUD**，平滑注入任何编辑器 |

---

## 🎯 专为 Vibe Coding 打造的杀手级体验

- 🌊 **边说边出字（实时流式预览）**：**最关键的体验革新！** 当你说话时，底部悬浮 HUD 实时流式吐出识别字词，所说即所见，不再面对盲盒式等待，心里随时有底。
- 🪶 **羽量级内存，极致轻快**：模型量化后仅约 300MB，**整机运行时内存占用仅相当于一个普通浏览器标签页**！长驻后台毫无感知，完全不和你的 IDE、Docker 或大型编译任务争抢 RAM。
- 🎙️ **用嘴狂飙 Prompt**：在 Cursor、Windsurf、VS Code、终端或浏览器中，直接用自然语言连珠炮般吐出复杂需求，毫秒级平滑注入当前光标处。
- 🖥️ **非侵入式悬浮 HUD**：底部小巧波形与流式实时预览，完全不抢占目标窗口焦点，让你的双手始终停留在键盘操作区。
- ⌨️ **极简交互，一键上屏**：按下热键说话，`Enter` / `Right Ctrl` 确认瞬间插入，`Esc` 随时取消。
- 📖 **智能纠错与词典**：专为开发者定制中英文混合纠正，完美识别 CamelCase、代码术语与专有名词。

---

## 🔄 核心架构流水线

```text
[ 🎙️ 麦克风拾音 ]
       │
       ▼
[ ⚡ 轻量级 VAD 语音活性检测 ]
       │
       ▼
[ 🚀 sherpa-onnx + SenseVoice (量化模型 ~300MB) ]
       │
       ▼ (边说边实时出字 ⚡)
[ 🖥️ 底部非激活悬浮 HUD 实时流式预览 ]
       │ (按下 Enter / Right Ctrl 确认)
       ▼
[ 🛠️ 开发者词典与智能门控 ] ─── (可选本地 Gemma / DeepSeek 保守润色)
       │
       ▼
[ 🎯 毫秒级直接注入当前光标位置 (VS Code / Cursor / Terminal 等) ]
```

---

## 📋 系统要求

- **操作系统**：macOS 14.0 (Sonoma) 或更高版本
- **芯片架构**：Apple Silicon (M1 / M2 / M3 / M4 系列芯片)
- **系统权限**：
  - 🎤 **麦克风权限**（用于本地拾音）
  - ♿ **辅助功能权限 (Accessibility)**（用于全局热键监听与无缝光标文本注入）

---

## 🚀 30 秒快速上手

### 1. 一键编译并安装到 Applications

确保本地已安装 Xcode 命令行工具及 Swift 环境：

```bash
# 1. 克隆代码库
git clone https://github.com/dfang/soundflow.git
cd soundflow

# 2. 一键编译并安装到 /Applications
./scripts/install.sh
```

启动 SoundFlow：
```bash
open /Applications/SoundFlow.app
```

### 2. 首次配置向导

首次启动将弹出轻量引导：
1. 一键授予 **麦克风** 与 **辅助功能** 权限。
2. 确认识别模型已就绪（已内置量化模型，开箱即用）。
3. 设定你顺手的全局热键（默认 `Right Option`，可自由定制）。

### 3. 开始沉浸式输入

1. 打开 **Cursor**、**VS Code**、**终端** 或任意编辑器。
2. 按住/按下全局热键，开始自然表达。
3. 底部悬浮 HUD **边说边实时出字**；按 `Enter` 或 `Right Ctrl` 瞬间插入光标处！

---

## 🛠️ 开发者指南

```bash
# 运行单元与集成测试
swift test

# 构建 Release App Bundle (输出至 dist/SoundFlow.app)
./scripts/build_app.sh

# 打包 DMG 安装镜像
./scripts/package_dmg.sh

# 代码格式化与 Lint 检查
swiftformat .
swiftlint
```

---

## ⚙️ 偏好设置

点击 macOS 状态栏图标进入设置面板：
- **通用 (General)**：开机自启、声音反馈等。
- **音频 (Audio)**：麦克风选择、录音时自动静音系统背景声。
- **快捷键 (Hotkeys)**：录音触发键、确认键模式设置。
- **模型 (Models)**：本地 SenseVoice 模型配置与可选的后处理器扩展。
- **词典 (Dictionary)**：自定义编程术语与中英混合映射词典。

---

## 📄 开源许可证

本项目采用 [MIT 许可证](LICENSE)。
