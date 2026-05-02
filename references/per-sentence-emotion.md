# 逐句情绪生成(per-sentence emotion)

## 核心原则

**MiniMax T2A v2 不支持文本内联情绪标签**(没有 `<emotion=happy>` 这种语法)。
**逐句情绪 = 拆段合成 + 每段独立 emotion + ffmpeg concat**。
正好契合"长段必须分段"的硬规则(见 `length-rules.md`)。

## 5 个安全 emotion(4 轮 A/B 后定)

| Emotion | 适用语境 | 语气特征 |
|---|---|---|
| `happy` | 默认 / 铺垫 / 愉悦 / 总结 / 揭晓 | 上扬,有活力 |
| `surprised` | 转折 / 疑问 / 反转 / 强调 | 惊讶,提调 |
| `calm` | 自嘲 / 深沉 / 陈述 / 解释 | 平稳,沉着 |
| `sad` | 低沉(慎用,长段易显丧)| 下沉,慢 |
| `fluent` | 流畅 / 中性 / 旁白 | 自然 |

### 失真禁用集
- ❌ `angry` — 失真
- ❌ `disgusted` — 失真
- ❌ `fearful` — 失真

## Agent 拆句标情绪 prompt(给用户的 agent)

> **不绑定 LLM provider** — 用户的 agent(Claude/GPT/MiniMax/任意)读这段 prompt 后自己产出。

```
你是 pro-video-composer 的逐句情绪规划助手。

输入:一段中文文稿(markdown 或纯文本)
输出:emotion_plan.json,符合 templates/emotion_plan.schema.json

规则:
1. **拆句**:按完整意群,1 段 = 1 个意群 (2-3 句),目标音频 ≤ 15s
   - 太长会让模型"长段偏移"(后段越来越偏)
   - 太短会破坏语气连贯
2. **标情绪**:每段从 [happy, surprised, calm, sad, fluent] 选一个
   - 跟随文本语义(铺垫→happy / 转折→surprised / 自嘲→calm)
   - 不要全段同一情绪 — 至少 2 种交替
3. **文本清洗**:
   - 删除 "啦/啊/诶/嘿" 等口语叹词(会破坏音色)
   - 删除 "(breath)/(chuckle)" 等标签
   - 保留自然标点 + "!" 强调

输出格式:
{
  "voice_id": "<USER_VOICE_ID>",
  "model": "speech-2.8-hd",
  "speed": 1.2,
  "segments": [
    {"id": 1, "text": "...", "emotion": "happy", "est_duration": 5.5},
    {"id": 2, "text": "...", "emotion": "surprised", "est_duration": 4.7},
    ...
  ]
}
```

## 选 emotion 的启发式规则

| 文本特征 | 推荐 emotion |
|---|---|
| 开场 / 抛话题 / 总结 | `happy` |
| "结果……" / "但是……" / 反转 | `surprised` |
| "好吧" / "其实……" / 自嘲 / 解释 | `calm` |
| "其实我也不知道……" / 失落 | `sad`(慎用)|
| 中性陈述 / 数字播报 / 流程介绍 | `fluent` |

## 长度切分启发

- 中文 1 字 ≈ 0.18s @ speed=1.2
- 15s 上限 = 约 80 字
- 实际目标 60-70 字 / 段(留余量)
- 长句优先按 "。" 分,其次 ","、";"、"——"
- 单句 > 80 字必须拆成 2 段(找 "," 或 ";")

## 拼接公式

```bash
# 段间无静音(默认)
ffmpeg -f concat -safe 0 -i segs.txt -c copy out/narration.mp3

# 段间加 100ms 静音(如果衔接不自然)
ffmpeg -f concat -safe 0 -i segs_with_silence.txt -c copy out/narration.mp3
```

`segs.txt` 格式:
```
file 'seg1.mp3'
file 'seg2.mp3'
...
```

## 校验清单

- [ ] 每段时长 ≤ 15s(超出报警 + 让 agent 重拆)
- [ ] 每段 emotion ∈ 安全集
- [ ] 文本无叹词无标签
- [ ] 拼接后总时长在预期 ±10% 内

## EP4 Hook 实战示例

```json
{
  "voice_id": "NyxVoice2026",
  "model": "speech-2.8-hd",
  "speed": 1.2,
  "segments": [
    {"id": 1, "text": "上期我准备撸起袖子做一期专业的视频,还专门拆了飓风影视的分镜节奏。", "emotion": "happy",     "est_duration": 5.5},
    {"id": 2, "text": "结果发给朋友看,他说:还行吧,但…… 有点怪。",                       "emotion": "surprised", "est_duration": 4.7},
    {"id": 3, "text": "好吧 — 作为一个主播,我普通话确实不够字正腔圆。",                      "emotion": "calm",      "est_duration": 3.7},
    {"id": 4, "text": "但我一直坚持自己录,是想留点个人特色 — 音色就是我的一部分。",              "emotion": "calm",      "est_duration": 4.7},
    {"id": 5, "text": "能不能既保留我的音色,又把发音补上?",                                "emotion": "surprised", "est_duration": 3.4},
    {"id": 6, "text": "能 — 刚刚这一整段,就是 AI 用我自己的声音配的。",                       "emotion": "happy",     "est_duration": 4.0}
  ]
}
```

总长 26s,跟 NyxVoice2026 实测 26.09s 完全对齐。
