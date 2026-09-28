#!/bin/bash
# Build and launch the app in the iOS Simulator from Terminal (macOS + Xcode 16).
#   ./tools/run-simulator.sh                 # uses "iPhone 16"
#   ./tools/run-simulator.sh "iPhone 16 Pro" # any simulator name from: xcrun simctl list devices available
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT="KiribatiBudgetTransparency.xcodeproj"
TARGET="KiribatiBudgetTransparency"
DEVICE="${1:-iPhone 16}"
BUILD_DIR="$PWD/build"

echo "▸ Building $TARGET for the simulator…"
# Simulator builds need no signing team, so signing is switched off here.
xcodebuild -project "$PROJECT" -target "$TARGET" -configuration Debug -sdk iphonesimulator \
  SYMROOT="$BUILD_DIR" CODE_SIGNING_ALLOWED=NO -quiet build

APP=$(find "$BUILD_DIR/Debug-iphonesimulator" -maxdepth 1 -name "*.app" | head -1)
[ -n "$APP" ] || { echo "Build produced no .app"; exit 1; }
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP/Info.plist")

echo "▸ Starting simulator: $DEVICE"
open -a Simulator
xcrun simctl boot "$DEVICE" 2>/dev/null || true   # already booted is fine
xcrun simctl bootstatus "$DEVICE" -b >/dev/null

echo "▸ Installing and launching $BUNDLE_ID"
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch "$DEVICE" "$BUNDLE_ID"
echo "✓ Running. Rebuild and relaunch by running this script again."
