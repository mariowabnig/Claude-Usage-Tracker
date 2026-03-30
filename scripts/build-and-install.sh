#!/bin/bash
# Build the custom fork and install to /Applications.
# Must rm first to bust macOS app cache.

set -e

cd "$(dirname "$0")/.."

echo "Building..."
xcodebuild -project "Claude Usage.xcodeproj" \
  -scheme "Claude Usage" \
  -configuration Debug \
  build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "error:|BUILD"

echo "Installing to /Applications..."
killall "Claude Usage" 2>/dev/null || true
sleep 1

rm -rf "/Applications/Claude Usage.app"

DERIVED=$(find ~/Library/Developer/Xcode/DerivedData/Claude_Usage-*/Build/Products/Debug -name "Claude Usage.app" -maxdepth 1 2>/dev/null | head -1)

if [ -z "$DERIVED" ]; then
  echo "ERROR: Built app not found in DerivedData"
  exit 1
fi

cp -R "$DERIVED" "/Applications/Claude Usage.app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/Claude Usage.app"

echo "Launching..."
open "/Applications/Claude Usage.app"
echo "Done."
