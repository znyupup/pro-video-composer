#!/usr/bin/env bash
# voice-clone.sh — MiniMax 音色复刻完整流程
#
# 用法:
#   bash voice-clone.sh <main.mp3> [sample.mp3]
#
# 流程:
#   1. 上传主音频 → file_id
#   2. (可选) 示例音频 ASR → transcript.md → 等用户校对
#   3. 调 voice cloning API → voice_id
#   4. 测试合成验证
#   5. 写入 voice_clone/voice_id.txt

set -e

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$(pwd)/voice_clone}"
mkdir -p "$WORK_DIR"

MAIN_AUDIO="$1"
SAMPLE_AUDIO="$2"

if [ -z "$MAIN_AUDIO" ] || [ ! -f "$MAIN_AUDIO" ]; then
  echo "ERROR: 必须指定主音频文件"
  echo "Usage: bash voice-clone.sh <main.mp3> [sample.mp3]"
  exit 1
fi

# 检查时长
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$MAIN_AUDIO")
DUR_INT=$(printf "%.0f" "$DUR")
if (( DUR_INT < 60 || DUR_INT > 180 )); then
  echo "⚠️  主音频时长 ${DUR}s 不在推荐范围 60-180s,继续? [y/N]"
  read -r CONFIRM
  [ "$CONFIRM" != "y" ] && exit 1
fi

# === Step 1:上传主音频 ===
echo "[1/5] 上传主音频 $MAIN_AUDIO ($(printf '%.1f' $DUR)s) ..."
UPLOAD_RESP=$(curl -s -X POST "https://api.minimaxi.com/v1/files" \
  -H "Authorization: Bearer ${MINIMAX_API_KEY:-$(security find-generic-password -s minimax -w 2>/dev/null)}" \
  -F "purpose=voice_clone" \
  -F "file=@$MAIN_AUDIO")
MAIN_FILE_ID=$(echo "$UPLOAD_RESP" | python3 -c "import json,sys; print(json.load(sys.stdin).get('file',{}).get('file_id',''))")
if [ -z "$MAIN_FILE_ID" ]; then
  echo "ERROR: 上传失败 $UPLOAD_RESP"
  exit 1
fi
echo "      ✓ file_id: $MAIN_FILE_ID"

# === Step 2:示例音频 ASR(可选)===
SAMPLE_TRANSCRIPT=""
if [ -n "$SAMPLE_AUDIO" ] && [ -f "$SAMPLE_AUDIO" ]; then
  echo "[2/5] 示例音频 ASR 转录 ..."
  TRANSCRIPT_FILE="$WORK_DIR/transcript.md"
  python3 "$SKILL_DIR/scripts/minimax-asr.py" --input "$SAMPLE_AUDIO" --output "$TRANSCRIPT_FILE"

  echo "      ⏸  打开 $TRANSCRIPT_FILE 校对错字 ..."
  ${EDITOR:-vim} "$TRANSCRIPT_FILE"
  SAMPLE_TRANSCRIPT=$(grep -v "^#" "$TRANSCRIPT_FILE" | grep -v "^<!--" | grep -v "^$" | head -20 | tr '\n' ' ')
  echo "      ✓ 校对完成,长度 ${#SAMPLE_TRANSCRIPT} 字"
else
  echo "[2/5] 跳过示例音频(未提供)"
fi

# === Step 3:调 voice cloning API ===
VOICE_ID="${VOICE_ID:-MyVoice$(date +%Y)}"
echo "[3/5] 调用 voice cloning API (voice_id: $VOICE_ID) ..."
if [ -n "$SAMPLE_AUDIO" ]; then
  # 上传示例音频
  SAMPLE_RESP=$(curl -s -X POST "https://api.minimaxi.com/v1/files" \
    -H "Authorization: Bearer ${MINIMAX_API_KEY:-$(security find-generic-password -s minimax -w 2>/dev/null)}" \
    -F "purpose=voice_clone" \
    -F "file=@$SAMPLE_AUDIO")
  SAMPLE_FILE_ID=$(echo "$SAMPLE_RESP" | python3 -c "import json,sys; print(json.load(sys.stdin).get('file',{}).get('file_id',''))")
  CLONE_PAYLOAD=$(python3 -c "
import json
print(json.dumps({
  'voice_id': '$VOICE_ID',
  'file_id': '$MAIN_FILE_ID',
  'audio_file': '$SAMPLE_FILE_ID',
  'text': '''$SAMPLE_TRANSCRIPT'''
}, ensure_ascii=False))")
else
  CLONE_PAYLOAD="{\"voice_id\":\"$VOICE_ID\",\"file_id\":\"$MAIN_FILE_ID\"}"
fi

CLONE_RESP=$(curl -s -X POST "https://api.minimaxi.com/v1/voice_cloning/clone" \
  -H "Authorization: Bearer ${MINIMAX_API_KEY:-$(security find-generic-password -s minimax -w 2>/dev/null)}" \
  -H "Content-Type: application/json" \
  -d "$CLONE_PAYLOAD")
STATUS=$(echo "$CLONE_RESP" | python3 -c "import json,sys; print(json.load(sys.stdin).get('base_resp',{}).get('status_code',-1))")
if [ "$STATUS" != "0" ]; then
  echo "ERROR: 复刻失败 $CLONE_RESP"
  exit 1
fi
echo "      ✓ voice_id: $VOICE_ID"

# === Step 4:测试合成 ===
echo "[4/5] 测试合成 \"你好,我是 $VOICE_ID\" ..."
python3 "$SKILL_DIR/scripts/minimax-t2a.py" \
  --voice-id "$VOICE_ID" \
  --text "你好,我是 $VOICE_ID,这是音色复刻测试。" \
  --emotion happy \
  --speed 1.2 \
  --output "$WORK_DIR/test.mp3"

# === Step 5:落档 ===
echo "$VOICE_ID" > "$WORK_DIR/voice_id.txt"
echo "[5/5] ✓ voice_id 写入 $WORK_DIR/voice_id.txt"
echo
echo "🎉 复刻完成!试听:$WORK_DIR/test.mp3"
echo "   voice_id: $VOICE_ID (7 天不调用 T2A 会被自动删除)"
