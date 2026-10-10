import Foundation
import CoreGraphics
import ImageIO
import AppKit
import Security
import SuperClipCore

@main
struct AdversarialRunner {
    static func main() {
        print("\u{001B}[1;35m==================================================\u{001B}[0m")
        print("\u{001B}[1;35m  SuperClipCore Empirical Adversarial Stress Test \u{001B}[0m")
        print("\u{001B}[1;35m  Target: SuperClipCore.StorageManager & Models   \u{001B}[0m")
        print("\u{001B}[1;35m==================================================\u{001B}[0m")

        let sandboxURL = TestHarness.createSandbox()
        print("Adversarial Sandbox initialized at: \(sandboxURL.path)")

        defer {
            TestHarness.cleanupSandbox(sandboxURL)
            print("Adversarial Sandbox cleaned up.")
        }

        let startTimestamp = Date()

        // Suite 1: FIFO Eviction Under Rapid Burst Insertion
        testFIFOEvictionRapidBurst(sandboxDir: sandboxURL.appendingPathComponent("BurstEviction"))

        // Suite 2: Dynamic Capacity Modification Stress
        testDynamicCapacityModifications(sandboxDir: sandboxURL.appendingPathComponent("DynamicCapacity"))

        // Suite 3: Pin Immunity Under Capacity Overflow & Interleaved Pressure
        testPinImmunityUnderOverflow(sandboxDir: sandboxURL.appendingPathComponent("PinImmunity"))

        // Suite 4: Pin Inversion & Eviction Edge Cases
        testPinInversionEdgeCases(sandboxDir: sandboxURL.appendingPathComponent("PinInversion"))

        // Suite 5: Duplicate Promotion Rigorous Edge Cases
        testDuplicatePromotionEdgeCases(sandboxDir: sandboxURL.appendingPathComponent("DuplicatePromotion"))

        // Suite 6: Disk Asset Lifecycle & Zero Disk Leaks
        testDiskAssetLifecycleAndZeroLeaks(sandboxDir: sandboxURL.appendingPathComponent("DiskLeaks"))

        // Suite 7: Atomic Writes & Corrupt File Recovery
        testAtomicWritesAndCorruptRecovery(sandboxDir: sandboxURL.appendingPathComponent("AtomicCorrupt"))

        // Suite 8: Cold Start Capacity Alignment Behavior
        testColdStartCapacityAlignment(sandboxDir: sandboxURL.appendingPathComponent("ColdStartCapacity"))

        // Suite 9: Domain Models & Edge Case Formats
        testDomainModelsAndEdgeCases()

        // Suite 10: High-Concurrency (64 Background Threads) Thread-Safety Stress
        testHighConcurrency64Threads(sandboxDir: sandboxURL.appendingPathComponent("ConcurrencyStress"))

        // Suite 11: Extreme Capacity Clamping & Immediate Pruning (0 and -100)
        testDirectZeroAndNegativeCapacityClamping(sandboxDir: sandboxURL.appendingPathComponent("ExtremeClamping"))

        // Suite 12: 100% Pin Retention Under Extreme Overflow
        testExtremePinRetentionOverflow(sandboxDir: sandboxURL.appendingPathComponent("ExtremePinOverflow"))

        // Suite 13: Exhaustive Corruption & Atomic Write Integrity
        testExhaustiveCorruptionAndAtomicWrites(sandboxDir: sandboxURL.appendingPathComponent("ExhaustiveCorruption"))

        let elapsed = Date().timeIntervalSince(startTimestamp)
        print("\nAdversarial stress testing completed in \(String(format: "%.3f", elapsed)) seconds.")

        TestHarness.printSummary()

        if TestHarness.shared.failedTests > 0 {
            exit(1)
        } else {
            exit(0)
        }
    }

    // MARK: - Suite 1: FIFO Eviction Rapid Burst
    static func testFIFOEvictionRapidBurst(sandboxDir: URL) {
        TestHarness.startSuite("Adversarial Suite 1: FIFO Eviction Rapid Burst")

        let capacity = 20
        let totalItems = 1000
        let storage = StorageManager(baseDirectory: sandboxDir, initialCapacity: capacity)

        // Rapidly insert 1000 items
        for i in 1...totalItems {
            let item = ClipItem(
                id: UUID(),
                contentType: .text,
                textContent: "Burst Item \(i)",
                byteSize: "Burst Item \(i)".utf8.count,
                isPinned: false
            )
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }
        storage.flushDiskQueue()

        TestHarness.assertEqual(storage.items.count, capacity, "Items count capped at exact capacity of \(capacity) after \(totalItems) rapid additions")

        // Invariant: newest item (1000) at index 0, oldest retained (981) at index 19
        TestHarness.assertEqual(storage.items.first?.textContent, "Burst Item 1000", "Index 0 is the most recently added item (Burst Item 1000)")
        TestHarness.assertEqual(storage.items.last?.textContent, "Burst Item 981", "Index \(capacity - 1) is the oldest retained item (Burst Item 981)")

        // Verify strictly descending order
        var isStrictlyDescending = true
        for idx in 0..<capacity {
            let expectedNum = totalItems - idx
            if storage.items[idx].textContent != "Burst Item \(expectedNum)" {
                isStrictlyDescending = false
                break
            }
        }
        TestHarness.assertTrue(isStrictlyDescending, "All 20 items follow strict FIFO chronological descending order")

        // Cold start reload verification
        let reloadStorage = StorageManager(baseDirectory: sandboxDir, initialCapacity: capacity)
        TestHarness.assertEqual(reloadStorage.items.count, capacity, "Cold restart reloads exactly \(capacity) items from disk")
        TestHarness.assertEqual(reloadStorage.items.first?.textContent, "Burst Item 1000", "Cold restart preserves newest item at index 0")
        TestHarness.assertEqual(reloadStorage.items.last?.textContent, "Burst Item 981", "Cold restart preserves oldest item at tail")
    }

    // MARK: - Suite 2: Dynamic Capacity Modifications
    static func testDynamicCapacityModifications(sandboxDir: URL) {
        TestHarness.startSuite("Adversarial Suite 2: Dynamic Capacity Modifications")

        let storage = StorageManager(baseDirectory: sandboxDir, initialCapacity: 50)

        // Fill with 50 items
        for i in 1...50 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Dyn Item \(i)", byteSize: 12, isPinned: false)
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }
        TestHarness.assertEqual(storage.items.count, 50, "Storage filled to capacity 50")

