#!/bin/bash
# 把選單列 App 註冊成開機自動啟動的 LaunchAgent。
# 之後每次用 build.sh 重新編譯，不需要重跑這支腳本（路徑不變）。
set -e
cd "$(dirname "$0")"

LABEL="com.bruce.diarymenubar"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
APP_BIN="$(pwd)/DiaryMenuBar.app/Contents/MacOS/DiaryMenuBar"

if [ ! -x "$APP_BIN" ]; then
  echo "找不到 $APP_BIN，請先執行 ./build.sh"
  exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP_BIN</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
PLIST

# 先移除舊的（若有）避免重複啟動
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "已註冊開機自動啟動：$PLIST"
echo "移除方式：launchctl bootout gui/\$(id -u)/$LABEL && rm $PLIST"
