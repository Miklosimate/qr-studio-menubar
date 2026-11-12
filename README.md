# QR Studio — macOS menu bar app

Standalone native Swift/AppKit app. No Node.js, browser, server, network, or third-party dependencies at runtime. Separate from `../qr-studio`.

## Run

Double-click `dist/QR Studio.app`, or:

```sh
open "/Users/miklosimate/Documents/ChatGPT/HomeLab/qr-studio-menubar/dist/QR Studio.app"
```

Drag a browser link or selected URL text onto the panel to generate a QR code immediately. Drag the generated QR preview to Finder, Desktop, or an application accepting SVG files to export the same transparent vector SVG. Drag export uses a temporary SVG file and supports copy operations; the destination app determines whether SVG drops are accepted. The Download SVG button remains available.

A QR icon appears in the macOS menu bar. Click it to show/hide the panel. Paste a complete HTTP/HTTPS link, choose a color using the native picker or hex field, click Generate, then Download SVG to choose a destination. The panel stays open while you use the color picker or Save dialog. Quit is at the bottom of the panel. No Dock icon is shown.

You can copy the app to Applications if desired. To run at login, add it in System Settings → General → Login Items. This project does not change your login settings.

## Export

SVG contains only vector paths for foreground modules, with no background or embedded bitmap. The checkerboard is a preview aid only. Four-module transparent quiet zone, medium error correction, and a 2,000-byte link limit. Keep the quiet zone clear, choose a foreground with good contrast against the final background, and test before publishing.

## Build and test

Requires Apple Command Line Tools with Swift. The included build targets Apple Silicon Macs running macOS 12 or later.

```sh
cd /Users/miklosimate/Documents/ChatGPT/HomeLab/qr-studio-menubar
./build.sh
```

Builds and ad-hoc signs the app, then runs QR decoding, transparent vector structure, quiet-zone, color, and URL-validation checks. It is a local build, not a Developer ID notarized distribution.
