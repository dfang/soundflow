#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SoundFlow"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
EXECUTABLE_PATH="$ROOT_DIR/.build/release/$APP_NAME"
PLIST_TEMPLATE="$ROOT_DIR/packaging/Info.plist"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

copy_dylib() {
    local source_path="$1"
    local destination_path="$FRAMEWORKS_DIR/$(basename "$source_path")"
    cp "$source_path" "$destination_path"
    install_name_tool -id "@executable_path/../Frameworks/$(basename "$source_path")" "$destination_path"
}

rewrite_dependency() {
    local binary_path="$1"
    local old_path="$2"
    local new_name="$3"
    install_name_tool -change "$old_path" "@executable_path/../Frameworks/$new_name" "$binary_path"
}

require_command swift
require_command install_name_tool
require_command codesign

# 签名身份：优先环境变量，否则自动检测第一个 Apple Development 证书
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-}"
if [[ -z "$CODE_SIGN_IDENTITY" ]]; then
    CODE_SIGN_IDENTITY="$(xcrun security find-identity -v -p codesigning 2>/dev/null \
        | awk '/Apple Development/ {print $2; exit}')"
fi
if [[ -z "$CODE_SIGN_IDENTITY" ]]; then
    echo "Warning: no Apple Development certificate found, falling back to ad-hoc signing." >&2
    CODE_SIGN_IDENTITY="-"
fi
echo "Signing identity: $CODE_SIGN_IDENTITY"

echo "Building release binary..."
(
    cd "$ROOT_DIR"
    swift build -c release
)

if [[ ! -f "$EXECUTABLE_PATH" ]]; then
    echo "Expected executable not found at $EXECUTABLE_PATH" >&2
    exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$FRAMEWORKS_DIR"

cp "$EXECUTABLE_PATH" "$MACOS_DIR/$APP_NAME"
cp "$PLIST_TEMPLATE" "$CONTENTS_DIR/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$CONTENTS_DIR/Info.plist"

copy_dylib "$ROOT_DIR/Vendor/sherpa-onnx/lib/libonnxruntime.1.23.2.dylib"
copy_dylib "$ROOT_DIR/Vendor/sherpa-onnx/lib/libsherpa-onnx-c-api.dylib"
copy_dylib "$ROOT_DIR/Vendor/sherpa-onnx/lib/libsherpa-onnx-cxx-api.dylib"

rewrite_dependency "$MACOS_DIR/$APP_NAME" "@rpath/libonnxruntime.1.23.2.dylib" "libonnxruntime.1.23.2.dylib"
rewrite_dependency "$MACOS_DIR/$APP_NAME" "@rpath/libsherpa-onnx-c-api.dylib" "libsherpa-onnx-c-api.dylib"
rewrite_dependency "$FRAMEWORKS_DIR/libsherpa-onnx-c-api.dylib" "@rpath/libonnxruntime.1.23.2.dylib" "libonnxruntime.1.23.2.dylib"
rewrite_dependency "$FRAMEWORKS_DIR/libsherpa-onnx-cxx-api.dylib" "@rpath/libonnxruntime.1.23.2.dylib" "libonnxruntime.1.23.2.dylib"

codesign --force --sign "$CODE_SIGN_IDENTITY" "$FRAMEWORKS_DIR/libonnxruntime.1.23.2.dylib"
codesign --force --sign "$CODE_SIGN_IDENTITY" "$FRAMEWORKS_DIR/libsherpa-onnx-c-api.dylib"
codesign --force --sign "$CODE_SIGN_IDENTITY" "$FRAMEWORKS_DIR/libsherpa-onnx-cxx-api.dylib"
codesign --force --deep --sign "$CODE_SIGN_IDENTITY" "$APP_BUNDLE"

echo "Created app bundle: $APP_BUNDLE"
