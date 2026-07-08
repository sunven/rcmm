#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'cd "$ROOT_DIR"; rm -rf "$TMP_DIR"' EXIT

cd "$TMP_DIR"
git init -q
git config user.email "test@example.com"
git config user.name "Test User"

printf 'one\n' > file.txt
git add file.txt
git commit -q -m "Initial release"
git tag v0.0.1

printf 'two\n' >> file.txt
git commit -q -am "Add update prompt release notes"

printf 'three\n' >> file.txt
git commit -q -am "Fix Sparkle appcast body"
git tag v0.0.2

notes_file="$TMP_DIR/release-notes.md"
bash "$ROOT_DIR/scripts/render-release-notes.sh" \
  0.0.2 \
  v0.0.2 \
  https://example.com/sunven/rcmm \
  > "$notes_file"

grep -Fq '## 更新内容' "$notes_file"
grep -Fq -- '- Fix Sparkle appcast body' "$notes_file"
grep -Fq -- '- Add update prompt release notes' "$notes_file"
grep -Fq '**Full Changelog**: [v0.0.1...v0.0.2](https://example.com/sunven/rcmm/compare/v0.0.1...v0.0.2)' "$notes_file"
