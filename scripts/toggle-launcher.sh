#!/bin/bash
# 常駐ランチャーをトグル（アクセシビリティ不要）
DIR="$HOME/Library/Application Support/CyberLauncher"
mkdir -p "$DIR"
if curl -sf --max-time 1 "http://127.0.0.1:39281/toggle" >/dev/null 2>&1; then
  exit 0
fi
touch "$DIR/toggle"
