#!/bin/bash
# pro-video-composer · Step 2: ASR 转录音 → 时间轴对齐分镜
#
# 用法: bash asr-align.sh voiceover.mp3 scenes.json [out=scenes_aligned.json]
# 输出: scenes_aligned.json (每 scene 加 start_sec / end_sec / duration_sec)
#
# 用 funASR (paraformer-zh + fsmn-vad + ct-punc-c) 产字级时间戳, 按文本相似度匹配
# Fallback: matrix MCP matrix_listen_audio

set -e

VOICE="${1:-}"
SCENES="${2:-}"
OUT="${3:-${SCENES%.json}_aligned.json}"

if [ -z "$VOICE" ] || [ -z "$SCENES" ] || [ ! -f "$VOICE" ] || [ ! -f "$SCENES" ]; then
  echo "Usage: $0 <voiceover.mp3> <scenes.json> [out=scenes_aligned.json]"
  exit 1
fi

mkdir -p "$(dirname "$OUT")"

# Try funASR first (local, most accurate for Chinese)
ASR_OUT=$(mktemp /tmp/asr-XXXXXX.json)

if python3 -c "import funasr" 2>/dev/null; then
  echo "=== using funASR (local) ===" >&2
  python3 <<PY > "$ASR_OUT"
import json
from funasr import AutoModel
m = AutoModel(model="paraformer-zh", vad_model="fsmn-vad", punc_model="ct-punc-c")
res = m.generate(input="$VOICE")
out = []
if res and len(res) > 0:
    r = res[0]
    text = r.get("text", "")
    ts = r.get("timestamp", [])
    # Pair char to ts (timestamp is per voiced char, text may have punc)
    out = {"text": text, "char_timestamps": ts}
print(json.dumps(out, ensure_ascii=False))
PY
else
  echo "=== fallback: matrix MCP listen_audio ===" >&2
  mavis mcp call matrix matrix_listen_audio "{\"file\":\"$VOICE\"}" 2>/dev/null > "$ASR_OUT" || {
    echo "ERROR: 无 funASR 也无 matrix MCP, 用线性 fallback" >&2
    DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$VOICE")
    echo "{\"duration_only\": $DURATION}" > "$ASR_OUT"
  }
fi

# Align scenes to timestamps
python3 <<PY > "$OUT"
import json, re

with open("$SCENES") as f:
    scenes_data = json.load(f)
with open("$ASR_OUT") as f:
    asr = json.load(f)

scenes = scenes_data["scenes"]
total_audio_dur = None

# Get audio actual duration
import subprocess
total_audio_dur = float(subprocess.check_output([
    "ffprobe", "-v", "error", "-show_entries", "format=duration",
    "-of", "default=noprint_wrappers=1:nokey=1", "$VOICE"
]).decode().strip())

# Strategy:
# Have ASR text + char_timestamps → match each scene.text to its position in ASR text → pull start/end ms
# Fallback: linear distribution by est_duration ratios

asr_text = asr.get("text", "")
char_ts = asr.get("char_timestamps", [])

if asr_text and char_ts:
    # Strip punctuation from asr_text and create voiced-char index map
    voiced = []
    for i, c in enumerate(asr_text):
        if not re.match(r'[\s\u3000\uff0c\u3002\uff1f\uff01\u201c\u201d\u2018\u2019\u3001\.\?\!\,\;\:\(\)\[\]]', c):
            voiced.append((i, c))

    # voiced[i] corresponds to char_ts[i] = [start_ms, end_ms]
    # Match scene.text to substring in asr_text (greedy from cursor)
    cursor_voiced = 0
    aligned = []
    for sc in scenes:
        text = re.sub(r'[\s\u3000\uff0c\u3002\uff1f\uff01\u201c\u201d\u2018\u2019\u3001\.\?\!\,\;\:\(\)\[\]]', '', sc.get("text", ""))
        if not text:
            # transition / no-text scene: take est_duration after last
            last_end = aligned[-1]["end_sec"] if aligned else 0.0
            aligned.append({**sc,
                "start_sec": round(last_end, 3),
                "end_sec": round(last_end + sc.get("est_duration", 1.5), 3),
                "duration_sec": round(sc.get("est_duration", 1.5), 3),
                "alignment": "no-text-after-prev"
            })
            continue
        # find this many voiced chars from cursor
        n = len(text)
        if cursor_voiced + n > len(char_ts):
            n = len(char_ts) - cursor_voiced
        if n <= 0:
            # ran out - use est_duration tail
            last_end = aligned[-1]["end_sec"] if aligned else 0.0
            aligned.append({**sc,
                "start_sec": round(last_end, 3),
                "end_sec": round(last_end + sc.get("est_duration", 1.5), 3),
                "duration_sec": round(sc.get("est_duration", 1.5), 3),
                "alignment": "fallback-est-tail"
            })
            continue
        start_ms = char_ts[cursor_voiced][0]
        end_ms = char_ts[cursor_voiced + n - 1][1]
        cursor_voiced += n
        aligned.append({**sc,
            "start_sec": round(start_ms/1000, 3),
            "end_sec": round(end_ms/1000, 3),
            "duration_sec": round((end_ms-start_ms)/1000, 3),
            "alignment": "asr-matched"
        })
else:
    # Linear fallback: distribute by est_duration ratios
    total_est = sum(s.get("est_duration", 2.0) for s in scenes)
    cursor = 0.0
    aligned = []
    for sc in scenes:
        dur = sc.get("est_duration", 2.0) / total_est * total_audio_dur
        aligned.append({**sc,
            "start_sec": round(cursor, 3),
            "end_sec": round(cursor + dur, 3),
            "duration_sec": round(dur, 3),
            "alignment": "linear-fallback"
        })
        cursor += dur

result = {
    "scenes": aligned,
    "total_audio_duration": round(total_audio_dur, 3),
    "alignment_method": "asr" if (asr_text and char_ts) else "linear-fallback"
}
print(json.dumps(result, ensure_ascii=False, indent=2))
PY

rm -f "$ASR_OUT"

echo ""
echo "=== ✅ ASR 对齐完成 ==="
python3 -c "
import json
d = json.load(open('$OUT'))
print(f\"音频总时长: {d['total_audio_duration']}s\")
print(f\"对齐方法: {d['alignment_method']}\")
print()
for s in d['scenes']:
    print(f\"  {s['id']:6s} {s['start_sec']:6.2f} → {s['end_sec']:6.2f} ({s['duration_sec']:.2f}s)  [{s['visual_hint']:18s}]  {s.get('text', '')[:36]}\")
"
echo ""
echo "📂 输出: $OUT"
echo "📌 下一步: bash generate-storyboard.sh $OUT out/storyboard.html"
