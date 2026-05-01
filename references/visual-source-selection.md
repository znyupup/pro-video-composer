# 视觉源选择规则

每个 scene 的 `visual_hint` 决定如何生成 video_path。

## 类型 → 处理流程

### `remotion` — 概念动画

1. 看 `references/remotion-conventions.md` 的 composition 设计原则
2. LLM 根据 scene.text 生成 `.jsx` 组件(用 `templates/composition.skeleton.jsx` 骨架)
3. 注册到 `remotion-test/src/index.jsx`(注意 id 不能含下划线)
4. 渲染:`npx remotion render src/index.jsx <id> out/<name>.mp4`
5. 截 `duration_sec` 长度,scale 1280×720,30fps,libx264

### `screenshot` — 截图 + 缩放动效

1. 用 playwright 抓 URL 或读本地图
2. ffmpeg `zoompan` 加缓慢 zoom(影视飓风风格)
3. 输出 `duration_sec` 长度的 mp4

### `broll` — 空镜从素材库选

1. 从用户提供的 `broll/` 目录扫所有 mp4
2. 用 vision MCP 看每个 broll 第 1 帧 + scene.text 算贴合度
3. 选最贴合的,trim 到 `duration_sec`
4. 简单 fallback:如果 vision 失败,按 broll 文件名匹配 scene.text 关键词

### `record_placeholder` — 待录屏

1. 不生成实际视频,占位 mp4(纯黑 / "待录屏" 大字)
2. 在 storyboard.html 高亮(状态 ⬜ 标"待录"+ 闪烁动画)
3. 用户录完替换 video_path 重跑下游

### `avatar_pip` — 数字人 PiP 强调

不单独生成 mp4,而是在拼接阶段:
- 全屏阶段(此 scene)= avatar 视频原帧 1280×720
- 用 `references/pip-overlay-recipes.md` 的全屏切换公式

### `transition` — 段间转场

- 用 Remotion 生成简单转场动画(MVP HOOK 大字 / 章节标题)
- 0.5-2s 时长

## 节奏建议

参考 `references/cut-pacing-strategy.md`:
- Hook 段(0-30s):多用 `remotion` + `screenshot`(信息密集)
- 主讲段:多用 `record_placeholder` + `broll`(真实感 + 节奏调味)
- 转折段:用 `transition` 章节切换
- 收尾段:`record_placeholder` 真人 + `screenshot` (CTA / 二维码)

## 失败处理

- Remotion 渲染失败 → 检查 composition id / entry point / `/tmp/render_*.log`
- 空镜库太少 → 提示用户加 broll
- 截图 URL 加载失败 → fallback 用本地占位图
