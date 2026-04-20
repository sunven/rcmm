# RCMM Logo App Icon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the `rcmm.app` icon pipeline so the shipped bundle icon comes from `logo.svg`, with an explicit small-size simplified SVG source for Finder-scale readability.

**Architecture:** Keep the existing Xcode asset-catalog wiring and continue shipping generated PNGs in `RCMMApp/Assets.xcassets/AppIcon.appiconset`. Refactor `scripts/generate-app-icon-set.sh` to render each slot from either `logo.svg` or a new `artwork/app-icon/logo-small.svg`, then verify the generated app icon all the way through the `rcmm` scheme build and DMG packaging flow.

**Tech Stack:** Bash, `sips`, `plutil`, Xcode asset catalogs, SVG source assets, `xcodebuild`, `create-dmg`

---

## File Map

- Modify: `scripts/generate-app-icon-set.sh` — switch the generator from a master-PNG model to explicit SVG source routing with output validation.
- Create: `artwork/app-icon/logo-small.svg` — simplified small-size icon source derived from `logo.svg`.
- Modify: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-16.png` — generated from `artwork/app-icon/logo-small.svg`.
- Modify: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-16@2x.png` — generated from `artwork/app-icon/logo-small.svg`.
- Modify: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-32.png` — generated from `artwork/app-icon/logo-small.svg`.
- Modify: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-32@2x.png` — generated from `artwork/app-icon/logo-small.svg`.
- Modify: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-128.png` — generated directly from `logo.svg`.
- Modify: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-128@2x.png` — generated directly from `logo.svg`.
- Modify: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-256.png` — generated directly from `logo.svg`.
- Modify: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-256@2x.png` — generated directly from `logo.svg`.
- Modify: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-512.png` — generated directly from `logo.svg`.
- Modify: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png` — generated directly from `logo.svg`.

## Scope Guards

- Do not modify `logo.svg`; it remains the canonical full-detail source.
- Do not modify `RCMMApp/Views/MenuBar/MenuBarStatusIcon.swift`; the menu bar status icon remains SF Symbol based and out of scope.
- Do not change `RCMMApp/Assets.xcassets/AppIcon.appiconset/Contents.json` unless validation proves the existing slot contract has drifted.

### Task 1: Refactor the Icon Generator Around SVG Sources

**Files:**
- Modify: `scripts/generate-app-icon-set.sh`

- [ ] **Step 1: Run the regression fixture that proves the current script still depends on `AppIcon-512@2x.png`**

Run:

```bash
tmpdir="$(mktemp -d)"
mkdir -p \
  "$tmpdir/scripts" \
  "$tmpdir/RCMMApp/Assets.xcassets/AppIcon.appiconset" \
  "$tmpdir/artwork/app-icon"
cp scripts/generate-app-icon-set.sh "$tmpdir/scripts/generate-app-icon-set.sh"
cp RCMMApp/Assets.xcassets/AppIcon.appiconset/Contents.json \
  "$tmpdir/RCMMApp/Assets.xcassets/AppIcon.appiconset/Contents.json"
cp logo.svg "$tmpdir/logo.svg"
cp logo.svg "$tmpdir/artwork/app-icon/logo-small.svg"
set +e
(cd "$tmpdir" && bash scripts/generate-app-icon-set.sh)
status="$?"
set -e
if [[ "$status" -eq 0 ]]; then
  echo "Error: expected current generator to fail without AppIcon-512@2x.png" >&2
  exit 1
fi
rm -rf "$tmpdir"
```

Expected: prints `Error: missing source icon: /.../RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png` and exits 0 after confirming the old failure mode.

- [ ] **Step 2: Replace `scripts/generate-app-icon-set.sh` with an SVG-source-aware generator**

Replace the file with:

```bash
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
```

- [ ] **Step 3: Verify the new contract with a passing fixture and a missing-source failure**

Run:

