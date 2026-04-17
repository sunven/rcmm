# RCMM App Icon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a native-feeling macOS app icon for `rcmm.app` that clearly reads as a folder-oriented Finder right-click menu tool, using the existing `AppIcon` asset catalog entry.

**Architecture:** Keep the current Xcode asset catalog wiring (`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`). Use one approved 1024x1024 master PNG for the `512x512@2x` slot, add a small Bash helper to regenerate the remaining macOS icon PNGs via `sips`, and map all filenames in `Contents.json`. Verify the work at three levels: file dimensions, asset-catalog-integrated app build, and Finder-side visual inspection of the built/copied app bundle.

**Tech Stack:** Xcode asset catalogs, PNG app icon assets, Bash, `sips`, `plutil`, `xcodebuild`, Finder manual verification

---

## File Map

- Create: `scripts/generate-app-icon-set.sh` — deterministic helper that renders the macOS icon slots from the approved 1024x1024 master PNG.
- Modify: `RCMMApp/Assets.xcassets/AppIcon.appiconset/Contents.json` — add filename mapping for all 10 macOS icon slots.
- Create: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-16.png`
- Create: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-16@2x.png`
- Create: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-32.png`
- Create: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-32@2x.png`
- Create: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-128.png`
- Create: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-128@2x.png`
- Create: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-256.png`
- Create: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-256@2x.png`
- Create: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-512.png`
- Create: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png` — the approved 1024x1024 master icon artwork.

### Task 1: Add deterministic export tooling

**Files:**
- Create: `scripts/generate-app-icon-set.sh`

- [ ] **Step 1: Create the export script**

```bash
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
```

- [ ] **Step 2: Make the script executable and verify the failure mode before the master icon exists**

Run:

```bash
chmod +x scripts/generate-app-icon-set.sh
bash scripts/generate-app-icon-set.sh
```

Expected: FAIL with `Error: missing source icon: /.../RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png`

- [ ] **Step 3: Commit the export script**

```bash
git add scripts/generate-app-icon-set.sh
git commit -m "chore: add app icon export script"
```

### Task 2: Add the approved master icon and wire the asset catalog

**Files:**
- Create: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png`
- Modify: `RCMMApp/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-16.png`
- Create: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-16@2x.png`
- Create: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-32.png`
- Create: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-32@2x.png`
- Create: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-128.png`
- Create: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-128@2x.png`
- Create: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-256.png`
- Create: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-256@2x.png`
- Create: `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-512.png`

- [ ] **Step 1: Create the approved 1024x1024 master PNG**

Create `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png` as a 1024x1024 PNG that matches this acceptance criteria exactly:

```text
- Dominant warm yellow macOS-style folder as the base shape
- White rounded context-menu card overlapping the folder in the upper-right quadrant
- Exactly 3 horizontal menu rows inside the card
- Exactly 1 row highlighted in blue
- Soft highlights, shallow shadow, modest volume; native macOS icon feel, not glossy skeuomorphism
- No cursor, no hand, no text, no badge, no extra symbol, no background scene
- Composition must still read at small sizes: folder silhouette first, menu card second
Reject any master art that reads as a browser window, generic launcher tile, file manager, or poster-style illustration.
```

- [ ] **Step 2: Verify the master icon file format and dimensions**

Run:

```bash
sips -g format -g pixelWidth -g pixelHeight RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png
```

Expected:

```text
format: png
pixelWidth: 1024
pixelHeight: 1024
```

- [ ] **Step 3: Update `Contents.json` so every macOS slot points at an actual filename**

Replace `RCMMApp/Assets.xcassets/AppIcon.appiconset/Contents.json` with:

```json
{
  "images" : [
    {
      "filename" : "AppIcon-16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "AppIcon-16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "AppIcon-32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "AppIcon-32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "AppIcon-128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "AppIcon-128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "AppIcon-256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "AppIcon-256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "AppIcon-512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "AppIcon-512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 4: Generate the remaining PNG slots from the approved master**

Run:

```bash
bash scripts/generate-app-icon-set.sh
```

Expected: `Generated macOS app icon PNGs in /.../RCMMApp/Assets.xcassets/AppIcon.appiconset`

- [ ] **Step 5: Verify the full PNG inventory and each output size**

Run:

```bash
find RCMMApp/Assets.xcassets/AppIcon.appiconset -maxdepth 1 -name 'AppIcon*.png' | sort

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
```

Expected:

```text
RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-16.png            -> 16x16
RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-16@2x.png         -> 32x32
RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-32.png            -> 32x32
RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-32@2x.png         -> 64x64
RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-128.png           -> 128x128
RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-128@2x.png        -> 256x256
RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-256.png           -> 256x256
RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-256@2x.png        -> 512x512
RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-512.png           -> 512x512
RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png        -> 1024x1024
```

- [ ] **Step 6: Validate the asset catalog JSON and commit the icon assets**

Run:

```bash
plutil -lint RCMMApp/Assets.xcassets/AppIcon.appiconset/Contents.json
git add RCMMApp/Assets.xcassets/AppIcon.appiconset
git commit -m "feat: add RCMM app icon assets"
```

Expected: `RCMMApp/Assets.xcassets/AppIcon.appiconset/Contents.json: OK`

### Task 3: Build the app and verify Finder-side presentation

**Files:**
- No file changes; this task is verification only

- [ ] **Step 1: Build the main app target that owns the `AppIcon` asset**

Run:

```bash
xcodebuild -project rcmm.xcodeproj -scheme rcmm -configuration Debug build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: Reveal the built app bundle in Finder and check the icon**

Run:

```bash
APP_BUILD_DIR="$(xcodebuild -project rcmm.xcodeproj -scheme rcmm -configuration Debug -showBuildSettings | awk -F' = ' '/TARGET_BUILD_DIR =/ {print $2; exit}')"
APP_PATH="$APP_BUILD_DIR/rcmm.app"
test -d "$APP_PATH"
open -R "$APP_PATH"
```

Expected:

```text
- `test -d` succeeds
- Finder reveals `rcmm.app`
- Finder shows the new warm-yellow folder + white menu-card icon on the bundle
```

Note: use the `rcmm` scheme even though older project docs mention `RCMMApp`; `xcodebuild -list` in this repository currently exposes `rcmm` as the main app scheme.

- [ ] **Step 3: Verify copied-bundle presentation outside the build products directory**

Run:

```bash
rm -rf /tmp/rcmm-icon-check
mkdir -p /tmp/rcmm-icon-check
cp -R "$APP_PATH" /tmp/rcmm-icon-check/rcmm.app
open -R /tmp/rcmm-icon-check/rcmm.app
```

Expected:

```text
- Finder reveals `/tmp/rcmm-icon-check/rcmm.app`
- The copied bundle shows the same icon as the build product
```

This replaces any Dock / app-switcher check because `RCMMApp/Info.plist` sets `LSUIElement = true`, so normal runtime Dock presence is not the correct validation surface.

- [ ] **Step 4: Perform the small-size acceptance check before declaring success**

Use Finder icon/list view or Preview and confirm all three statements are true:

```text
- At small display sizes, the folder silhouette still reads before the menu card
- The white menu card remains visibly separate from the yellow folder
- The blue highlighted row is still readable as a menu-action accent, not as a second badge
```

If any check fails, revise `RCMMApp/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png`, rerun `bash scripts/generate-app-icon-set.sh`, and repeat Task 3 without changing any project metadata.
