import AppKit
import Foundation

// MARK: - SuperClip App Icon Generator
// Generates a multi-resolution macOS AppIcon (.icns) conforming to Apple flat design.
// Zero emojis permitted. SF Symbols compliant.

struct IconGenerator {
    let outputURL: URL

    // Standard macOS iconset specification for iconutil
    static let iconSpecs: [(name: String, pixelSize: Int)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024)
    ]

    func generate() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SuperClip_\(UUID().uuidString).iconset")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        print("Generating iconset bitmaps in \(tempDir.path)...")
        for spec in Self.iconSpecs {
            guard let pngData = renderIcon(pixelSize: spec.pixelSize) else {
                throw NSError(
                    domain: "IconGenerator",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to render \(spec.name)"]
                )
            }
            let fileURL = tempDir.appendingPathComponent(spec.name)
            try pngData.write(to: fileURL)
            print("  Created \(spec.name) (\(spec.pixelSize)x\(spec.pixelSize)px)")
        }

        let outputParent = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: outputParent, withIntermediateDirectories: true)

        print("Compiling iconset to ICNS: \(outputURL.path)...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        process.arguments = ["-c", "icns", "-o", outputURL.path, tempDir.path]

        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "IconGenerator",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "iconutil failed with code \(process.terminationStatus): \(errorString)"]
            )
        }

        print("Successfully generated icon: \(outputURL.path)")
    }

    private func renderIcon(pixelSize: Int) -> Data? {
        let size = NSSize(width: pixelSize, height: pixelSize)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelSize,
            pixelsHigh: pixelSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = context

        let fullRect = NSRect(origin: .zero, size: size)

        // Clear transparent canvas
        NSColor.clear.setFill()
        fullRect.fill()

        // macOS App Icon Squircle (standard ~82% dimension, ~22.4% corner radius)
        let margin = CGFloat(pixelSize) * 0.082
        let iconRect = fullRect.insetBy(dx: margin, dy: margin)
        let cornerRadius = iconRect.width * 0.224
        let baseClipPath = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)

        // Background Gradient: Modern Apple Blue (#1E70E8 -> #0C46B6)
        let gradient = NSGradient(
            colors: [
                NSColor(calibratedRed: 0.12, green: 0.44, blue: 0.91, alpha: 1.0),
                NSColor(calibratedRed: 0.05, green: 0.27, blue: 0.71, alpha: 1.0)
            ],
            atLocations: [0.0, 1.0],
            colorSpace: .deviceRGB
        )
        gradient?.draw(in: baseClipPath, angle: -90.0)

        // Crisp Border Highlight
        let highlightPath = NSBezierPath(
            roundedRect: iconRect.insetBy(dx: 0.75, dy: 0.75),
            xRadius: cornerRadius,
            yRadius: cornerRadius
        )
        highlightPath.lineWidth = max(1.0, CGFloat(pixelSize) * 0.012)
        NSColor(white: 1.0, alpha: 0.25).setStroke()
        highlightPath.stroke()

        // Center Symbol: doc.on.clipboard
        var drawnSymbol = false
        if let baseSymbol = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil) {
            let symbolPointSize = iconRect.height * 0.54
            let config = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .semibold)
                .applying(NSImage.SymbolConfiguration(paletteColors: [
                    NSColor.white,
                    NSColor(white: 1.0, alpha: 0.85)
                ]))
            let symbol = baseSymbol.withSymbolConfiguration(config) ?? baseSymbol
            let symbolSize = symbol.size
            let targetRect = NSRect(
                x: (size.width - symbolSize.width) / 2.0,
                y: (size.height - symbolSize.height) / 2.0,
                width: symbolSize.width,
                height: symbolSize.height
            )
            symbol.draw(in: targetRect, from: .zero, operation: .sourceOver, fraction: 1.0)
            drawnSymbol = true
        }

        // Vector Fallback if system symbol is unavailable in headless runtime
        if !drawnSymbol {
            drawFallbackClipboard(in: iconRect, pixelSize: pixelSize)
        }

        NSGraphicsContext.restoreGraphicsState()

        return rep.representation(using: .png, properties: [:])
    }

    private func drawFallbackClipboard(in rect: NSRect, pixelSize: Int) {
        let boardWidth = rect.width * 0.58
        let boardHeight = rect.height * 0.68
        let boardRect = NSRect(
            x: rect.midX - boardWidth / 2.0,
            y: rect.midY - boardHeight / 2.0 - rect.height * 0.02,
            width: boardWidth,
            height: boardHeight
        )
        let boardCorner = boardWidth * 0.08
        let boardPath = NSBezierPath(roundedRect: boardRect, xRadius: boardCorner, yRadius: boardCorner)
        NSColor(white: 0.95, alpha: 0.95).setFill()
        boardPath.fill()

        // Paper sheet
        let paperMargin = boardWidth * 0.08
        let paperRect = boardRect.insetBy(dx: paperMargin, dy: paperMargin)
        let paperPath = NSBezierPath(roundedRect: paperRect, xRadius: boardCorner * 0.5, yRadius: boardCorner * 0.5)
        NSColor.white.setFill()
        paperPath.fill()

        // Sheet content lines
        let lineWidth = paperRect.width * 0.65
        let lineHeight = max(1.0, CGFloat(pixelSize) * 0.015)
        let lineSpacing = paperRect.height * 0.12
        let lineStartX = paperRect.midX - lineWidth / 2.0
        let firstLineY = paperRect.midY + paperRect.height * 0.1

        NSColor(white: 0.75, alpha: 1.0).setFill()
        for i in 0..<3 {
            let y = firstLineY - CGFloat(i) * lineSpacing
            let lineRect = NSRect(x: lineStartX, y: y, width: lineWidth, height: lineHeight)
            lineRect.fill()
        }

        // Top Clip
        let clipWidth = boardWidth * 0.42
        let clipHeight = boardHeight * 0.14
        let clipRect = NSRect(
            x: rect.midX - clipWidth / 2.0,
            y: boardRect.maxY - clipHeight * 0.6,
            width: clipWidth,
            height: clipHeight
        )
        let clipPath = NSBezierPath(roundedRect: clipRect, xRadius: clipHeight * 0.3, yRadius: clipHeight * 0.3)
        NSColor(calibratedRed: 0.3, green: 0.3, blue: 0.35, alpha: 1.0).setFill()
        clipPath.fill()
    }
}

// MARK: - Entry Point
let arguments = CommandLine.arguments
let destinationPath: String
if arguments.count > 1 {
    destinationPath = arguments[1]
} else {
    destinationPath = "SuperClip.app/Contents/Resources/AppIcon.icns"
}

let generator = IconGenerator(outputURL: URL(fileURLWithPath: destinationPath))
do {
    try generator.generate()
    print("AppIcon generation completed successfully.")
} catch {
    fputs("Error generating AppIcon: \(error.localizedDescription)\n", stderr)
    exit(1)
}