```bash
tmpdir="$(mktemp -d)"
mkdir -p \
  "$tmpdir/scripts" \
  "$tmpdir/RCMMApp/Assets.xcassets/AppIcon.appiconset" \
  "$tmpdir/artwork/app-icon"
cp scripts/generate-app-icon-set.sh "$tmpdir/scripts/generate-app-icon-set.sh"
cp RCMMApp/Assets.xcassets/AppIcon.appiconset/Contents.json \
  "$tmpdir/RCMMApp/Assets.xcassets/AppIcon.appiconset/Contents.json"
cp logo.svg "$tmpdir/logo.svg"
cp logo.svg "$tmpdir/artwork/app-icon/logo-small.svg"
(cd "$tmpdir" && bash scripts/generate-app-icon-set.sh)
rm "$tmpdir/artwork/app-icon/logo-small.svg"
set +e
missing_output="$(cd "$tmpdir" && bash scripts/generate-app-icon-set.sh 2>&1)"
missing_status="$?"
set -e
printf '%s\n' "$missing_output"
rm -rf "$tmpdir"
if [[ "$missing_status" -eq 0 ]]; then
  echo "Error: expected generator to fail without artwork/app-icon/logo-small.svg" >&2
  exit 1
fi
```

Expected:

```text
Generated macOS app icon PNGs in /.../RCMMApp/Assets.xcassets/AppIcon.appiconset
Error: missing source svg: /.../artwork/app-icon/logo-small.svg
```

- [ ] **Step 4: Commit the generator refactor**

```bash
git add scripts/generate-app-icon-set.sh
git commit -m "refactor: switch app icon generator to svg sources"
```

### Task 2: Add the Simplified Small-Size Source and Regenerate the App Icon Set

**Files:**
- Create: `artwork/app-icon/logo-small.svg`
- Modify: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-16.png`
- Modify: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-16@2x.png`
- Modify: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-32.png`
- Modify: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-32@2x.png`
- Modify: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-128.png`
- Modify: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-128@2x.png`
- Modify: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-256.png`
- Modify: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-256@2x.png`
- Modify: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-512.png`
- Modify: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png`

- [ ] **Step 1: Create the small-size simplified SVG source**

Create `artwork/app-icon/logo-small.svg` with:

```svg
<svg width="256" height="256" viewBox="0 0 256 256" xmlns="http://www.w3.org/2000/svg">
  <title>rcmm small app icon source</title>
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#3b82f6"/>
      <stop offset="100%" stop-color="#1d4ed8"/>
    </linearGradient>
    <linearGradient id="card" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#ffffff"/>
      <stop offset="100%" stop-color="#eff4ff"/>
    </linearGradient>
  </defs>
  <rect width="256" height="256" rx="54" fill="url(#bg)"/>
  <path fill="#ffffff" opacity=".95" d="M30 26v72l18-18 12 26 14-7-12-25h26z"/>
  <rect x="72" y="70" width="160" height="162" rx="16" fill="url(#card)"/>
  <rect x="72" y="70" width="160" height="162" rx="16" fill="none" stroke="#cbd5e1" stroke-width="2"/>
  <rect x="82" y="82" width="140" height="42" rx="10" fill="#2563eb"/>
  <rect x="92" y="146" width="118" height="13" rx="6.5" fill="#cbd5e1"/>
  <rect x="92" y="176" width="118" height="13" rx="6.5" fill="#cbd5e1"/>
  <rect x="92" y="206" width="88" height="13" rx="6.5" fill="#cbd5e1"/>
</svg>
```

- [ ] **Step 2: Regenerate every app icon PNG from the approved SVG sources**

Run:

```bash
bash scripts/generate-app-icon-set.sh
```

Expected: `Generated macOS app icon PNGs in /.../RCMMApp/Assets.xcassets/AppIcon.appiconset`

- [ ] **Step 3: Verify source routing, output dimensions, and the small-size override**

Run:

