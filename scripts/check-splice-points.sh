#!/bin/bash
# pro-video-composer · 检测拼接素材的拼接点
#
# 用法: bash check-splice-points.sh <video.mp4>
# 输出: 候选拼接点时间 + 安全区段 (适合放 fade out 完成位置)

set -e

VIDEO="${1:-}"
if [ -z "$VIDEO" ] || [ ! -f "$VIDEO" ]; then
  echo "Usage: $0 <video.mp4>"
  exit 1
fi

echo "=== 分析 $VIDEO ==="
DUR=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$VIDEO")
echo "总时长: ${DUR}s"

# 用 scene cut 检测 (frame-level scene change >= 0.3 通常对应硬切)
echo ""
echo "=== Scene cut 检测 (potential 拼接点) ==="
ffmpeg -i "$VIDEO" -filter:v "select='gt(scene,0.3)',showinfo" -f null - 2>&1 \
  | grep -oE 'pts_time:[0-9.]+' \
  | sed 's/pts_time://' \
  | awk '{printf "  候选拼接点: t=%ss\n", $1}'

# 也用 freezedetect (静止帧通常出现在拼接附近)
echo ""
echo "=== Freeze frame 检测 (拼接前后常有 stall) ==="
ffmpeg -i "$VIDEO" -vf "freezedetect=n=-60dB:d=0.05" -map 0:v:0 -f null - 2>&1 \
  | grep -E "freeze_(start|end|duration)" \
  | head -10

echo ""
echo "=== 安全区段建议 ==="
echo "若发现拼接点 t=X:"
echo "  - 全屏 fade out 完成时间应 < X - 1.0s"
echo "  - 或 全屏 fade in 起点 > X + 1.0s (跨过拼接区)"
echo "  - PiP 圆框 220x220 在拼接点期间天然弱化卡顿,可不做特殊处理"
echo ""
echo "📖 完整安全余量规则: references/splice-safety-rules.md"
