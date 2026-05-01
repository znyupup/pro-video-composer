#!/bin/bash
# pro-video-composer · Step 3: 生成 / 刷新可视化分镜看板
#
# 用法: bash generate-storyboard.sh scenes_aligned.json [out=out/storyboard.html] [final_video_path]
# 输出: storyboard.html (浅色 macOS 风, 双击浏览器打开)

set -e

SCENES="${1:-}"
OUT="${2:-out/storyboard.html}"
FINAL_VIDEO="${3:-}"  # 如果有 FINAL.mp4 则嵌入预览

if [ -z "$SCENES" ] || [ ! -f "$SCENES" ]; then
  echo "Usage: $0 <scenes_aligned.json> [out=out/storyboard.html] [final_video_path]"
  exit 1
fi

mkdir -p "$(dirname "$OUT")"

SKILL_DIR=$(dirname "$(realpath "$0")")/..
TEMPLATE="$SKILL_DIR/templates/storyboard.template.html"

if [ ! -f "$TEMPLATE" ]; then
  echo "ERROR: storyboard 模板缺失: $TEMPLATE" >&2
  exit 1
fi

NOW=$(date "+%Y-%m-%d %H:%M (%Z)")

# Inject scenes data + final video + timestamp into template
python3 <<PY
import json, re
with open("$SCENES") as f:
    data = json.load(f)
with open("$TEMPLATE") as f:
    tmpl = f.read()

scenes_json = json.dumps(data["scenes"], ensure_ascii=False)
total_dur = data.get("total_audio_duration", 0)
align_method = data.get("alignment_method", "?")
final_video = "$FINAL_VIDEO"

# Compute progress: 完成的 scene 比例(有 visual_ready 标记)
done = sum(1 for s in data["scenes"] if s.get("status") == "done")
total = len(data["scenes"])
pct = int(done / total * 100) if total else 0

video_block = ""
if final_video:
    video_block = f"""
    <div class="section-summary">
      <strong>整片预览</strong>
      <video src="{final_video}" controls preload="metadata"></video>
      <p style="font-size: 12px; color: #6b7280; margin-top: 8px;">🎯 时长 {total_dur}s · 文件 <code>{final_video}</code></p>
    </div>
    """

html = tmpl.replace("__SCENES_JSON__", scenes_json) \
           .replace("__TOTAL_DURATION__", str(total_dur)) \
           .replace("__ALIGN_METHOD__", align_method) \
           .replace("__LAST_UPDATED__", "$NOW") \
           .replace("__PROGRESS_PCT__", str(pct)) \
           .replace("__PROGRESS_TEXT__", f"{done} / {total} scenes 已就绪") \
           .replace("__FINAL_VIDEO_BLOCK__", video_block)

with open("$OUT", "w") as f:
    f.write(html)

print(f"✅ Storyboard 已生成: $OUT")
print(f"   {total} scenes / {done} 完成 / {pct}% 进度")
print(f"   时长: {total_dur}s · 对齐: {align_method}")
PY

echo ""
echo "📂 输出: $OUT"
echo "📌 双击 $OUT 浏览器打开看分镜"
