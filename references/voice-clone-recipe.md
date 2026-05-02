# voice-clone 配方(MiniMax)

## 锁定参数(4 轮 A/B 后稳定)

```python
{
    "model": "speech-2.8-hd",     # 最新旗舰,turbo 会复读,2.6 也 OK 但 2.8 更稳
    "voice_setting": {
        "voice_id": "<USER_VOICE_ID>",
        "speed": 1.2,             # 1.2-1.25 安全;1.3+ 偏快;<1.0 偏慢
        "pitch": 0,               # 不要动,任何非 0 都失真
        "vol": 1.0,
        "emotion": "<PER_SEG>",   # 拆段独立指定(见 per-sentence-emotion.md)
    },
    # voice_modify 全部禁用!任何参数都让音色失真
}
```

## 失败方向黑名单

### 模型层
| 模型 | 状态 | 原因 |
|---|---|---|
| `speech-2.8-turbo` | ❌ | 长段会复读 |
| `speech-2.6-hd` | ⚠️ | 上一代,够用但不稳 |
| `speech-2.8-hd` | ✅ | **锁定** |

### 参数层
| 参数 | 状态 | 失真现象 |
|---|---|---|
| `voice_modify.pitch != 0` | ❌ | 立刻不像 |
| `voice_modify.intensity` | ❌ | 任何非 0 都失真 |
| `voice_modify.timbre` | ❌ | 音色质感破坏 |
| `voice_setting.pitch != 0` | ❌ | 整调失真 |
| `voice_setting.speed > 1.3` | ⚠️ | 偏快,语速失常 |
| `voice_setting.speed < 1.0` | ⚠️ | 偏慢,缺乏活力 |

### 文本层(黑名单)
- ❌ 不加 `啦/啊/诶/嘿` 等口语叹词(部分破坏音色)
- ❌ 不加 `(breath)/(chuckle)/(sigh)` 等动作标签
- ❌ 不加 `<#x#>` 强制停顿
- ✅ 原书面文稿 + 自然标点(可加 `!` 强调)

## 复刻流程

```
1. 主音频(60-180s)→ /v1/voice_cloning/upload_clone_audio
   ↓ 拿 file_id

2. 示例音频(5-30s)→ MiniMax ASR 转录
   ↓ 写入 transcript.md
   ↓ 用户校对错字
   ↓ 保存回车继续

3. file_id + sample.mp3 + transcript → /v1/voice_cloning/clone
   ↓ 拿 voice_id

4. 测试合成 "你好,我是 <voice_id>" → 验证可用
   ↓ 写入 voice_clone/test.mp3
   ↓ 写入 voice_clone/voice_id.txt
```

## 保鲜规则

- voice_id **7 天不调用 T2A 会被自动删除**
- 启动 EP 视频 = 第一次正式调用 T2A,自动重置 7 天计时
- 长期闲置音色:每周跑一次 narrate-emotion 续命

## 安全边界

- **音色相似度上限** = 主音频质量 + 时长决定。147s 主音频 + 24kHz 录音 ≈ 90% 相似度
- 调参数只能逼近上限,不能突破
- 用户期望管理:复刻不是 100% 像,是"明显是这个人 + 普通话标准了"
