#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICON_DIR="$ROOT_DIR/RCMMApp/Assets.xcassets/AppIcon.appiconset"
MASTER_FILENAME="AppIcon-512@2x.png"
ICON_SLOTS=(
  "AppIcon-16.png|16x16|1x|16"
  "AppIcon-16@2x.png|16x16|2x|32"
  "AppIcon-32.png|32x32|1x|32"
  "AppIcon-32@2x.png|32x32|2x|64"
  "AppIcon-128.png|128x128|1x|128"
  "AppIcon-128@2x.png|128x128|2x|256"
  "AppIcon-256.png|256x256|1x|256"
  "AppIcon-256@2x.png|256x256|2x|512"
  "AppIcon-512.png|512x512|1x|512"
  "AppIcon-512@2x.png|512x512|2x|1024"
)
MASTER_PIXEL_SIZE=""

for slot in "${ICON_SLOTS[@]}"; do
  IFS='|' read -r filename _ _ pixel_size <<<"$slot"
  if [[ "$filename" == "$MASTER_FILENAME" ]]; then
    MASTER_PIXEL_SIZE="$pixel_size"
    break
  fi
done

if [[ -z "$MASTER_PIXEL_SIZE" ]]; then
  echo "Error: missing master slot metadata for $MASTER_FILENAME" >&2
  exit 1
fi

SOURCE="$ICON_DIR/$MASTER_FILENAME"

require_cmd() {
  local cmd="$1"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: missing required command: $cmd" >&2
    exit 1
  fi
}

require_cmd sips
require_cmd plutil

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

build_expected_contents_json() {
  local file="$1"
  local index
  local total="${#ICON_SLOTS[@]}"

  {
    printf '{\n'
    printf '  "images" : [\n'

    for index in "${!ICON_SLOTS[@]}"; do
      IFS='|' read -r filename logical_size scale _ <<<"${ICON_SLOTS[$index]}"
      printf '    {\n'
      printf '      "filename" : "%s",\n' "$filename"
      printf '      "idiom" : "mac",\n'
      printf '      "scale" : "%s",\n' "$scale"
      printf '      "size" : "%s"\n' "$logical_size"
      printf '    }'
      if (( index < total - 1 )); then
        printf ','
      fi
      printf '\n'
    done

    printf '  ],\n'
    printf '  "info" : {\n'
    printf '    "author" : "xcode",\n'
    printf '    "version" : 1\n'
    printf '  }\n'
    printf '}\n'
  } >"$file"
}

normalize_json() {
  local input_file="$1"
  local output_file="$2"

  if ! plutil -convert json -r -o "$output_file" "$input_file" >/dev/null 2>&1; then
    echo "Error: failed to normalize JSON file: $input_file" >&2
    return 1
  fi
}

validate_contents_contract() {
  local actual_file="$1"
  local expected_file
  local expected_normalized
  local actual_normalized
  local status=0

  expected_file="$(mktemp)"
  expected_normalized="$(mktemp)"
  actual_normalized="$(mktemp)"

  build_expected_contents_json "$expected_file"
  normalize_json "$expected_file" "$expected_normalized"
  normalize_json "$actual_file" "$actual_normalized"

  if ! cmp -s "$expected_normalized" "$actual_normalized"; then
    echo "Error: asset catalog contents do not match the expected app icon slot contract: $actual_file" >&2
    diff -u "$expected_normalized" "$actual_normalized" >&2 || true
    status=1
  fi

  rm -f "$expected_file" "$expected_normalized" "$actual_normalized"
  return "$status"
}

if [[ ! -f "$SOURCE" ]]; then
  echo "Error: missing source icon: $SOURCE" >&2
  exit 1
fi

format="$(sips -g format "$SOURCE" | awk '/format/ {print $2}')"
width="$(sips -g pixelWidth "$SOURCE" | awk '/pixelWidth/ {print $2}')"
height="$(sips -g pixelHeight "$SOURCE" | awk '/pixelHeight/ {print $2}')"

if [[ "$format" != "png" || "$width" != "$MASTER_PIXEL_SIZE" || "$height" != "$MASTER_PIXEL_SIZE" ]]; then
  echo "Error: source icon must be a ${MASTER_PIXEL_SIZE}x${MASTER_PIXEL_SIZE} PNG; got ${format} ${width}x${height}" >&2
  exit 1
fi

render() {
  local filename="$1"
  local size="$2"

  sips -z "$size" "$size" "$SOURCE" --out "$ICON_DIR/$filename" >/dev/null
}

for slot in "${ICON_SLOTS[@]}"; do
  IFS='|' read -r filename _ _ pixel_size <<<"$slot"
  if [[ "$filename" == "$MASTER_FILENAME" ]]; then
    continue
  fi
  render "$filename" "$pixel_size"
done

validate_contents_json "$ICON_DIR/Contents.json"
validate_contents_contract "$ICON_DIR/Contents.json"

echo "Generated macOS app icon PNGs in $ICON_DIR"
