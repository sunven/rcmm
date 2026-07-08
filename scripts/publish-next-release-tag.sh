#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/publish-next-release-tag.sh [--dry-run]

Options:
  --dry-run    Print the next release tag without creating or pushing it.
  -h, --help   Show this help message.

Behavior:
  - Fetches tags from origin
  - Finds the latest stable vX.Y.Z tag
  - Increments the patch version
  - Creates the next tag on HEAD
  - Pushes the tag to origin
EOF
}

latest_stable_version() {
  git tag --list 'v*.*.*' \
    | sed -nE 's/^v([0-9]+)\.([0-9]+)\.([0-9]+)$/\1.\2.\3/p' \
    | sort -t. -k1,1n -k2,2n -k3,3n \
    | tail -n 1
}

DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "Error: missing git remote: origin" >&2
  exit 1
fi

echo "Fetching release tags from origin..."
git fetch --tags origin

LATEST_VERSION="$(latest_stable_version)"

if [[ -z "$LATEST_VERSION" ]]; then
  echo "Error: no stable release tag found. Expected at least one vX.Y.Z tag." >&2
  exit 1
fi

IFS=. read -r MAJOR MINOR PATCH <<< "$LATEST_VERSION"
NEXT_VERSION="${MAJOR}.${MINOR}.$((10#$PATCH + 1))"
LATEST_TAG="v${LATEST_VERSION}"
NEXT_TAG="v${NEXT_VERSION}"

if git rev-parse -q --verify "refs/tags/${NEXT_TAG}" >/dev/null; then
  echo "Error: next tag already exists locally: ${NEXT_TAG}" >&2
  exit 1
fi

if [[ "$DRY_RUN" == true ]]; then
  cat <<EOF
Latest stable tag: ${LATEST_TAG}
Next stable tag:   ${NEXT_TAG}

Dry run: no tag created or pushed.
Would run:
  git tag ${NEXT_TAG}
  git push origin ${NEXT_TAG}
EOF
  exit 0
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: working tree is not clean. Commit or stash changes before publishing a release tag." >&2
  exit 1
fi

git tag "$NEXT_TAG"
git push origin "$NEXT_TAG"

echo "Published release tag: ${NEXT_TAG}"
