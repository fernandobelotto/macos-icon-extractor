# macOS App Icon Extractor

Extracts application icons from all installed macOS applications and converts them to high-resolution PNG files (up to 1024x1024).

## Features

- Extracts icons from `/Applications`, `~/Applications`, and `/System/Applications`
- Handles both traditional `.icns` files and modern Asset Catalog (`.car`) icons
- Outputs PNG at the highest available resolution
- Progress logging with counts and summary
- Skips already-extracted icons on re-run

## Requirements

- macOS (tested on macOS 14+)
- Xcode Command Line Tools (for Swift compiler)

## Setup

1. Clone this repository
2. Compile the Swift helper:

```bash
swiftc extract-icon.swift -o extract-icon
```

## Usage

Run the script:

```bash
./extract-app-icons.sh
```

Icons will be saved to `./app_icons/` by default.

To specify a custom output directory:

```bash
./extract-app-icons.sh /path/to/output
```

## Output

```
╔═══════════════════════════════════════════════════════════════╗
║         macOS Application Icon Extractor                      ║
║         Converting .icns to high-resolution PNG               ║
╚═══════════════════════════════════════════════════════════════╝

[  1/238] [✓] Extracted: Slack.app → Slack.png (1024x1024)
[  2/238] [✓] Extracted: Rectangle.app → Rectangle.png (1024x1024) [Asset Catalog]
...

═══════════════════════════════════════════════════════════════
                         SUMMARY
═══════════════════════════════════════════════════════════════

  Total applications found:  238
  Successfully extracted:    235
  Skipped (already exist):   0
  Failed:                    3
```

## How It Works

1. **Primary method**: Reads `CFBundleIconFile` from each app's `Info.plist` and converts the `.icns` file using macOS's built-in `sips` tool

2. **Fallback method**: For apps using Asset Catalogs (common in modern apps), uses a Swift helper that leverages `NSWorkspace` to extract the icon

## Files

- `extract-app-icons.sh` - Main extraction script
- `extract-icon.swift` - Swift helper for Asset Catalog icons
- `extract-icon` - Compiled Swift binary (generated)
