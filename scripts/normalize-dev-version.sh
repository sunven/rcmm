#!/usr/bin/env bash

set -euo pipefail

input="${1:-}"
version="${input#v}"

if [[ -z "$version" ]]; then
  echo "Usage: bash scripts/normalize-dev-version.sh v1.2.3-dev.4" >&2
  exit 1
fi

if [[ ! "$version" =~ ^([0-9]+\.[0-9]+\.[0-9]+)-dev(\.([0-9]+))?$ ]]; then
  echo "Error: invalid development version: $input" >&2
  exit 1
fi

short_version="${BASH_REMATCH[1]}"
build_number="${BASH_REMATCH[3]:-0}"
bundle_version="${short_version}.${build_number}"

cat <<EOF
DISPLAY_VERSION=${version}
SHORT_VERSION=${short_version}
BUILD_NUMBER=${build_number}
BUNDLE_VERSION=${bundle_version}
EOF
