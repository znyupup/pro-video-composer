# Remotion 4.0+ 项目约定

用 Remotion 生成主层 cuts 的工程约定 + 踩过的坑。

## 项目结构

```
remotion-test/
├── src/
│   ├── index.jsx       # 全部 composition 注册
│   ├── Composition.jsx # 默认场景(可不用)
│   └── ep<N>/          # 按视频期归档组件
│       ├── TimelineMontage.jsx
│       ├── TimelineMontageB.jsx  # B variant
│       ├── TimelineMontageC.jsx  # C variant
│       └── ...
├── public/             # 静态资源(staticFile)
└── out/                # 渲染输出
```

## Composition id 命名 ⚠

**禁止下划线**:`TimelineMontageB` ✅ / `TimelineMontage_B` ❌

下划线 id 会导致 RemotionRoot 全局校验失败,**整个项目挂掉**。多 worker 协作时尤其要小心。

## 渲染命令

```bash
# Remotion 4.0.450+ 必须显式带 entry point
npx remotion render src/index.jsx <CompositionId> out/<name>.mp4 --concurrency=2
```

省 `src/index.jsx` 会报 `No entry point specified`,即使 package.json 配了 entry。

## frame clamp freeze(Variant B 套路)

NYX 反馈"读不完"时,常做 Variant B:动画到中段 freeze 后段静帧给眼睛多看一拍。

**关键技巧**(一行实现):
```jsx
const ANIM_END = 30;
export const FooB = () => {
  const rawFrame = useCurrentFrame();
  const frame = Math.min(rawFrame, ANIM_END);  // ← 后续所有 spring/interpolate/Math.sin 自动冻结
  // 下面所有动画代码完全照抄原版,不动一个字
};
```

## B / C 对偶 variant

NYX 让派多个 worker 同时改时,常出 A/B/C 三个变体让他对比:
- **A** 原版:NYX 已看过的基线
- **B** 加时长 + freeze 后段:慢节奏
- **C** 砍装饰 + 微加时长:聚焦视觉

每个 variant 一个独立 composition id(`FooB` / `FooC`),共享同一份 props 接口。

## 多 worker 改 index.jsx 协议

撞同一个 `index.jsx` 容易出:
- "Multiple composition with id Foo are registered" — 两个 worker 各加一份注册
- 一个 worker 改的同时另一个把同段重新写,id 漂移

**协议**:
1. 改 index.jsx 前 grep 一下 `id="<前缀>` 看现状,再决定加 / 改
2. 一个 composition entry 只允许一个 worker 维护
3. 改完立刻 `npx remotion render src/index.jsx <id> <out>` 验证(必须显式 entry point),挂了看 `/tmp/render_*.log` 里 `Error` 行(不是 React stack)
4. board.md 第一条标"我要动 index.jsx 的 X composition",降低撞车概率

## 影视飓风 3D rotateY 套路

多张相关图(GitHub README 全图 + zoom 图)别用 ffmpeg 双图拼接,改 Remotion 3D rotateY 翻转:

```jsx
const rotY = interpolate(frame, [0, 30], [0, 15], {extrapolateRight: 'clamp'});
<div style={{transform: `perspective(1200px) rotateY(${rotY}deg)`, transformStyle: 'preserve-3d'}}>
  <img src={...} />
</div>
```

视觉效果像真实双机位看截图,1.5-2s 完成。

## 字号 / 颜色 / 节奏(参考 knowledge-explainer-skill)

- 字号:标签 14, 正文 22, 标题 28-44, 大字 60+
- 颜色:bg #0a0a14 / #1a1a2e,主色 #6c5ce7 / #00cec9 / #4DC3FF / #FFD64D
- 出现节奏:先静(0-22f)再入场,避免一次全出
- 单镜停留:1-2s(跟切镜节奏一致),长镜头需内置动效持续刷新

## 渲染失败 debug

```bash
# 看错误行(不是 React stack)
grep -E "Error|error|fail" /tmp/render_*.log | head
```

常见错误:
- `Multiple composition with id` → 多 worker 撞车,grep id 后只留一份注册
- `Invalid composition id "Foo_B"` → 下划线被禁,改 `FooB`
- `Cannot find module './ep<N>/Foo'` → import 路径或文件名拼错
