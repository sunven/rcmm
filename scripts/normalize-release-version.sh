#!/usr/bin/env bash

set -euo pipefail

input="${1:-}"
version="${input#v}"

if [[ -z "$version" ]]; then
  echo "Usage: bash scripts/normalize-release-version.sh v1.2.3" >&2
  exit 1
fi

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: invalid stable release version: $input" >&2
  exit 1
fi

cat <<EOF
DISPLAY_VERSION=${version}
SHORT_VERSION=${version}
BUILD_NUMBER=0
BUNDLE_VERSION=${version}.0
EOF
