import Foundation
import CoreGraphics
import ImageIO
import AppKit
import SuperClipCore

public struct ThumbnailTests {
    public static func run(sandboxDir: URL) {
        TestHarness.startSuite("Thumbnail Generator & ImageIO Pipeline")
        
        // Synthesize test image 800x600 exact pixels
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 800,
            pixelsHigh: 600,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 800 * 4,
            bitsPerPixel: 32
        ) else {
            TestHarness.recordFail("Synthesize Test Bitmap", reason: "Failed to initialize NSBitmapImageRep")
            return
        }
        
        // Fill bitmap with blue pixels
        if let dataPtr = rep.bitmapData {
            memset(dataPtr, 0x80, 800 * 600 * 4)
        }
        
        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            TestHarness.recordFail("Synthesize Test Bitmap", reason: "Failed to encode PNG bitmap")
            return
        }
        TestHarness.recordPass("Synthesize 800x600 PNG test bitmap")
        
        // Test 1: Generate thumbnail with max 180px
        guard let thumbData = ThumbnailGenerator.generateThumbnail(from: pngData, maxPixelSize: 180) else {
            TestHarness.recordFail("Thumbnail Generation", reason: "generateThumbnail returned nil")
            return
        }
        TestHarness.recordPass("Thumbnail generated successfully")
        
        // Test 2: File size constraint (< 50KB, typically sub-2KB)
        TestHarness.assertTrue(thumbData.count < 50000, "Thumbnail data size (\(thumbData.count) bytes) is compact")
        
        // Test 3: Downscaled dimensions
        guard let dimensions = ThumbnailGenerator.extractDimensions(from: thumbData) else {
            TestHarness.recordFail("Extract Thumbnail Dimensions", reason: "extractDimensions returned nil")
            return
        }
        TestHarness.assertTrue(dimensions.width <= 180 && dimensions.height <= 180, "Thumbnail dimensions (\(dimensions.width)x\(dimensions.height)) respect max 180px bound")
        TestHarness.assertEqual(dimensions.width, 180, "Longer dimension scaled to exactly 180px")
        TestHarness.assertEqual(dimensions.height, 135, "Shorter dimension preserves 4:3 aspect ratio (135px)")
        
        // Test 4: Extract dimensions of original image
        guard let origDimensions = ThumbnailGenerator.extractDimensions(from: pngData) else {
            TestHarness.recordFail("Extract Original Dimensions", reason: "extractDimensions returned nil")
            return
        }
        TestHarness.assertEqual(origDimensions.width, 800, "Original width extracted as 800")
        TestHarness.assertEqual(origDimensions.height, 600, "Original height extracted as 600")
        
        // Test 5: Empty data handling
        let emptyResult = ThumbnailGenerator.generateThumbnail(from: Data())
        TestHarness.assertNil(emptyResult, "Empty data produces nil thumbnail safely")
        
        // Test 6: Corrupt noise data handling
        let corruptData = Data(repeating: 0xDE, count: 200)
        let corruptResult = ThumbnailGenerator.generateThumbnail(from: corruptData)
        TestHarness.assertNil(corruptResult, "Corrupt byte stream produces nil thumbnail without throwing")
    }
}
