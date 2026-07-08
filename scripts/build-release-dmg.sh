#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/build-release-dmg.sh [--unsigned] version

Options:
  --unsigned    Build without Xcode signing, then apply ad-hoc signing. This is the default.
  -h, --help    Show this help message.

Behavior:
  - Builds a Release xcarchive for the rcmm scheme
  - Extracts rcmm.app from the archive
  - Applies ad-hoc signing
  - Creates a clean DMG containing only rcmm.app
  - Creates a ZIP archive for Sparkle updates
  - Writes release assets and SHA-256 checksums into ./dist

Example:
  bash scripts/build-release-dmg.sh --unsigned 1.0.0
EOF
}

require_cmd() {
  local cmd="$1"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: missing required command: $cmd" >&2
    exit 1
  fi
}

expand_entitlements() {
  local input_path="$1"
  local output_path="$2"

  sed \
    -e "s|\$(RCMM_APP_GROUP_IDENTIFIER)|group.com.sunven.rcmm|g" \
    "$input_path" > "$output_path"
}

verify_extension_bundle() {
  if [[ ! -d "$APP_PATH/Contents/PlugIns/RCMMFinderExtension.appex" ]]; then
    echo "Error: Finder extension is missing from extracted app bundle" >&2
    exit 1
  fi

  if [[ ! -f "$APP_PATH/Contents/PlugIns/RCMMFinderExtension.appex/Contents/MacOS/RCMMFinderExtension" ]]; then
    echo "Error: Finder extension executable is missing from extracted app bundle" >&2
    exit 1
  fi
}

adhoc_sign_app() {
  local app_entitlements="$BUILD_DIR/rcmm.entitlements"
  local extension_entitlements="$BUILD_DIR/RCMMFinderExtension.entitlements"
  local sparkle_framework="$APP_PATH/Contents/Frameworks/Sparkle.framework"
  local sparkle_version="$sparkle_framework/Versions/B"

  expand_entitlements "$ROOT_DIR/RCMMApp/rcmm.entitlements" "$app_entitlements"
  expand_entitlements "$ROOT_DIR/RCMMFinderExtension/RCMMFinderExtension.entitlements" "$extension_entitlements"

  if [[ -d "$sparkle_version" ]]; then
    codesign --force --sign - "$sparkle_version/XPCServices/Downloader.xpc"
    codesign --force --sign - "$sparkle_version/XPCServices/Installer.xpc"
    codesign --force --sign - "$sparkle_version/Updater.app"
    codesign --force --sign - "$sparkle_version/Autoupdate"
    codesign --force --sign - "$sparkle_version"
  elif [[ -d "$sparkle_framework" ]]; then
    codesign --force --sign - "$sparkle_framework"
  fi

  codesign \
    --force \
    --sign - \
    --entitlements "$extension_entitlements" \
    "$APP_PATH/Contents/PlugIns/RCMMFinderExtension.appex"

  codesign \
    --force \
    --sign - \
    --entitlements "$app_entitlements" \
    "$APP_PATH"
}

POSITIONAL_VERSION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --unsigned)
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "$POSITIONAL_VERSION" ]]; then
        echo "Error: version specified more than once" >&2
        usage >&2
        exit 1
      fi
      POSITIONAL_VERSION="$1"
      shift
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/release"
ARCHIVE_PATH="$BUILD_DIR/rcmm.xcarchive"
APP_PATH="$BUILD_DIR/rcmm.app"
STAGING_DIR="$BUILD_DIR/dmg-root"
DIST_DIR="$ROOT_DIR/dist"
XCODEBUILD_LOG="$BUILD_DIR/xcodebuild.log"

require_cmd xcodebuild
require_cmd codesign
require_cmd create-dmg
require_cmd ditto
require_cmd shasum

VERSION="$POSITIONAL_VERSION"

if [[ -z "$VERSION" ]]; then
  echo "Error: missing release version" >&2
  usage >&2
  exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: release version must look like 1.2.3: $VERSION" >&2
  exit 1
fi

DMG_NAME="rcmm-${VERSION}.dmg"
CHECKSUM_NAME="${DMG_NAME}.sha256"
ZIP_NAME="rcmm-${VERSION}.zip"
ZIP_CHECKSUM_NAME="${ZIP_NAME}.sha256"
STABLE_FEED_URL="https://github.com/sunven/rcmm/releases/latest/download/stable.xml"

echo "Building release DMG for version: $VERSION"
echo "Signing mode: ad-hoc"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

pushd "$ROOT_DIR" >/dev/null

xcodebuild archive \
  -project rcmm.xcodeproj \
  -scheme rcmm \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$VERSION.0" \
  RCMM_SHORT_VERSION="$VERSION" \
  RCMM_BUILD_NUMBER="0" \
  RCMM_BUNDLE_VERSION="$VERSION.0" \
  RCMM_DISPLAY_VERSION="$VERSION" \
  RCMM_SU_FEED_URL="$STABLE_FEED_URL" \
  RCMM_UPDATES_ENABLED=YES \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  | tee "$XCODEBUILD_LOG"

if [[ ! -d "$ARCHIVE_PATH" ]]; then
  echo "Error: archive was not created at $ARCHIVE_PATH" >&2
  exit 1
fi

cp -R "$ARCHIVE_PATH/Products/Applications/rcmm.app" "$APP_PATH"
verify_extension_bundle
adhoc_sign_app
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/rcmm.app"

rm -f \
  "$DIST_DIR/$DMG_NAME" \
  "$DIST_DIR/$CHECKSUM_NAME" \
  "$DIST_DIR/$ZIP_NAME" \
  "$DIST_DIR/$ZIP_CHECKSUM_NAME"

create-dmg \
  --volname "rcmm" \
  --skip-jenkins \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "rcmm.app" 200 190 \
  --hide-extension "rcmm.app" \
  --app-drop-link 600 185 \
  "$DIST_DIR/$DMG_NAME" \
  "$STAGING_DIR"

if [[ ! -f "$DIST_DIR/$DMG_NAME" ]]; then
  echo "Error: DMG was not created at $DIST_DIR/$DMG_NAME" >&2
  exit 1
fi

shasum -a 256 "$DIST_DIR/$DMG_NAME" > "$DIST_DIR/$CHECKSUM_NAME"

pushd "$BUILD_DIR" >/dev/null
ditto -c -k --sequesterRsrc --keepParent "rcmm.app" "$DIST_DIR/$ZIP_NAME"
popd >/dev/null

if [[ ! -f "$DIST_DIR/$ZIP_NAME" ]]; then
  echo "Error: ZIP was not created at $DIST_DIR/$ZIP_NAME" >&2
  exit 1
fi

shasum -a 256 "$DIST_DIR/$ZIP_NAME" > "$DIST_DIR/$ZIP_CHECKSUM_NAME"

popd >/dev/null

cat <<EOF
Release DMG created successfully.

DMG:          $DIST_DIR/$DMG_NAME
DMG checksum: $DIST_DIR/$CHECKSUM_NAME
ZIP:          $DIST_DIR/$ZIP_NAME
ZIP checksum: $DIST_DIR/$ZIP_CHECKSUM_NAME

This build is not notarized. First launch may require a manual Gatekeeper
override or removing the quarantine attribute after installation.
EOF
