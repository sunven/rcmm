#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/build-dev-dmg.sh [options] [version]

Options:
  --signed      Build with local Xcode automatic signing. This is the default.
  --unsigned    Build without Xcode signing, then apply ad-hoc signing.
  -h, --help    Show this help message.

Behavior:
  - Builds a Release xcarchive for the rcmm scheme
  - Extracts rcmm.app from the archive
  - In signed mode, keeps the Xcode-produced local development signature
  - In unsigned mode, applies ad-hoc signing as a fallback
  - Creates a clean development DMG containing only rcmm.app
  - Writes the DMG and SHA-256 checksum into ./dist

Examples:
  bash scripts/build-dev-dmg.sh
  bash scripts/build-dev-dmg.sh 1.0.0-dev.1
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
    | tee "$XCODEBUILD_LOG"
}

build_archive_unsigned() {
  xcodebuild archive \
    -project rcmm.xcodeproj \
    -scheme rcmm \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
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

SIGNING_MODE="signed"
POSITIONAL_VERSION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
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
BUILD_DIR="$ROOT_DIR/build/dev-release"
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

DMG_NAME="rcmm-dev-${VERSION}.dmg"
CHECKSUM_NAME="${DMG_NAME}.sha256"

echo "Building development DMG for version: $VERSION"
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
  codesign --force --deep --sign - "$APP_PATH"
  codesign --verify --deep --strict --verbose=2 "$APP_PATH"
fi

print_signing_summary

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/rcmm.app"

rm -f "$DIST_DIR/$DMG_NAME" "$DIST_DIR/$CHECKSUM_NAME"

create-dmg \
  --volname "rcmm" \
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

if [[ "$SIGNING_MODE" == "signed" ]]; then
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
