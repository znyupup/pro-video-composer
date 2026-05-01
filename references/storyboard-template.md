# Storyboard 看板设计规范

可视化分镜进度看板(`storyboard.html`),用户双击浏览器打开就看,self-contained。

## 设计原则(NYX 沉淀)

1. **浅色底**(macOS 风):bg `#f5f5f7` / 卡片白底 / accent 蓝 `#007aff`
2. **每个 scene 一个卡片**:编号 / 时长 / 类型 emoji / 状态 badge / 口播词 / 视觉
3. **已完成 scene** → 嵌入视频 / 截图;**未完成** → 占位卡留白
4. **顶部进度条**(已完成 / 总数 百分比)
5. **底部 footer**:lastUpdated 时间戳 + 编辑提示
6. **不要塞 skill 进展**(只做视频内容追踪)

## 必需字段(注入模板)

模板用 `__XXX__` 占位符:

| 占位符 | 含义 |
|---|---|
| `__SCENES_JSON__` | scenes 数组 JSON |
| `__TOTAL_DURATION__` | 音频总时长 (s) |
| `__ALIGN_METHOD__` | asr / linear-fallback |
| `__LAST_UPDATED__` | 最后更新时间字符串 |
| `__PROGRESS_PCT__` | 0-100 百分比 |
| `__PROGRESS_TEXT__` | "X / Y scenes 已就绪" |
| `__FINAL_VIDEO_BLOCK__` | (可选)整片预览 video 块 |

## 状态 badge

| 状态 | 颜色 | 含义 |
|---|---|---|
| `todo` | 红 | 待处理(刚拆完) |
| `planning` | 蓝 | 已对齐(ASR 完成) |
| `progress` | 黄 | 视觉素材生成中 |
| `done` | 绿 | 视觉素材就绪 / 已并入 FINAL |

## 类型 emoji 映射

```js
const TYPE_EMOJI = {
  "remotion": "🎬 Remotion",
  "screenshot": "🎨 截图",
  "broll": "🌅 空镜",
  "record_placeholder": "📹 待录屏",
  "avatar_pip": "🤖 数字人 PiP",
  "transition": "🔁 转场",
};
```

## 更新触发

每一 pipeline step 完成后调用 `generate-storyboard.sh` 重生成:
1. Step 1 拆完:状态全 `todo`
2. Step 2 对齐完:状态全 `planning`,加真实 start_sec/end_sec
3. Step 4 视觉就绪:对应 scene 状态 `done` + 加 video_path
4. Step 6 拼接完:整片 video 嵌入顶部预览

## 反模式

- ❌ 用户要看进度还要执行命令(必须双击 HTML 直接看)
- ❌ 暗色背景(NYX 明确要浅色 macOS 风)
- ❌ 把 skill 文件清单放进看板(NYX 不看)
- ❌ 一锅端(每次都重写整个 HTML — 应该用模板 + 数据注入)
