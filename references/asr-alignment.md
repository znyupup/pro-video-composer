# ASR 时间轴对齐

把 LLM 拆出的分镜文本对齐到录音真实时间轴(start/end_sec)。

## 工具优先级

1. **funASR**(本地优先,中文最准):`paraformer-zh + fsmn-vad + ct-punc-c`
2. **matrix MCP** `matrix_listen_audio`(无 funASR 时 fallback)
3. **线性 fallback**(无 ASR 时,按 est_duration 比例分配)

详见 `docs/asr-recipes.md` (项目级 doc, asr-aligner 入场必读)。

## 对齐策略

funASR 输出格式:
```python
{
  "text": "想做一条5分钟科普视频?以前要花我3天剪辑..." (含标点),
  "timestamp": [[start_ms, end_ms], ...]  # 每个有声字一个
}
```

注意:`timestamp` 只对应**有声字**(标点不算)。

对齐算法:
1. 遍历 ASR text,过滤掉标点,得到 `voiced[]`(每元素 = (text 索引, 字符))
2. `char_ts[i]` 对应 `voiced[i]` 的时间戳
3. 维护 cursor:从 0 开始,每个 scene.text 占用 N 个有声字 → cursor 推 N
4. scene.start_sec = char_ts[cursor][0] / 1000
5. scene.end_sec = char_ts[cursor + N - 1][1] / 1000

## 边界情况

| 情况 | 处理 |
|---|---|
| scene.text 为空(transition) | 紧接前一 scene.end_sec,长度 = est_duration |
| ASR 字数 < 文稿字数(漏识) | cursor 越界时 fallback est_duration tail |
| ASR 完全失败 | 全部 fallback 线性分配(按 est_duration 占比) |

## 校验

对齐完后必看:
- [ ] 总时长 ≈ 音频时长(±0.5s)
- [ ] 没有 scene.start > scene.end
- [ ] 没有 scene.duration > 5s 或 < 0.3s(异常值)

异常时:看 `alignment_method` 字段,`linear-fallback` 表示 ASR 失败,要让用户检查 funASR 是否装好。
