#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICON_DIR="$ROOT_DIR/RCMMApp/Assets.xcassets/AppIcon.appiconset"
MASTER_FILENAME="AppIcon-512@2x.png"
SOURCE="$ICON_DIR/$MASTER_FILENAME"
RENDER_SPECS=(
  "AppIcon-16.png:16"
  "AppIcon-16@2x.png:32"
  "AppIcon-32.png:32"
  "AppIcon-32@2x.png:64"
  "AppIcon-128.png:128"
  "AppIcon-128@2x.png:256"
  "AppIcon-256.png:256"
  "AppIcon-256@2x.png:512"
  "AppIcon-512.png:512"
)

require_cmd() {
  local cmd="$1"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: missing required command: $cmd" >&2
    exit 1
  fi
}

require_cmd sips
require_cmd plutil
require_cmd python3

validate_contents_json() {
  local file="$1"

  if plutil -lint "$file" >/dev/null 2>&1; then
    return 0
  fi

  if [[ "$file" == *.json ]] && plutil -convert xml1 -o /dev/null "$file" >/dev/null 2>&1; then
    return 0
  fi

  echo "Error: invalid asset catalog contents file: $file" >&2
  return 1
}

validate_filename_mappings() {
  local file="$1"
  shift

  python3 - "$file" "$@" <<'PY'
import json
import sys

file_path = sys.argv[1]
expected = sys.argv[2:]

with open(file_path, "r", encoding="utf-8") as handle:
    data = json.load(handle)

actual = []
for image in data.get("images", []):
    filename = image.get("filename")
    if filename is not None:
        actual.append(filename)

expected_set = set(expected)
actual_set = set(actual)

missing = sorted(expected_set - actual_set)
unexpected = sorted(actual_set - expected_set)

if missing or unexpected or len(actual) != len(expected):
    if missing:
        print(f"Error: missing filename mappings in {file_path}: {', '.join(missing)}", file=sys.stderr)
    if unexpected:
        print(f"Error: unexpected filename mappings in {file_path}: {', '.join(unexpected)}", file=sys.stderr)
    if len(actual) != len(actual_set):
        print(f"Error: duplicate filename mappings found in {file_path}", file=sys.stderr)
    if len(actual) != len(expected):
        print(
            f"Error: expected {len(expected)} filename mappings in {file_path}, found {len(actual)}",
            file=sys.stderr,
        )
    sys.exit(1)
PY
}

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

for spec in "${RENDER_SPECS[@]}"; do
  filename="${spec%%:*}"
  size="${spec##*:}"
  render "$filename" "$size"
done

validate_contents_json "$ICON_DIR/Contents.json"
validate_filename_mappings \
  "$ICON_DIR/Contents.json" \
  "$MASTER_FILENAME" \
  "${RENDER_SPECS[@]%%:*}"

echo "Generated macOS app icon PNGs in $ICON_DIR"
