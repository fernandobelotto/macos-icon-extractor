#!/usr/bin/env swift

import Cocoa

// Get command line arguments
let args = CommandLine.arguments
guard args.count == 3 else {
    fputs("Usage: extract-icon <app-path> <output-png-path>\n", stderr)
    exit(1)
}

let appPath = args[1]
let outputPath = args[2]

// Get the app icon using NSWorkspace
let workspace = NSWorkspace.shared
let icon = workspace.icon(forFile: appPath)

// Request the largest size
icon.size = NSSize(width: 1024, height: 1024)

// Get the best representation
guard let tiffData = icon.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Error: Failed to convert icon to PNG\n", stderr)
    exit(1)
}

// Write to file
do {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
    print("OK")
} catch {
    fputs("Error: Failed to write file: \(error.localizedDescription)\n", stderr)
    exit(1)
}
