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

Requires Apple Command Line Tools with Swift. Local builds target the current Mac’s architecture and require macOS 12 or later. GitHub Releases provide both Apple Silicon and Intel builds.

```sh
cd /Users/miklosimate/Documents/ChatGPT/HomeLab/qr-studio-menubar
./build.sh
```

Builds and ad-hoc signs the app, then runs QR decoding, transparent vector structure, quiet-zone, color, and URL-validation checks. It is a local build, not a Developer ID notarized distribution.

## Automated GitHub releases

The workflow in `.github/workflows/release.yml` builds and tests on both Apple Silicon and Intel macOS runners. A version tag such as `v1.0.1` publishes a GitHub Release with separate architecture DMG and ZIP downloads with SHA-256 checksums. The app's version comes from the tag; its build number comes from the Actions run number. No secrets or Apple Developer membership are required for these ad-hoc signed releases. They are **not notarized**, so downloaded copies may be blocked by Gatekeeper.

After committing and pushing your changes, release a version:

```sh
git tag -a v1.0.1 -m "Release 1.0.1"
git push origin v1.0.1
```

Use a new `vMAJOR.MINOR.PATCH` tag each time. Do not move or reuse published tags. The release appears only after both builds and their QR self-tests pass. Interrupted or empty releases can be completed with the manual recovery option; existing download assets are never overwritten.

For a build without publishing, choose **Actions → Build and release macOS app → Run workflow**. Download the build artifacts from the workflow run. Pull requests touching the app or workflow also run both builds. Manual builds without a release tag and pull-request builds use version `0.0.0`. To recover an existing release, run the workflow from the default branch and enter its tag (for example `v1.0.1`) in **release_tag**. This builds the source at that tag and attaches missing assets to its release.

Downloads: https://github.com/Miklosimate/qr-studio-menubar/releases/latest

The repository must have GitHub Actions enabled and permit the workflow's `contents: write` permission for its release job. Publishing uses the built-in `GITHUB_TOKEN`; no personal access token is needed.

For a local versioned build, run `VERSION=1.0.1 BUILD_NUMBER=2 ./build.sh`. It targets your current Mac's architecture by default. `ARCH=arm64` or `ARCH=x86_64` can override the target, but the resulting self-test must be runnable on the build host. `OUTPUT_DIR` overrides the default `dist` directory.

### Finding release downloads

A green build does not necessarily publish a release: a manual run with an empty `release_tag` only creates Actions artifacts. To publish or repair `v1.0.1`, choose **Run workflow**, select the updated default branch (not the old `v1.0.1` tag), and enter `v1.0.1` in **release_tag**. Start a new run; rerunning an old run uses its old workflow. Once **Publish GitHub Release** succeeds, the release page’s **Assets** section contains Apple Silicon and Intel `.dmg`, `.zip`, and checksum files.

Each DMG contains QR Studio.app and an Applications shortcut. Open the DMG and drag the app to Applications. DMG packaging does not add Apple notarization.
