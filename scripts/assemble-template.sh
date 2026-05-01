#!/bin/bash
# pro-video-composer · FINAL recipe 通用模板
#
# 用法:
#   1. 复制本文件为 0XXX_<project>_FINAL_recipe.sh
#   2. 改下方 CONFIG 区
#   3. 跑 bash <new>.sh 出 FINAL.mp4
#
# 输入要求 (放在 $TMP/):
#   - c01.mp4, c02.mp4, ... cNN.mp4 (主层 cuts, 30fps 1280x720)
#   - voice_landscape.mp4 (数字人横屏完整版, 1280x720)
#   - voice_audio.aac (口播音轨)
# 输出: $OUT (FINAL.mp4)

set -e

# ============== CONFIG (改这里) ==============
ROOT="/path/to/project"
TMP="$ROOT/_assemble_tmp"          # 中间文件目录
OUT="$ROOT/0XXX_<project>_FINAL_v1.mp4"

# 主层 cut 列表 (按顺序)
CUTS=(c01 c02 c03 c04 c05 c06 c07 c08 c09 c10 c11 c12)

# PiP 数字人 crop 偏移 (vision 测人物 x_center, 起点 = x_center - 210)
PIP_CROP_X=330       # 默认 330 (人物在 x=540)
PIP_CROP_Y=60        # 默认 60 (露脸 + 上半身)

# cut5 全屏切换时间窗 (距素材内拼接点 ≥ 1s)
FS_FADE_IN=10.13     # fade in 起点
FS_FADE_OUT_START=11.33  # fade out 起点 (= fade in + duration of hold)
FS_END=11.53         # 全屏完全退出

# 整片总时长 (略大于主层 concat 总长, 用于 -t 截断)
TOTAL_DURATION=22.63

# ============== STEP 1: concat 主层 ==============
echo "=== Step 1: concat 主层 ${#CUTS[@]} 段 ==="
> "$TMP/main_list.txt"
for c in "${CUTS[@]}"; do
  echo "file '$TMP/${c}.mp4'" >> "$TMP/main_list.txt"
done
ffmpeg -y -f concat -safe 0 -i "$TMP/main_list.txt" -c copy "$TMP/main_layer.mp4" 2>/dev/null

MAIN_DUR=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$TMP/main_layer.mp4")
echo "主层时长: ${MAIN_DUR}s (期望 ${TOTAL_DURATION}s)"

# ============== STEP 2: PiP overlay + 全屏切换 ==============
echo "=== Step 2: PiP overlay + cut5 全屏切换 ==="

cat > "$TMP/filter.txt" << EOF
[1:v]split=2[src1][src2];
[src1]crop=420:420:${PIP_CROP_X}:${PIP_CROP_Y},scale=220:220,format=yuva420p,geq=lum='p(X,Y)':a='if(gt(pow(X-110,2)+pow(Y-110,2),pow(108,2)),0,255)'[pip];
[src2]format=yuva420p,scale=1280:720,fade=t=in:st=${FS_FADE_IN}:d=0.2:alpha=1,fade=t=out:st=${FS_FADE_OUT_START}:d=0.2:alpha=1[fs];
[0:v][pip]overlay=W-w-30:H-h-30:enable='lte(t,${TOTAL_DURATION})'[v1];
[v1][fs]overlay=0:0:enable='gte(t,${FS_FADE_IN})*lte(t,${FS_END})'[v]
EOF

ffmpeg -y -i "$TMP/main_layer.mp4" -i "$TMP/voice_landscape.mp4" \
  -filter_complex_script "$TMP/filter.txt" \
  -map "[v]" -t "$TOTAL_DURATION" -c:v libx264 -preset veryfast -crf 18 \
  "$TMP/main_with_pip.mp4" 2>&1 | tail -2

# ============== STEP 3: 合并音轨 ==============
echo "=== Step 3: 合并音轨 ==="
ffmpeg -y -i "$TMP/main_with_pip.mp4" -i "$TMP/voice_audio.aac" \
  -filter_complex "[1:a]apad[a]" \
  -map 0:v -map "[a]" -c:v copy -c:a aac -b:a 192k -shortest \
  "$OUT" 2>&1 | tail -2

# ============== 完成 ==============
echo ""
echo "=== ✅ FINAL ==="
ls -lh "$OUT"
ffprobe -v quiet -print_format json -show_format "$OUT" | jq -r '.format | "duration: \(.duration)s, size: \((.size|tonumber)/1024/1024 | floor) MB"'
