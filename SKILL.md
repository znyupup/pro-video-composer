---
name: pro-video-composer
description: 开箱即用的 AI 视频合成流水线 + 声音复刻 + 逐句情绪生成。用户提供文稿(.md)+ 录音(.mp3/.wav) [可选](.md)+ 空镜素材目录,可选数字人视频,skill 自动:① LLM 拆 ~13 个 ~2s 分镜 ② ASR 转录音对齐时间轴 ③ 生成可视化分镜看板让用户过审 ④ 选/生成视觉素材(Remotion 动画/空镜/录屏占位)⑤ ffmpeg 程序化拼接 + PiP 数字人 + 全屏切换 + 字幕 → FINAL.mp4。**v0.3 新增**:**音色复刻**(主音频 + 示例音频 + 自动 ASR 校对 → voice_id)+ **逐句情绪生成**(文稿 → agent 拆句标 emotion → 逐段调 t2a_v2 → ffmpeg concat → narration.mp3),NyxVoice2026 锁定配方(speech-2.8-hd / happy / 1.2 / pitch=0)+ 5 个安全 emotion(happy/surprised/calm/sad/fluent)。每一步都刷可视化 storyboard.html。串联 4 个角色:**ffmpeg(剪辑师)+ Remotion(动画师)+ 视觉/ASR 模型(时间轴对齐)+ agent(协调大脑)**。当用户说"这是我的视频文稿,开始制作视频"、"做个科普视频开头"、"按文稿+录音+空镜剪一段"、"生成 hook 段"、"AI 自动剪辑视频"、"复刻我的音色"、"用我的 voice_id 生成口播"、"按情绪拆句合成"、"AI 配音" 时使用。**不用于** 单一 markdown → 讲解动画(那是 knowledge-explainer-skill)、纯录屏剪辑(用剪映)、AI 自动剪 vlog(用 vlog-auto-edit)。
version: 0.3.0
type: video-composition
tags: [video-composition, ffmpeg, remotion, asr, pip, hook, ai-pipeline, voice-cloning, tts, per-sentence-emotion, minimax]
author: nyx研究所 (https://github.com/znyupup)
status: experimental
---

# pro-video-composer

> **开箱即用** AI 视频合成 — 用户给文稿 + 录音 + 空镜,skill 自动出片。
> 串联 4 个角色:ffmpeg 剪辑师 + Remotion 动画师 + 视觉/ASR 时间轴对齐 + agent 大脑。

## 触发场景

### 视频合成(原 v0.2)
- "这是我的视频文稿,开始制作视频" / "按文稿剪一段"
- "做个科普视频开头" / "生成 hook 段"
- "AI 自动剪辑视频" / "用 skill 出片"
- 用户提供 .md 文稿 + .mp3/.wav 录音 + 空镜素材目录

### 声音复刻(v0.3 新增)
- "复刻我的音色" / "创建 voice_id" / "克隆我的声音"
- 用户提供 1-3 分钟主音频 + 5-30s 示例音频

### 逐句情绪生成(v0.3 新增)
- "用我的 voice_id 生成口播" / "AI 配音"
- "按情绪拆句合成" / "用我的音色按情绪生成这段口播"
- 用户提供文稿 + voice_id

## 输入约定

### 视频合成路径
1. **文稿** `script.md`(分段或纯文本均可,LLM 会自动拆)
2. **录音** `voiceover.mp3` / `voiceover.wav`(口播音轨)

可选:
3. **空镜目录** `broll/`(任意数量 mp4,用于节奏调味 / 衔接)
4. **数字人视频** `avatar.mp4`(用于 PiP 圆框 + 偶尔全屏震撼)
5. **既有 Remotion 项目**(否则 skill 会自己 scaffold 一个)

### 声音复刻路径(v0.3)
1. **主音频** `main.mp3`(60-180s,音质干净,无杂音)
2. **示例音频** `sample.mp3`(5-30s,可选;不给则跳过文字稿配对)

### 逐句情绪生成路径(v0.3)
1. **文稿** `narration.md`
2. **voice_id**(从 `voice_clone/voice_id.txt` 读,或 CLI 参数传)

输出:
- `out/FINAL.mp4` — 整片成品
- `out/storyboard.html` — 可视化分镜看板(过审 + 进度追踪)
- `out/recipe.sh` — 可重跑公式
- `out/scenes.json` — 分镜结构化数据
- **(v0.3)** `out/narration.mp3` — 逐句情绪 AI 配音
- **(v0.3)** `out/narration_segments/seg{N}.mp3` — 单段
- **(v0.3)** `out/emotion_plan.json` — 拆句 + 情绪结果
- **(v0.3)** `voice_clone/voice_id.txt` — 复刻后的 voice_id

## Pipeline(7 步 + v0.3 前置 2 步)

### Step -1(v0.3):声音复刻 → voice_id

`scripts/voice-clone.sh main.mp3 sample.mp3 → voice_clone/voice_id.txt`

子步:
1. 上传主音频 → MiniMax `/v1/voice_cloning/upload_clone_audio` → 拿 `file_id`
2. **示例音频自动 ASR**(MiniMax audio understanding 中文转录)→ 写入 `voice_clone/transcript.md`
3. **暂停等用户校对**:打开 transcript.md(默认 vim),用户改完保存回车继续
4. 调 `/v1/voice_cloning/clone` 携带 file_id + sample.mp3 + 校对后 transcript → 拿 voice_id
5. 跑测试合成验证可用 → `voice_clone/test.mp3`
6. 写入 `voice_clone/voice_id.txt`

详见 `references/voice-clone-recipe.md`。

### Step 0(v0.3):文稿 + voice_id → AI 配音 narration.mp3

`scripts/narrate-emotion.sh narration.md → out/narration.mp3`

子步:
1. **agent 拆句**(用户的 agent — Claude/GPT/MiniMax/etc — 不绑定):agent 读 `references/per-sentence-emotion.md` 获取 5 个安全 emotion 集 + 长度规则,自己拆句标情绪,写入 `out/emotion_plan.json`
2. **校验** emotion_plan:每段 ≤15s 文本 / emotion ∈ {happy/surprised/calm/sad/fluent} / 文本无叹词无标签
3. **逐段调 t2a_v2** `model=speech-2.8-hd` `voice_id=<USER>` `speed=1.2` `pitch=0` `voice_modify=禁用` → `out/narration_segments/seg{N}.mp3`
4. **ffmpeg concat** → `out/narration.mp3`
5. 输出可视化 emotion 表 `out/emotion_plan.html`

详见 `references/per-sentence-emotion.md` + `references/length-rules.md`。

**集成点**:Step 0 输出的 `out/narration.mp3` 可直接作为 Step 2 的 `voiceover.mp3` 输入,后续 ASR 对齐 / 视觉合成不变。

---

### Step 1:文稿 → 分镜拆解

`scripts/split-scenes.sh script.md → scenes.json`

调用 LLM(默认 `llm-call` skill,或 matrix MCP)按以下规则拆:
- 平均 1.8-2.2s/镜(Hook 段大 V 节奏)
- 每镜含:`id` / `text`(口播片段)/ `est_duration`(估时)/ `visual_hint`(LLM 给的视觉建议:动画/录屏/空镜/数字人)
- 拆完总数 ~10-15 个

详见 `references/scene-splitting.md`。

### Step 2:录音 → 时间轴精准对齐

`scripts/asr-align.sh voiceover.mp3 scenes.json → scenes_aligned.json`

调用 funASR(本地中文最准,见 `docs/asr-recipes.md`)产字级时间戳,
按文本相似度匹配每个 scene → 真实 in/out frame。

详见 `references/asr-alignment.md`。

### Step 3:刷看板 + 用户过审 ⭐

`scripts/generate-storyboard.sh scenes_aligned.json out/storyboard.html`

生成浅色 macOS 风可视化看板,每个 scene 卡片含 编号/时长/类型/口播词/状态。
**用户在浏览器打开看,标 ✅ 或 ✋(要改),改完手动编辑 scenes_aligned.json 重跑下游**。

详见 `references/storyboard-template.md` + `templates/storyboard.template.html`。

### Step 4:为每个 scene 决定视觉源

按 `visual_hint` 类型:
- **`remotion`** → 调用 LLM 生成 Remotion `.jsx` 组件(`templates/composition.skeleton.jsx`),注册到 `src/index.jsx`,渲染 mp4
- **`broll`** → 从 `broll/` 用 vision 选最贴合的 + 截 `est_duration`
- **`screenshot`** → 用截图工具(playwright / matrix)抓 + 加缩放动效
- **`record_placeholder`** → 标记 ✋ 等用户后录(导出 storyboard 时高亮)
- **`avatar_pip`** → 用 `avatar.mp4` 做 PiP overlay(默认右下 220×220 圆形)

详见 `references/visual-source-selection.md`。

### Step 5:生成 PiP overlay + 全屏切换公式

如有 `avatar.mp4`,自动生成 ffmpeg filter:
- PiP 永远 alpha=1 + crop 以脸部为中心(用 vision 测人物 x_center,起点 = x_center - 210)
- 全屏切换 0.2s fade in/out,避开数字人源拼接点 ≥ 1s

详见 `references/pip-overlay-recipes.md` + `references/splice-safety-rules.md`。

### Step 6:ffmpeg 程序化拼接

`scripts/assemble.sh scenes_aligned.json → FINAL.mp4`

按 scene 顺序 concat → PiP overlay → 全屏 fade → 音轨同步。
输出 `recipe.sh` 可重跑。

详见 `templates/assemble.template.sh`。

### Step 7:验证 + 推送

- ffprobe 验证总时长 / 码率
- 用 `scripts/sample-frames.sh` 抽关键帧(看每个 scene 的中点)
- 在 storyboard.html 嵌入 FINAL.mp4 视频预览
- 推用户看 + 等反馈

## 节奏策略(分段)

不要全程 1-2s/镜也不要全程 8s+。**分段节奏**(详见 `references/cut-pacing-strategy.md`):

| 段位 | 镜头时长 | 视觉策略 |
|---|---|---|
| Hook 0-30s | 1-2s/镜 | 信息轰炸 + 痛点 |
| 主讲段 | 3-8s/镜 | 单镜头讲完一概念,内置动效 |
| 转折/对比段 | 1-2s/镜 | 短爆发 |
| 收尾 + CTA | 2-5s/镜 | 沉淀 + CTA |

## 用户反馈应对(沉淀)

- 用户说"换个思路" 90% 是 crop 偏移参数错(先 vision 测人脸,再调 crop,别急着推 N 个架构思路)
- 用户模糊反馈"白色的字" 是指**具体某一个**,不是所有,**别一锅端**
- 用户偏好"对比再选" — 改架构性决策时做 A/B 候选让用户选,不要"我推荐 X"
- 用户反馈是**渐进迭代**,删元素时减一半比全删稳(留回退空间)
- 数字人 PiP **必须动态**(说话/微动),静态头像被 NYX 明确拒绝

详见 `references/feedback-patterns.md`。

## Remotion 主层约定

- composition id 禁用下划线(`TimelineMontageB` ✅ / `TimelineMontage_B` ❌)
- 多 worker 改 index.jsx 必须串行 / try-edit retry
- frame clamp freeze 一行实现 Variant B(原版 + 后段冻结)
- 渲染命令必须显式 entry point: `npx remotion render src/index.jsx <id> <out>`

详见 `references/remotion-conventions.md`。

## 关键文件清单

| 文件 | 用途 |
|---|---|
| `scripts/voice-clone.sh` | **(v0.3)** 上传 + ASR + 校对 + clone + 测试 |
| `scripts/narrate-emotion.sh` | **(v0.3)** 校验 emotion_plan + 逐段 t2a + concat |
| `scripts/minimax-asr.py` | **(v0.3)** MiniMax audio understanding 中文转录 |
| `scripts/minimax-t2a.py` | **(v0.3)** T2A v2 调用 + 黑名单校验 |
| `scripts/split-scenes.sh` | LLM 拆分镜 |
| `scripts/asr-align.sh` | 录音转录 + 时间轴对齐 |
| `scripts/generate-storyboard.sh` | 生成 / 刷新可视化看板 |
| `scripts/select-broll.sh` | vision 选空镜 |
| `scripts/assemble.sh` | ffmpeg 程序化拼接 |
| `scripts/sample-frames.sh` | 抽验证帧 |
| `scripts/check-splice-points.sh` | 检测拼接素材卡顿点 |
| `scripts/extract-portrait.sh` | 抽数字人头像 PNG(fallback,默认不用) |
| `templates/voice_clone_call.json` | **(v0.3)** voice cloning API 请求模板 |
| `templates/t2a_v2_call.json` | **(v0.3)** T2A v2 请求模板(含锁定参数) |
| `templates/emotion_plan.schema.json` | **(v0.3)** agent 输出 emotion_plan JSON Schema |
| `templates/storyboard.template.html` | 看板模板 |
| `templates/composition.skeleton.jsx` | Remotion 组件骨架 |
| `templates/assemble.template.sh` | 拼接公式模板 |
| `references/voice-clone-recipe.md` | **(v0.3)** 锁定配方 + 失败方向黑名单 |
| `references/per-sentence-emotion.md` | **(v0.3)** 5 emotion 安全集 + 拆句策略 + agent prompt |
| `references/length-rules.md` | **(v0.3)** T2A ≤ 15s / 数字人 ≤ 6s 硬约束 |
| `references/scene-splitting.md` | LLM 拆分镜 prompt + 规则 |
| `references/asr-alignment.md` | ASR 对齐策略 |
| `references/visual-source-selection.md` | 视觉源类型 + 选择规则 |
| `references/pip-overlay-recipes.md` | PiP ffmpeg 公式 + crop 偏移 |
| `references/splice-safety-rules.md` | 拼接素材 1s+ 余量 |
| `references/cut-pacing-strategy.md` | 节奏分段策略 |
| `references/storyboard-template.md` | 看板设计规范 |
| `references/remotion-conventions.md` | Remotion 4.0+ 约定 |
| `references/feedback-patterns.md` | 用户反馈应对模式 |

## Failure handling

- LLM 拆分镜数 ≠ 期望:重 prompt 强调"~2s/镜"
- ASR 对齐误差大:fallback 到字符级线性映射(每字 0.2s)
- Remotion 渲染挂:看 `/tmp/render_*.log` 的 `Error` 行(不是 React stack)
- ffmpeg 拼接卡:用 `check-splice-points.sh` 检测拼接素材
- 用户对某 scene 不满意:不重跑全 pipeline,只改那一个 scene 的视觉源 + 重跑 Step 4-6

## 进度追踪 ⭐(必备)

**每一步必须刷 storyboard.html**(NYX 明确要求 user-facing dashboard):
1. Step 1 拆完 → 看板显示分镜列表(状态 ⬜ 待处理)
2. Step 2 对齐完 → 看板显示真实时长 + 状态 📋 已对齐
3. Step 3 用户过审 → 看板等用户操作
4. Step 4 视觉源就绪 → 状态 🚧 渲染中 / ✅ 就绪
5. Step 5 PiP 公式生成 → 状态 🚧 拼接中
6. Step 6 拼接完 → 状态 ✅ 完成 + 嵌入预览视频
7. Step 7 验证完 → 总进度 100% + 可下载

**不刷看板 = 不算这一步完成**。
