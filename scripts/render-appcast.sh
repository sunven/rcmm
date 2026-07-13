#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/render-appcast.sh display_version bundle_version archive_url archive_length signature release_page_url [release_notes_file]

Example:
  bash scripts/render-appcast.sh 1.2.3 1.2.3.0 https://example.com/rcmm-1.2.3.zip 12345 sig https://example.com/releases/tag/v1.2.3 notes.md
EOF
}

xml_escape() {
  printf '%s' "$1" \
    | sed \
      -e 's/&/\&amp;/g' \
      -e 's/"/\&quot;/g' \
      -e "s/'/\&apos;/g" \
      -e 's/</\&lt;/g' \
      -e 's/>/\&gt;/g'
}

cdata_escape() {
  printf '%s' "$1" | sed 's/]]>/]]]]><![CDATA[>/g'
}

if [[ $# -ne 6 && $# -ne 7 ]]; then
  usage >&2
  exit 1
fi

display_version="$1"
bundle_version="$2"
archive_url="$3"
archive_length="$4"
signature="$5"
release_page_url="$6"
release_notes_file="${7:-}"

if [[ ! "$bundle_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: bundle_version must look like 1.2.3.0: $bundle_version" >&2
  exit 1
fi

if [[ ! "$archive_length" =~ ^[0-9]+$ ]]; then
  echo "Error: archive_length must be a positive integer: $archive_length" >&2
  exit 1
fi

if [[ -z "$display_version" || -z "$archive_url" || -z "$signature" || -z "$release_page_url" ]]; then
  echo "Error: display_version, archive_url, signature, and release_page_url are required" >&2
  exit 1
fi

release_notes_markdown=""
if [[ -n "$release_notes_file" ]]; then
  if [[ ! -f "$release_notes_file" ]]; then
    echo "Error: release_notes_file does not exist: $release_notes_file" >&2
    exit 1
  fi
  release_notes_markdown="$(< "$release_notes_file")"
fi

if [[ -z "${release_notes_markdown//[[:space:]]/}" ]]; then
  release_notes_markdown="$(printf 'rcmm %s is available.\n\nOpen the GitHub release page for the full changelog:\n%s' "$display_version" "$release_page_url")"
else
  release_notes_markdown="$(printf '%s\n\nFull release: %s' "$release_notes_markdown" "$release_page_url")"
fi

pub_date="$(LC_ALL=C TZ=UTC date '+%a, %d %b %Y %H:%M:%S +0000')"

cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>rcmm Updates</title>
    <description>Most recent rcmm release.</description>
    <language>zh-CN</language>
    <item>
      <title>Version $(xml_escape "$display_version")</title>
      <description sparkle:format="markdown"><![CDATA[
$(cdata_escape "$release_notes_markdown")
      ]]></description>
      <sparkle:fullReleaseNotesLink>$(xml_escape "$release_page_url")</sparkle:fullReleaseNotesLink>
      <pubDate>$pub_date</pubDate>
      <enclosure
        url="$(xml_escape "$archive_url")"
        sparkle:version="$(xml_escape "$bundle_version")"
        sparkle:shortVersionString="$(xml_escape "$display_version")"
        length="$(xml_escape "$archive_length")"
        type="application/octet-stream"
        sparkle:edSignature="$(xml_escape "$signature")" />
      <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
    </item>
  </channel>
</rss>
EOF
