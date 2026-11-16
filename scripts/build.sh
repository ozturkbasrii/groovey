#!/bin/bash
# Builds Groovey.app (Release, universal, ad-hoc signed) into dist/.
# Usage: scripts/build.sh [install]
set -euo pipefail
cd "$(dirname "$0")/.."

command -v xcodegen >/dev/null || { echo "XcodeGen is required: brew install xcodegen" >&2; exit 1; }

xcodegen generate --quiet
xcodebuild -project Groovey.xcodeproj -scheme Groovey -configuration Release \
  -derivedDataPath build -destination "generic/platform=macOS" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO build | tail -n 3

rm -rf dist/Groovey.app
mkdir -p dist
cp -R build/Build/Products/Release/Groovey.app dist/Groovey.app
codesign --verify --deep --strict dist/Groovey.app
echo "Built dist/Groovey.app"

if [[ "${1:-}" == "install" ]]; then
  pkill -x Groovey 2>/dev/null || true
  rm -rf /Applications/Groovey.app
  cp -R dist/Groovey.app /Applications/Groovey.app
  open /Applications/Groovey.app
  echo "Installed to /Applications and launched"
fi
