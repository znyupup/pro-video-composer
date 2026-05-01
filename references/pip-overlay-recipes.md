# PiP overlay 公式集

数字人圆形 PiP overlay 的完整 ffmpeg 公式 + 踩坑沉淀。

## 基础公式:圆形 alpha mask + scale 220

```
[input_video]crop=420:420:X:Y,scale=220:220,format=yuva420p,
  geq=lum='p(X,Y)':a='if(gt(pow(X-110,2)+pow(Y-110,2),pow(108,2)),0,255)'[pip]
```

参数说明:
- `crop=420:420:X:Y` — 从原画面抠 420×420 框,起点 (X, Y)
- `scale=220:220` — 缩到 220×220(影视飓风风格 PiP 尺寸)
- `geq` 圆形遮罩:中心 (110, 110) 半径 108 的圆,圈外 alpha=0,圈内 alpha=255
- 输出 `[pip]` 用于 overlay

## crop 偏移规则 ⭐(踩过的坑)

**人物中心 ≠ 画面中心** — 不同数字人源人物位置不同,必须先测:

1. ffmpeg 抽 1 帧到 PNG
2. vision 看人物在 1280×720 画面里的精确 x_center
3. crop 起点 X = x_center − 210(420 框居中,scale 后人脸恰在 220 圆中)
4. Y 一般 60-120(露脸 + 上半身,避免头顶截断)

**反例**:NYX ep3 数字人完整版人物在 x≈540,我用了 `crop=420:420:0:60` 抠左半画面 → PiP 圆框只看到书架 + 人物左肩 → **PiP 全程无人脸**。改成 `crop=420:420:330:60` 才正确。

**规则**:任何"PiP 圆框人脸不见"问题,90% 是 crop 偏移错,**先 vision 测,别急着换思路**。

## PiP overlay 位置

```
overlay=W-w-30:H-h-30:enable='lte(t,T_END)'
```

- `W-w-30:H-h-30` — 右下角偏移 30px(影视飓风通用)
- `enable='lte(t,T_END)'` — 限制时间窗

## 全屏切换公式 ⭐(简化版)

**思路**:PiP 永远 alpha=1,全屏 video 0.2s fade in/out 时 1280×720 直接盖住右下 PiP,不需要管 PiP 显隐。

```
[1:v]split=2[src1][src2];
[src1]crop=420:420:330:60,scale=220:220,format=yuva420p,
      geq=lum='p(X,Y)':a='if(gt(pow(X-110,2)+pow(Y-110,2),pow(108,2)),0,255)'[pip];
[src2]format=yuva420p,scale=1280:720,
      fade=t=in:st=10.13:d=0.2:alpha=1,
      fade=t=out:st=11.33:d=0.2:alpha=1[fs];
[main][pip]overlay=W-w-30:H-h-30:enable='lte(t,23)'[v1];
[v1][fs]overlay=0:0:enable='gte(t,10.13)*lte(t,11.53)'[v]
```

**关键设计**:
1. **split=2**:PiP 和全屏共用同一个数字人源,时间戳天然同步
2. **PiP 永远 alpha=1**:不需要 fade out / fade in PiP(全屏 alpha=1 时会盖住)
3. **fs fade in/out 0.2s**:平滑过渡,避免 hard cut

## 反模式:PiP fade in 不复活 ⚠

```
# ❌ 这个会让 PiP 在 t>9.64 永久消失
[1:v]loop=loop=-1...,fade=t=out:st=7.84:d=0.2:alpha=1,fade=t=in:st=9.24:d=0.2:alpha=1[pip]
```

`fade=in` 在 PNG loop input + 之前 fade out 后,alpha 残留 0,fade in 不会从 0 复活。

**修法**:用 `split=2` 分两路,各自 fade,enable 互斥区间;或者直接 PiP 永远 alpha=1 + fs 上层覆盖(推荐)。

## PiP 静态头像 fallback(用户拒绝过)

如果用户接受静态头像(NYX 拒绝过,要"陪伴感"动态),可以抽 1 帧成 PNG 用 `-loop 1` 输入:

```bash
ffmpeg -ss 12.0 -i source.mp4 -frames:v 1 \
  -vf "scale=1280:720:...,crop=420:420:330:60,scale=220:220,
       format=yuva420p,geq=lum='p(X,Y)':a='if(...)'" \
  portrait.png
```

然后:
```
ffmpeg -i main -loop 1 -t 22 -i portrait.png -i fs.mp4 ...
```

⚠ 默认**不要**用静态头像,用户通常要动态 PiP 维持"主持人正在讲" 的视觉。

## 数字人源选择优先级

1. **用户自己拼好的"完整版"** ✅ 优先
2. agent 自己 concat 多段 ❌ 容易拼接卡顿(见 `splice-safety-rules.md`)
3. 单段无拼接 ✅ 没问题但通常时长不够

## 验证 checklist

PiP overlay 写完后必须 sample 关键帧验证:
- [ ] cut 早段 PiP 圆框人脸完整
- [ ] cut 中段 PiP 圆框人脸完整(不会因为 video 内容变化失效)
- [ ] 全屏切换前后 PiP 完整(切换不跳)
- [ ] 全屏 hold 期间数字人完整 1280×720(无 crop 截断)
