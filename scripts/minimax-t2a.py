#!/usr/bin/env python3
"""
MiniMax T2A v2 调用 + 黑名单校验 + 锁定配方

用法:
  python minimax-t2a.py --voice-id NyxVoice2026 --emotion happy \
      --text "你好,我是 NyxVoice2026" --output out.mp3

环境变量:
  MINIMAX_API_KEY  必须 (或在 keychain `security find-generic-password -s minimax -w`)
"""
import argparse
import json
import os
import sys
import subprocess
from pathlib import Path

import requests

API_URL = "https://api.minimaxi.com/v1/t2a_v2"
SAFE_EMOTIONS = {"happy", "surprised", "calm", "sad", "fluent"}
TEXT_BLACKLIST = ["啦", "诶", "(breath)", "(chuckle)", "(sigh)", "<#"]
MAX_TEXT_LEN = 80


def get_api_key():
    key = os.environ.get("MINIMAX_API_KEY")
    if key:
        return key
    # 尝试从 keychain 读
    try:
        result = subprocess.run(
            ["security", "find-generic-password", "-s", "minimax", "-w"],
            capture_output=True, text=True, check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        sys.exit("ERROR: MINIMAX_API_KEY not set and not in keychain")


def validate(text, emotion):
    if emotion not in SAFE_EMOTIONS:
        sys.exit(f"ERROR: emotion '{emotion}' 不在安全集 {SAFE_EMOTIONS}")
    if len(text) > MAX_TEXT_LEN:
        sys.exit(f"ERROR: 文本 {len(text)} 字 > {MAX_TEXT_LEN},会触发长段偏移,请拆段")
    for bad in TEXT_BLACKLIST:
        if bad in text:
            sys.exit(f"ERROR: 文本包含黑名单 '{bad}',会破坏音色")


def synth(voice_id, text, emotion, speed, output_path):
    validate(text, emotion)
    payload = {
        "model": "speech-2.8-hd",
        "text": text,
        "stream": False,
        "voice_setting": {
            "voice_id": voice_id,
            "speed": speed,
            "vol": 1.0,
            "pitch": 0,
            "emotion": emotion,
        },
        "audio_setting": {
            "sample_rate": 32000,
            "bitrate": 128000,
            "format": "mp3",
            "channel": 1,
        },
    }
    headers = {
        "Authorization": f"Bearer {get_api_key()}",
        "Content-Type": "application/json",
    }
    r = requests.post(API_URL, headers=headers, json=payload, timeout=60)
    r.raise_for_status()
    data = r.json()
    base = data.get("base_resp", {})
    if base.get("status_code") != 0:
        sys.exit(f"ERROR: MiniMax {base}")
    audio_hex = data["data"]["audio"]
    audio_bytes = bytes.fromhex(audio_hex)
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    Path(output_path).write_bytes(audio_bytes)
    extra = data.get("extra_info", {})
    print(f"✓ {output_path} ({len(audio_bytes)//1024}KB, "
          f"{extra.get('audio_length', 0)/1000:.2f}s, "
          f"{extra.get('usage_characters', 0)} 字)")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--voice-id", required=True)
    p.add_argument("--text", required=True)
    p.add_argument("--emotion", default="happy", choices=sorted(SAFE_EMOTIONS))
    p.add_argument("--speed", type=float, default=1.2)
    p.add_argument("--output", required=True)
    args = p.parse_args()
    synth(args.voice_id, args.text, args.emotion, args.speed, args.output)


if __name__ == "__main__":
    main()
