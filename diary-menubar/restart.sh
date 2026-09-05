#!/bin/bash
# 改完程式碼之後：重新編譯 → 關掉舊的 → 開新的 → 驗證。
#
# 會自動判斷目前是哪一種啟動方式：
#   - LaunchAgent 已 bootstrap（跑過 install-autostart.sh）→ 用 launchctl kickstart -k
#   - 否則（手動 open / Finder 啟動）→ pkill + open
#
# 用法：
#   ./restart.sh            編譯後重啟
#   ./restart.sh --no-build 只重啟，不重新編譯
set -e
cd "$(dirname "$0")"

LABEL="com.bruce.diarymenubar"
APP="DiaryMenuBar.app"
BIN="$APP/Contents/MacOS/DiaryMenuBar"

# ── 1. 編譯 ──────────────────────────────────────────────
if [ "$1" = "--no-build" ]; then
  echo "▸ 略過編譯"
else
  echo "▸ 編譯中…"
  ./build.sh >/dev/null
  echo "  完成：$(stat -f '%Sm' "$BIN")"
fi

if [ ! -x "$BIN" ]; then
  echo "✗ 找不到 $BIN，請先執行 ./build.sh"
  exit 1
fi

# ── 2. 關掉現有實例（可能不只一個）─────────────────────────
BEFORE=$(pgrep -f "$APP" | wc -l | tr -d ' ')
if [ "$BEFORE" -gt 0 ]; then
  echo "▸ 關掉現有的 $BEFORE 個實例"
  pkill -f "$APP" || true
  # 等它真的收掉，最多 5 秒
  for _ in $(seq 1 25); do
    pgrep -f "$APP" >/dev/null || break
    sleep 0.2
  done
  pgrep -f "$APP" >/dev/null && { echo "  還沒關掉，強制結束"; pkill -9 -f "$APP" || true; sleep 1; }
fi

# ── 3. 啟動 ─────────────────────────────────────────────
if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
  echo "▸ 由 LaunchAgent 啟動"
  launchctl kickstart -k "gui/$(id -u)/$LABEL"
else
  echo "▸ 手動啟動（LaunchAgent 未載入；要開機自動啟動請跑 ./install-autostart.sh）"
  open "$APP"
fi

# ── 4. 驗證 ─────────────────────────────────────────────
for _ in $(seq 1 25); do
  pgrep -f "$APP" >/dev/null && break
  sleep 0.2
done

COUNT=$(pgrep -f "$APP" | wc -l | tr -d ' ')
case "$COUNT" in
  0)
    echo "✗ 沒有啟動成功"
    echo "  直接跑執行檔看錯誤訊息：./$BIN"
    exit 1
    ;;
  1)
    echo "✓ 已啟動  PID $(pgrep -f "$APP")"
    echo "  執行檔時間：$(stat -f '%Sm' "$BIN")"
    ;;
  *)
    echo "⚠ 跑了 $COUNT 個實例，選單列會出現重複圖示"
    pgrep -lf "$APP" | sed 's/^/    /'
    echo "  修正：pkill -f \"$APP\" 然後再跑一次 ./restart.sh"
    exit 1
    ;;
esac
