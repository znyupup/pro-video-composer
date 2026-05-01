#!/bin/bash
# pro-video-composer · 抽数字人 1 帧成圆形 PNG 头像
#
# 用法: bash extract-portrait.sh <source.mp4> <timestamp> <output.png> [crop_x] [crop_y]
# 输出: 220x220 圆形 alpha PNG 头像 (用于静态 PiP fallback,默认情况下不推荐用)
#
# 注:
#   - crop_x 默认 330 (NYX 完整版人物在 x=540, 起点 540-210=330)
#   - 不同数字人源人物位置不同, 调用前先 vision 测 x_center
#   - 用户通常要动态 PiP 不要静态, 这个脚本是 fallback

set -e

SRC="${1:-}"
TS="${2:-}"
OUT="${3:-}"
CROP_X="${4:-330}"
CROP_Y="${5:-60}"

if [ -z "$SRC" ] || [ -z "$TS" ] || [ -z "$OUT" ]; then
  echo "Usage: $0 <source.mp4> <timestamp_seconds> <output.png> [crop_x=330] [crop_y=60]"
  echo "Example: $0 voice_landscape.mp4 12.0 portrait.png 330 60"
  exit 1
fi

# scale + pad 归一化到 1280x720, 然后 crop=420x420 以脸部中心, scale 220, 圆形 alpha mask
ffmpeg -y -ss "$TS" -i "$SRC" -frames:v 1 \
  -vf "scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2,crop=420:420:${CROP_X}:${CROP_Y},scale=220:220,format=yuva420p,geq=lum='p(X,Y)':a='if(gt(pow(X-110,2)+pow(Y-110,2),pow(108,2)),0,255)'" \
  "$OUT" 2>&1 | tail -2

echo ""
echo "✅ 抽帧完成: $OUT"
ls -lh "$OUT"
echo ""
echo "📋 验证步骤:"
echo "  1. open $OUT"
echo "  2. 看人脸是否居中、表情自然 (嘴自然合 + 眼睁开 + 平视)"
echo "  3. 不满意换 timestamp 重抽"
echo ""
echo "⚠ 提醒: 用户通常要动态 PiP 不要静态头像, 除非用户明确要求才用这个静态 PNG."
