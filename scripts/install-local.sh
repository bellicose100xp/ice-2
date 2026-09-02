#!/usr/bin/env bash
#
# install-local.sh — build the Release product and install it as /Applications/Ice 2.app.
#
# The installed app is this fork's own build, signed with the developer team in the
# project. Its Sparkle feed (SUFeedURL in App/Info.plist) points at this fork's GitHub
# releases, so it updates from `scripts/release-local.sh` output, never from the public
# Ice 2 release. Upstream changes arrive through `git merge upstream/main`.
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

# Same stamping as release-local.sh, so Sparkle compares like with like.
build_number="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
"$pb" -c "Set :CFBundleVersion $build_number" "$plist"
commit_date="$(git log -1 --format=%cI 2>/dev/null || true)"
if [[ -n "$commit_date" ]]; then
  "$pb" -c "Set :DragonCommitDate $commit_date" "$plist" 2>/dev/null || "$pb" -c "Add :DragonCommitDate string $commit_date" "$plist"
fi

echo "==> Re-signing with: $identity"
codesign --force --deep --preserve-metadata=entitlements,flags,runtime --sign "$identity" "$app"
codesign --verify --deep --strict "$app"

short_version="$("$pb" -c "Print :CFBundleShortVersionString" "$plist")"

echo "==> Installing to $INSTALL_DIR/$APP_NAME.app"
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 1
rm -rf "$INSTALL_DIR/$APP_NAME.app"
ditto "$app" "$INSTALL_DIR/$APP_NAME.app"

# Remove the build product so only the installed copy claims the bundle id. Two
# bundles with one id make Launch Services resolve it ambiguously, and it can then
# launch the stale build. xcodebuild recreates the product on the next run.
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"$lsregister" -u "$app" >/dev/null 2>&1 || true
rm -rf "$app" "$derived/Build/Products/$CONFIG/MenuBarItemService.xpc"
"$lsregister" -f "$INSTALL_DIR/$APP_NAME.app" >/dev/null 2>&1 || true

open "$INSTALL_DIR/$APP_NAME.app"

echo "Installed $APP_NAME v$short_version (build $build_number) from $(git rev-parse --short HEAD)."
