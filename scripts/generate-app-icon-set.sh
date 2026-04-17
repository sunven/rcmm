#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICON_DIR="$ROOT_DIR/RCMMApp/Assets.xcassets/AppIcon.appiconset"
SOURCE="$ICON_DIR/AppIcon-512@2x.png"

require_cmd() {
  local cmd="$1"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: missing required command: $cmd" >&2
    exit 1
  fi
}

require_cmd sips
require_cmd plutil

if [[ ! -f "$SOURCE" ]]; then
  echo "Error: missing source icon: $SOURCE" >&2
  exit 1
fi

format="$(sips -g format "$SOURCE" | awk '/format/ {print $2}')"
width="$(sips -g pixelWidth "$SOURCE" | awk '/pixelWidth/ {print $2}')"
height="$(sips -g pixelHeight "$SOURCE" | awk '/pixelHeight/ {print $2}')"

if [[ "$format" != "png" || "$width" != "1024" || "$height" != "1024" ]]; then
  echo "Error: source icon must be a 1024x1024 PNG; got ${format} ${width}x${height}" >&2
  exit 1
fi

render() {
  local filename="$1"
  local size="$2"

  sips -z "$size" "$size" "$SOURCE" --out "$ICON_DIR/$filename" >/dev/null
}

render "AppIcon-16.png" 16
render "AppIcon-16@2x.png" 32
render "AppIcon-32.png" 32
render "AppIcon-32@2x.png" 64
render "AppIcon-128.png" 128
render "AppIcon-128@2x.png" 256
render "AppIcon-256.png" 256
render "AppIcon-256@2x.png" 512
render "AppIcon-512.png" 512

plutil -lint "$ICON_DIR/Contents.json" >/dev/null

echo "Generated macOS app icon PNGs in $ICON_DIR"
