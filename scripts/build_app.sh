#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$DIR/build"
APP_DIR="$BUILD_DIR/EasyTab.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🔨 Compiling EasyTab..."
mkdir -p "$BUILD_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

swiftc -O \
    "$DIR/Sources/EasyTab/Core/Models/WindowItem.swift" \
    "$DIR/Sources/EasyTab/Core/Protocols/WindowProvider.swift" \
    "$DIR/Sources/EasyTab/Core/StateMachine/SwitcherEngine.swift" \
    "$DIR/Sources/EasyTab/Platform/Permissions/PermissionsManager.swift" \
    "$DIR/Sources/EasyTab/Platform/LoginService/LoginItemManager.swift" \
    "$DIR/Sources/EasyTab/Platform/Accessibility/SystemWindowProvider.swift" \
    "$DIR/Sources/EasyTab/Platform/Accessibility/WindowFocusManager.swift" \
    "$DIR/Sources/EasyTab/Platform/EventTap/EventTapInterceptor.swift" \
    "$DIR/Sources/EasyTab/UI/Views/AppKitSwitcherView.swift" \
    "$DIR/Sources/EasyTab/UI/Panel/SwitcherHUDPanel.swift" \
    "$DIR/Sources/EasyTab/UI/MenuBar/MenuBarController.swift" \
    "$DIR/Sources/EasyTab/App/AppDelegate.swift" \
    "$DIR/Sources/EasyTab/App/main.swift" \
    -o "$MACOS_DIR/EasyTab"

if [ -f "$DIR/Sources/EasyTab/Resources/AppIcon.icns" ]; then
    echo "🎨 Copying AppIcon.icns..."
    cp "$DIR/Sources/EasyTab/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

echo "📝 Creating Info.plist..."
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.open.easytab</string>
    <key>CFBundleName</key>
    <string>EasyTab</string>
    <key>CFBundleDisplayName</key>
    <string>EasyTab</string>
    <key>CFBundleExecutable</key>
    <string>EasyTab</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.0</string>
    <key>CFBundleVersion</key>
    <string>3</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

echo "🔏 Ad-hoc code signing EasyTab.app with stable designated identifier..."
codesign -s - --force --deep -r='designated => identifier "com.open.easytab"' "$APP_DIR"

echo "✅ Successfully built: $APP_DIR"
echo "👉 You can launch it by running: open $APP_DIR"
