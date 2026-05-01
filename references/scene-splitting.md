# 分镜拆解(LLM prompt)

调用 LLM 把文稿拆成 ~13 个 ~2s/镜的分镜列表(JSON)。

## Prompt 关键约束

```
平均 1.8-2.2s/镜, 容差 1.5-2.5s, 极少数转场镜可以 0.5-1s
总时长应接近文稿口播时间 (中文每字 ~0.2s, 英文每词 ~0.3s)
最后一镜可以是 transition (0.5-2s, 无口播)
```

## visual_hint 类型选择

| hint | 使用场景 |
|---|---|
| `remotion` | 抽象概念 / 数字对比 / 时间线 / UI 演示动画 |
| `screenshot` | 工具 UI 截图 / 代码 / 网页 / GitHub README |
| `broll` | 节奏调味 / 换气衔接 / 空气感 (keyboard / coffee 等) |
| `record_placeholder` | 真实操作演示 / 真人入画段(标待录,等用户录) |
| `avatar_pip` | 强调"主持人在讲"的核心镜头 |
| `transition` | 段间转场(MVP HOOK / 主题切换) |

## 输出 JSON schema

```json
{
  "scenes": [
    {
      "id": "c01",
      "text": "口播片段",
      "est_duration": 2.0,
      "visual_hint": "remotion"
    }
  ],
  "total_estimated_duration": 22.0
}
```

## 失败处理

- LLM 拆数量明显偏离 (< 5 或 > 30):重 prompt 强调"~2s/镜 不要太碎也不要太大"
- LLM 输出非纯 JSON (有 markdown 代码块):脚本里 regex 提取 + json.loads
- 视觉 hint 全是同一类型(全 remotion):重 prompt 加"必须混用 3+ 类型"
