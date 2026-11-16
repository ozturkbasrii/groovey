#!/bin/bash
# Packages dist/Groovey.app into dist/Groovey-<version>.dmg.
set -euo pipefail
cd "$(dirname "$0")/.."

[[ -d dist/Groovey.app ]] || scripts/build.sh
command -v create-dmg >/dev/null || { echo "create-dmg is required: brew install create-dmg" >&2; exit 1; }

version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" dist/Groovey.app/Contents/Info.plist)
dmg="dist/Groovey-$version.dmg"
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
cp -R dist/Groovey.app "$staging/"

rm -f "$dmg"
create-dmg \
  --volname "Groovey" \
  --window-size 540 360 \
  --icon-size 110 \
  --icon "Groovey.app" 140 170 \
  --app-drop-link 400 170 \
  --no-internet-enable \
  "$dmg" "$staging" >/dev/null

echo "$dmg"
