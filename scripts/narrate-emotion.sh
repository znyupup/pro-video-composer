#!/usr/bin/env bash
# narrate-emotion.sh — 用 emotion_plan.json 逐段合成口播 mp3
#
# 输入:emotion_plan.json (agent 拆句标情绪后的产物,符合 templates/emotion_plan.schema.json)
# 输出:out/narration.mp3 + out/narration_segments/seg{N}.mp3 + out/emotion_plan.html
#
# 用法:
#   bash narrate-emotion.sh emotion_plan.json [out_dir]

set -e

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLAN_FILE="$1"
OUT_DIR="${2:-./out}"

if [ -z "$PLAN_FILE" ] || [ ! -f "$PLAN_FILE" ]; then
  echo "ERROR: 必须指定 emotion_plan.json"
  echo "Usage: bash narrate-emotion.sh <emotion_plan.json> [out_dir]"
  echo
  echo "Schema 见 $SKILL_DIR/templates/emotion_plan.schema.json"
  exit 1
fi

mkdir -p "$OUT_DIR/narration_segments"

# 校验 + 解析
python3 - <<PYEOF
import json, sys
plan = json.load(open("$PLAN_FILE"))
SAFE = {"happy", "surprised", "calm", "sad", "fluent"}
BLACKLIST = ["啦", "诶", "(breath)", "(chuckle)", "(sigh)", "<#"]
errors = []
for s in plan["segments"]:
    if s["emotion"] not in SAFE:
        errors.append(f"seg{s['id']}: emotion '{s['emotion']}' 不在安全集 {SAFE}")
    if len(s["text"]) > 80:
        errors.append(f"seg{s['id']}: 文本 {len(s['text'])} 字 > 80,会触发长段偏移")
    for bad in BLACKLIST:
        if bad in s["text"]:
            errors.append(f"seg{s['id']}: 包含黑名单 '{bad}'")
if errors:
    print("校验失败:")
    for e in errors: print(f"  ❌ {e}")
    sys.exit(1)
print(f"✓ 校验通过 {len(plan['segments'])} 段")
PYEOF

VOICE_ID=$(python3 -c "import json; print(json.load(open('$PLAN_FILE'))['voice_id'])")
SPEED=$(python3 -c "import json; print(json.load(open('$PLAN_FILE')).get('speed', 1.2))")
SEG_COUNT=$(python3 -c "import json; print(len(json.load(open('$PLAN_FILE'))['segments']))")

echo "[1/3] 逐段合成 $SEG_COUNT 段 (voice_id: $VOICE_ID, speed: $SPEED)..."
for i in $(seq 1 $SEG_COUNT); do
  IDX=$((i - 1))
  TEXT=$(python3 -c "import json; print(json.load(open('$PLAN_FILE'))['segments'][$IDX]['text'])")
  EMOTION=$(python3 -c "import json; print(json.load(open('$PLAN_FILE'))['segments'][$IDX]['emotion'])")
  OUT="$OUT_DIR/narration_segments/seg${i}.mp3"
  printf "  seg%d/%d %s ... " "$i" "$SEG_COUNT" "$EMOTION"
  python3 "$SKILL_DIR/scripts/minimax-t2a.py" \
    --voice-id "$VOICE_ID" \
    --text "$TEXT" \
    --emotion "$EMOTION" \
    --speed "$SPEED" \
    --output "$OUT" 2>&1 | grep "^✓" || { echo "FAIL"; exit 1; }
done

echo "[2/3] ffmpeg concat ..."
CONCAT_FILE="$OUT_DIR/narration_segments/concat.txt"
> "$CONCAT_FILE"
for i in $(seq 1 $SEG_COUNT); do
  echo "file 'seg${i}.mp3'" >> "$CONCAT_FILE"
done
ffmpeg -f concat -safe 0 -i "$CONCAT_FILE" -c copy -y "$OUT_DIR/narration.mp3" 2>&1 | tail -1

# 总时长
TOTAL=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT_DIR/narration.mp3")
SIZE=$(stat -f%z "$OUT_DIR/narration.mp3" 2>/dev/null || stat -c%s "$OUT_DIR/narration.mp3")
SIZE_KB=$((SIZE / 1024))

echo "[3/3] 生成可视化 emotion 表 ..."
python3 - <<PYEOF
import json
plan = json.load(open("$PLAN_FILE"))
total = $TOTAL
html = f"""<!DOCTYPE html><html><head><meta charset='utf-8'>
<title>EmotionPlan</title><style>
body {{ font-family: -apple-system, sans-serif; padding: 40px; background: #0a0a14; color: #fff; }}
h1 {{ color: #FFD64D; }}
table {{ width: 100%; border-collapse: collapse; margin-top: 20px; }}
th, td {{ padding: 12px; text-align: left; border-bottom: 1px solid #333; }}
th {{ background: #1a1a24; color: #FFD64D; }}
.emotion {{ display: inline-block; padding: 4px 12px; border-radius: 4px; font-weight: 600; }}
.happy {{ background: #fbbf24; color: #000; }}
.surprised {{ background: #f87171; color: #000; }}
.calm {{ background: #60a5fa; color: #000; }}
.sad {{ background: #94a3b8; color: #000; }}
.fluent {{ background: #4ade80; color: #000; }}
</style></head><body>
<h1>📢 emotion_plan · {plan['voice_id']}</h1>
<p>共 {len(plan['segments'])} 段 · 总时长 {total:.2f}s · {SIZE_KB} KB</p>
<table><tr><th>#</th><th>Emotion</th><th>文本</th><th>估时</th></tr>
"""
for s in plan['segments']:
    html += f"<tr><td>{s['id']}</td><td><span class='emotion {s['emotion']}'>{s['emotion']}</span></td>"
    html += f"<td>{s['text']}</td><td>{s.get('est_duration', '-')}</td></tr>"
html += "</table></body></html>"
open("$OUT_DIR/emotion_plan.html", "w").write(html)
print("  ✓ emotion_plan.html")
PYEOF

echo
echo "🎉 narration.mp3 (${TOTAL}s, ${SIZE_KB}KB) → $OUT_DIR/narration.mp3"
echo "   单段 → $OUT_DIR/narration_segments/seg{1..$SEG_COUNT}.mp3"
echo "   可视化 → $OUT_DIR/emotion_plan.html"
