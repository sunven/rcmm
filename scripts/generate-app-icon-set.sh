#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICON_DIR="$ROOT_DIR/RCMMApp/Assets.xcassets/AppIcon.appiconset"
FULL_SOURCE="$ROOT_DIR/logo.svg"
SMALL_SOURCE="$ROOT_DIR/artwork/app-icon/logo-small.svg"
ICON_SLOTS=(
  "AppIcon-16.png|16x16|1x|16|small"
  "AppIcon-16@2x.png|16x16|2x|32|small"
  "AppIcon-32.png|32x32|1x|32|small"
  "AppIcon-32@2x.png|32x32|2x|64|small"
  "AppIcon-128.png|128x128|1x|128|full"
  "AppIcon-128@2x.png|128x128|2x|256|full"
  "AppIcon-256.png|256x256|1x|256|full"
  "AppIcon-256@2x.png|256x256|2x|512|full"
  "AppIcon-512.png|512x512|1x|512|full"
  "AppIcon-512@2x.png|512x512|2x|1024|full"
)

require_cmd() {
  local cmd="$1"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: missing required command: $cmd" >&2
    exit 1
  fi
}

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
      IFS='|' read -r filename logical_size scale _ _ <<<"${ICON_SLOTS[$index]}"
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

source_path_for_slot() {
  local source_key="$1"

  case "$source_key" in
    full)
      printf '%s\n' "$FULL_SOURCE"
      ;;
    small)
      printf '%s\n' "$SMALL_SOURCE"
      ;;
    *)
      echo "Error: unknown source key: $source_key" >&2
      return 1
      ;;
  esac
}

validate_svg_source() {
  local file="$1"
  local format

  if [[ ! -f "$file" ]]; then
    echo "Error: missing source svg: $file" >&2
    return 1
  fi

  format="$(sips -g format "$file" | awk '/format/ {print $2}')"

  if [[ "$format" != "svg" ]]; then
    echo "Error: source file must be svg: $file (got ${format:-unknown})" >&2
    return 1
  fi
}

render_slot() {
  local source="$1"
  local filename="$2"
  local pixel_size="$3"

  sips -z "$pixel_size" "$pixel_size" -s format png "$source" --out "$ICON_DIR/$filename" >/dev/null
}

validate_rendered_png() {
  local file="$1"
  local pixel_size="$2"
  local format
  local width
  local height

  format="$(sips -g format "$file" | awk '/format/ {print $2}')"
  width="$(sips -g pixelWidth "$file" | awk '/pixelWidth/ {print $2}')"
  height="$(sips -g pixelHeight "$file" | awk '/pixelHeight/ {print $2}')"

  if [[ "$format" != "png" || "$width" != "$pixel_size" || "$height" != "$pixel_size" ]]; then
    echo "Error: rendered icon has wrong format or dimensions: $file -> ${format:-unknown} ${width:-?}x${height:-?}" >&2
    return 1
  fi
}

require_cmd sips
require_cmd plutil

validate_svg_source "$FULL_SOURCE"
validate_svg_source "$SMALL_SOURCE"
validate_contents_json "$ICON_DIR/Contents.json"
validate_contents_contract "$ICON_DIR/Contents.json"

for slot in "${ICON_SLOTS[@]}"; do
  IFS='|' read -r filename _ _ pixel_size source_key <<<"$slot"
  source_path="$(source_path_for_slot "$source_key")"
  render_slot "$source_path" "$filename" "$pixel_size"
  validate_rendered_png "$ICON_DIR/$filename" "$pixel_size"
done

echo "Generated macOS app icon PNGs in $ICON_DIR"
