#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SoundFlow"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/dist"
STAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/soundflow-dmg.XXXXXX")"
VERSION="${VERSION:-0.1.0}"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"

cleanup() {
    rm -rf "$STAGE_DIR"
}
trap cleanup EXIT

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

require_command hdiutil

"$ROOT_DIR/scripts/build_app.sh"

ln -s /Applications "$STAGE_DIR/Applications"
cp -R "$APP_BUNDLE" "$STAGE_DIR/"

rm -f "$DMG_PATH"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGE_DIR" \
    -format UDZO \
    -ov \
    "$DMG_PATH" >/dev/null

echo "Created dmg: $DMG_PATH"
