#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="$PWD/dist/QR Studio.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" .build/module-cache
swiftc Sources/main.swift -o "$APP/Contents/MacOS/QRStudio" -framework AppKit -framework CoreImage -framework UniformTypeIdentifiers -module-cache-path "$PWD/.build/module-cache" -O -target arm64-apple-macosx12.0
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>QRStudio</string>
<key>CFBundleIdentifier</key><string>local.homelab.qrstudio.menubar</string>
<key>CFBundleName</key><string>QR Studio</string>
<key>CFBundleDisplayName</key><string>QR Studio</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>12.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
"$APP/Contents/MacOS/QRStudio" --self-test
printf 'Built: %s\n' "$APP"