        // Shrink capacity to 25
        storage.capacity = 25
        TestHarness.assertEqual(storage.items.count, 25, "Dynamic shrink to 25 immediately prunes excess 25 items")
        TestHarness.assertEqual(storage.items.first?.textContent, "Dyn Item 50", "Newest item 50 retained after shrink")
        TestHarness.assertEqual(storage.items.last?.textContent, "Dyn Item 26", "Oldest retained item is 26 after shrink")

        // Shrink capacity to 5
        storage.capacity = 5
        TestHarness.assertEqual(storage.items.count, 5, "Dynamic shrink to 5 immediately prunes to 5 items")
        TestHarness.assertEqual(storage.items.first?.textContent, "Dyn Item 50", "Newest item 50 retained")
        TestHarness.assertEqual(storage.items.last?.textContent, "Dyn Item 46", "Oldest retained item is 46")

        // Shrink capacity to 1
        storage.capacity = 1
        TestHarness.assertEqual(storage.items.count, 1, "Dynamic shrink to 1 leaves exactly 1 item")
        TestHarness.assertEqual(storage.items.first?.textContent, "Dyn Item 50", "Single retained item is newest item 50")

        // Dynamic clamp on 0 and negative
        storage.capacity = 0
        TestHarness.assertEqual(storage.capacity, 1, "Setting capacity to 0 clamps safely to 1")
        storage.capacity = -100
        TestHarness.assertEqual(storage.capacity, 1, "Setting capacity to -100 clamps safely to 1")
        TestHarness.assertEqual(storage.items.count, 1, "Items array remains at 1 item")

        // Dynamic expansion to 30
        storage.capacity = 30
        TestHarness.assertEqual(storage.capacity, 30, "Capacity expanded to 30")
        TestHarness.assertEqual(storage.items.count, 1, "Items array count unchanged during expansion")

