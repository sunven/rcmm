#!/usr/bin/env bash

set -euo pipefail

display_version="${1:?missing display version}"
bundle_version="${2:?missing bundle version}"
archive_url="${3:?missing archive url}"
archive_length="${4:?missing archive length}"
signature="${5:?missing sparkle signature}"
release_notes_url="${6:-}"
pub_date="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S %z')"

cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>rcmm dev updates</title>
    <link>https://github.com/sunven/rcmm/releases</link>
    <description>Development builds for rcmm</description>
    <language>en</language>
    <item>
      <title>Version ${display_version}</title>
      <pubDate>${pub_date}</pubDate>
      <sparkle:releaseNotesLink>${release_notes_url}</sparkle:releaseNotesLink>
      <enclosure
        url="${archive_url}"
        sparkle:version="${bundle_version}"
        sparkle:shortVersionString="${display_version}"
        length="${archive_length}"
        type="application/octet-stream"
        sparkle:edSignature="${signature}" />
    </item>
  </channel>
</rss>
EOF
