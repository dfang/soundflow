#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_BUNDLE="${1:-$ROOT_DIR/dist/SoundFlow.app}"
SOURCE_DICTIONARY="$ROOT_DIR/Sources/system_dictionary.json"
PACKAGED_DICTIONARY="$APP_BUNDLE/Contents/Resources/system_dictionary.json"

if [[ ! -f "$PACKAGED_DICTIONARY" ]]; then
    echo "Missing packaged dictionary: $PACKAGED_DICTIONARY" >&2
    exit 1
fi

if ! cmp -s "$SOURCE_DICTIONARY" "$PACKAGED_DICTIONARY"; then
    echo "Packaged dictionary is stale: $PACKAGED_DICTIONARY" >&2
    exit 1
fi
