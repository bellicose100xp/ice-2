#!/usr/bin/env bash
#
# install-local.sh — build the Release product and install it as /Applications/Ice 2.app.
#
# The installed app is this fork's own build, signed with the developer team in the
# project. It replaces the public release, so the script removes the Sparkle feed and
# disables automatic update checks: otherwise the next public release would offer to
# replace this build. Upstream changes arrive through `git merge upstream/main` instead.
#
# Usage: bash scripts/install-local.sh
set -euo pipefail

SCHEME="Ice"
CONFIG="Release"
APP_NAME="Ice 2"
INSTALL_DIR="/Applications"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

derived="$repo_root/build"
log="$derived/install-local.log"
mkdir -p "$derived"

echo "==> Building $SCHEME ($CONFIG)…"
if ! xcodebuild -project Ice.xcodeproj -scheme "$SCHEME" -configuration "$CONFIG" -destination 'generic/platform=macOS' -derivedDataPath "$derived" -allowProvisioningUpdates build > "$log" 2>&1; then
  grep -E "error:|BUILD FAILED" "$log" | sort -u >&2
  echo "error: build failed, full log at $log" >&2
  exit 1
fi

app="$derived/Build/Products/$CONFIG/$APP_NAME.app"
plist="$app/Contents/Info.plist"
pb=/usr/libexec/PlistBuddy

if [[ ! -d "$app" ]]; then
  echo "error: built app not found at: $app" >&2
  exit 1
fi

# The identity xcodebuild signed with; re-signing below must use the same one so the
# TCC grants for Accessibility and Screen Recording survive rebuilds.
identity="$(codesign -dvv "$app" 2>&1 | sed -n 's/^Authority=\(Apple Development.*\)$/\1/p' | head -n 1)"
if [[ -z "$identity" ]]; then
  echo "error: built app is not signed with an Apple Development identity" >&2
  exit 1
fi

build_number="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
"$pb" -c "Set :CFBundleVersion $build_number" "$plist"
if "$pb" -c "Print :SUEnableAutomaticChecks" "$plist" >/dev/null 2>&1; then
  "$pb" -c "Set :SUEnableAutomaticChecks false" "$plist"
else
  "$pb" -c "Add :SUEnableAutomaticChecks bool false" "$plist"
fi
"$pb" -c "Delete :SUFeedURL" "$plist" 2>/dev/null || true

echo "==> Re-signing with: $identity"
codesign --force --deep --preserve-metadata=entitlements,flags,runtime --sign "$identity" "$app"
codesign --verify --deep --strict "$app"

echo "==> Installing to $INSTALL_DIR/$APP_NAME.app"
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 1
rm -rf "$INSTALL_DIR/$APP_NAME.app"
ditto "$app" "$INSTALL_DIR/$APP_NAME.app"
open "$INSTALL_DIR/$APP_NAME.app"

short_version="$("$pb" -c "Print :CFBundleShortVersionString" "$plist")"
echo "Installed $APP_NAME v$short_version (build $build_number) from $(git rev-parse --short HEAD)."
