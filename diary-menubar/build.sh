#!/bin/bash
set -e
cd "$(dirname "$0")"

swift build -c release

APP="DiaryMenuBar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/DiaryMenuBar "$APP/Contents/MacOS/DiaryMenuBar"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DiaryMenuBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.bruce.diarymenubar</string>
    <key>CFBundleName</key>
    <string>DiaryMenuBar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP" 2>/dev/null || true
echo "Built $APP — 用「open $APP」啟動，或雙擊它"
