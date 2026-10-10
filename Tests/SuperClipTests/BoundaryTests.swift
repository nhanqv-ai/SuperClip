import Foundation
import CoreGraphics
import ImageIO
import AppKit
import SuperClipCore

public struct BoundaryTests {
    public static func run(sandboxDir: URL) {
        TestHarness.startSuite("Tier 2: Boundary & Corner Cases")
        
        let storage = StorageManager(baseDirectory: sandboxDir, initialCapacity: 5)
        
        // Boundary 1: Empty and whitespace strings display titles
        let emptyItem = ClipItem(id: UUID(), contentType: .text, textContent: "", byteSize: 0, isPinned: false)
        TestHarness.assertEqual(emptyItem.displayTitle, "(Empty)", "Empty text string renders display title '(Empty)'")
        
        let whitespaceItem = ClipItem(id: UUID(), contentType: .text, textContent: "   \t\n  ", byteSize: 6, isPinned: false)
        TestHarness.assertEqual(whitespaceItem.displayTitle, "(Whitespace)", "Whitespace-only string renders display title '(Whitespace)'")
        
        // Boundary 2: Large text payload (100KB)
        let largeString = String(repeating: "SuperClip_E2E_Test_Block_", count: 4000) // ~100KB
        let largeItem = ClipItem(id: UUID(), contentType: .text, textContent: largeString, byteSize: largeString.utf8.count, isPinned: false)
        storage.addClip(item: largeItem, imageData: nil, thumbData: nil)
        TestHarness.assertEqual(storage.items.first?.id, largeItem.id, "Large text payload stored safely")
        TestHarness.assertEqual(storage.items.first?.byteSize, largeString.utf8.count, "Large byte count tracked accurately")
        
        // Boundary 3: Special characters and control characters
        let specialString = "Test\u{0000}Null\tTab\r\nNewline!@#$%^&*()_+-=[]{}|;':\",./<>?"
        let specialItem = ClipItem(id: UUID(), contentType: .text, textContent: specialString, byteSize: specialString.utf8.count, isPinned: false)
        storage.addClip(item: specialItem, imageData: nil, thumbData: nil)
        TestHarness.assertEqual(storage.items.first?.textContent, specialString, "Control characters and punctuation preserved identically")
        
        // Boundary 4: 1x1 pixel micro image
        if let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 1,
            pixelsHigh: 1,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 4,
            bitsPerPixel: 32
        ), let microPNG = rep.representation(using: .png, properties: [:]) {
            let thumb = ThumbnailGenerator.generateThumbnail(from: microPNG, maxPixelSize: 180)
            TestHarness.assertNotNil(thumb, "1x1 pixel image generates thumbnail without division-by-zero")
            let dims = ThumbnailGenerator.extractDimensions(from: microPNG)
            TestHarness.assertEqual(dims?.width, 1, "Micro image width extracted as 1")
            TestHarness.assertEqual(dims?.height, 1, "Micro image height extracted as 1")
        } else {
            TestHarness.recordFail("1x1 Image Synthesis", reason: "Failed to create 1x1 image")
        }
        
        // Boundary 5: Search with regex meta-characters
        let regexQueryItems = [
            ClipItem(id: UUID(), contentType: .text, textContent: "Pattern [a-z]+ with (group).* and $end?", byteSize: 40, isPinned: false),
            ClipItem(id: UUID(), contentType: .text, textContent: "Simple text line", byteSize: 16, isPinned: false)
        ]
        let regexResult = SearchEngine.filter(items: regexQueryItems, query: "[a-z]+")
        TestHarness.assertEqual(regexResult.count, 1, "Search engine treats regex metacharacters as literal substrings")
        
        // Boundary 6: Capacity boundary limit (minimum 1)
        storage.capacity = 0 // Attempts setting 0
        TestHarness.assertTrue(storage.capacity >= 1, "Capacity clamps to minimum safe bound >= 1")
        
        // Boundary 7: Corrupt metadata recovery
        let corruptSandbox = sandboxDir.appendingPathComponent("CorruptRecovery")
        try? FileManager.default.createDirectory(at: corruptSandbox, withIntermediateDirectories: true)
        let corruptMetadataURL = corruptSandbox.appendingPathComponent("metadata.json")
        try? "THIS IS INVALID NOT JSON {{{".data(using: .utf8)?.write(to: corruptMetadataURL)
        
        let recoveredStorage = StorageManager(baseDirectory: corruptSandbox, initialCapacity: 10)
        TestHarness.assertEqual(recoveredStorage.items.count, 0, "Corrupt metadata.json gracefully recovers with empty items array without crashing")
        try? FileManager.default.removeItem(at: corruptSandbox)
    }
}
