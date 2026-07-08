#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/render-release-notes.sh display_version current_tag repository_url

Example:
  bash scripts/render-release-notes.sh 1.2.3 v1.2.3 https://github.com/sunven/rcmm
EOF
}

stable_tags_by_version() {
  git tag --list 'v*.*.*' \
    | sed -nE 's/^v([0-9]+)\.([0-9]+)\.([0-9]+)$/\1 \2 \3 v\1.\2.\3/p' \
    | sort -k1,1n -k2,2n -k3,3n
}

previous_stable_tag() {
  local current_tag="$1"
  local previous_tag=""

  while read -r _major _minor _patch tag; do
    if [[ "$tag" == "$current_tag" ]]; then
      printf '%s' "$previous_tag"
      return 0
    fi
    previous_tag="$tag"
  done < <(stable_tags_by_version)
}

if [[ $# -ne 3 ]]; then
  usage >&2
  exit 1
fi

display_version="$1"
current_tag="$2"
repository_url="${3%/}"

if [[ ! "$current_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: current_tag must look like v1.2.3: $current_tag" >&2
  exit 1
fi

if [[ -z "$display_version" || -z "$repository_url" ]]; then
  echo "Error: display_version and repository_url are required" >&2
  exit 1
fi

if ! git rev-parse -q --verify "refs/tags/$current_tag" >/dev/null; then
  echo "Error: tag does not exist: $current_tag" >&2
  exit 1
fi

previous_tag="$(previous_stable_tag "$current_tag")"
if [[ -n "$previous_tag" ]]; then
  log_range="$previous_tag..$current_tag"
else
  log_range="$current_tag"
fi

cat <<EOF
## 更新内容

EOF

has_subject=false
while IFS= read -r subject; do
  trimmed_subject="$(printf '%s' "$subject" \
    | sed -E 's/^(build|chore|ci|docs|feat|fix|perf|refactor|style|test)(\([^)]+\))?:[[:space:]]*//' \
    | sed 's/[[:space:]]*$//')"
  [[ -z "$trimmed_subject" ]] && continue

  printf -- '- %s\n' "$trimmed_subject"
  has_subject=true
done < <(git log --format=%s "$log_range")

if [[ "$has_subject" == false ]]; then
  printf '%s\n' '- 本次发布更新了安装包和自动更新元数据。'
fi

if [[ -n "$previous_tag" ]]; then
  printf '\n**Full Changelog**: [%s...%s](%s/compare/%s...%s)\n' \
    "$previous_tag" \
    "$current_tag" \
    "$repository_url" \
    "$previous_tag" \
    "$current_tag"
fi
