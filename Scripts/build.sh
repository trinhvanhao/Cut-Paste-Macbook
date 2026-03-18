#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="CutPaste"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
VERSION="1.0.0"

SWIFT_SOURCES=(
    "$PROJECT_DIR/Sources/main.swift"
    "$PROJECT_DIR/Sources/StatusBarController.swift"
    "$PROJECT_DIR/Sources/EventTapManager.swift"
    "$PROJECT_DIR/Sources/FinderBridge.swift"
    "$PROJECT_DIR/Sources/FileMover.swift"
    "$PROJECT_DIR/Sources/LoginItemManager.swift"
)

SWIFT_FLAGS=(
    -O
    -framework Cocoa
    -framework ServiceManagement
)

echo "=== Building $APP_NAME v$VERSION ==="

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build Universal Binary (Apple Silicon + Intel)
echo "Compiling for arm64..."
swiftc "${SWIFT_FLAGS[@]}" -target arm64-apple-macos13.0 \
    -o "$BUILD_DIR/${APP_NAME}_arm64" "${SWIFT_SOURCES[@]}"

echo "Compiling for x86_64..."
swiftc "${SWIFT_FLAGS[@]}" -target x86_64-apple-macos13.0 \
    -o "$BUILD_DIR/${APP_NAME}_x86_64" "${SWIFT_SOURCES[@]}"

echo "Creating Universal Binary..."
lipo -create \
    "$BUILD_DIR/${APP_NAME}_arm64" \
    "$BUILD_DIR/${APP_NAME}_x86_64" \
    -output "$BUILD_DIR/$APP_NAME"

rm "$BUILD_DIR/${APP_NAME}_arm64" "$BUILD_DIR/${APP_NAME}_x86_64"

echo "Compilation successful!"

# Create .app bundle
echo "Creating app bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"

# Remove standalone binary
rm "$BUILD_DIR/$APP_NAME"

echo "Signing app bundle..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "App bundle created at: $APP_BUNDLE"

# Create DMG installer
echo ""
echo "Creating DMG installer..."
DMG_DIR="$BUILD_DIR/dmg_staging"
DMG_PATH="$BUILD_DIR/CutPaste-${VERSION}.dmg"

mkdir -p "$DMG_DIR"
cp -r "$APP_BUNDLE" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

hdiutil create -volname "CutPaste" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "$DMG_PATH" 2>/dev/null

rm -rf "$DMG_DIR"

echo ""
echo "=== Build complete! ==="
echo ""
echo "  App:  $APP_BUNDLE"
echo "  DMG:  $DMG_PATH"
echo ""
echo "To install:"
echo "  cp -r \"$APP_BUNDLE\" /Applications/"
echo ""
echo "NOTE: Grant Accessibility permission in:"
echo "  System Settings → Privacy & Security → Accessibility"
