# SVG Ops

SVG Ops is a native macOS utility for converting flat raster illustrations into clean SVG files.

It is built for quick personal workflows: drop an image, choose a simple conversion mode, preview the SVG, then copy or save the result. Everything runs locally on your Mac. There is no cloud service, no account system, no backend, no analytics, and no AI in the conversion pipeline.

## What It Does

- Converts PNG, JPG, JPEG, and WEBP images to SVG.
- Works best with flat illustrations, icons, line art, single-colour artwork, and simple 2-3 colour graphics.
- Supports Line Art, Single Colour, 2 Colours, and 3 Colours modes.
- Supports Clean, Balanced, and Accurate quality presets.
- Supports `currentColor`, original foreground colour, and custom fill colour for Potrace-based modes.
- Shows a local SVG preview inside the native macOS app.
- Copies raw SVG code to the clipboard.
- Saves SVG files manually or next to the source image.
- Remembers the last used conversion settings.

## What It Does Not Do

- It is not a full image editor.
- It is not a general photo-to-SVG converter.
- It is not intended for realistic photos, shadows, gradients, highly detailed renders, or complex artwork.
- It does not upload files anywhere.
- It does not use AI.

## Tech Stack

- Swift Package Manager
- SwiftUI for the macOS interface
- AppKit bridging for native file panels, clipboard, alerts, and window behavior
- WKWebView only for local SVG preview rendering
- Potrace for line art and single-colour tracing
- VTracer for 2-colour and 3-colour flat illustration tracing
- Native Swift SVG cleanup, validation, crop safety checks, and export smoke tests

## Requirements

- macOS 13 or later
- Swift 6 toolchain
- Potrace for Line Art and Single Colour modes
- VTracer for 2 Colours and 3 Colours modes

During development, SVG Ops resolves vectorization binaries in this order:

1. Bundled app resources under `Resources/Binaries`
2. Homebrew fallback paths such as `/opt/homebrew/bin/potrace` and `/opt/homebrew/bin/vtracer`

If a required binary is missing, the app keeps running and shows a clear error when that conversion mode needs it.

## Development

Build the package:

```sh
swift build
```

Run the self-tests:

```sh
Scripts/test.sh
```

Create a launchable macOS app bundle:

```sh
Scripts/package-app.sh
```

The package script writes:

```txt
SVG Ops.app
```

## Project Layout

```txt
Sources/SVGOpsApp       App entry point
Sources/SVGOpsCore/App  Main app state and view model
Sources/SVGOpsCore/UI   SwiftUI views
Sources/SVGOpsCore/Domain
                         Conversion settings, preferences, result models
Sources/SVGOpsCore/Conversion
                         Potrace, VTracer, raster preparation, binary resolution
Sources/SVGOpsCore/SVG  SVG document model, optimizer, validation, bounds, stats
Sources/SVGOpsCore/Platform
                         AppKit-backed platform services
Sources/SVGOpsCore/Support
                         Process runner, image analysis, temporary files
Sources/SVGOpsSelfTests Self-test executable and golden corpus checks
Tests/Fixtures          Golden test manifests and future image fixtures
```

## Golden Corpus

SVG Ops includes a small manifest-driven golden corpus under:

```txt
Tests/Fixtures/GoldenImages/manifest.json
```

The corpus validates that generated SVGs are non-empty, modernized, reasonably sized, not over-cropped, and internally consistent. New real-world fixtures can be added to the manifest without changing the test runner.

## Privacy

SVG Ops is local-first by design. Source images and generated SVGs stay on the Mac. The app has no backend and does not perform network uploads.

## Licensing

The SVG Ops source code is released under the MIT License.

Bundled or separately installed vectorization binaries are third-party tools and retain their own upstream licenses. Check those licenses before redistributing a packaged app that includes third-party binaries.

Designed and developed by yaba.studio, 2026.
