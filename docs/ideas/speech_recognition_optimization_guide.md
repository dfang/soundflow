# 提高 SoundFlow 编程与中英混杂场景识别率的优化指南

针对“帮我 review 这个 PR”“把这个 handler 改成 async await”等编程指令，近期值得重点跟进的方向是 **Int8 量化模型调优**与 **Hotwords（上下文偏置）算法**。两者不能混为一谈：Int8 可以用于当前 SenseVoice Small；sherpa-onnx 原生 Hotwords 目前不能用于 SenseVoice。

## 一、Int8 量化模型调优

SoundFlow 当前会优先加载 `model.int8.onnx`。Int8 的主要价值是降低模型体积、内存占用与 CPU 推理时间，它不会天然提高识别准确率，因此应通过同一批录音对 Int8 和 FP32 模型做 A/B 测试。

建议建立一组覆盖以下内容的本地评测集：

- 中文、英文以及中英混杂指令；
- Git、框架、API 和项目专有名词；
- 安静环境、键盘噪声和不同麦克风；
- 短命令与连续长句。

至少记录以下指标：

- CER/WER；
- 编程术语召回率；
- 实时率（RTF）和最终解码耗时；
- 首次预览延迟；
- 峰值内存。

调优顺序建议为：

1. 固定音频、VAD 和文本后处理，仅比较 `model.int8.onnx` 与 `model.onnx`。
2. 在 Apple Silicon 上分别测试 `num_threads = 1/2/4`，选择延迟稳定且不会抢占 UI 的配置。
3. 如果 Int8 的术语召回率明显下降，保留 FP32 作为诊断基线，不要用后处理掩盖声学模型回归。
4. 将评测结果和模型版本一起记录，避免只凭单次听感判断。

