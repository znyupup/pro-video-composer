#!/usr/bin/env python3
"""
MiniMax audio understanding ASR — 音频转中文文字
用于 voice-clone 流程中自动转录示例音频,用户校对后传给 voice cloning API

用法:
  python minimax-asr.py --input sample.mp3 --output transcript.md
"""
import argparse
import os
import sys
import subprocess
from pathlib import Path

import requests

API_URL = "https://api.minimaxi.com/v1/files"
ASR_API_URL = "https://api.minimaxi.com/v1/audio_speech_recognition"


def get_api_key():
    key = os.environ.get("MINIMAX_API_KEY")
    if key:
        return key
    try:
        result = subprocess.run(
            ["security", "find-generic-password", "-s", "minimax", "-w"],
            capture_output=True, text=True, check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        sys.exit("ERROR: MINIMAX_API_KEY not set and not in keychain")


def transcribe(audio_path, output_path):
    """
    使用 MiniMax audio understanding 接口转录中文音频
    """
    key = get_api_key()
    headers = {"Authorization": f"Bearer {key}"}

    # 上传文件
    with open(audio_path, "rb") as f:
        files = {"file": f}
        data = {"purpose": "voice_clone"}
        r = requests.post(API_URL, headers=headers, files=files, data=data, timeout=120)
        r.raise_for_status()
        upload = r.json()
    file_id = upload.get("file", {}).get("file_id")
    if not file_id:
        sys.exit(f"ERROR: 上传失败 {upload}")
    print(f"  ✓ 上传 file_id: {file_id}")

    # 调 ASR
    asr_payload = {
        "file_id": file_id,
        "model": "speech_to_text",
        "language": "zh",
    }
    r = requests.post(
        ASR_API_URL,
        headers={**headers, "Content-Type": "application/json"},
        json=asr_payload,
        timeout=120,
    )
    r.raise_for_status()
    result = r.json()
    transcription = result.get("text", "")
    if not transcription:
        sys.exit(f"ERROR: ASR 返回空 {result}")

    # 写文件
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    Path(output_path).write_text(
        f"# 示例音频文字稿(请校对错字后保存回车继续)\n\n"
        f"<!-- 原音频: {audio_path} -->\n\n"
        f"{transcription}\n",
        encoding="utf-8",
    )
    print(f"  ✓ 转录写入 {output_path}")
    print(f"  ⚠️  请用 vim/编辑器打开校对错字后保存,回车继续")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--input", required=True, help="音频文件路径")
    p.add_argument("--output", required=True, help="转录结果输出 .md 路径")
    args = p.parse_args()
    if not Path(args.input).exists():
        sys.exit(f"ERROR: 找不到 {args.input}")
    transcribe(args.input, args.output)


if __name__ == "__main__":
    main()
