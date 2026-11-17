#!/bin/bash
# Builds Groovey.app (Release, universal) into dist/.
#
# Usage: scripts/build.sh            ad-hoc signed, for running locally
#        scripts/build.sh install    same, then copies it to /Applications and launches it
#        scripts/build.sh release    Developer ID signed with Hardened Runtime, ready to notarize
#
# The release mode only ever signs with the maintainer's own team below, never with any
# other team that happens to have a certificate in the Keychain.
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID="864N8V85P8"
mode="${1:-}"

command -v xcodegen >/dev/null || { echo "XcodeGen is required: brew install xcodegen" >&2; exit 1; }

xcodegen generate --quiet
rm -rf dist/Groovey.app
mkdir -p dist

if [[ "$mode" == "release" ]]; then
  # Pick the Developer ID Application certificate of this team by its hash, so a
  # certificate with a similar name from another team can never be chosen.
  identity=$(security find-identity -v -p codesigning \
    | awk -v team="($TEAM_ID)\"" '/"Developer ID Application: / && index($0, team) {print $2; exit}')
  if [[ -z "$identity" ]]; then
    echo "No 'Developer ID Application' certificate for team $TEAM_ID in the Keychain." >&2
    echo "Create it in Xcode: Settings > Accounts > (your account, team $TEAM_ID) > Manage Certificates > + > Developer ID Application." >&2
    exit 1
  fi

  rm -rf build/Groovey.xcarchive build/export
  xcodebuild -project Groovey.xcodeproj -scheme Groovey -configuration Release \
    -derivedDataPath build -destination "generic/platform=macOS" \
    -archivePath build/Groovey.xcarchive \
    ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
    DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_IDENTITY="$identity" \
    ENABLE_HARDENED_RUNTIME=YES OTHER_CODE_SIGN_FLAGS="--timestamp" \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    archive | tail -n 3

  # Exporting with the developer-id method re-signs Sparkle's helpers (Autoupdate,
  # Updater.app, XPC services) correctly for notarization.
  xcodebuild -exportArchive -archivePath build/Groovey.xcarchive \
    -exportPath build/export -exportOptionsPlist scripts/ExportOptions.plist | tail -n 3
  cp -R build/export/Groovey.app dist/Groovey.app

  codesign --verify --deep --strict dist/Groovey.app
  signed_team=$(codesign -dv dist/Groovey.app 2>&1 | sed -n 's/^TeamIdentifier=//p')
  [[ "$signed_team" == "$TEAM_ID" ]] || { echo "Signed with team '$signed_team', expected $TEAM_ID." >&2; exit 1; }
  echo "Built dist/Groovey.app (Developer ID, team $TEAM_ID)"
  exit 0
fi

xcodebuild -project Groovey.xcodeproj -scheme Groovey -configuration Release \
  -derivedDataPath build -destination "generic/platform=macOS" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO build | tail -n 3

cp -R build/Build/Products/Release/Groovey.app dist/Groovey.app
codesign --verify --deep --strict dist/Groovey.app
echo "Built dist/Groovey.app"

if [[ "$mode" == "install" ]]; then
  pkill -x Groovey 2>/dev/null || true
  rm -rf /Applications/Groovey.app
  cp -R dist/Groovey.app /Applications/Groovey.app
  open /Applications/Groovey.app
  echo "Installed to /Applications and launched"
fi
