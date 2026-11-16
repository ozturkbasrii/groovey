#!/bin/bash
# Cuts a release: builds, packages, signs the update for Sparkle, updates appcast.xml,
# then tags and publishes a GitHub release.
#
# Usage: scripts/release.sh <version>      e.g. scripts/release.sh 0.2.0
#
# The Sparkle private key lives in the maintainer's login Keychain (created once with
# Sparkle's generate_keys); only someone holding it can publish updates.
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:?usage: scripts/release.sh <version>}"
repo="ozturkbasrii/groovey"
build_number=$(git rev-list --count HEAD)

[[ -z "$(git status --porcelain)" ]] || { echo "Commit or stash your changes first." >&2; exit 1; }

# Stamp the version.
sed -i '' -E "s/(MARKETING_VERSION: )\"[^\"]*\"/\1\"$version\"/; s/(CURRENT_PROJECT_VERSION: )\"[^\"]*\"/\1\"$build_number\"/" project.yml

scripts/build.sh
dmg=$(scripts/make-dmg.sh | tail -n 1)

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