        for i in 51...79 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Dyn Item \(i)", byteSize: 12, isPinned: false)
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }
        TestHarness.assertEqual(storage.items.count, 30, "Storage filled to new expanded capacity of 30")

        // Adding 1 more item triggers FIFO eviction at expanded capacity
        let overflowItem = ClipItem(id: UUID(), contentType: .text, textContent: "Dyn Item 80", byteSize: 12, isPinned: false)
        storage.addClip(item: overflowItem, imageData: nil, thumbData: nil)
        TestHarness.assertEqual(storage.items.count, 30, "Adding item 80 respects capacity 30")
        TestHarness.assertEqual(storage.items.first?.textContent, "Dyn Item 80", "Newest item is Dyn Item 80")
        TestHarness.assertFalse(storage.items.contains(where: { $0.textContent == "Dyn Item 50" }), "Dyn Item 50 was evicted as oldest")

        storage.flushDiskQueue()
        // Verify settings.json persisted the updated capacity
        let reloadStorage = StorageManager(baseDirectory: sandboxDir)
        TestHarness.assertEqual(reloadStorage.capacity, 30, "Settings persistence accurately reloads dynamic capacity 30")
    }

    // MARK: - Suite 3: Pin Immunity Under Capacity Overflow
    static func testPinImmunityUnderOverflow(sandboxDir: URL) {
        TestHarness.startSuite("Adversarial Suite 3: Pin Immunity Under Capacity Overflow")

        let capacity = 5
        let storage = StorageManager(baseDirectory: sandboxDir, initialCapacity: capacity)

        // Add 5 items
        for i in 1...5 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Base Item \(i)", byteSize: 12, isPinned: false)
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }

        // Pin items 2 and 4
        let pinTarget2 = storage.items.first(where: { $0.textContent == "Base Item 2" })!
        let pinTarget4 = storage.items.first(where: { $0.textContent == "Base Item 4" })!
        storage.togglePin(id: pinTarget2.id)
        storage.togglePin(id: pinTarget4.id)

        TestHarness.assertEqual(storage.pinnedItems.count, 2, "2 items marked pinned")
        TestHarness.assertEqual(storage.historyItems.count, 3, "3 unpinned history items remain")

        // Add 50 new unpinned items to exert massive eviction pressure
        for i in 6...55 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Pressure Item \(i)", byteSize: 16, isPinned: false)
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }

        TestHarness.assertEqual(storage.pinnedItems.count, 2, "Both pinned items remain after 50 overflow additions")
        TestHarness.assertEqual(storage.historyItems.count, capacity, "Unpinned history items strictly capped at capacity \(capacity)")
        TestHarness.assertEqual(storage.items.count, 2 + capacity, "Total items equal 2 pinned + \(capacity) unpinned (7 total)")

        TestHarness.assertTrue(storage.items.contains(where: { $0.id == pinTarget2.id }), "Pin Target 2 retains 100% immunity")
        TestHarness.assertTrue(storage.items.contains(where: { $0.id == pinTarget4.id }), "Pin Target 4 retains 100% immunity")

        // Pin an item at index 0 (Pressure Item 55)
        let pinTarget55 = storage.items.first!
        storage.togglePin(id: pinTarget55.id)
        TestHarness.assertEqual(storage.pinnedItems.count, 3, "3 items now pinned")

        // Add 50 more unpinned items
        for i in 56...105 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Pressure Item \(i)", byteSize: 16, isPinned: false)
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }

        TestHarness.assertEqual(storage.pinnedItems.count, 3, "All 3 pinned items survive second overflow barrage")
        TestHarness.assertEqual(storage.historyItems.count, capacity, "Unpinned history items strictly capped at capacity \(capacity)")
        TestHarness.assertEqual(storage.items.count, 3 + capacity, "Total items equal 3 pinned + \(capacity) unpinned (8 total)")

        // 100% Pinned Overflow Scenario
        let currentUnpinned = storage.historyItems
        for uItem in currentUnpinned {
            storage.togglePin(id: uItem.id)
        }
        TestHarness.assertEqual(storage.pinnedItems.count, 8, "All 8 items are now pinned")
        TestHarness.assertEqual(storage.historyItems.count, 0, "0 unpinned items remain")

        // Add 10 new unpinned items when pinned items alone exceed capacity
        for i in 1...10 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "AllPinned Overflow \(i)", byteSize: 20, isPinned: false)
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }
        TestHarness.assertEqual(storage.pinnedItems.count, 8, "All 8 pinned items survive when pinned count alone > capacity")
        TestHarness.assertEqual(storage.historyItems.count, capacity, "Unpinned items capped at \(capacity)")
        TestHarness.assertEqual(storage.items.count, 8 + capacity, "Total items equal 8 pinned + \(capacity) unpinned (13 total)")

        // Dynamic capacity shrink under pinned presence
        storage.capacity = 2
        TestHarness.assertEqual(storage.pinnedItems.count, 8, "Pinned items untouched when capacity shrinks to 2")
        TestHarness.assertEqual(storage.historyItems.count, 2, "Unpinned history items pruned to new capacity 2")
        TestHarness.assertEqual(storage.items.count, 10, "Total items equal 8 pinned + 2 unpinned")
    }

    // MARK: - Suite 4: Pin Inversion & Eviction Edge Cases
    static func testPinInversionEdgeCases(sandboxDir: URL) {
        TestHarness.startSuite("Adversarial Suite 4: Pin Inversion & Eviction Edge Cases")

        let storage = StorageManager(baseDirectory: sandboxDir, initialCapacity: 3)

        // Case 1: Unpinning the oldest item under full capacity triggers its instant eviction
        let pOld = ClipItem(id: UUID(), contentType: .text, textContent: "Old Pinned", byteSize: 10, isPinned: true)
        storage.addClip(item: pOld, imageData: nil, thumbData: nil)
        // Add 3 unpinned items (U1, U2, U3)
        for i in 1...3 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Unpinned \(i)", byteSize: 10, isPinned: false)
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }

        TestHarness.assertEqual(storage.items.count, 4, "Store contains 1 pinned + 3 unpinned items")
        TestHarness.assertTrue(storage.items.contains(where: { $0.id == pOld.id }), "Old pinned item is present")

        // Now unpin pOld. Since pOld is at index 3 (the oldest item in the store), unpinning it makes unpinned count 4 > 3.
        // FIFO eviction should evict pOld as the oldest unpinned item!
        storage.togglePin(id: pOld.id)
        TestHarness.assertEqual(storage.items.count, 3, "Unpinning oldest item at capacity bound prunes store to capacity 3")
        TestHarness.assertFalse(storage.items.contains(where: { $0.id == pOld.id }), "Old item pOld was cleanly evicted upon unpinning")

        // Case 2: Unpinning the newest item (at index 0) under full capacity evicts the tail unpinned item instead
        let pNew = ClipItem(id: UUID(), contentType: .text, textContent: "New Pinned", byteSize: 10, isPinned: true)
        storage.addClip(item: pNew, imageData: nil, thumbData: nil)
        TestHarness.assertEqual(storage.items.count, 4, "Store contains 1 pinned (at index 0) + 3 unpinned")

        let tailItem = storage.historyItems.last!
        storage.togglePin(id: pNew.id) // unpin pNew
        TestHarness.assertEqual(storage.items.count, 3, "Store capped at capacity 3 after unpinning pNew")
        TestHarness.assertTrue(storage.items.contains(where: { $0.id == pNew.id }), "New unpinned item pNew is retained at index 0")
        TestHarness.assertFalse(storage.items.contains(where: { $0.id == tailItem.id }), "Oldest unpinned item was evicted instead of pNew")

        // Case 3: Toggle pin on non-existent UUID
        let nonExistentUUID = UUID()
        let countBefore = storage.items.count
        storage.togglePin(id: nonExistentUUID)
        TestHarness.assertEqual(storage.items.count, countBefore, "Toggling pin on non-existent UUID is safe no-op")
    }

    // MARK: - Suite 5: Duplicate Promotion Rigorous Edge Cases
    static func testDuplicatePromotionEdgeCases(sandboxDir: URL) {
        TestHarness.startSuite("Adversarial Suite 5: Duplicate Promotion Edge Cases")

        let storage = StorageManager(baseDirectory: sandboxDir, initialCapacity: 50)

        // 1. Promoting an already-pinned duplicate
        let pinnedDup = ClipItem(id: UUID(), contentType: .text, textContent: "Pinned Dup Target", byteSize: 17, isPinned: true)
        storage.addClip(item: pinnedDup, imageData: nil, thumbData: nil)

        for i in 1...5 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Interleaved \(i)", byteSize: 13, isPinned: false)
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }

        // Pinned item is now at index 5
        TestHarness.assertEqual(storage.items[5].id, pinnedDup.id, "Pinned item is at index 5")
        TestHarness.assertEqual(storage.items.count, 6, "Store count is 6")

        // Add identical text payload
        let reAddPinned = ClipItem(id: UUID(), contentType: .text, textContent: "Pinned Dup Target", byteSize: 17, isPinned: false)
        storage.addClip(item: reAddPinned, imageData: nil, thumbData: nil)

        TestHarness.assertEqual(storage.items.count, 6, "Duplicate promotion maintains total count")
        TestHarness.assertEqual(storage.items[0].id, pinnedDup.id, "Promoted clip maintains original UUID")
        TestHarness.assertEqual(storage.items[0].textContent, "Pinned Dup Target", "Promoted clip is at index 0")
        TestHarness.assertTrue(storage.items[0].isPinned, "Promoted duplicate preserves original pinned state")

        // 2. Immediate consecutive duplicate at index 0
        let countBeforeImmediate = storage.items.count
        let immediateDup = ClipItem(id: UUID(), contentType: .text, textContent: "Pinned Dup Target", byteSize: 17, isPinned: false)
        storage.addClip(item: immediateDup, imageData: nil, thumbData: nil)
        TestHarness.assertEqual(storage.items.count, countBeforeImmediate, "Immediate duplicate at index 0 causes zero re-allocations")

        // 3. Promoting the oldest item from the tail of a long list
        for i in 1...20 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Tail Test \(i)", byteSize: 11, isPinned: false)
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }
        let tailItem = storage.items.last!
        let tailText = tailItem.textContent!
        let tailUUID = tailItem.id
        let countBeforeTailPromo = storage.items.count

        let promoItem = ClipItem(id: UUID(), contentType: .text, textContent: tailText, byteSize: tailText.utf8.count, isPinned: false)
        storage.addClip(item: promoItem, imageData: nil, thumbData: nil)

        TestHarness.assertEqual(storage.items.count, countBeforeTailPromo, "Promoting tail item preserves items count")
        TestHarness.assertEqual(storage.items.first?.id, tailUUID, "Tail item promoted to index 0 with identical UUID")

        // 4. Whitespace and case differentiation
        let itemBase = ClipItem(id: UUID(), contentType: .text, textContent: "CaseSensitive", byteSize: 13, isPinned: false)
        let itemLower = ClipItem(id: UUID(), contentType: .text, textContent: "casesensitive", byteSize: 13, isPinned: false)
        let itemSpace = ClipItem(id: UUID(), contentType: .text, textContent: "CaseSensitive ", byteSize: 14, isPinned: false)
        let itemNewline = ClipItem(id: UUID(), contentType: .text, textContent: "CaseSensitive\n", byteSize: 14, isPinned: false)

        let initialCount = storage.items.count
        storage.addClip(item: itemBase, imageData: nil, thumbData: nil)
        storage.addClip(item: itemLower, imageData: nil, thumbData: nil)
        storage.addClip(item: itemSpace, imageData: nil, thumbData: nil)
        storage.addClip(item: itemNewline, imageData: nil, thumbData: nil)

        TestHarness.assertEqual(storage.items.count, initialCount + 4, "Case, trailing space, and newline are treated as distinct items")
    }

    // MARK: - Suite 6: Disk Asset Lifecycle & Zero Disk Leaks
    static func testDiskAssetLifecycleAndZeroLeaks(sandboxDir: URL) {
        TestHarness.startSuite("Adversarial Suite 6: Disk Asset Lifecycle & Zero Disk Leaks")

        let capacity = 3
        let storage = StorageManager(baseDirectory: sandboxDir, initialCapacity: capacity)
        let fileManager = FileManager.default

        // Ingest 10 image items
        var addedItemIDs: [UUID] = []
        for i in 1...10 {
            let id = UUID()
            addedItemIDs.append(id)
            let imgData = Data(repeating: UInt8(i), count: 300)
            let thumbData = Data(repeating: UInt8(i + 10), count: 100)
            let item = ClipItem(
                id: id,
                contentType: .image,
                imageFileName: "\(id.uuidString).png",
                thumbnailFileName: "\(id.uuidString)_thumb.png",
                imageWidth: 640,
                imageHeight: 480,
                byteSize: 300,
                isPinned: false
            )
            storage.addClip(item: item, imageData: imgData, thumbData: thumbData)
        }
        storage.flushDiskQueue()

        // Inspect images and thumbnails directories
        let imageFiles = (try? fileManager.contentsOfDirectory(atPath: storage.imagesDirectory.path)) ?? []
        let thumbFiles = (try? fileManager.contentsOfDirectory(atPath: storage.thumbnailsDirectory.path)) ?? []

        TestHarness.assertEqual(imageFiles.count, capacity, "Disk images count exactly equals capacity \(capacity) (7 evicted files deleted)")
        TestHarness.assertEqual(thumbFiles.count, capacity, "Disk thumbnails count exactly equals capacity \(capacity) (7 evicted files deleted)")

        // Verify that the files on disk match the 3 retained items
        let retainedIDs = Set(storage.items.map { $0.id.uuidString })
        let diskImageUUIDs = Set(imageFiles.map { ($0 as NSString).deletingPathExtension })
        TestHarness.assertEqual(retainedIDs, diskImageUUIDs, "Disk image files correspond 1-to-1 with retained items in memory")

        // Pin 1 image item
        let pinnedImage = storage.items[0]
        storage.togglePin(id: pinnedImage.id)

        // Ingest 10 more unpinned images
        for i in 11...20 {
            let id = UUID()
            let imgData = Data(repeating: UInt8(i), count: 300)
            let thumbData = Data(repeating: UInt8(i + 10), count: 100)
            let item = ClipItem(
                id: id,
                contentType: .image,
                imageFileName: "\(id.uuidString).png",
                thumbnailFileName: "\(id.uuidString)_thumb.png",
                imageWidth: 640,
                imageHeight: 480,
                byteSize: 300,
                isPinned: false
            )
            storage.addClip(item: item, imageData: imgData, thumbData: thumbData)
        }
        storage.flushDiskQueue()

        let imageFilesAfterPinOverflow = (try? fileManager.contentsOfDirectory(atPath: storage.imagesDirectory.path)) ?? []
        TestHarness.assertEqual(imageFilesAfterPinOverflow.count, 1 + capacity, "Disk holds 1 pinned + \(capacity) unpinned images = 4 files")
        TestHarness.assertTrue(imageFilesAfterPinOverflow.contains("\(pinnedImage.id.uuidString).png"), "Pinned image asset retained on disk during overflow")

        // Clear unpinned history
        storage.clearUnpinnedHistory()
        storage.flushDiskQueue()

        let imageFilesAfterClear = (try? fileManager.contentsOfDirectory(atPath: storage.imagesDirectory.path)) ?? []
        let thumbFilesAfterClear = (try? fileManager.contentsOfDirectory(atPath: storage.thumbnailsDirectory.path)) ?? []

        TestHarness.assertEqual(imageFilesAfterClear.count, 1, "Only 1 pinned image remains on disk after clearUnpinnedHistory")
        TestHarness.assertEqual(thumbFilesAfterClear.count, 1, "Only 1 pinned thumbnail remains on disk after clearUnpinnedHistory")
        TestHarness.assertEqual(imageFilesAfterClear.first, "\(pinnedImage.id.uuidString).png", "Remaining image is the pinned asset")

        // Delete the pinned item via deleteItem
        storage.deleteItem(id: pinnedImage.id)
        storage.flushDiskQueue()

        let imageFilesFinal = (try? fileManager.contentsOfDirectory(atPath: storage.imagesDirectory.path)) ?? []
        let thumbFilesFinal = (try? fileManager.contentsOfDirectory(atPath: storage.thumbnailsDirectory.path)) ?? []

        TestHarness.assertEqual(imageFilesFinal.count, 0, "Zero orphan image files on disk after deleting pinned item")
        TestHarness.assertEqual(thumbFilesFinal.count, 0, "Zero orphan thumbnail files on disk after deleting pinned item")
    }

    // MARK: - Suite 7: Atomic Writes & Corrupt File Recovery
    static func testAtomicWritesAndCorruptRecovery(sandboxDir: URL) {
        TestHarness.startSuite("Adversarial Suite 7: Atomic Writes & Corrupt File Recovery")

        // Test 7a: Normal serialization and cold reload
        let store1 = StorageManager(baseDirectory: sandboxDir, initialCapacity: 10)
        let item1 = ClipItem(id: UUID(), contentType: .text, textContent: "Persistence Test Item", byteSize: 21, isPinned: false)
        store1.addClip(item: item1, imageData: nil, thumbData: nil)
        store1.flushDiskQueue()

        let store2 = StorageManager(baseDirectory: sandboxDir, initialCapacity: 10)
        TestHarness.assertEqual(store2.items.count, 1, "Cold restart reloads serialized clip")
        TestHarness.assertEqual(store2.items.first?.textContent, "Persistence Test Item", "Payload intact on cold restart")

        // Test 7b: Corrupt metadata.json with arbitrary garbage bytes
        let garbageData = "NOT_JSON_DATA_GARBAGE_BYTES_$%^&*()!@#".data(using: .utf8)!
        try? garbageData.write(to: sandboxDir.appendingPathComponent("metadata.json"), options: .atomic)

        let storeCorrupt1 = StorageManager(baseDirectory: sandboxDir, initialCapacity: 10)
        TestHarness.assertEqual(storeCorrupt1.items.count, 0, "Corrupt garbage metadata recovers gracefully with empty store")

        // Test 7c: Corrupt metadata.json with truncated JSON
        let truncatedData = "[{\"id\": \"1234\", \"contentType\": \"text\", \"textConten".data(using: .utf8)!
        try? truncatedData.write(to: sandboxDir.appendingPathComponent("metadata.json"), options: .atomic)

        let storeCorrupt2 = StorageManager(baseDirectory: sandboxDir, initialCapacity: 10)
        TestHarness.assertEqual(storeCorrupt2.items.count, 0, "Truncated metadata recovers gracefully with empty store")

        // Test 7d: Zero-byte metadata.json
        let emptyData = Data()
        try? emptyData.write(to: sandboxDir.appendingPathComponent("metadata.json"), options: .atomic)

        let storeEmpty = StorageManager(baseDirectory: sandboxDir, initialCapacity: 10)
        TestHarness.assertEqual(storeEmpty.items.count, 0, "Zero-byte metadata recovers gracefully with empty store")

        // Test 7e: Corrupt settings.json recovers with default settings
        let corruptSettings = "{ \"capacity\": \"NOT_A_NUMBER\" }".data(using: .utf8)!
        try? corruptSettings.write(to: sandboxDir.appendingPathComponent("settings.json"), options: .atomic)

        let storeSettings = StorageManager(baseDirectory: sandboxDir)
        TestHarness.assertEqual(storeSettings.capacity, AppSettings.defaultCapacity, "Corrupt settings.json falls back to default capacity \(AppSettings.defaultCapacity)")

        // Test 7f: Deep nested directory initialization
        let deepURL = sandboxDir.appendingPathComponent("sub1/sub2/sub3/DeepStorage")
        let deepStore = StorageManager(baseDirectory: deepURL, initialCapacity: 10)
        TestHarness.assertEqual(deepStore.items.count, 0, "Deep directory hierarchy initialized without error")
        TestHarness.assertTrue(FileManager.default.fileExists(atPath: deepStore.imagesDirectory.path), "Deep images directory created")
    }

    // MARK: - Suite 8: Cold Start Capacity Alignment Behavior
    static func testColdStartCapacityAlignment(sandboxDir: URL) {
        TestHarness.startSuite("Adversarial Suite 8: Cold Start Capacity Alignment Behavior")

        // Scenario: 15 items saved on disk
        let storageA = StorageManager(baseDirectory: sandboxDir, initialCapacity: 20)
        for i in 1...15 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Alignment Item \(i)", byteSize: 16, isPinned: false)
            storageA.addClip(item: item, imageData: nil, thumbData: nil)
        }
        storageA.flushDiskQueue()
        TestHarness.assertEqual(storageA.items.count, 15, "Initial store holds 15 items")

        // Reopen with initialCapacity: 5
        let storageB = StorageManager(baseDirectory: sandboxDir, initialCapacity: 5)
        TestHarness.assertEqual(storageB.capacity, 5, "StorageB configured with capacity 5")

        // Note: loadFromDisk loads all 15 items, then the next addClip or enforceCapacity prunes to capacity.
        // Let's verify behavior on next clip addition
        let nextClip = ClipItem(id: UUID(), contentType: .text, textContent: "Trigger Clip", byteSize: 12, isPinned: false)
        storageB.addClip(item: nextClip, imageData: nil, thumbData: nil)

        TestHarness.assertEqual(storageB.items.count, 5, "Next addClip enforces capacity down to 5 items")
        TestHarness.assertEqual(storageB.items.first?.textContent, "Trigger Clip", "Newest item is Trigger Clip")
    }

    // MARK: - Suite 9: Domain Models & Edge Case Formats
    static func testDomainModelsAndEdgeCases() {
        TestHarness.startSuite("Adversarial Suite 9: Domain Models & Edge Case Formats")

        // 1. ClipItem displayTitle formatting
        let emptyItem = ClipItem(contentType: .text, textContent: "", byteSize: 0)
        TestHarness.assertEqual(emptyItem.displayTitle, "(Empty)", "Empty text string formatted as '(Empty)'")

        let nilItem = ClipItem(contentType: .text, textContent: nil, byteSize: 0)
        TestHarness.assertEqual(nilItem.displayTitle, "(Empty)", "Nil text string formatted as '(Empty)'")

        let whitespaceItem = ClipItem(contentType: .text, textContent: "   \n\t  \r\n  ", byteSize: 10)
        TestHarness.assertEqual(whitespaceItem.displayTitle, "(Whitespace)", "Whitespace-only string formatted as '(Whitespace)'")

        let multiLineItem = ClipItem(contentType: .text, textContent: "Line 1 Header\nLine 2 Body\nLine 3 Details", byteSize: 30)
        TestHarness.assertEqual(multiLineItem.displayTitle, "Line 1 Header", "Multiline text displays only first line")

        let longLine = String(repeating: "A", count: 100)
        let longItem = ClipItem(contentType: .text, textContent: longLine, byteSize: 100)
        TestHarness.assertEqual(longItem.displayTitle.count, 60, "Long line clamped to exactly 60 characters with ellipsis")
        TestHarness.assertTrue(longItem.displayTitle.hasSuffix("..."), "Long line clamped title ends with '...'")

        let imgZero = ClipItem(contentType: .image, imageWidth: 0, imageHeight: 0, byteSize: 0)
        TestHarness.assertEqual(imgZero.displayTitle, "Image", "0x0 image displays title 'Image'")

        let imgValid = ClipItem(contentType: .image, imageWidth: 1920, imageHeight: 1080, byteSize: 5000)
        TestHarness.assertEqual(imgValid.displayTitle, "Image (1920x1080)", "Valid image displays 'Image (1920x1080)'")

        // 2. ByteCountFormatter
        let smallBytesItem = ClipItem(contentType: .text, textContent: "abc", byteSize: 3)
        TestHarness.assertTrue(smallBytesItem.formattedByteSize.contains("bytes") || smallBytesItem.formattedByteSize.contains("3"), "Small byte size formatted properly")

        let largeBytesItem = ClipItem(contentType: .text, textContent: "big", byteSize: 1048576)
        TestHarness.assertTrue(largeBytesItem.formattedByteSize.contains("MB"), "1MB byte size formatted with MB")

        // 3. AppSettings boundary clamping
        let s1 = AppSettings(capacity: 5, pollIntervalMs: 10, maxThumbnailPixelSize: 20)
        TestHarness.assertEqual(s1.capacity, 10, "AppSettings clamps minimum capacity to 10")
        TestHarness.assertEqual(s1.pollIntervalMs, 50, "AppSettings clamps minimum poll interval to 50ms")
        TestHarness.assertEqual(s1.maxThumbnailPixelSize, 60, "AppSettings clamps minimum thumbnail size to 60px")

        let s2 = AppSettings(capacity: 5000, pollIntervalMs: 5000, maxThumbnailPixelSize: 1000)
        TestHarness.assertEqual(s2.capacity, 1000, "AppSettings clamps maximum capacity to 1000")
        TestHarness.assertEqual(s2.pollIntervalMs, 2000, "AppSettings clamps maximum poll interval to 2000ms")
        TestHarness.assertEqual(s2.maxThumbnailPixelSize, 512, "AppSettings clamps maximum thumbnail size to 512px")
    }

    // MARK: - Suite 10: High-Concurrency Thread Safety Stress
    static func testHighConcurrency64Threads(sandboxDir: URL) {
        TestHarness.startSuite("Adversarial Suite 10: High-Concurrency (64 Background Threads) Thread-Safety Stress")
        let capacity = 50
        let storage = StorageManager(baseDirectory: sandboxDir, initialCapacity: capacity)
        let threadCount = 64
        let itemsPerThread = 50
        let group = DispatchGroup()
        let concurrentQueue = DispatchQueue(label: "com.superclip.adversarial.concurrency", attributes: .concurrent)

        // Spawn 64 concurrent threads adding clips and reading
        for t in 0..<threadCount {
            group.enter()
            concurrentQueue.async {
                for i in 0..<itemsPerThread {
                    let id = UUID()
                    let isImage = (i % 6 == 0)
                    let text = "Thread \(t) Clip \(i)"
                    let item = ClipItem(
                        id: id,
                        contentType: isImage ? .image : .text,
                        textContent: isImage ? nil : text,
                        imageFileName: isImage ? "\(id.uuidString).png" : nil,
                        thumbnailFileName: isImage ? "\(id.uuidString)_thumb.png" : nil,
                        imageWidth: isImage ? 120 : nil,
                        imageHeight: isImage ? 120 : nil,
                        byteSize: 120,
                        isPinned: (i % 10 == 0)
                    )
                    let imgData = isImage ? Data(repeating: UInt8(t % 250), count: 120) : nil
                    let thumbData = isImage ? Data(repeating: UInt8(i % 250), count: 60) : nil
                    storage.addClip(item: item, imageData: imgData, thumbData: thumbData)

                    // Interleaved concurrent reader queries
                    if i % 4 == 0 {
                        _ = storage.items.count
                        _ = storage.pinnedItems.count
                        _ = storage.historyItems.count
                    }
                    if i % 8 == 0 {
                        if let firstItem = storage.items.first {
                            storage.togglePin(id: firstItem.id)
                        }
                    }
                    if isImage {
                        _ = storage.getImageData(for: item)
                    }
                }
                group.leave()
            }
        }

        // Dedicated concurrent reader polling threads
        for _ in 0..<16 {
            group.enter()
            concurrentQueue.async {
                for _ in 0..<100 {
                    _ = storage.items
                    _ = storage.pinnedItems
                    _ = storage.historyItems
                    _ = storage.capacity
                    Thread.sleep(forTimeInterval: 0.0005)
                }
                group.leave()
            }
        }

        let waitResult = group.wait(timeout: .now() + 20.0)
        TestHarness.assertEqual(waitResult, .success, "All 64 concurrent threads and 16 reader threads completed within timeout without deadlocks or crashes")

        storage.flushDiskQueue()

        let totalItems = storage.items.count
        let pinnedCount = storage.pinnedItems.count
        let historyCount = storage.historyItems.count

        TestHarness.assertEqual(totalItems, pinnedCount + historyCount, "Total items strictly equals pinned items + unpinned items after 3200 concurrent insertions")
        TestHarness.assertTrue(historyCount <= storage.capacity, "Unpinned history count (\(historyCount)) is strictly capped at capacity (\(storage.capacity))")
        TestHarness.assertTrue(totalItems > 0, "Storage retains items after massive concurrency")

        // Invariant: Cold restart preserves valid metadata
        let coldRestart = StorageManager(baseDirectory: sandboxDir)
        TestHarness.assertEqual(coldRestart.items.count, totalItems, "Cold restart reloads exact items count after concurrent writes")
    }

    // MARK: - Suite 11: Extreme Capacity Clamping & Immediate Pruning
    static func testDirectZeroAndNegativeCapacityClamping(sandboxDir: URL) {
        TestHarness.startSuite("Adversarial Suite 11: Extreme Capacity Clamping & Immediate Pruning (0 and -100)")

        // Subtest 11a: Set capacity = 0 directly on full store
        let sZero = StorageManager(baseDirectory: sandboxDir.appendingPathComponent("ZeroDirect"), initialCapacity: 50)
        for i in 1...50 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "ZeroPrune \(i)", byteSize: 12, isPinned: false)
            sZero.addClip(item: item, imageData: nil, thumbData: nil)
        }
        TestHarness.assertEqual(sZero.items.count, 50, "Store loaded with 50 unpinned items")
        sZero.capacity = 0
        TestHarness.assertEqual(sZero.capacity, 1, "Capacity 0 is clamped to 1")
        TestHarness.assertEqual(sZero.items.count, 1, "Setting capacity = 0 immediately prunes store from 50 down to 1 item")
        TestHarness.assertEqual(sZero.items.first?.textContent, "ZeroPrune 50", "The single retained item is newest item (ZeroPrune 50)")

        // Subtest 11b: Set capacity = -100 directly on full store
        let sNeg = StorageManager(baseDirectory: sandboxDir.appendingPathComponent("NegDirect"), initialCapacity: 50)
        for i in 1...50 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "NegPrune \(i)", byteSize: 12, isPinned: false)
            sNeg.addClip(item: item, imageData: nil, thumbData: nil)
        }
        TestHarness.assertEqual(sNeg.items.count, 50, "Store loaded with 50 unpinned items")
        sNeg.capacity = -100
        TestHarness.assertEqual(sNeg.capacity, 1, "Capacity -100 is clamped to 1")
        TestHarness.assertEqual(sNeg.items.count, 1, "Setting capacity = -100 immediately prunes store from 50 down to 1 item")
        TestHarness.assertEqual(sNeg.items.first?.textContent, "NegPrune 50", "The single retained item is newest item (NegPrune 50)")

        // Subtest 11c: Mixed pinned and unpinned store clamped to 0
        let sMixed = StorageManager(baseDirectory: sandboxDir.appendingPathComponent("MixedDirect"), initialCapacity: 50)
        for i in 1...10 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Pinned \(i)", byteSize: 12, isPinned: true)
            sMixed.addClip(item: item, imageData: nil, thumbData: nil)
        }
        for i in 1...40 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Unpinned \(i)", byteSize: 12, isPinned: false)
            sMixed.addClip(item: item, imageData: nil, thumbData: nil)
        }
        TestHarness.assertEqual(sMixed.pinnedItems.count, 10, "10 pinned items present before clamping")
        TestHarness.assertEqual(sMixed.historyItems.count, 40, "40 unpinned items present before clamping")

        sMixed.capacity = 0
        TestHarness.assertEqual(sMixed.capacity, 1, "Capacity clamped to 1")
        TestHarness.assertEqual(sMixed.pinnedItems.count, 10, "All 10 pinned items retained intact under capacity 0")
        TestHarness.assertEqual(sMixed.historyItems.count, 1, "Unpinned history immediately pruned to 1 item")
        TestHarness.assertEqual(sMixed.items.count, 11, "Total store contains 10 pinned + 1 unpinned = 11 items")

        // Subtest 11d: Mixed pinned and unpinned store clamped to -100
        sMixed.capacity = -100
        TestHarness.assertEqual(sMixed.capacity, 1, "Capacity clamped to 1 on -100")
        TestHarness.assertEqual(sMixed.pinnedItems.count, 10, "All 10 pinned items retained intact under capacity -100")
        TestHarness.assertEqual(sMixed.historyItems.count, 1, "Unpinned history remains at 1 item")
        TestHarness.assertEqual(sMixed.items.count, 11, "Total store remains at 11 items")
    }

    // MARK: - Suite 12: 100% Pin Retention Under Extreme Overflow
    static func testExtremePinRetentionOverflow(sandboxDir: URL) {
        TestHarness.startSuite("Adversarial Suite 12: 100% Pin Retention Under Extreme Overflow")
        let capacity = 1
        let storage = StorageManager(baseDirectory: sandboxDir, initialCapacity: capacity)

        // Step 1: Ingest 50 pinned items
        var pinnedUUIDs: [UUID] = []
        for i in 1...50 {
            let id = UUID()
            pinnedUUIDs.append(id)
            let item = ClipItem(id: id, contentType: .text, textContent: "Permanent Pin \(i)", byteSize: 16, isPinned: true)
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }
        TestHarness.assertEqual(storage.pinnedItems.count, 50, "50 pinned items created")
        TestHarness.assertEqual(storage.items.count, 50, "Store holds exactly 50 pinned items")

        // Step 2: Flood with 1,000 unpinned items under capacity = 1
        for i in 1...1000 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Flood Unpinned \(i)", byteSize: 16, isPinned: false)
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }

        TestHarness.assertEqual(storage.pinnedItems.count, 50, "100% pin retention: exactly 50 pinned items survive 1000 unpinned overflow additions")
        TestHarness.assertEqual(storage.historyItems.count, capacity, "Unpinned history items strictly capped at capacity 1")
        TestHarness.assertEqual(storage.items.count, 51, "Total items equal 50 pinned + 1 unpinned = 51")

        // Verify all 50 pinned UUIDs are present
        let currentItemIDs = Set(storage.items.map { $0.id })
        var all50Present = true
        for pid in pinnedUUIDs {
            if !currentItemIDs.contains(pid) {
                all50Present = false
                break
            }
        }
        TestHarness.assertTrue(all50Present, "100% pin retention: all 50 original UUIDs confirmed intact")

        // Step 3: Clear unpinned history
        storage.clearUnpinnedHistory()
        TestHarness.assertEqual(storage.pinnedItems.count, 50, "All 50 pinned items survive clearUnpinnedHistory")
        TestHarness.assertEqual(storage.historyItems.count, 0, "Unpinned history items count is 0")
        TestHarness.assertEqual(storage.items.count, 50, "Total items equal 50 pinned items")

        // Step 4: Add another 100 unpinned items
        for i in 1...100 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Second Wave \(i)", byteSize: 14, isPinned: false)
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }
        TestHarness.assertEqual(storage.pinnedItems.count, 50, "All 50 pinned items survive second wave of 100 additions")
        TestHarness.assertEqual(storage.historyItems.count, capacity, "Unpinned history items capped at 1")

        // Step 5: Capacity reduction to 0 and -100 preserves all 50 pinned items
        storage.capacity = 0
        TestHarness.assertEqual(storage.pinnedItems.count, 50, "All 50 pinned items survive capacity reduction to 0")
        storage.capacity = -100
        TestHarness.assertEqual(storage.pinnedItems.count, 50, "All 50 pinned items survive capacity reduction to -100")
    }

    // MARK: - Suite 13: Exhaustive Corruption & Atomic Write Integrity
    static func testExhaustiveCorruptionAndAtomicWrites(sandboxDir: URL) {
        TestHarness.startSuite("Adversarial Suite 13: Exhaustive Corruption & Atomic Write Integrity")
        let fm = FileManager.default

        // 13a: Binary fuzzing - 8KB random bytes from SecRandomCopyBytes
        let randomDir = sandboxDir.appendingPathComponent("RandomFuzz")
        try? fm.createDirectory(at: randomDir, withIntermediateDirectories: true)
        let metaURL = randomDir.appendingPathComponent("metadata.json")

        var randomBytes = [UInt8](repeating: 0, count: 8192)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        try? Data(randomBytes).write(to: metaURL, options: .atomic)

        let sRand = StorageManager(baseDirectory: randomDir, initialCapacity: 10)
        TestHarness.assertEqual(sRand.items.count, 0, "8KB random binary garbage in metadata.json recovers safely with 0 items")

        let freshClip = ClipItem(id: UUID(), contentType: .text, textContent: "Post-Corruption Recovery Item", byteSize: 29, isPinned: false)
        sRand.addClip(item: freshClip, imageData: nil, thumbData: nil)
        TestHarness.assertEqual(sRand.items.count, 1, "Store is immediately writable after binary corruption recovery")
        sRand.flushDiskQueue()

        let sRandReload = StorageManager(baseDirectory: randomDir, initialCapacity: 10)
        TestHarness.assertEqual(sRandReload.items.count, 1, "Cold reload after corruption recovery loads new valid item")

        // 13b: Array of invalid primitives
        let primDir = sandboxDir.appendingPathComponent("PrimFuzz")
        try? fm.createDirectory(at: primDir, withIntermediateDirectories: true)
        let primData = "[10, 20, 30, 40, 50]".data(using: .utf8)!
        try? primData.write(to: primDir.appendingPathComponent("metadata.json"), options: .atomic)
        let sPrim = StorageManager(baseDirectory: primDir, initialCapacity: 10)
        TestHarness.assertEqual(sPrim.items.count, 0, "Array of primitive numbers recovers safely with 0 items")

        // 13c: JSON Object dictionary instead of array
        let dictDir = sandboxDir.appendingPathComponent("DictFuzz")
        try? fm.createDirectory(at: dictDir, withIntermediateDirectories: true)
        let dictData = "{\"clips\": [\"item1\", \"item2\"]}".data(using: .utf8)!
        try? dictData.write(to: dictDir.appendingPathComponent("metadata.json"), options: .atomic)
        let sDict = StorageManager(baseDirectory: dictDir, initialCapacity: 10)
        TestHarness.assertEqual(sDict.items.count, 0, "JSON dictionary object recovers safely with 0 items")

        // 13d: Truncated JSON sweep across multiple cutoffs
        let sampleEncoder = JSONEncoder()
        sampleEncoder.dateEncodingStrategy = .iso8601
        let validEncoded = try! sampleEncoder.encode([freshClip])
        for cutoff in [5, 12, 25, 40, 65] {
            let truncSlice = validEncoded.prefix(cutoff)
            let truncDir = sandboxDir.appendingPathComponent("Trunc_\(cutoff)")
            try? fm.createDirectory(at: truncDir, withIntermediateDirectories: true)
            try? truncSlice.write(to: truncDir.appendingPathComponent("metadata.json"), options: .atomic)
            let sTrunc = StorageManager(baseDirectory: truncDir, initialCapacity: 10)
            TestHarness.assertEqual(sTrunc.items.count, 0, "Truncated JSON at cutoff \(cutoff) recovers safely with 0 items")
        }

        // 13e: Corrupt settings with random bytes
        let settingsDir = sandboxDir.appendingPathComponent("CorruptSettings")
        try? fm.createDirectory(at: settingsDir, withIntermediateDirectories: true)
        let settingsURL = settingsDir.appendingPathComponent("settings.json")
        var randSettingsBytes = [UInt8](repeating: 0, count: 256)
        _ = SecRandomCopyBytes(kSecRandomDefault, randSettingsBytes.count, &randSettingsBytes)
        try? Data(randSettingsBytes).write(to: settingsURL, options: .atomic)
        let sSettings = StorageManager(baseDirectory: settingsDir)
        TestHarness.assertEqual(sSettings.capacity, AppSettings.defaultCapacity, "Random binary garbage in settings.json falls back to default capacity")

        // 13f: Atomic writes verification
        let atomicDir = sandboxDir.appendingPathComponent("AtomicIntegrity")
        let sAtomic = StorageManager(baseDirectory: atomicDir, initialCapacity: 100)
        for i in 1...30 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Atomic Payload \(i)", byteSize: 18, isPinned: false)
            sAtomic.addClip(item: item, imageData: nil, thumbData: nil)
        }
        sAtomic.flushDiskQueue()
        let diskMeta = try? Data(contentsOf: atomicDir.appendingPathComponent("metadata.json"))
        TestHarness.assertNotNil(diskMeta, "Atomic write metadata file exists")
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let reloadedClips = try? dec.decode([ClipItem].self, from: diskMeta ?? Data())
        TestHarness.assertNotNil(reloadedClips, "Atomic write file is decodable without corruption")
        TestHarness.assertEqual(reloadedClips?.count, 30, "All 30 items successfully decoded from atomic write")
    }
}
