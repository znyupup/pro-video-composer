#!/bin/bash
# pro-video-composer · Step 1: LLM 拆分镜
#
# 用法: bash split-scenes.sh script.md [out_path] [target_seconds_per_scene]
# 输出: scenes.json
#
# 调用 LLM(优先 mavis llm-call,fallback matrix MCP)拆分镜
# 默认目标 1.8-2.2s/镜(Hook 段大 V 节奏)

set -e

SCRIPT="${1:-}"
OUT="${2:-out/scenes.json}"
TARGET_SEC="${3:-2.0}"

if [ -z "$SCRIPT" ] || [ ! -f "$SCRIPT" ]; then
  echo "Usage: $0 <script.md> [out=out/scenes.json] [target_sec=2.0]"
  exit 1
fi

mkdir -p "$(dirname "$OUT")"

PROMPT=$(cat <<EOF
你是视频分镜师。我给你一段视频文稿,请按平均 ${TARGET_SEC}s/镜 拆成多个分镜,产出 JSON。

每个分镜必须包含:
- id (字符串, 形如 c01, c02, ...)
- text (这一镜的口播文本片段, 中文/英文)
- est_duration (估计秒数, 1.5-3.0 之间)
- visual_hint (视觉建议, 取以下之一: "remotion" 概念动画 / "screenshot" 截图 / "broll" 空镜 / "record_placeholder" 待录屏 / "avatar_pip" 数字人 PiP 强调 / "transition" 转场)

规则:
1. 平均 ${TARGET_SEC}s/镜, 容差 1.5-2.5s, 极少数转场镜可以 0.5-1s
2. 总时长应接近文稿口播时间(中文每字约 0.2s, 英文每词约 0.3s)
3. 最后一镜可以是 "transition" 类型(0.5-2s, 无口播 text 留空)
4. visual_hint 选择策略:
   - 抽象概念/数字/对比 → remotion
   - 工具UI/代码/网页 → screenshot
   - 节奏调味/换气衔接 → broll  
   - 操作演示/真实场景 → record_placeholder
   - 强调"主持人/数字人"那一刻 → avatar_pip
   - 转场 → transition

输出格式 (严格 JSON, 无 markdown 代码块):
{
  "scenes": [
    {"id": "c01", "text": "...", "est_duration": 2.0, "visual_hint": "remotion"},
    ...
  ],
  "total_estimated_duration": 22.0
}

文稿:
$(cat "$SCRIPT")
EOF
)

# Try llm-call (python script directly, more reliable than `mavis llm-call` wrapper)
LLM_SKILL_DIR=$(mavis skill show llm-call 2>/dev/null | python3 -c "import sys, json; print(json.load(sys.stdin)['location'].rsplit('/', 1)[0])" 2>/dev/null)
if [ -n "$LLM_SKILL_DIR" ] && [ -f "$LLM_SKILL_DIR/scripts/llm_call.py" ]; then
  echo "=== using llm-call (anthropic/claude-sonnet-4-6) ===" >&2
  python3 "$LLM_SKILL_DIR/scripts/llm_call.py" \
    --model anthropic/claude-sonnet-4-6 \
    --system "你是视频分镜师, 严格输出 JSON 不带任何其他文字" \
    --prompt "$PROMPT" 2>/dev/null > "$OUT.raw"
else
  echo "ERROR: llm-call skill 不可用, 请装 mavis llm-call" >&2
  exit 1
fi

# Extract JSON from response (strip code blocks if any)
PYSCRIPT=$(mktemp /tmp/extract-XXXXXX.py)
cat > "$PYSCRIPT" <<'PYEND'
import json, re, sys
raw_path = sys.argv[1]
out_path = sys.argv[2]
with open(raw_path) as f:
    txt = f.read()
# Strip markdown code blocks
txt = txt.strip()
# Remove leading/trailing code fences
txt = re.sub(r'^```(?:json)?\s*\n?', '', txt)
txt = re.sub(r'\n?```\s*$', '', txt)
# Find first {...} block
m = re.search(r'\{.*\}', txt, re.DOTALL)
if m:
    txt = m.group(0)
data = json.loads(txt)
with open(out_path, 'w') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
PYEND

python3 "$PYSCRIPT" "$OUT.raw" "$OUT"
rm -f "$PYSCRIPT" "$OUT.raw"

echo ""
echo "=== ✅ 分镜拆解完成 ==="
python3 -c "
import json
d = json.load(open('$OUT'))
print(f\"总分镜数: {len(d['scenes'])}\")
print(f\"估计总时长: {d.get('total_estimated_duration', '?')}s\")
print()
for s in d['scenes']:
    print(f\"  {s['id']:6s} {s['est_duration']:.1f}s  [{s['visual_hint']:18s}]  {s.get('text', '')[:40]}\")
"
echo ""
echo "📂 输出: $OUT"
echo "📌 下一步: bash asr-align.sh <voiceover.mp3> $OUT"
