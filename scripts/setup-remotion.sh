#!/usr/bin/env bash
#
# setup-remotion.sh — pro-video-composer 的最小 Remotion 项目 scaffold
#
# 用法:
#   ./scripts/setup-remotion.sh                    # 在当前目录创建 remotion-test/
#   ./scripts/setup-remotion.sh ./my-video         # 指定目标目录
#
# 创建后,skill 会往 src/ 注册新组件,你也可以手动 npx remotion studio 预览。
#
# 依赖:node >= 18 (Remotion 4 需要)
#

set -e

TARGET="${1:-./remotion-test}"
VERSION_REMOTION="^4.0.450"
VERSION_REACT="^19.2.5"

# ── 校验 ─────────────────────────────────────────────────────────────
if ! command -v node >/dev/null 2>&1; then
  echo "❌ node 未安装。Remotion 4 需要 node >= 18。"
  echo "   macOS: brew install node"
  echo "   其他:  https://nodejs.org/"
  exit 1
fi

NODE_MAJOR=$(node -v | sed 's/v\([0-9]*\).*/\1/')
if [ "$NODE_MAJOR" -lt 18 ]; then
  echo "⚠️  node 版本 $(node -v) 偏低,Remotion 4 推荐 >= 18"
fi

if [ -e "$TARGET" ]; then
  echo "❌ 目标已存在: $TARGET"
  echo "   删掉或换个路径再跑"
  exit 1
fi

echo "📦 在 $TARGET 创建最小 Remotion 项目..."
mkdir -p "$TARGET/src" "$TARGET/public"
cd "$TARGET"

# ── package.json ─────────────────────────────────────────────────────
cat > package.json << EOF
{
  "name": "remotion-test",
  "version": "1.0.0",
  "description": "Remotion project for pro-video-composer skill",
  "license": "ISC",
  "scripts": {
    "studio": "remotion studio",
    "render": "remotion render"
  },
  "dependencies": {
    "@remotion/bundler": "${VERSION_REMOTION}",
    "@remotion/cli": "${VERSION_REMOTION}",
    "@remotion/renderer": "${VERSION_REMOTION}",
    "react": "${VERSION_REACT}",
    "react-dom": "${VERSION_REACT}",
    "remotion": "${VERSION_REMOTION}"
  }
}
EOF

# ── src/index.jsx ────────────────────────────────────────────────────
# skill 会按惯例把新组件 import 进来 + 注册 Composition
cat > src/index.jsx << 'EOF'
import React from 'react';
import {registerRoot, Composition} from 'remotion';
import {SceneSkeleton} from './SceneSkeleton';

// ─── pro-video-composer 注册区 ───
// skill 会按规则在这里 import 新组件 + 加 Composition 节点
// 全部 1920×1080 @ 30fps,id 不能含下划线

export const RemotionRoot = () => {
  return (
    <>
      <Composition
        id="SceneSkeleton"
        component={SceneSkeleton}
        durationInFrames={90}
        fps={30}
        width={1920}
        height={1080}
        defaultProps={{
          title: 'Hello Remotion',
          subtitle: 'pro-video-composer scaffold',
        }}
      />
      {/* skill 会在这里追加新的 <Composition /> */}
    </>
  );
};

registerRoot(RemotionRoot);
EOF

# ── src/SceneSkeleton.jsx ────────────────────────────────────────────
# skill 生成新组件时的参考模板 (跟 templates/composition.skeleton.jsx 一致)
cat > src/SceneSkeleton.jsx << 'EOF'
import React from 'react';
import {AbsoluteFill, useCurrentFrame, useVideoConfig, interpolate, spring} from 'remotion';

const FONT = '"PingFang SC", "Hiragino Sans GB", -apple-system, sans-serif';
const BG = '#0a0a14';
const ACCENT = '#FFD64D';
const TEXT = '#ffffff';

export const SceneSkeleton = ({title = 'Hello Remotion', subtitle = ''}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  const fadeIn = interpolate(frame, [0, 12], [0, 1], {extrapolateRight: 'clamp'});
  const pop = spring({frame: frame - 6, fps, config: {damping: 12, stiffness: 100}});
  const scale = interpolate(pop, [0, 1], [0.7, 1]);

  return (
    <AbsoluteFill
      style={{
        backgroundColor: BG,
        fontFamily: FONT,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 24,
      }}
    >
      <div
        style={{
          fontSize: 140,
          fontWeight: 900,
          color: ACCENT,
          opacity: fadeIn,
          transform: `scale(${scale})`,
          textShadow: '0 8px 30px rgba(0,0,0,0.6)',
        }}
      >
        {title}
      </div>
      {subtitle ? (
        <div
          style={{
            fontSize: 40,
            fontWeight: 500,
            color: TEXT,
            opacity: interpolate(frame, [20, 40], [0, 1], {extrapolateRight: 'clamp'}),
            letterSpacing: 2,
          }}
        >
          {subtitle}
        </div>
      ) : null}
    </AbsoluteFill>
  );
};
EOF

# ── .gitignore ───────────────────────────────────────────────────────
cat > .gitignore << 'EOF'
node_modules/
out/
.DS_Store
*.log
EOF

# ── README.md ────────────────────────────────────────────────────────
cat > README.md << 'EOF'
# remotion-test

pro-video-composer skill 的 Remotion 工作区。

## 安装依赖

```bash
npm install
```

## 预览

```bash
npx remotion studio
# 打开 http://localhost:3000 看 SceneSkeleton
```

## 渲染单个 composition

```bash
npx remotion render src/index.jsx SceneSkeleton out/scene.mp4
```

## 给 skill 用

在你的 agent 里说:
> 用 pro-video-composer 这个 skill,工作区是 `./` (含本 remotion-test 项目)

skill 会自动:
- 解析文稿 + 录音
- 生成新 Remotion 组件并注册到 `src/index.jsx`
- 渲染 mp4 + ffmpeg 拼接

## 约定

- 所有 composition 默认 1920×1080 @ 30fps
- composition id **不能含下划线**(Remotion CLI 限制)
- 静态资源放 `public/`,用 `staticFile('xxx.mp4')` 引用
EOF

# ── 完成 ─────────────────────────────────────────────────────────────
echo ""
echo "✅ Remotion 项目已创建在 $(pwd)"
echo ""
echo "📁 结构:"
ls -1
echo ""
echo "▶️  下一步:"
echo "   cd $TARGET"
echo "   npm install            # 装依赖 (~30s, 600MB)"
echo "   npx remotion studio    # 本地预览"
echo ""
echo "💡 macOS 如遇 Gatekeeper 拦截:"
echo "   xattr -drs com.apple.quarantine node_modules"
echo ""
