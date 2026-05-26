#!/bin/bash
# macOS の「クイックアクション」に ⌘+Shift+L 用トグルを登録する
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVICE_NAME="Toggle Cyber Launcher.workflow"
SERVICE_DIR="$HOME/Library/Services/${SERVICE_NAME}"
TOGGLE_SH="$REPO_ROOT/scripts/toggle-launcher.sh"
chmod +x "$TOGGLE_SH"

mkdir -p "$SERVICE_DIR/Contents"

cat > "$SERVICE_DIR/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.cyber-launcher.toggle-service</string>
    <key>CFBundleName</key>
    <string>Toggle Cyber Launcher</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>NSServices</key>
    <array>
        <dict>
            <key>NSMenuItem</key>
            <dict>
                <key>default</key>
                <string>Toggle Cyber Launcher</string>
            </dict>
            <key>NSMessage</key>
            <string>runWorkflowAsService</string>
            <key>NSRequiredContext</key>
            <dict/>
            <key>NSSendTypes</key>
            <array/>
        </dict>
    </array>
</dict>
</plist>
EOF

# Automator ワークフロー（シェル実行）
cat > "$SERVICE_DIR/Contents/document.wflow" <<WFLOW
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AMApplicationBuild</key>
    <string>523</string>
    <key>AMApplicationVersion</key>
    <string>2.10</string>
    <key>AMDocumentVersion</key>
    <string>2</string>
    <key>actions</key>
    <array>
        <dict>
            <key>action</key>
            <dict>
                <key>AMAccepts</key>
                <dict><key>Container</key><string>List</string></dict>
                <key>AMActionVersion</key>
                <string>2.0.3</string>
                <key>AMParameterProperties</key>
                <dict>
                    <key>COMMAND_STRING</key>
                    <dict/>
                    <key>CheckedForUserDefaultShell</key>
                    <dict/>
                    <key>inputMethod</key>
                    <dict/>
                    <key>shell</key>
                    <dict/>
                    <key>source</key>
                    <dict/>
                </dict>
                <key>AMProvides</key>
                <dict><key>Container</key><string>List</string></dict>
                <key>ActionBundlePath</key>
                <string>/System/Library/Automator/Run Shell Script.action</string>
                <key>ActionName</key>
                <string>Run Shell Script</string>
                <key>ActionParameters</key>
                <dict>
                    <key>COMMAND_STRING</key>
                    <string>${TOGGLE_SH}</string>
                    <key>CheckedForUserDefaultShell</key>
                    <true/>
                    <key>inputMethod</key>
                    <integer>0</integer>
                    <key>shell</key>
                    <string>/bin/bash</string>
                    <key>source</key>
                    <string></string>
                </dict>
                <key>BundleIdentifier</key>
                <string>com.apple.RunShellScript</string>
                <key>CFBundleVersion</key>
                <string>2.0.3</string>
                <key>CanShowSelectedItemsWhenRun</key>
                <false/>
                <key>CanShowWhenRun</key>
                <true/>
                <key>Category</key>
                <array><string>AMCategoryUtilities</string></array>
                <key>Class Name</key>
                <string>RunShellScriptAction</string>
                <key>InputUUID</key>
                <string>0</string>
                <key>Keywords</key>
                <array><string>Shell</string><string>Script</string></array>
                <key>OutputUUID</key>
                <string>1</string>
                <key>UUID</key>
                <string>1</string>
                <key>UnlocalizedApplications</key>
                <array><string>Automator</string></array>
                <key>arguments</key>
                <dict/>
            </dict>
        </dict>
    </array>
    <key>connectors</key>
    <dict/>
    <key>workflowType</key>
    <string>Service</string>
</dict>
</plist>
WFLOW

echo "Installed: $SERVICE_DIR"
echo ""
echo "次の手順（1回だけ）:"
echo "  1. システム設定 → キーボード → キーボードショートカット → サービス"
echo "  2. 「Toggle Cyber Launcher」にチェック"
echo "  3. 右側で ⌘+Shift+L を割り当て"
echo ""
echo "または:"
echo "  curl http://127.0.0.1:39281/toggle"
echo ""
open "x-apple.systempreferences:com.apple.Keyboard-Settings.extension?Services" 2>/dev/null || true
