#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

notes_file="$TMP_DIR/notes.md"
appcast_file="$TMP_DIR/stable.xml"

printf '## Changes\n\n- Fixed update notes rendering.\n' > "$notes_file"

bash "$ROOT_DIR/scripts/render-appcast.sh" \
  1.2.3 \
  1.2.3.0 \
  https://example.com/rcmm-1.2.3.zip \
  12345 \
  sig \
  https://example.com/releases/tag/v1.2.3 \
  "$notes_file" \
  > "$appcast_file"

xmllint --noout "$appcast_file"

if grep -Fq '<sparkle:releaseNotesLink>' "$appcast_file"; then
  echo "Error: appcast must not embed a releaseNotesLink for the Sparkle update dialog" >&2
  exit 1
fi

grep -Fq '<description sparkle:descriptionFormat="markdown"><![CDATA[' "$appcast_file"
grep -Fq 'Fixed update notes rendering.' "$appcast_file"
grep -Fq '<sparkle:fullReleaseNotesLink>https://example.com/releases/tag/v1.2.3</sparkle:fullReleaseNotesLink>' "$appcast_file"
