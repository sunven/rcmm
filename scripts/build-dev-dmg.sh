#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/build-dev-dmg.sh [options] [version]

Options:
  --release     Build a stable DMG: rcmm-{version}.dmg, no appcast update feed.
  --signed      Build with local Xcode automatic signing. This is the default.
  --unsigned    Build without Xcode signing, then apply ad-hoc signing.
  -h, --help    Show this help message.

Behavior:
  - Builds a Release xcarchive for the rcmm scheme
  - Extracts rcmm.app from the archive
  - In signed mode, keeps the Xcode-produced local development signature
  - In unsigned mode, applies ad-hoc signing as a fallback
  - Creates a clean DMG containing only rcmm.app
  - Writes the DMG and SHA-256 checksum into ./dist

Examples:
  bash scripts/build-dev-dmg.sh
  bash scripts/build-dev-dmg.sh 1.0.0-dev.1
  bash scripts/build-dev-dmg.sh --release --unsigned 1.0.0
  bash scripts/build-dev-dmg.sh --unsigned 1.0.0-dev.1
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

default_version() {
  local exact_tag short_sha

  if exact_tag="$(git -C "$ROOT_DIR" describe --tags --exact-match 2>/dev/null)"; then
    printf '%s\n' "${exact_tag#v}"
    return
  fi

  short_sha="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || echo nogit)"
  printf 'dev-local-%s-%s\n' "$(date '+%Y%m%d-%H%M%S')" "$short_sha"
}

build_archive_signed() {
  xcodebuild archive \
    -project rcmm.xcodeproj \
    -scheme rcmm \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    "${XCODEBUILD_VERSION_SETTINGS[@]}" \
    CODE_SIGN_STYLE=Automatic \
    PROVISIONING_PROFILE="" \
    PROVISIONING_PROFILE_SPECIFIER="" \
    | tee "$XCODEBUILD_LOG"
}

build_archive_unsigned() {
  xcodebuild archive \
    -project rcmm.xcodeproj \
    -scheme rcmm \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    "${XCODEBUILD_VERSION_SETTINGS[@]}" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    | tee "$XCODEBUILD_LOG"
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

print_signing_summary() {
  echo
  echo "Signing summary:"
  codesign -dv --verbose=2 "$APP_PATH" 2>&1 | rg 'Authority=|TeamIdentifier=|Signature=' || true
  codesign -dv --verbose=2 "$APP_PATH/Contents/PlugIns/RCMMFinderExtension.appex" 2>&1 | rg 'Authority=|TeamIdentifier=|Signature=' || true
  echo
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

SIGNING_MODE="signed"
CHANNEL="dev"
POSITIONAL_VERSION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release)
      CHANNEL="release"
      shift
      ;;
    --signed)
      SIGNING_MODE="signed"
      shift
      ;;
    --unsigned)
      SIGNING_MODE="unsigned"
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
BUILD_DIR="$ROOT_DIR/build/$CHANNEL-release"
ARCHIVE_PATH="$BUILD_DIR/rcmm.xcarchive"
APP_PATH="$BUILD_DIR/rcmm.app"
STAGING_DIR="$BUILD_DIR/dmg-root"
DIST_DIR="$ROOT_DIR/dist"
XCODEBUILD_LOG="$BUILD_DIR/xcodebuild.log"

require_cmd git
require_cmd xcodebuild
require_cmd codesign
require_cmd create-dmg
require_cmd shasum
require_cmd rg

VERSION="${POSITIONAL_VERSION:-$(default_version)}"

if [[ ! "$VERSION" =~ ^[A-Za-z0-9._+-]+$ ]]; then
  echo "Error: version contains unsupported characters: $VERSION" >&2
  exit 1
fi

XCODEBUILD_VERSION_SETTINGS=()
case "$CHANNEL" in
  dev)
    DMG_NAME="rcmm-dev-${VERSION}.dmg"
    ;;
  release)
    if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "Error: stable release version must look like 1.2.3: $VERSION" >&2
      exit 1
    fi
    DMG_NAME="rcmm-${VERSION}.dmg"
    XCODEBUILD_VERSION_SETTINGS=(
      MARKETING_VERSION="$VERSION"
      CURRENT_PROJECT_VERSION="$VERSION.0"
      RCMM_SHORT_VERSION="$VERSION"
      RCMM_BUILD_NUMBER="0"
      RCMM_BUNDLE_VERSION="$VERSION.0"
      RCMM_DISPLAY_VERSION="$VERSION"
      RCMM_SU_FEED_URL=
      RCMM_UPDATES_ENABLED=NO
    )
    ;;
  *)
    echo "Error: unsupported channel: $CHANNEL" >&2
    exit 1
    ;;
esac
CHECKSUM_NAME="${DMG_NAME}.sha256"

echo "Building $CHANNEL DMG for version: $VERSION"
echo "Signing mode: $SIGNING_MODE"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

pushd "$ROOT_DIR" >/dev/null

if [[ "$SIGNING_MODE" == "signed" ]]; then
  build_archive_signed
else
  build_archive_unsigned
fi

if [[ ! -d "$ARCHIVE_PATH" ]]; then
  echo "Error: archive was not created at $ARCHIVE_PATH" >&2
  exit 1
fi

cp -R "$ARCHIVE_PATH/Products/Applications/rcmm.app" "$APP_PATH"
verify_extension_bundle

if [[ "$SIGNING_MODE" == "signed" ]]; then
  codesign --verify --deep --strict --verbose=2 "$APP_PATH"
else
  adhoc_sign_app
  codesign --verify --deep --strict --verbose=2 "$APP_PATH"
fi

print_signing_summary

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/rcmm.app"

rm -f "$DIST_DIR/$DMG_NAME" "$DIST_DIR/$CHECKSUM_NAME"

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

popd >/dev/null

if [[ "$CHANNEL" == "release" ]]; then
  cat <<EOF
Release DMG created successfully.

DMG:      $DIST_DIR/$DMG_NAME
Checksum: $DIST_DIR/$CHECKSUM_NAME

This build is not notarized. First launch may require a manual Gatekeeper
override or removing the quarantine attribute after installation.
EOF
elif [[ "$SIGNING_MODE" == "signed" ]]; then
  cat <<EOF
Development DMG created successfully.

DMG:      $DIST_DIR/$DMG_NAME
Checksum: $DIST_DIR/$CHECKSUM_NAME

This build keeps the local Xcode development signature, which is the mode most
likely to let Finder Sync register on this machine.
EOF
else
  cat <<EOF
Development DMG created successfully.

DMG:      $DIST_DIR/$DMG_NAME
Checksum: $DIST_DIR/$CHECKSUM_NAME

This build uses ad-hoc signing. It can be useful as a fallback package, but
Finder Sync registration may not work reliably outside Xcode-built local runs.
EOF
fi
