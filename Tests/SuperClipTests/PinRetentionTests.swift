import Foundation
import SuperClipCore

public struct PinRetentionTests {
    public static func run(sandboxDir: URL) {
        TestHarness.startSuite("Pin Retention & Capacity Eviction")
        
        let storage = StorageManager(baseDirectory: sandboxDir, initialCapacity: 3)
        
        // Test 1: Add 3 items
        let item1 = ClipItem(id: UUID(), contentType: .text, textContent: "Clip 1", byteSize: 6, isPinned: false)
        let item2 = ClipItem(id: UUID(), contentType: .text, textContent: "Clip 2", byteSize: 6, isPinned: false)
        let item3 = ClipItem(id: UUID(), contentType: .text, textContent: "Clip 3", byteSize: 6, isPinned: false)
        
        storage.addClip(item: item1, imageData: nil, thumbData: nil)
        storage.addClip(item: item2, imageData: nil, thumbData: nil)
        storage.addClip(item: item3, imageData: nil, thumbData: nil)
        TestHarness.assertEqual(storage.items.count, 3, "Storage holds 3 items at initial capacity")
        
        // Test 2: Pin item1
        storage.togglePin(id: item1.id)
        TestHarness.assertTrue(storage.items.first(where: { $0.id == item1.id })?.isPinned == true, "item1 toggled to isPinned = true")
        
        // Test 3: Add 2 more unpinned items (exceeding capacity of 3 unpinned)
        let item4 = ClipItem(id: UUID(), contentType: .text, textContent: "Clip 4", byteSize: 6, isPinned: false)
        let item5 = ClipItem(id: UUID(), contentType: .text, textContent: "Clip 5", byteSize: 6, isPinned: false)
        
        storage.addClip(item: item4, imageData: nil, thumbData: nil)
        storage.addClip(item: item5, imageData: nil, thumbData: nil)
        
        // Verify: Pinned item1 MUST remain intact
        TestHarness.assertTrue(storage.items.contains(where: { $0.id == item1.id }), "Pinned item1 retained during capacity overflow")
        
        // Total unpinned items must be capped at 3
        let unpinned = storage.items.filter { !$0.isPinned }
        TestHarness.assertEqual(unpinned.count, 3, "Unpinned items capped at exactly configured capacity of 3")
        
        // Total items is 1 pinned + 3 unpinned = 4
        TestHarness.assertEqual(storage.items.count, 4, "Total items equal 1 pinned + 3 unpinned")
        
        // Test 4: Clear unpinned history
        storage.clearUnpinnedHistory()
        TestHarness.assertTrue(storage.items.contains(where: { $0.id == item1.id }), "Pinned item1 survives clearUnpinnedHistory")
        TestHarness.assertEqual(storage.items.count, 1, "Only pinned items remain after clearUnpinnedHistory")
        TestHarness.assertEqual(storage.items.filter { !$0.isPinned }.count, 0, "Zero unpinned items remain after clearUnpinnedHistory")
        
        // Test 5: Dynamic capacity reduction
        let item6 = ClipItem(id: UUID(), contentType: .text, textContent: "Clip 6", byteSize: 6, isPinned: false)
        let item7 = ClipItem(id: UUID(), contentType: .text, textContent: "Clip 7", byteSize: 6, isPinned: false)
        let item8 = ClipItem(id: UUID(), contentType: .text, textContent: "Clip 8", byteSize: 6, isPinned: false)
        storage.addClip(item: item6, imageData: nil, thumbData: nil)
        storage.addClip(item: item7, imageData: nil, thumbData: nil)
        storage.addClip(item: item8, imageData: nil, thumbData: nil)
        TestHarness.assertEqual(storage.items.count, 4, "Store contains 1 pinned + 3 unpinned items")
        
        // Lower capacity to 1
        storage.capacity = 1
        TestHarness.assertTrue(storage.items.contains(where: { $0.id == item1.id }), "Pinned item1 survives capacity reduction to 1")
        let unpinnedAfterReduction = storage.items.filter { !$0.isPinned }
        TestHarness.assertEqual(unpinnedAfterReduction.count, 1, "Unpinned items pruned to 1 upon dynamic capacity reduction")
    }
}
