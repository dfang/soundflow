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

## 五、后续路线

1. 先建立 Int8/FP32 可重复评测集和基线。
2. 保持词典与 Gemma 修改保守，补充真实误识别样本。
3. 评估剪贴板或当前项目术语作为最终后处理参考，但不放入实时预览路径。
4. 只有在允许更换 ASR 模型时，再以 Transducer 原型验证 Hotwords 的收益和成本。
