#!/usr/bin/env bash
#
# release-local.sh — cut a release of this fork from this Mac and publish it for Sparkle.
#
# Builds Release, stamps the build number (git commit count) and commit date, signs with
# a Developer ID Application identity when the keychain has one (otherwise the Apple
# Development identity xcodebuild used), notarizes and staples when a notarytool keychain
# profile named $NOTARY_PROFILE exists, zips the app, signs the zip with the Sparkle EdDSA
# key in the keychain, generates appcast.xml, tags the built commit build-<N>, pushes the
# tag, and creates the GitHub Release with the zip and appcast attached.
#
# The app reads its feed from the "latest release" asset URL
# (SUFeedURL in App/Info.plist), so publishing the release is the whole deployment.
#
# One-time setup for notarized releases (paid Apple Developer Program):
#   1. Xcode > Settings > Accounts > Manage Certificates > + > Developer ID Application
#   2. xcrun notarytool store-credentials ice-2-notary --apple-id <apple id> --team-id 7A6VQZ5YWT --password <app-specific password>
#
# Usage: bash scripts/release-local.sh
#        NOTARY_PROFILE=<profile> bash scripts/release-local.sh
set -euo pipefail

SCHEME="Ice"
CONFIG="Release"
APP_NAME="Ice 2"
REPO="bellicose100xp/ice-2"
NOTARY_PROFILE="${NOTARY_PROFILE:-ice-2-notary}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "error: commit or stash your changes first; releases build a committed tree" >&2
  exit 1
fi
if [[ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]]; then
  echo "error: release from main" >&2
  exit 1
fi

built_sha="$(git rev-parse HEAD)"
build_number="$(git rev-list --count HEAD)"
tag="build-$build_number"
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null || gh release view "$tag" --repo "$REPO" >/dev/null 2>&1; then
  echo "error: $tag already exists; commit something before releasing again" >&2
  exit 1
fi

derived="$repo_root/build"
log="$derived/release-local.log"
out="$derived/release"
rm -rf "$out"
mkdir -p "$out"

echo "==> Building $SCHEME ($CONFIG) at $(git rev-parse --short HEAD)…"
if ! xcodebuild -project Ice.xcodeproj -scheme "$SCHEME" -configuration "$CONFIG" -destination 'generic/platform=macOS' -derivedDataPath "$derived" -allowProvisioningUpdates build > "$log" 2>&1; then
  grep -E "error:|BUILD FAILED" "$log" | sort -u >&2
  echo "error: build failed, full log at $log" >&2
  exit 1
fi

app="$derived/Build/Products/$CONFIG/$APP_NAME.app"
plist="$app/Contents/Info.plist"
pb=/usr/libexec/PlistBuddy
sparkle_bin="$derived/SourcePackages/artifacts/sparkle/Sparkle/bin"

if [[ ! -d "$app" ]]; then
  echo "error: built app not found at: $app" >&2
  exit 1
fi
if [[ ! -x "$sparkle_bin/generate_appcast" ]]; then
  echo "error: Sparkle tools not found under $sparkle_bin" >&2
  exit 1
fi

short_version="$("$pb" -c "Print :CFBundleShortVersionString" "$plist")"
"$pb" -c "Set :CFBundleVersion $build_number" "$plist"
commit_date="$(git log -1 --format=%cI)"
"$pb" -c "Set :DragonCommitDate $commit_date" "$plist" 2>/dev/null || "$pb" -c "Add :DragonCommitDate string $commit_date" "$plist"

# Prefer Developer ID so Gatekeeper accepts fresh installs on other machines.
identity="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -n 1)"
notarize=true
if [[ -z "$identity" ]]; then
  identity="$(codesign -dvv "$app" 2>&1 | sed -n 's/^Authority=\(Apple Development.*\)$/\1/p' | head -n 1)"
  notarize=false
  echo "note: no Developer ID Application identity in the keychain; signing with the Apple Development identity."
  echo "      Fresh installs on another machine will need a one-time right-click > Open."
fi
if [[ -z "$identity" ]]; then
  echo "error: no usable signing identity" >&2
  exit 1
fi

echo "==> Signing with: $identity"
codesign --force --deep --options runtime --preserve-metadata=entitlements --sign "$identity" "$app"
codesign --verify --deep --strict "$app"

if $notarize && security find-generic-password -s com.apple.gke.notary.tool -a "$NOTARY_PROFILE" >/dev/null 2>&1; then
  echo "==> Notarizing with keychain profile $NOTARY_PROFILE…"
  ditto -c -k --keepParent "$app" "$out/notarize.zip"
  xcrun notarytool submit "$out/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$app"
  rm -f "$out/notarize.zip"
elif $notarize; then
  echo "note: no notarytool keychain profile named $NOTARY_PROFILE; skipping notarization."
fi

zip_name="Ice-2-$tag.zip"
echo "==> Packaging $zip_name"
ditto -c -k --keepParent "$app" "$out/$zip_name"

echo "==> Generating appcast (signed with the Sparkle key in the keychain)"
"$sparkle_bin/generate_appcast" --download-url-prefix "https://github.com/$REPO/releases/download/$tag/" -o "$out/appcast.xml" "$out"
grep -q "sparkle:edSignature" "$out/appcast.xml"

echo "==> Tagging $tag and publishing"
git tag "$tag" "$built_sha"
git push --quiet origin "$tag"
gh release create "$tag" "$out/$zip_name" "$out/appcast.xml" --repo "$REPO" --target "$built_sha" --title "$APP_NAME $short_version ($build_number)" --notes "Build $build_number of $short_version from $(git rev-parse --short "$built_sha")."

echo "Released $APP_NAME $short_version ($build_number) as $tag."
echo "Feed: https://github.com/$REPO/releases/latest/download/appcast.xml"
