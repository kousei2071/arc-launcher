#!/bin/bash
# Cyber Launcher の LaunchAgent 登録を解除する。
set -euo pipefail

LABEL="com.cyber-launcher"
PLIST_DEST="$HOME/Library/LaunchAgents/${LABEL}.plist"
GUI_DOMAIN="gui/$(id -u)"

if launchctl print "$GUI_DOMAIN/$LABEL" &>/dev/null; then
  launchctl bootout "$GUI_DOMAIN" "$PLIST_DEST"
  echo "Stopped: $LABEL"
fi

if [[ -f "$PLIST_DEST" ]]; then
  rm -f "$PLIST_DEST"
  echo "Removed: $PLIST_DEST"
fi

SUPPORT_DIR="$HOME/Library/Application Support/CyberLauncher"
if [[ -d "$SUPPORT_DIR" ]]; then
  rm -f "$SUPPORT_DIR/launch.sh"
  rmdir "$SUPPORT_DIR" 2>/dev/null || true
fi

echo "Done."
