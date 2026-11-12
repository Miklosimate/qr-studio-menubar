#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
ARCH="${ARCH:-$(uname -m)}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "VERSION must be a numeric version such as 1.2.3" >&2; exit 1
fi
if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "BUILD_NUMBER must be numeric" >&2; exit 1
fi
case "$ARCH" in arm64|x86_64) ;; *) echo "Unsupported ARCH: $ARCH" >&2; exit 1 ;; esac
APP="${OUTPUT_DIR:-$PWD/dist}/QR Studio.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" .build/module-cache
swiftc Sources/main.swift -o "$APP/Contents/MacOS/QRStudio" -framework AppKit -framework CoreImage -framework UniformTypeIdentifiers -module-cache-path "$PWD/.build/module-cache" -O -target "$ARCH-apple-macosx12.0"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>QRStudio</string>
<key>CFBundleIdentifier</key><string>local.homelab.qrstudio.menubar</string>
<key>CFBundleName</key><string>QR Studio</string>
<key>CFBundleDisplayName</key><string>QR Studio</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
<key>LSMinimumSystemVersion</key><string>12.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
"$APP/Contents/MacOS/QRStudio" --self-test
printf 'Built: %s\n' "$APP"
