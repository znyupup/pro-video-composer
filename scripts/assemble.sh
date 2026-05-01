#!/bin/bash
# pro-video-composer · Step 6: ffmpeg 程序化拼接
#
# 用法: bash assemble.sh scenes_aligned.json voiceover.mp3 [avatar.mp4] [out=FINAL.mp4]
#
# 假定每个 scene 已有 video_path 字段(Step 4 视觉源就绪后回写到 json)

set -e

SCENES="${1:-}"
VOICE="${2:-}"
AVATAR="${3:-}"
OUT="${4:-out/FINAL.mp4}"

if [ -z "$SCENES" ] || [ -z "$VOICE" ]; then
  echo "Usage: $0 <scenes_aligned.json> <voiceover.mp3> [avatar.mp4] [out=out/FINAL.mp4]"
  exit 1
fi

mkdir -p "$(dirname "$OUT")"
TMP=$(mktemp -d /tmp/assemble-XXXXXX)
trap "rm -rf $TMP" EXIT

# Step 1: concat 主层 cut by cut
echo "=== Step 1: concat 主层 ==="
LIST="$TMP/main_list.txt"
> "$LIST"
python3 <<PY
import json
d = json.load(open("$SCENES"))
with open("$LIST", "w") as f:
    for s in d["scenes"]:
        vp = s.get("video_path")
        if not vp:
            print(f"⚠ scene {s['id']} 无 video_path, 跳过 (visual_hint={s.get('visual_hint')})")
            continue
        f.write(f"file '{vp}'\n")
PY

ffmpeg -y -f concat -safe 0 -i "$LIST" -c copy "$TMP/main_layer.mp4" 2>&1 | tail -2

MAIN_DUR=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$TMP/main_layer.mp4")
echo "主层时长: ${MAIN_DUR}s"

# Step 2: PiP overlay (如有 avatar)
if [ -n "$AVATAR" ] && [ -f "$AVATAR" ]; then
  echo "=== Step 2: PiP 数字人 overlay ==="

  # 默认 crop 偏移以脸部为中心 (用户应根据自己 avatar 测 x_center 后改 PIP_CROP_X)
  # 这里用通用 330 (假定人物在 1280x720 画面 x=540)
  PIP_CROP_X="${PIP_CROP_X:-330}"
  PIP_CROP_Y="${PIP_CROP_Y:-60}"

  cat > "$TMP/filter.txt" <<FILTER
[1:v]crop=420:420:${PIP_CROP_X}:${PIP_CROP_Y},scale=220:220,format=yuva420p,geq=lum='p(X,Y)':a='if(gt(pow(X-110,2)+pow(Y-110,2),pow(108,2)),0,255)'[pip];
[0:v][pip]overlay=W-w-30:H-h-30:enable='lte(t,${MAIN_DUR})'[v]
FILTER

  ffmpeg -y -i "$TMP/main_layer.mp4" -i "$AVATAR" \
    -filter_complex_script "$TMP/filter.txt" \
    -map "[v]" -t "$MAIN_DUR" -c:v libx264 -preset veryfast -crf 18 \
    "$TMP/main_with_pip.mp4" 2>&1 | tail -2

  WITH_PIP="$TMP/main_with_pip.mp4"
else
  echo "=== 跳过 PiP (无 avatar) ==="
  WITH_PIP="$TMP/main_layer.mp4"
fi

# Step 3: 合并音轨
echo "=== Step 3: 合并音轨 ==="
ffmpeg -y -i "$WITH_PIP" -i "$VOICE" \
  -filter_complex "[1:a]apad[a]" \
  -map 0:v -map "[a]" -c:v copy -c:a aac -b:a 192k -shortest \
  "$OUT" 2>&1 | tail -2

# Step 4: 验证
echo ""
echo "=== ✅ FINAL ==="
ls -lh "$OUT"
ffprobe -v quiet -print_format json -show_format "$OUT" | python3 -c "
import json, sys
d = json.load(sys.stdin)['format']
print(f'  duration: {float(d[\"duration\"]):.2f}s')
print(f'  size: {int(d[\"size\"])/1024/1024:.1f} MB')
print(f'  bitrate: {int(d[\"bit_rate\"])/1000:.0f} kbps')
"
echo ""
echo "📂 输出: $OUT"
echo "📌 推送给用户 + 同时刷 storyboard.html (传入 final_video_path 参数)"
