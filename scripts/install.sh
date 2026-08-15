#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SoundFlow"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
DEST="/Applications/$APP_NAME.app"
LEGACY_STAGE_DIR="$ROOT_DIR/dist/dmg"
LEGACY_APP_BUNDLE="$LEGACY_STAGE_DIR/$APP_NAME.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

"$ROOT_DIR/scripts/build_app.sh"

if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    echo "$APP_NAME is running, quitting..."
    osascript -e "quit app \"$APP_NAME\""
    for _ in $(seq 1 20); do
        pgrep -x "$APP_NAME" >/dev/null 2>&1 || break
        sleep 0.5
    done
    if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
        echo "Quit timed out, force quitting..."
        kill "$(pgrep -x "$APP_NAME")"
        sleep 1
    fi
fi

if [[ -x "$LSREGISTER" ]]; then
    "$LSREGISTER" -u "$LEGACY_APP_BUNDLE" >/dev/null 2>&1 || true
fi
rm -rf "$LEGACY_STAGE_DIR"
rm -rf "$DEST"
ditto "$APP_BUNDLE" "$DEST"
if [[ -x "$LSREGISTER" ]]; then
    "$LSREGISTER" -f "$DEST" >/dev/null
fi
echo "Installed $APP_NAME to $DEST"
echo "Run: open $DEST"
