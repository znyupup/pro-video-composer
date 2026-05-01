# pro-video-composer

**Author:** nyx研究所 · [GitHub](https://github.com/znyupup) · [B站 @nyx研究所](https://space.bilibili.com/4330525) · 小红书 @nyx研究所 · [X @znyupup_music](https://x.com/znyupup_music)

> ⚠️ **v0.2 · experimental MVP** · Step 1 已测通,Step 2-7 实现完待端到端验证。
> 推上来就是为了让你边用边帮我找 bug。

把 **文稿(.md) + 录音(.mp3) + 空镜目录** 喂给 AI agent,自动出 mp4 成片 — 不是模板填空,是 LLM 拆分镜 + ASR 对齐 + ffmpeg 程序化拼接的真正 pipeline。

```bash
# 在 agent (Claude Code / Codex) 里:
> 这是我的视频文稿,开始制作视频吧
```

## 这个 skill 解决什么问题

之前两个 skill 各管一块:
- [ai-video-editing-skill](https://github.com/znyupup/ai-video-editing-skill) — AI 自动剪 vlog(原始素材 → 成片,有人脸/旁白)
- [knowledge-explainer-skill](https://github.com/znyupup/knowledge-explainer-skill) — markdown → 讲解动画(无录音、无空镜、纯生成)

**真实做科普视频的中间地带**没人管:
- 你已经写好文稿了
- 你已经录好旁白了
- 你有一些空镜 / 数字人素材了
- 但你不想手动剪

**pro-video-composer 干的就是这个**:把 4 个 AI 角色串起来 — ffmpeg(剪辑师)+ Remotion(动画师)+ ASR/Vision(时间轴对齐师)+ agent(协调脑)— 自动出片。

## Pipeline(7 步)

```
script.md + voiceover.mp3 + broll/ + (avatar.mp4)
    ↓ Step 1: split-scenes.sh   (LLM 拆 ~13 个 ~2s 分镜 → scenes.json)
    ↓ Step 2: asr-align.sh      (funASR 字级时间戳 → scenes_aligned.json)
    ↓ Step 3: generate-storyboard.sh  (浏览器看的可视化看板, 用户过审)
    ↓ Step 4: 视觉源就绪        (Remotion / 截图 / 空镜 / 数字人 PiP)
    ↓ Step 5: PiP overlay 公式  (crop 以脸部为中心, splice 1s+ 余量)
    ↓ Step 6: assemble.sh       (ffmpeg concat + overlay + 音轨同步)
    ↓ Step 7: 验证             (ffprobe + 抽关键帧)
out/FINAL.mp4 + storyboard.html + recipe.sh
```

每一步都刷新 `storyboard.html`,你随时浏览器打开看进度 + 过审某一步。

## 4 个 AI 角色分工

| 角色 | 工具 | 做什么 |
|---|---|---|
| 🎬 剪辑师 | ffmpeg | concat / overlay / fade / 编码 |
| 🎨 动画师 | Remotion | React 写概念动画(章节封面 / 数据可视化) |
| 🎯 对齐师 | funASR + Vision | 录音→字级时间戳,视觉→人脸 x_center |
| 🧠 协调脑 | agent (Claude Code / Codex) | 调度上面 3 位,处理用户反馈 |
| 👤 你 | 总导演 | 给文稿 + 录音 + 空镜,审看板,选定稿 |

## Quickstart

### 1. 安装

```bash
git clone https://github.com/znyupup/pro-video-composer ~/.mavis/skills/pro-video-composer
```

(或者你的 agent runtime 的等价路径)

依赖:
- **ffmpeg** — `brew install ffmpeg`
- **funASR**(Step 2 用) — `pip install funasr modelscope`(可选,fallback 到 matrix MCP)
- **Remotion 项目**(Step 4 用) — 你的工作区有 `remotion-test/` 之类的项目即可

### 2. 准备素材

```
your-video-project/
├── script.md          ← 文稿(分段或纯文本均可)
├── voiceover.mp3      ← 录音(口播音轨)
├── broll/             ← (可选) 空镜目录
└── avatar.mp4         ← (可选) 数字人视频(PiP 圆框 + 偶尔全屏)
```

### 3. 在 agent 里说

```
> 用 pro-video-composer 这个 skill,按 script.md + voiceover.mp3 出片
```

agent 会按 7 步走,每步刷 `out/storyboard.html` 让你过审。

## 完成度 / 已知问题

| Step | 脚本 | 状态 |
|---|---|---|
| 1 拆分镜 | `split-scenes.sh` | ✅ 已测(12 cut demo) |
| 2 ASR 对齐 | `asr-align.sh` | ⚠️ 实现完,端到端待测 |
| 3 看板生成 | `generate-storyboard.sh` | ⚠️ 实现完,端到端待测 |
| 4 视觉源 | (在 references) | 📋 文档 + 模板,无独立脚本 |
| 5 PiP overlay | (公式在 references) | 📋 ffmpeg 公式参考 |
| 6 拼接 | `assemble.sh` | ⚠️ 实现完,端到端待测 |
| 7 验证 | `check-splice-points.sh` | ⚠️ 实现完,端到端待测 |

**下一步路线图:**
- [ ] Step 2-7 端到端跑通一个 hook 段(20s 左右)
- [ ] 加 `cli.js` 一键启动(类似 knowledge-explainer-skill)
- [ ] Remotion 项目 scaffold(自动生成 `src/index.jsx`)
- [ ] 节奏分段策略(Hook 1-2s/镜 / 主讲 3-8s/镜 / 收尾 2-5s/镜)纳入 LLM 拆分镜 prompt

## 实战参考

第一期完整使用案例:**0429 ep3 hook 段**(22.63s 成片)— 视频发布后会贴 B 站链接。

技术要点的硬约束(写在 `references/` 里):
- **PiP crop 必须以脸部为中心**(不是从 0,0 起点抠图,会丢人脸)
- **拼接素材安全余量 ≥ 1s**(0.39s 不够,人能感知拼接点的卡顿)
- **数字人 PiP 必须动态**(静态头像感觉像假人)
- **Remotion composition id 禁用下划线**(部分版本会校验失败)
- **多 worker 改 index.jsx 必须串行**(否则覆写打架)

## 为什么不直接调云 API?

云 API(剪映 / 必剪 / Veed / Descript)是封装好的剪辑器,你点按钮,它出片。
**这个 skill 反过来** — 你跟 agent 对话,agent 用本地 ffmpeg / Remotion / funASR 出片。优势:
- 全程跑本地,无 API key 烦恼
- 每一步都是开源工具,你能改公式
- 反馈环路是"对话改",不是"重新拖时间轴"
- 文稿 / 公式 / 配色 / pacing 全都在 git 里 — 可重跑可 diff

## 致谢

- [Remotion](https://www.remotion.dev/) · React 写视频的核心引擎
- [ffmpeg](https://ffmpeg.org/) · 视频处理瑞士军刀
- [funASR](https://github.com/modelscope/FunASR) · 阿里中文 ASR
- 姊妹项目 [ai-video-editing-skill](https://github.com/znyupup/ai-video-editing-skill) + [knowledge-explainer-skill](https://github.com/znyupup/knowledge-explainer-skill)

## 反馈

发 issue 到 [GitHub Issues](https://github.com/znyupup/pro-video-composer/issues),或在 B站 / 小红书 @nyx研究所 评论区说哪一步炸了 + 输入素材描述,我会跟。

## License

MIT — 随便用,标注来源就行。
