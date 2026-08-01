#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SoundFlow"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
DEST="/Applications/$APP_NAME.app"

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

if [[ -d "$DEST" ]]; then
    rm -rf "$DEST"
fi

cp -R "$APP_BUNDLE" "$DEST"
echo "Installed $APP_NAME to $DEST"
echo "Run: open -a $APP_NAME"