```bash
tmpdir="$(mktemp -d)"
sips -z 128 128 -s format png logo.svg --out "$tmpdir/logo-128.png" >/dev/null
sips -z 32 32 -s format png logo.svg --out "$tmpdir/logo-32.png" >/dev/null
sips -z 32 32 -s format png artwork/app-icon/logo-small.svg --out "$tmpdir/logo-small-32.png" >/dev/null
cmp -s "$tmpdir/logo-128.png" RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-128.png
cmp -s "$tmpdir/logo-small-32.png" RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-16@2x.png
if cmp -s "$tmpdir/logo-32.png" RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-16@2x.png; then
  echo "Error: AppIcon-16@2x.png still matches a direct logo.svg downscale" >&2
  exit 1
fi
for file in \
  AppIcon-16.png \
  AppIcon-16@2x.png \
  AppIcon-32.png \
  AppIcon-32@2x.png \
  AppIcon-128.png \
  AppIcon-128@2x.png \
  AppIcon-256.png \
  AppIcon-256@2x.png \
  AppIcon-512.png \
  AppIcon-512@2x.png
do
  sips -g pixelWidth -g pixelHeight "RCMMApp/Assets.xcassets/AppIcon.appiconset/$file"
done
rm -rf "$tmpdir"
```

Expected:

```text
pixelWidth: 16 / pixelHeight: 16
pixelWidth: 32 / pixelHeight: 32
pixelWidth: 32 / pixelHeight: 32
pixelWidth: 64 / pixelHeight: 64
pixelWidth: 128 / pixelHeight: 128
pixelWidth: 256 / pixelHeight: 256
pixelWidth: 256 / pixelHeight: 256
pixelWidth: 512 / pixelHeight: 512
pixelWidth: 512 / pixelHeight: 512
pixelWidth: 1024 / pixelHeight: 1024
```

- [ ] **Step 4: Commit the new small-size source and regenerated icon assets**

```bash
git add \
  artwork/app-icon/logo-small.svg \
  RCMMApp/Assets.xcassets/AppIcon.appiconset
git commit -m "feat: regenerate app icons from logo sources"
```

### Task 3: Verify the Bundle Icon in the Real Build and DMG Flows

**Files:**
- No planned source changes. If this verification exposes a readability problem, return to Task 2, adjust `artwork/app-icon/logo-small.svg`, regenerate assets, and commit the follow-up as `fix: tune small-size app icon`.

- [ ] **Step 1: Build the `rcmm` scheme that produces the shipped app bundle**

Run:

```bash
xcodebuild -project rcmm.xcodeproj -scheme rcmm -configuration Debug build | rg "BUILD SUCCEEDED|BUILD FAILED|error:"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 2: Locate the built app bundle for Finder and Dock inspection**

Run:

```bash
APP_BUILD_DIR="$(xcodebuild -project rcmm.xcodeproj -scheme rcmm -configuration Debug -showBuildSettings | awk -F' = ' '/TARGET_BUILD_DIR =/ {print $2; exit}')"
printf '%s\n' "$APP_BUILD_DIR/rcmm.app"
```

Expected: prints an absolute path ending in `rcmm.app`

- [ ] **Step 3: Package a DMG from the same bundle icon pipeline**

Run:

```bash
if ! command -v create-dmg >/dev/null 2>&1; then
  brew install create-dmg
fi
bash scripts/build-dev-dmg.sh --unsigned icon-check
```

Expected:

```text
Development DMG created successfully.
DMG:      /.../dist/rcmm-dev-icon-check.dmg
Checksum: /.../dist/rcmm-dev-icon-check.dmg.sha256
```

- [ ] **Step 4: Perform the manual icon-surface check**

Check these three surfaces before closing the task:

```text
1. Finder: the built rcmm.app should show the logo-based icon, not the previous folder/menu illustration.
2. Dock: launching the Debug build should show the same logo-based icon with the small-size simplification still recognizable.
3. DMG window: opening rcmm-dev-icon-check.dmg should show the same logo-based bundle icon for rcmm.app.
```

Expected: all three surfaces show the new brand-aligned icon, and the 16/32/64 pixel presentations still read as a blue tile with a white menu card, blue highlight row, and pointer shape instead of unreadable menu text.
