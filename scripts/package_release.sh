#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$DIR/build"
APP_DIR="$BUILD_DIR/EasyTab.app"
DIST_DIR="$BUILD_DIR/dist"

# Ensure EasyTab.app is built
if [ ! -d "$APP_DIR" ]; then
    echo "📦 Building EasyTab.app first..."
    "$DIR/scripts/build_app.sh"
fi

echo "📦 Packaging EasyTab for Release..."
mkdir -p "$DIST_DIR"
rm -rf "$DIST_DIR/*"

# 1. Package ZIP
echo "🗜️ Creating EasyTab.zip..."
(cd "$BUILD_DIR" && zip -q -r "$DIST_DIR/EasyTab.zip" "EasyTab.app")

# 2. Package DMG (Standard macOS Drag-to-Applications installer)
echo "💿 Creating EasyTab.dmg..."
DMG_STAGING="$BUILD_DIR/dmg_staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"

cp -R "$APP_DIR" "$DMG_STAGING/EasyTab.app"
ln -s /Applications "$DMG_STAGING/Applications"

# Create compressed read-only DMG
hdiutil create \
    -volname "EasyTab" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$DIST_DIR/EasyTab.dmg"

rm -rf "$DMG_STAGING"

# 3. Compute SHA256 checksums
echo "🔐 Computing Checksums..."
(cd "$DIST_DIR" && shasum -a 256 EasyTab.dmg EasyTab.zip > checksums.txt)

cat "$DIST_DIR/checksums.txt"

DMG_SHA=$(shasum -a 256 "$DIST_DIR/EasyTab.dmg" | awk '{print $1}')
ZIP_SHA=$(shasum -a 256 "$DIST_DIR/EasyTab.zip" | awk '{print $1}')

echo ""
echo "🎉 Packaging Complete!"
echo "📍 Artifacts:"
echo "   - DMG: $DIST_DIR/EasyTab.dmg"
echo "   - ZIP: $DIST_DIR/EasyTab.zip"
echo ""
echo "🍺 Homebrew Cask SHA256:"
echo "   sha256 \"$ZIP_SHA\""
