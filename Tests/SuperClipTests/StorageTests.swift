import Foundation
import AppKit
import SuperClipCore

public struct StorageTests {
    public static func run(sandboxDir: URL) {
        TestHarness.startSuite("Storage Persistence & Management")
        
        // Test 1: Initialize StorageManager in empty sandbox
        let storage = StorageManager(baseDirectory: sandboxDir, initialCapacity: 10)
        TestHarness.assertEqual(storage.items.count, 0, "StorageManager initializes with empty items array")
        TestHarness.assertEqual(storage.capacity, 10, "StorageManager initializes with correct configured capacity")
        
        // Test 2: Add plain text clip
        let text1 = "Hello SuperClip Storage Test"
        let item1 = ClipItem(
            id: UUID(),
            contentType: .text,
            textContent: text1,
            byteSize: text1.utf8.count,
            createdAt: Date(),
            isPinned: false
        )
        storage.addClip(item: item1, imageData: nil, thumbData: nil)
        storage.flushDiskQueue()
        TestHarness.assertEqual(storage.items.count, 1, "Adding text clip increments items count to 1")
        TestHarness.assertEqual(storage.items.first?.textContent, text1, "Added clip contains exact text content")
        
        // Test 3: Cold-start reload from disk
        let storage2 = StorageManager(baseDirectory: sandboxDir, initialCapacity: 10)
        TestHarness.assertEqual(storage2.items.count, 1, "Cold-start StorageManager reloads persisted item from disk")
        TestHarness.assertEqual(storage2.items.first?.id, item1.id, "Persisted item maintains identical UUID")
        TestHarness.assertEqual(storage2.items.first?.textContent, text1, "Persisted item maintains identical string payload")
        
        // Test 4: Duplicate promotion
        let item2 = ClipItem(id: UUID(), contentType: .text, textContent: "Second Clip", byteSize: 11, isPinned: false)
        storage2.addClip(item: item2, imageData: nil, thumbData: nil)
        TestHarness.assertEqual(storage2.items.first?.id, item2.id, "Second clip added at index 0")
        
        // Re-adding item1 text promotes item1 to index 0
        let item1Dup = ClipItem(id: UUID(), contentType: .text, textContent: text1, byteSize: text1.utf8.count, isPinned: false)
        storage2.addClip(item: item1Dup, imageData: nil, thumbData: nil)
        TestHarness.assertEqual(storage2.items.first?.textContent, text1, "Duplicate text promoted to top of history")
        TestHarness.assertEqual(storage2.items.count, 2, "Duplicate promotion does not increase total items count")
        
        // Test 5: Delete item
        let toDeleteID = storage2.items[0].id
        storage2.deleteItem(id: toDeleteID)
        storage2.flushDiskQueue()
        TestHarness.assertEqual(storage2.items.count, 1, "Deleting item decrements items count")
        TestHarness.assertFalse(storage2.items.contains(where: { $0.id == toDeleteID }), "Deleted item removed from storage")
        
        // Test 6: Image and thumbnail disk storage
        let imgID = UUID()
        let fakeImageData = Data(repeating: 0x89, count: 500)
        let fakeThumbData = Data(repeating: 0x50, count: 200)
        let imgItem = ClipItem(
            id: imgID,
            contentType: .image,
            imageFileName: "\(imgID.uuidString).png",
            thumbnailFileName: "\(imgID.uuidString)_thumb.png",
            imageWidth: 640,
            imageHeight: 480,
            byteSize: fakeImageData.count,
            isPinned: false
        )
        storage2.addClip(item: imgItem, imageData: fakeImageData, thumbData: fakeThumbData)
        storage2.flushDiskQueue()
        
        TestHarness.assertNotNil(storage2.getThumbnailURL(for: imgItem), "Thumbnail URL generated for image item")
        TestHarness.assertEqual(storage2.getImageData(for: imgItem)?.count, fakeImageData.count, "Image data retrieved identically from disk")

        // Test 7: ClipItem isMasked property, Codable round-trip and backward compatibility
        var defaultItem = ClipItem(id: UUID(), contentType: .text, textContent: "Sensitive Token 123")
        TestHarness.assertFalse(defaultItem.isMasked, "Default isMasked is false")

        defaultItem.toggleMasked()
        TestHarness.assertTrue(defaultItem.isMasked, "toggleMasked toggles isMasked to true")

        let toggledCopy = defaultItem.toggledMasked()
        TestHarness.assertFalse(toggledCopy.isMasked, "toggledMasked produces copy with isMasked false")

        // JSON Codable round-trip with isMasked: true
        let maskedItem = ClipItem(
            id: UUID(),
            contentType: .text,
            textContent: "Secret API Key",
            byteSize: 14,
            isPinned: false,
            isMasked: true
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let encodedData = try? encoder.encode(maskedItem)
        TestHarness.assertNotNil(encodedData, "ClipItem with isMasked encoded successfully")
        let decodedItem = encodedData.flatMap { try? decoder.decode(ClipItem.self, from: $0) }
        TestHarness.assertNotNil(decodedItem, "ClipItem with isMasked decoded successfully")
        if let decodedItem = decodedItem {
            TestHarness.assertEqual(decodedItem.id, maskedItem.id, "Decoded item preserves UUID")
            TestHarness.assertEqual(decodedItem.textContent, maskedItem.textContent, "Decoded item preserves raw textContent")
            TestHarness.assertTrue(decodedItem.isMasked, "Decoded item preserves isMasked == true")
        }

        // Backward compatibility: JSON lacking isMasked key decodes with default isMasked = false
        let legacyJSON = """
        {
            "id": "\(UUID().uuidString)",
            "contentType": "text",
            "textContent": "Legacy unmasked item",
            "byteSize": 20,
            "createdAt": 0,
            "isPinned": false
        }
        """.data(using: .utf8)!
        let legacyDecoded = try? decoder.decode(ClipItem.self, from: legacyJSON)
        TestHarness.assertNotNil(legacyDecoded, "Legacy JSON without isMasked decoded successfully")
        TestHarness.assertFalse(legacyDecoded?.isMasked ?? true, "Legacy JSON without isMasked defaults to false")

        // Test 8: StorageManager.toggleMaskItem persists masked state correctly
        let sensitiveClip = ClipItem(
            id: UUID(),
            contentType: .text,
            textContent: "PasswordSecret999",
            byteSize: 17,
            isPinned: false,
            isMasked: false
        )
        storage2.addClip(item: sensitiveClip, imageData: nil, thumbData: nil)
        storage2.flushDiskQueue()
        TestHarness.assertFalse(storage2.items.first!.isMasked, "Initially unmasked in storage")

        storage2.toggleMaskItem(id: sensitiveClip.id)
        storage2.flushDiskQueue()
        TestHarness.assertTrue(storage2.items.first!.isMasked, "toggleMaskItem toggles isMasked to true in memory")

        // Cold-start reload from disk
        let storage3 = StorageManager(baseDirectory: sandboxDir, initialCapacity: 10)
        let reloadedClip = storage3.items.first(where: { $0.id == sensitiveClip.id })
        TestHarness.assertNotNil(reloadedClip, "Reloaded storage contains sensitive clip")
        TestHarness.assertTrue(reloadedClip?.isMasked ?? false, "Masked state isMasked == true persisted across reload")
        TestHarness.assertEqual(reloadedClip?.textContent, "PasswordSecret999", "Original plain text preserved in storage")

        // Toggle back to false and verify persistence
        storage3.toggleMaskItem(id: sensitiveClip.id)
        storage3.flushDiskQueue()
        TestHarness.assertFalse(storage3.items.first(where: { $0.id == sensitiveClip.id })?.isMasked ?? true, "Toggled back to unmasked in memory")

        let storage4 = StorageManager(baseDirectory: sandboxDir, initialCapacity: 10)
        TestHarness.assertFalse(storage4.items.first(where: { $0.id == sensitiveClip.id })?.isMasked ?? true, "Unmasked state persisted across reload")
    }
}
