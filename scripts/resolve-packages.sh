#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/resolve-packages.sh [options]

Options:
  --reset      Move this project's Xcode DerivedData aside before resolving.
  -h, --help   Show this help message.

Behavior:
  - Resolves Swift Package dependencies for rcmm.xcodeproj / rcmm scheme.
  - With --reset, moves matching Xcode DerivedData directories to a timestamped
    backup directory so Xcode can rebuild its SwiftPM package cache.

Examples:
  bash scripts/resolve-packages.sh
  bash scripts/resolve-packages.sh --reset
EOF
}

require_cmd() {
  local cmd="$1"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: missing required command: $cmd" >&2
    exit 1
  fi
}

xcode_is_running() {
  command -v pgrep >/dev/null 2>&1 && pgrep -x Xcode >/dev/null 2>&1
}

reset_project_derived_data() {
  local derived_data_root="$HOME/Library/Developer/Xcode/DerivedData"
  local backup_root="$derived_data_root/_rcmm-package-cache-backups"
  local timestamp
  local dirs=()

  if [[ ! -d "$derived_data_root" ]]; then
    echo "No Xcode DerivedData directory found at: $derived_data_root"
    return
  fi

  shopt -s nullglob
  dirs=("$derived_data_root"/rcmm-*)
  shopt -u nullglob

  if [[ ${#dirs[@]} -eq 0 ]]; then
    echo "No rcmm DerivedData directories found."
    return
  fi

  timestamp="$(date '+%Y%m%d-%H%M%S')"
  mkdir -p "$backup_root"

  for dir in "${dirs[@]}"; do
    local base
    local target

    base="$(basename "$dir")"
    target="$backup_root/${base}.${timestamp}"

    echo "Moving DerivedData cache:"
    echo "  from: $dir"
    echo "  to:   $target"
    mv "$dir" "$target"
  done
}

RESET=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reset)
      RESET=true
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
      echo "Error: unexpected argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/rcmm.xcodeproj"
SCHEME="rcmm"

require_cmd xcodebuild

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Error: project not found: $PROJECT_PATH" >&2
  exit 1
fi

if [[ "$RESET" == true ]]; then
  if xcode_is_running; then
    echo "Error: Xcode is running. Quit Xcode before using --reset." >&2
    exit 1
  fi

  reset_project_derived_data
fi

echo "Resolving Swift packages for $PROJECT_PATH / scheme $SCHEME..."

pushd "$ROOT_DIR" >/dev/null
xcodebuild -resolvePackageDependencies \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME"
popd >/dev/null

echo "Swift packages resolved."
