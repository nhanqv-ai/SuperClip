import AppKit
import Foundation

// MARK: - SuperClip App Icon Generator
// Generates a vibrant, multi-resolution macOS AppIcon (.icns) conforming to macOS design standards.
// Features a dynamic Sapphire Blue -> Neon Violet -> Cyan gradient, glassmorphic depth, and crisp clipboard geometry.
// Strictly 0 emojis permitted. SF Symbols compliant.

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

        // macOS App Icon Squircle geometry
        // Margin: 8.2% of canvas, corner radius: ~22.4% of icon dimension
        let margin = CGFloat(pixelSize) * 0.082
        let iconRect = fullRect.insetBy(dx: margin, dy: margin)
        let cornerRadius = iconRect.width * 0.224

        // 1. Ambient Drop Shadow underneath the Squircle
        if pixelSize >= 32 {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.35, alpha: 0.38)
            shadow.shadowBlurRadius = CGFloat(pixelSize) * 0.06
            shadow.shadowOffset = NSSize(width: 0, height: -CGFloat(pixelSize) * 0.025)
            shadow.set()

            let shadowPath = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)
            NSColor(calibratedRed: 0.1, green: 0.2, blue: 0.5, alpha: 0.2).setFill()
            shadowPath.fill()

            // Reset shadow
            NSShadow().set()
        }

        // 2. Base Squircle Shape
        let baseClipPath = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)

        NSGraphicsContext.saveGraphicsState()
        baseClipPath.addClip()

        // 3. Vibrant Modern macOS Gradient:
        // Top-left: Vibrant Cyan / Sky Blue (#00D2FF)
        // Mid-point: Royal Sapphire Blue (#2563EB)
        // Bottom-right: Neon Violet / Deep Purple (#7C3AED -> #4C1D95)
        let backgroundGradient = NSGradient(
            colors: [
                NSColor(calibratedRed: 0.0, green: 0.82, blue: 1.0, alpha: 1.0),      // Cyan #00D2FF
                NSColor(calibratedRed: 0.14, green: 0.38, blue: 0.94, alpha: 1.0),    // Royal Sapphire #2563EB
                NSColor(calibratedRed: 0.45, green: 0.18, blue: 0.88, alpha: 1.0),    // Neon Violet #732EE0
                NSColor(calibratedRed: 0.28, green: 0.10, blue: 0.58, alpha: 1.0)     // Deep Purple #471994
            ],
            atLocations: [0.0, 0.40, 0.80, 1.0],
            colorSpace: .deviceRGB
        )
        backgroundGradient?.draw(in: iconRect, angle: -45.0)

        // 4. Subtle Top Radial Specular Sheen (Glassmorphism highlight)
        let sheenCenter = NSPoint(x: iconRect.midX, y: iconRect.maxY)
        let sheenGradient = NSGradient(
            colors: [
                NSColor(white: 1.0, alpha: 0.32),
                NSColor(white: 1.0, alpha: 0.08),
                NSColor(white: 1.0, alpha: 0.0)
            ],
            atLocations: [0.0, 0.45, 1.0],
            colorSpace: .deviceRGB
        )
        sheenGradient?.draw(
            fromCenter: sheenCenter,
            radius: 0.0,
            toCenter: sheenCenter,
            radius: iconRect.width * 0.75,
            options: []
        )

        NSGraphicsContext.restoreGraphicsState()

        // 5. Crisp Outer Glass Rim Highlight
        let rimPath = NSBezierPath(
            roundedRect: iconRect.insetBy(dx: 0.75, dy: 0.75),
            xRadius: cornerRadius - 0.75,
            yRadius: cornerRadius - 0.75
        )
        rimPath.lineWidth = max(1.0, CGFloat(pixelSize) * 0.012)
        NSColor(white: 1.0, alpha: 0.35).setStroke()
        rimPath.stroke()

        // 6. Modern Elevated 3D Clipboard & Document Stack
        drawModernClipboardGraphic(in: iconRect, pixelSize: pixelSize)

        NSGraphicsContext.restoreGraphicsState()

        return rep.representation(using: .png, properties: [:])
    }

    private func drawModernClipboardGraphic(in rect: NSRect, pixelSize: Int) {
        let boardW = rect.width * 0.56
        let boardH = rect.height * 0.68
        let boardX = rect.midX - boardW / 2.0
        let boardY = rect.midY - boardH / 2.0 - rect.height * 0.015

        let boardRect = NSRect(x: boardX, y: boardY, width: boardW, height: boardH)
        let boardRadius = boardW * 0.12

        // A. Back Layer Card (Frosted Glass / Secondary Document with slight elevation)
        let backCardW = boardW * 0.90
        let backCardH = boardH * 0.90
        let backCardRect = NSRect(
            x: rect.midX - backCardW / 2.0 + rect.width * 0.02,
            y: boardY + boardH * 0.04,
            width: backCardW,
            height: backCardH
        )
        let backCardPath = NSBezierPath(roundedRect: backCardRect, xRadius: boardRadius * 0.8, yRadius: boardRadius * 0.8)

        if pixelSize >= 32 {
            let backShadow = NSShadow()
            backShadow.shadowColor = NSColor(calibratedRed: 0.05, green: 0.08, blue: 0.25, alpha: 0.30)
            backShadow.shadowBlurRadius = CGFloat(pixelSize) * 0.03
            backShadow.shadowOffset = NSSize(width: 0, height: -CGFloat(pixelSize) * 0.015)
            backShadow.set()
        }
        NSColor(calibratedRed: 0.92, green: 0.95, blue: 1.0, alpha: 0.45).setFill()
        backCardPath.fill()
        NSShadow().set()

        // B. Main Clipboard Base Board (Deep Frosted Obsidian Glass)
        let mainBoardPath = NSBezierPath(roundedRect: boardRect, xRadius: boardRadius, yRadius: boardRadius)

        if pixelSize >= 32 {
            let boardShadow = NSShadow()
            boardShadow.shadowColor = NSColor(calibratedRed: 0.03, green: 0.05, blue: 0.20, alpha: 0.40)
            boardShadow.shadowBlurRadius = CGFloat(pixelSize) * 0.05
            boardShadow.shadowOffset = NSSize(width: 0, height: -CGFloat(pixelSize) * 0.02)
            boardShadow.set()
        }

        // Board gradient: Sleek dark glass with subtle blue tint
        let boardGradient = NSGradient(
            colors: [
                NSColor(calibratedRed: 0.14, green: 0.18, blue: 0.32, alpha: 0.95),
                NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.22, alpha: 0.95)
            ],
            atLocations: [0.0, 1.0],
            colorSpace: .deviceRGB
        )
        boardGradient?.draw(in: mainBoardPath, angle: -90.0)
        NSShadow().set()

        // Board border rim
        NSColor(white: 1.0, alpha: 0.20).setStroke()
        mainBoardPath.lineWidth = max(1.0, CGFloat(pixelSize) * 0.008)
        mainBoardPath.stroke()

        // C. Elevated Paper Sheet (Crisp White Document)
        let sheetMargin = boardW * 0.075
        let sheetRect = NSRect(
            x: boardX + sheetMargin,
            y: boardY + sheetMargin * 0.7,
            width: boardW - sheetMargin * 2.0,
            height: boardH - sheetMargin * 1.8
        )
        let sheetRadius = boardRadius * 0.6
        let sheetPath = NSBezierPath(roundedRect: sheetRect, xRadius: sheetRadius, yRadius: sheetRadius)

        // Paper sheet gradient (Crisp pure white with subtle shadow)
        let paperGradient = NSGradient(
            colors: [
                NSColor(white: 1.0, alpha: 1.0),
                NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.99, alpha: 1.0)
            ],
            atLocations: [0.0, 1.0],
            colorSpace: .deviceRGB
        )
        paperGradient?.draw(in: sheetPath, angle: -90.0)

        // D. Document Lines (Vibrant Content Simulation)
        let lineW = sheetRect.width * 0.72
        let lineH = max(1.5, CGFloat(pixelSize) * 0.018)
        let lineSpacing = sheetRect.height * 0.125
        let lineStartX = sheetRect.midX - lineW / 2.0
        let firstLineY = sheetRect.midY + sheetRect.height * 0.12

        // Line 1: Cyan / Blue Accent
        let line1Rect = NSRect(x: lineStartX, y: firstLineY, width: lineW * 0.85, height: lineH)
        let line1Path = NSBezierPath(roundedRect: line1Rect, xRadius: lineH * 0.5, yRadius: lineH * 0.5)
        NSColor(calibratedRed: 0.0, green: 0.65, blue: 0.95, alpha: 0.90).setFill()
        line1Path.fill()

        // Line 2: Violet Accent
        let line2Rect = NSRect(x: lineStartX, y: firstLineY - lineSpacing, width: lineW, height: lineH)
        let line2Path = NSBezierPath(roundedRect: line2Rect, xRadius: lineH * 0.5, yRadius: lineH * 0.5)
        NSColor(calibratedRed: 0.45, green: 0.30, blue: 0.85, alpha: 0.80).setFill()
        line2Path.fill()

        // Line 3: Lavender / Neutral
        let line3Rect = NSRect(x: lineStartX, y: firstLineY - lineSpacing * 2.0, width: lineW * 0.60, height: lineH)
        let line3Path = NSBezierPath(roundedRect: line3Rect, xRadius: lineH * 0.5, yRadius: lineH * 0.5)
        NSColor(calibratedRed: 0.65, green: 0.68, blue: 0.80, alpha: 0.70).setFill()
        line3Path.fill()

        // E. Top Metallic Spring Clip (Polished Chrome / Titanium with Specular Highlight)
        let clipW = boardW * 0.44
        let clipH = boardH * 0.15
        let clipRect = NSRect(
            x: rect.midX - clipW / 2.0,
            y: boardRect.maxY - clipH * 0.65,
            width: clipW,
            height: clipH
        )
        let clipRadius = clipH * 0.35
        let clipPath = NSBezierPath(roundedRect: clipRect, xRadius: clipRadius, yRadius: clipRadius)

        // Clip metallic gradient
        let clipGradient = NSGradient(
            colors: [
                NSColor(calibratedRed: 0.95, green: 0.96, blue: 0.98, alpha: 1.0),
                NSColor(calibratedRed: 0.72, green: 0.75, blue: 0.82, alpha: 1.0),
                NSColor(calibratedRed: 0.48, green: 0.52, blue: 0.60, alpha: 1.0)
            ],
            atLocations: [0.0, 0.45, 1.0],
            colorSpace: .deviceRGB
        )
        clipGradient?.draw(in: clipPath, angle: -90.0)

        // Clip rim
        NSColor(white: 1.0, alpha: 0.60).setStroke()
        clipPath.lineWidth = max(0.8, CGFloat(pixelSize) * 0.007)
        clipPath.stroke()

        // Clip Center Fastener / Hole
        let holeW = clipW * 0.28
        let holeH = clipH * 0.35
        let holeRect = NSRect(
            x: rect.midX - holeW / 2.0,
            y: clipRect.midY - holeH / 2.0,
            width: holeW,
            height: holeH
        )
        let holePath = NSBezierPath(roundedRect: holeRect, xRadius: holeH * 0.5, yRadius: holeH * 0.5)
        NSColor(calibratedRed: 0.20, green: 0.22, blue: 0.30, alpha: 0.95).setFill()
        holePath.fill()
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
