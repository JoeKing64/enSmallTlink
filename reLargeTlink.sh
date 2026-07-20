#!/bin/zsh
APP="/Applications/Tlink.app"
ICON="$APP/Contents/Resources/icon.icns"
BACKUP="$APP/Contents/Resources/icon.icns.original-backup"

osascript -e 'tell application "Tlink" to quit' 2>/dev/null || true
pkill -x Tlink 2>/dev/null || true

if [ ! -f "$BACKUP" ]; then
    echo "错误：找不到原始备份：$BACKUP"
    exit 1
fi

sudo cp "$BACKUP" "$ICON"
sudo chmod 644 "$ICON"

sudo codesign \
    --force \
    --deep \
    --sign - \
    "$APP"

codesign \
    --verify \
    --deep \
    --strict \
    --verbose=2 \
    "$APP"

sudo touch "$APP"

killall iconservicesagent 2>/dev/null || true
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true

open "$APP"