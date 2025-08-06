#!/bin/bash

# Net Speed Monitor - Create DMG Distribution Package
# This script creates a .dmg file for distribution

APP_NAME="NetSpeedMonitor"
VERSION="1.0.0"
BUILD_DIR="/Users/bishwajit/Library/Developer/Xcode/DerivedData/NetSpeedMonitor-*/Build/Products/Debug"
DMG_NAME="${APP_NAME}-${VERSION}"
VOLUME_NAME="Net Speed Monitor"

# Create a temporary directory for DMG contents
TEMP_DMG_DIR="/tmp/${APP_NAME}_dmg"
rm -rf "$TEMP_DMG_DIR"
mkdir -p "$TEMP_DMG_DIR"

# Copy the app to the temporary directory
cp -R "$BUILD_DIR/${APP_NAME}.app" "$TEMP_DMG_DIR/"

# Create Applications folder symlink
ln -s /Applications "$TEMP_DMG_DIR/Applications"

# Create a simple README
cat > "$TEMP_DMG_DIR/README.txt" << EOF
Net Speed Monitor v${VERSION}
==========================

Installation:
1. Drag NetSpeedMonitor.app to the Applications folder
2. Launch the app from Applications
3. The app will appear in your menu bar

Features:
- Real-time network speed monitoring in menu bar
- Detailed popup with per-app bandwidth usage
- Network interface information and ping stats
- Configurable settings and notifications
- Launch at login support

Requirements:
- macOS Sequoia (15.0) or later
- Universal binary (Intel + Apple Silicon)

For support and updates:
https://github.com/frolax/net-speed-monitor

© 2024 Frolax. All rights reserved.
EOF

# Create the DMG
DMG_PATH="/Users/bishwajit/Frolax/net-speed-monitor/${DMG_NAME}.dmg"
rm -f "$DMG_PATH"

hdiutil create -volname "$VOLUME_NAME" \
    -srcfolder "$TEMP_DMG_DIR" \
    -ov -format UDZO \
    "$DMG_PATH"

# Clean up
rm -rf "$TEMP_DMG_DIR"

echo "✅ DMG created successfully: $DMG_PATH"
echo "📦 Distribution package ready for deployment!"