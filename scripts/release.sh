#!/bin/bash
# Cuts a release: builds and signs with Developer ID, packages, notarizes and staples the
# DMG, signs the update for Sparkle, updates appcast.xml, then tags and publishes a
# GitHub release.
#
# Usage: scripts/release.sh <version>      e.g. scripts/release.sh 0.3.0
#
# Needs, once per Mac, in the maintainer's login Keychain:
#   - the Sparkle private key (created once with Sparkle's generate_keys); only someone
#     holding it can publish updates.
#   - a "Developer ID Application" certificate for team 864N8V85P8.
#   - notarytool credentials saved under the profile name below:
#       xcrun notarytool store-credentials groovey-notary --apple-id <apple-id> --team-id 864N8V85P8
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:?usage: scripts/release.sh <version>}"
repo="ozturkbasrii/groovey"
notary_profile="groovey-notary"
build_number=$(git rev-list --count HEAD)

[[ -z "$(git status --porcelain)" ]] || { echo "Commit or stash your changes first." >&2; exit 1; }
xcrun notarytool history --keychain-profile "$notary_profile" >/dev/null || {
  echo "notarytool profile '$notary_profile' is missing or invalid. Create it with:" >&2
  echo "  xcrun notarytool store-credentials $notary_profile --apple-id <apple-id> --team-id 864N8V85P8" >&2
  exit 1
}

# Stamp the version.
sed -i '' -E "s/(MARKETING_VERSION: )\"[^\"]*\"/\1\"$version\"/; s/(CURRENT_PROJECT_VERSION: )\"[^\"]*\"/\1\"$build_number\"/" project.yml

scripts/build.sh release
dmg=$(scripts/make-dmg.sh | tail -n 1)

# Sign, notarize and staple the DMG so Gatekeeper opens it without warnings.
# Sparkle's signature below must be computed after this, on the final bytes.
identity=$(codesign -dvv dist/Groovey.app 2>&1 | sed -n 's/^Authority=//p' | head -n 1)
codesign --force --timestamp --sign "$identity" "$dmg"
xcrun notarytool submit "$dmg" --keychain-profile "$notary_profile" --wait
xcrun stapler staple "$dmg"
spctl --assess --type open --context context:primary-signature -vv "$dmg"

sign_update=$(find build/SourcePackages/artifacts -name sign_update -type f | head -n 1)
[[ -x "$sign_update" ]] || { echo "Sparkle's sign_update tool was not found under build/SourcePackages." >&2; exit 1; }
signature=$("$sign_update" --account groovey "$dmg")   # prints: sparkle:edSignature="..." length="..."

cat > appcast.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Groovey</title>
    <link>https://github.com/$repo</link>
    <item>
      <title>Groovey $version</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$build_number</sparkle:version>
      <sparkle:shortVersionString>$version</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>https://github.com/$repo/releases/tag/v$version</sparkle:releaseNotesLink>
      <enclosure url="https://github.com/$repo/releases/download/v$version/$(basename "$dmg")" type="application/octet-stream" $signature />
    </item>
  </channel>
</rss>
EOF

git add project.yml appcast.xml
git commit -m "Release $version"
git tag "v$version"
git push origin HEAD "v$version"
gh release create "v$version" "$dmg" --repo "$repo" --title "Groovey $version" --generate-notes
echo "Released v$version"