参考：[sherpa-onnx SenseVoice 导出文档](https://k2-fsa.github.io/sherpa/onnx/sense-voice/export.html)。

## 二、Hotwords 的能力边界

sherpa-onnx 的 Hotwords 使用 Aho-Corasick 上下文偏置，但官方当前只支持 **Transducer 模型 + `modified_beam_search`**。SoundFlow 使用的是 SenseVoice Small 与 `greedy_search`，所以仅给 `SherpaOnnxOfflineRecognizerConfig` 填入 `hotwords_file` 或 `hotwords_score` 不会让热词生效。

因此当前实现应遵循：

- 不在 SenseVoice 路径中接入一个实际无效的 `hotwords.txt`；
- 继续使用保守词典和最终 Gemma 后处理修正常见术语；
- 只有产品明确允许从 SenseVoice 切换到 Transducer 时，才评估 sherpa 原生 Hotwords。

如果未来切换到兼容模型，热词文件的单条权重格式是“短语 + 冒号权重”，例如：

```text
commit :2.0
rebase :2.0
async :2.5
await :2.5
Docker :1.5
TypeScript :2.0
```

同时需要设置正确的 `modeling_unit`，并实测 `modified_beam_search` 相对当前 greedy search 的 RTF、内存和准确率；不能预设为“零延迟、零额外算力”。

参考：[sherpa-onnx Hotwords 官方文档](https://k2-fsa.github.io/sherpa/onnx/hotwords/index.html)。

## 三、Gemma 最终后处理

默认后处理模型仍是 Gemma 4 E4B，并且只在最终 ASR 文本产生后运行。Prompt 可以补充编程语境，但必须继续遵守最小编辑原则：

- 中英混杂是正常输入，不要强制翻译；
- 只修复明显的 ASR 错误、大小写和空格；
- 默认保留输入已有标点，不自动追加句末标点；
- 不确定时保留原文；
- 失败时返回原始最终 ASR 文本。

Few-shot 示例：

```text
Input: "帮我review一下这个pr并发到main分支"
Output: "帮我 review 一下这个 PR 并发到 main 分支"

Input: "把这个函数重构为啊星克二喂特"
Output: "把这个函数重构为 async await"

Input: "重新跑一下达克肯破死"
Output: "重新跑一下 docker-compose"
```

实时预览仍只使用 VAD + ASR，不依赖 Gemma。

## 四、系统词典

系统词典适合确定性较高的映射，例如：

| ASR 易错输入 | 纠正目标 |
| :--- | :--- |
| `可密特` / `渴密` | `commit` |
| `吉特` / `即特` | `Git` |
| `批二` / `匹尔` | `PR` |
| `睿倍斯` / `热杯子` | `rebase` |
| `啊星克` / `阿星克` | `async` |
| `二喂特` / `厄维特` | `await` |

不要把正常中文中常见且有明确含义的词加入全局映射，例如将“摩羯”“默记”无条件替换成 `merge`。高歧义词应放入用户词典，或等未来具备可靠的前台开发应用上下文后再启用。

## 五、当前实现诊断（2026-08-15）

以下是对代码路径的诊断记录。两个 P0 问题已实施，P1/P2 仍是待评测方向。

### P0（已实施）：采样率边界不一致

`AudioCaptureService` 使用输入设备的原生格式采集音频；本次检查的默认输入是 48 kHz。采集端会转为单声道，但保留设备采样率。修复前，识别服务将这些原始样本直接同时传给 ASR 和 VAD。

这对两个下游消费者的影响不同：

- sherpa-onnx 离线 ASR 的 `AcceptWaveform` 接收采样率参数，当输入与特征采样率不同时会内部重采样；
- 当前 VAD 被固定配置为 16 kHz，`acceptWaveform` 却没有采样率参数，因此直接喂入 48 kHz 样本会让 VAD 的时间尺度错三倍；
- `minimumPreviewSamples`、`previewStrideSamples` 和 `previewReuseSlackSamples` 都是按 16 kHz 写死的样本数，输入为 48 kHz 时实际时长会变成原来的三分之一。

现已在识别服务入口实现以下边界：

```text
Mic（设备原生采样率） -> 单声道 -> 一次有状态重采样到 16 kHz -> VAD / 缓冲 / 预览 / 最终解码
```

重采样器跨音频块保持状态，在停止时 flush；输入采样率变化时先 flush 已缓冲尾部再重建，取消时才直接丢弃状态。没有强制麦克风或 `AVAudioEngine` 以 16 kHz 采集；统一的是内部识别域，不是硬件采集域。

### P0（已实施）：最终提交可能复用未覆盖尾部的预览

修复前，只要预览覆盖率达到 80%，或未解码尾部不超过 8000 个样本，最终提交就可能直接复用预览。这会丢掉句尾，而 80% 覆盖率对长句尤其不安全。

现在 `stop()` 总是解码完整的 16 kHz 缓冲，预览只用于 HUD，不再作为最终结果。

### P1：VAD 只被用作布尔开关

当前代码只检查 VAD 是否检测到语音，最终仍解码全部原始缓冲，没有消费 VAD 输出的语音片段。后续可暴露并使用 `Front` 片段，配合少量 pre-roll/tail padding，并对超长音频分段。这项改动会改变断句语义，应在采样率修复之后单独评测。

当前 Silero VAD 参数也非常激进：`threshold = 0.12`、`minSilenceDuration = 0.08`、`minSpeechDuration = 0.03`。不应靠猜测调参，而应在真实录音集上检查首字截断、尾字截断和噪声误触发。

### P1：SenseVoice 兼容的术语纠错

sherpa-onnx 的 Homophone Replacer 可用于 SenseVoice greedy search，而且当前 C API 封装已经包含其配置，但默认未启用。它是解码后的确定性纠错，不是声学热词偏置。可优先验证低歧义编程术语，并为每条规则同时增加命中和不应命中的样例。

另外，SenseVoice 支持 `auto/zh/en/yue/ja/ko` 语言选项和 ITN 开关。当前使用自动语言与开启 ITN，应对纯中文、纯英文、中英混杂和包含数字的子集分别 A/B，不预设某一组在所有场景都更好。

### P2：噪声与领域适配

- 只对低信噪比录音评估 GTCRN、DPDFNet 或系统语音处理，并与原音做 A/B；降噪可能失真，不应默认覆盖干净输入。
- 通过用户可选的本地反馈积累“音频 + 原始 ASR + 用户确认文本 + 上下文”，再评估 SenseVoice 领域微调。
- `num_threads`、provider/CoreML 和 Int8 主要是延迟与资源优化，不应当作识别率优化；SenseVoice 的 greedy search 也不会因调大 beam 参数而提高识别率。

### 分开评估原始 ASR 与最终文本

固定产品路径是 Gemma 4 E4B 只处理最终文本。当前 `.mlxGemma` 仍连接占位实现，因此“提交后看起来更准”与“声学识别更准”必须分开评估。建议从 100–300 条真实录音起步，分别记录：

- 原始 ASR 的 CER/WER 和术语召回率；
- 句尾丢失率、空结果率和误断句率；
- 首次预览、最终 ASR 和 Gemma 各自的延迟；
- 后处理的纠错收益与误改率。

## 六、建议实施顺序

1. 建立可重复的真实录音评测集和当前基线。
2. （已完成）保留设备原生采集，在识别边界统一重采样为单声道 16 kHz。
3. （已完成）最终提交总是解码完整缓冲，先消除句尾丢失。
4. 再单独实现和评测 VAD 分段，包括 pre-roll、tail padding 和超长音频。
5. 验证 Homophone Replacer，再对语言和 ITN 设置做 A/B。
6. 根据实测评估选择性降噪、完整 MLX Gemma 和领域微调。
7. 只有在允许更换 ASR 模型时，再以 Transducer 原型验证原生 Hotwords 的收益和成本。

## 七、本轮实现边界

本轮只处理两个 P0 问题，不新增产品 spec 或独立长文档。本节直接作为轻量技术 spec，固定以下可验收约束：

- 采集保持设备原生格式，VAD、缓冲、预览与最终 ASR 只消费单声道 16 kHz 样本；
- 重采样器跨音频块保持状态，在停止时 flush；设备采样率变化时先 flush 再 recreate，取消时 reset；
- 音频块通过串行队列投递；停止采集时等待已进入 tap 的回调完成入队，再排空已接收的块；每轮采集使用独立 generation，拒绝旧会话的延迟回调；开始录音时先打开 ASR 会话，再启动麦克风采集；
- 所有时间阈值用秒或毫秒表达，样本数仅由 16 kHz 换算；
- 最终提交解码完整缓冲，预览不能丢弃未解码尾部；
- 使用 16/44.1/48 kHz 输入的确定性测试，验证时长、flush/reset、预览节奏和完整最终结果。

VAD 片段消费、参数调优、降噪和 Homophone Replacer 不纳入这个最小改动，它们需要各自的评测数据和验收标准。
