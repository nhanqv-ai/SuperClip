import Foundation
import CoreGraphics
import ImageIO
import AppKit
import SuperClipCore

@main
public struct StorageStressRunner {
    private static var totalTests = 0
    private static var passedTests = 0
    private static var failedTests = 0

    private static func report(name: String, passed: Bool, detail: String = "") {
        totalTests += 1
        if passed {
            passedTests += 1
            print("  [PASS] \(name)")
        } else {
            failedTests += 1
            print("  [FAIL] \(name): \(detail)")
        }
    }

    private static func createSandbox() -> URL {
        let tempBase = FileManager.default.temporaryDirectory
        let sandboxURL = tempBase.appendingPathComponent("SuperClip_Stress_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: sandboxURL, withIntermediateDirectories: true)
        return sandboxURL
    }

    private static func cleanupSandbox(_ sandboxURL: URL) {
        try? FileManager.default.removeItem(at: sandboxURL)
    }

    public static func main() {
        print("==================================================")
        print("  SuperClip StorageManager Adversarial Stress Test")
        print("  Target: Concurrency (100 tasks), Read-After-Write, Capacity Clamp")
        print("==================================================")

        let startTime = Date()

        // ----------------------------------------------------
        // Suite 1: High Concurrency Under Contention (100 tasks)
        // ----------------------------------------------------
        testHighConcurrency100Tasks()

        // ----------------------------------------------------
        // Suite 2: Read-After-Write Stress on getImageData
        // ----------------------------------------------------
        testReadAfterWriteStress()

        // ----------------------------------------------------
        // Suite 3: Dynamic Capacity Clamp Boundary Conditions
        // ----------------------------------------------------
        testCapacityClampBoundaries()

        // ----------------------------------------------------
        // Suite 4: Extreme Interleaved Torture Stress
        // ----------------------------------------------------
        testExtremeInterleavedStress()

        let elapsed = Date().timeIntervalSince(startTime)
        print("\n==================================================")
        print("  Stress Test Execution Summary")
        print("==================================================")
        print("  Total Tests Executed: \(totalTests)")
        print("  Tests Passed:         \(passedTests)")
        print("  Tests Failed:         \(failedTests)")
        print("  Elapsed Time:         \(String(format: "%.3f", elapsed))s")

        if failedTests == 0 {
            print("\nRESULT: ALL ADVERSARIAL STRESS TESTS PASSED (0 FAILURES)\n")
            exit(0)
        } else {
            print("\nRESULT: STRESS TESTS FAILED (\(failedTests) FAILURES)\n")
            exit(1)
        }
    }

    // ========================================================
    // SUITE 1: High Concurrency Under Contention (100 Tasks)
    // ========================================================
    private static func testHighConcurrency100Tasks() {
        print("\n--- Suite 1: High Concurrency (100 Parallel Tasks) ---")

        let sandbox = createSandbox()
        defer { cleanupSandbox(sandbox) }

        // Test 1.1: 100 parallel tasks inserting distinct text clips simultaneously
        let storage1 = StorageManager(baseDirectory: sandbox.appendingPathComponent("ConcText"), initialCapacity: 100)
        let queue = DispatchQueue(label: "stress.concurrent.queue", attributes: .concurrent)
        let group1 = DispatchGroup()

        for i in 0..<100 {
            group1.enter()
            queue.async {
                let item = ClipItem(
                    id: UUID(),
                    contentType: .text,
                    textContent: "Concurrent Text Clip \(i)",
                    byteSize: 30,
                    isPinned: false
                )
                storage1.addClip(item: item, imageData: nil, thumbData: nil)
                group1.leave()
            }
        }
        let waitResult1 = group1.wait(timeout: .now() + 10.0)
        report(
            name: "100 parallel text insertions complete without deadlock or timeout",
            passed: waitResult1 == .success,
            detail: "Timed out waiting for 100 concurrent tasks"
        )
        report(
            name: "StorageManager contains exactly 100 items after 100 parallel insertions",
            passed: storage1.items.count == 100,
            detail: "Expected 100 items, got \(storage1.items.count)"
        )

        // Verify all 100 items have unique text content
        let texts1 = Set(storage1.items.compactMap { $0.textContent })
        report(
            name: "All 100 concurrent items have distinct content without race collision",
            passed: texts1.count == 100,
            detail: "Expected 100 distinct items, got \(texts1.count)"
        )

        // Test 1.2: 100 parallel tasks inserting distinct image clips simultaneously
        let storage2 = StorageManager(baseDirectory: sandbox.appendingPathComponent("ConcImg"), initialCapacity: 50)
        let group2 = DispatchGroup()

        for i in 0..<100 {
            group2.enter()
            queue.async {
                let id = UUID()
                let imgPayload = Data(repeating: UInt8(i % 250), count: 256)
                let thumbPayload = Data(repeating: UInt8((i + 1) % 250), count: 64)
                let item = ClipItem(
                    id: id,
                    contentType: .image,
                    imageFileName: "\(id.uuidString).png",
                    thumbnailFileName: "\(id.uuidString)_thumb.png",
                    imageWidth: 320,
                    imageHeight: 240,
                    byteSize: 256,
                    isPinned: false
                )
                storage2.addClip(item: item, imageData: imgPayload, thumbData: thumbPayload)
                group2.leave()
            }
        }
        let waitResult2 = group2.wait(timeout: .now() + 10.0)
        report(
            name: "100 parallel image insertions complete without deadlock or timeout",
            passed: waitResult2 == .success,
            detail: "Timed out waiting for 100 concurrent image tasks"
        )
        storage2.flushDiskQueue()

        report(
            name: "Capacity bound 50 strictly enforced after 100 concurrent image insertions",
            passed: storage2.items.count == 50,
            detail: "Expected exactly 50 items, got \(storage2.items.count)"
        )

        // Verify disk files match in-memory count
        let diskImages = (try? FileManager.default.contentsOfDirectory(atPath: storage2.imagesDirectory.path)) ?? []
        report(
            name: "Disk image files pruned to exactly 50 matching in-memory capacity",
            passed: diskImages.count == 50,
            detail: "Expected 50 disk image files, found \(diskImages.count)"
        )

        // Test 1.3: 100 parallel tasks executing chaotic mixed CRUD operations
        let storage3 = StorageManager(baseDirectory: sandbox.appendingPathComponent("ConcMixed"), initialCapacity: 30)

        // Prepopulate with 20 items
        for i in 0..<20 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Preload \(i)", byteSize: 10, isPinned: (i % 4 == 0))
            storage3.addClip(item: item, imageData: nil, thumbData: nil)
        }

        let group3 = DispatchGroup()
        for i in 0..<100 {
            group3.enter()
            queue.async {
                let op = i % 6
                switch op {
                case 0:
                    // Add text clip
                    let item = ClipItem(id: UUID(), contentType: .text, textContent: "Chaos Text \(i)", byteSize: 15, isPinned: false)
                    storage3.addClip(item: item, imageData: nil, thumbData: nil)
                case 1:
                    // Add image clip
                    let id = UUID()
                    let data = Data(repeating: UInt8(i), count: 128)
                    let item = ClipItem(
                        id: id,
                        contentType: .image,
                        imageFileName: "\(id.uuidString).png",
                        thumbnailFileName: "\(id.uuidString)_thumb.png",
                        imageWidth: 100,
                        imageHeight: 100,
                        byteSize: 128,
                        isPinned: false
                    )
                    storage3.addClip(item: item, imageData: data, thumbData: data)
                case 2:
                    // Toggle pin on a random existing item
                    let allItems = storage3.items
                    if let target = allItems.randomElement() {
                        storage3.togglePin(id: target.id)
                    }
                case 3:
                    // Delete a random item
                    let allItems = storage3.items
                    if let target = allItems.randomElement() {
                        storage3.deleteItem(id: target.id)
                    }
                case 4:
                    // Read consistency check
                    let items = storage3.items
                    let pinned = storage3.pinnedItems
                    let history = storage3.historyItems
                    _ = (items.count, pinned.count, history.count)
                case 5:
                    // Clear unpinned history
                    if i % 20 == 0 {
                        storage3.clearUnpinnedHistory()
                    } else {
                        _ = storage3.capacity
                    }
                default:
                    break
                }
                group3.leave()
            }
        }
        let waitResult3 = group3.wait(timeout: .now() + 15.0)
        report(
            name: "100 chaotic parallel CRUD operations execute without deadlock or crash",
            passed: waitResult3 == .success,
            detail: "Timed out or hung during 100 concurrent CRUD tasks"
        )

        // Verify storage internal consistency after chaos
        let finalItems = storage3.items
        let finalPinned = storage3.pinnedItems
        let finalHistory = storage3.historyItems
        report(
            name: "StorageManager maintains partition invariant after chaos (pinned + history == total)",
            passed: finalPinned.count + finalHistory.count == finalItems.count,
            detail: "Mismatch: total=\(finalItems.count), pinned=\(finalPinned.count), history=\(finalHistory.count)"
        )
        report(
            name: "StorageManager unpinned items never exceed capacity after chaos",
            passed: finalHistory.count <= storage3.capacity,
            detail: "Unpinned count \(finalHistory.count) exceeded capacity \(storage3.capacity)"
        )
    }

    // ========================================================
    // SUITE 2: Read-After-Write Stress on getImageData
    // ========================================================
    private static func testReadAfterWriteStress() {
        print("\n--- Suite 2: Read-After-Write Stress on getImageData ---")

        let sandbox = createSandbox()
        defer { cleanupSandbox(sandbox) }

        let storage = StorageManager(baseDirectory: sandbox, initialCapacity: 100)

        // Test 2.1: Immediate synchronous read-after-write across 50 image clips
        var immediateMatches = 0
        for i in 0..<50 {
            let id = UUID()
            let expectedData = "Unique payload \(i) - \(UUID().uuidString)".data(using: .utf8)!
            let item = ClipItem(
                id: id,
                contentType: .image,
                imageFileName: "\(id.uuidString).png",
                thumbnailFileName: "\(id.uuidString)_thumb.png",
                imageWidth: 640,
                imageHeight: 480,
                byteSize: expectedData.count,
                isPinned: false
            )
            storage.addClip(item: item, imageData: expectedData, thumbData: nil)

            // IMMEDIATELY on the very next instruction, retrieve image data
            let retrieved = storage.getImageData(for: item)
            if retrieved == expectedData {
                immediateMatches += 1
            }
        }
        report(
            name: "Immediate synchronous read-after-write succeeds 50/50 times",
            passed: immediateMatches == 50,
            detail: "Only \(immediateMatches)/50 immediate reads returned matching data"
        )

        // Test 2.2: 100 parallel tasks performing concurrent read-after-write
        let queue = DispatchQueue(label: "raw.concurrent.queue", attributes: .concurrent)
        let group = DispatchGroup()
        let lock = NSLock()
        var concurrentSuccesses = 0

        for i in 0..<100 {
            group.enter()
            queue.async {
                let id = UUID()
                let expectedData = Data(repeating: UInt8((i * 7) % 255), count: 512)
                let item = ClipItem(
                    id: id,
                    contentType: .image,
                    imageFileName: "\(id.uuidString).png",
                    thumbnailFileName: "\(id.uuidString)_thumb.png",
                    imageWidth: 800,
                    imageHeight: 600,
                    byteSize: expectedData.count,
                    isPinned: true // Keep pinned to prevent eviction race
                )
                storage.addClip(item: item, imageData: expectedData, thumbData: nil)

                // Read immediately
                let retrieved = storage.getImageData(for: item)
                if retrieved == expectedData {
                    lock.lock()
                    concurrentSuccesses += 1
                    lock.unlock()
                }
                group.leave()
            }
        }
        let waitResult = group.wait(timeout: .now() + 15.0)
        report(
            name: "100 parallel read-after-write tasks complete within timeout",
            passed: waitResult == .success,
            detail: "Parallel read-after-write timed out"
        )
        report(
            name: "100 parallel read-after-write tasks retrieve 100% exact byte payload",
            passed: concurrentSuccesses == 100,
            detail: "Expected 100 successes, got \(concurrentSuccesses)"
        )

        // Test 2.3: Cache eviction & disk fallback
        // Storage has NSCache with countLimit = 50.
        // We have added > 100 pinned items. The earliest pinned items MUST have been evicted from NSCache.
        // Let's verify that getImageData transparently falls back to disk and returns the payload!
        storage.flushDiskQueue()

        let allPinned = storage.pinnedItems
        report(
            name: "Storage has 100 pinned items in memory",
            passed: allPinned.count >= 100,
            detail: "Expected at least 100 pinned items, found \(allPinned.count)"
        )

        var fallbackMatches = 0
        // Read all 100 items back; items beyond cache limit will hit disk queue
        for item in allPinned {
            if let data = storage.getImageData(for: item), data.count == 512 {
                fallbackMatches += 1
            }
        }
        report(
            name: "Disk fallback correctly retrieves payloads for all items evicted from in-memory cache",
            passed: fallbackMatches == allPinned.count,
            detail: "Expected \(allPinned.count) disk fallback matches, got \(fallbackMatches)"
        )

        // Test 2.4: Non-existent image file returns nil safely without throwing
        let fakeItem = ClipItem(
            id: UUID(),
            contentType: .image,
            imageFileName: "non_existent_file_\(UUID().uuidString).png",
            thumbnailFileName: nil,
            imageWidth: 100,
            imageHeight: 100,
            byteSize: 100,
            isPinned: false
        )
        let nilResult = storage.getImageData(for: fakeItem)
        report(
            name: "getImageData safely returns nil for non-existent image asset",
            passed: nilResult == nil,
            detail: "Expected nil, got non-nil data"
        )
    }

    // ========================================================
    // SUITE 3: Dynamic Capacity Clamp Boundary Conditions
    // ========================================================
    private static func testCapacityClampBoundaries() {
        print("\n--- Suite 3: Capacity Clamp Boundary Conditions ---")

        let sandbox = createSandbox()
        defer { cleanupSandbox(sandbox) }

        let storage = StorageManager(baseDirectory: sandbox, initialCapacity: 50)

        // Test 3.1: Clamp capacity to 1 with mixed pinned and unpinned items
        // Add 30 unpinned items
        for i in 1...30 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Unpinned \(i)", byteSize: 10, isPinned: false)
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }
        // Add 5 pinned items
        var pinnedUUIDs: [UUID] = []
        for i in 1...5 {
            let id = UUID()
            pinnedUUIDs.append(id)
            let item = ClipItem(id: id, contentType: .text, textContent: "Pinned \(i)", byteSize: 10, isPinned: true)
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }

        report(
            name: "Initial store has 5 pinned and 30 unpinned items (35 total)",
            passed: storage.pinnedItems.count == 5 && storage.historyItems.count == 30,
            detail: "pinned=\(storage.pinnedItems.count), unpinned=\(storage.historyItems.count)"
        )

        // Now dynamically clamp capacity down to 1
        storage.capacity = 1

        report(
            name: "Dynamic capacity set to 1 updates storage.capacity property",
            passed: storage.capacity == 1,
            detail: "Expected capacity 1, got \(storage.capacity)"
        )
        report(
            name: "Unpinned items strictly pruned to exactly 1 item",
            passed: storage.historyItems.count == 1,
            detail: "Expected 1 unpinned item, got \(storage.historyItems.count)"
        )
        report(
            name: "All 5 pinned items 100% retained after clamp to 1",
            passed: storage.pinnedItems.count == 5,
            detail: "Expected 5 pinned items, got \(storage.pinnedItems.count)"
        )
        report(
            name: "Total items equals exactly 1 unpinned + 5 pinned (6 total)",
            passed: storage.items.count == 6,
            detail: "Expected 6 items, got \(storage.items.count)"
        )
        report(
            name: "The 1 retained unpinned item is the most recent unpinned clip (Unpinned 30)",
            passed: storage.historyItems.first?.textContent == "Unpinned 30",
            detail: "Expected 'Unpinned 30', got '\(storage.historyItems.first?.textContent ?? "nil")'"
        )

        // Test 3.2: Clamping boundary edge cases: 0, negative, extreme values
        storage.capacity = 0
        report(
            name: "Assigning capacity = 0 clamps safely to 1",
            passed: storage.capacity == 1,
            detail: "Expected 1, got \(storage.capacity)"
        )

        storage.capacity = -1
        report(
            name: "Assigning capacity = -1 clamps safely to 1",
            passed: storage.capacity == 1,
            detail: "Expected 1, got \(storage.capacity)"
        )

        storage.capacity = -999999
        report(
            name: "Assigning capacity = -999999 clamps safely to 1",
            passed: storage.capacity == 1,
            detail: "Expected 1, got \(storage.capacity)"
        )
        report(
            name: "Unpinned history count remains exactly 1 after negative clamps",
            passed: storage.historyItems.count == 1,
            detail: "Expected 1 unpinned item, got \(storage.historyItems.count)"
        )

        // Test 3.3: Operations when capacity = 1
        // Adding new unpinned item evicts previous unpinned item
        let newClip = ClipItem(id: UUID(), contentType: .text, textContent: "Brand New Unpinned", byteSize: 18, isPinned: false)
        storage.addClip(item: newClip, imageData: nil, thumbData: nil)

        report(
            name: "Adding new clip under capacity=1 keeps unpinned count at 1",
            passed: storage.historyItems.count == 1,
            detail: "Expected 1 unpinned item, got \(storage.historyItems.count)"
        )
        report(
            name: "New clip occupies index 0 of history items",
            passed: storage.historyItems.first?.textContent == "Brand New Unpinned",
            detail: "Expected 'Brand New Unpinned', got '\(storage.historyItems.first?.textContent ?? "nil")'"
        )
        report(
            name: "All 5 pinned items remain unaffected",
            passed: storage.pinnedItems.count == 5,
            detail: "Expected 5 pinned items, got \(storage.pinnedItems.count)"
        )

        // Test 3.4: Pin toggle behavior when capacity = 1
        // Toggle pin on the single unpinned item -> now 6 pinned, 0 unpinned
        let unpinnedId = storage.historyItems.first!.id
        storage.togglePin(id: unpinnedId)

        report(
            name: "Pinning the only unpinned item results in 6 pinned and 0 unpinned",
            passed: storage.pinnedItems.count == 6 && storage.historyItems.count == 0,
            detail: "pinned=\(storage.pinnedItems.count), unpinned=\(storage.historyItems.count)"
        )

        // Add 1 new unpinned item -> now 6 pinned, 1 unpinned (7 total)
        let unpinnedNext = ClipItem(id: UUID(), contentType: .text, textContent: "Next Unpinned", byteSize: 13, isPinned: false)
        storage.addClip(item: unpinnedNext, imageData: nil, thumbData: nil)
        report(
            name: "Adding unpinned item when unpinned count is 0 yields 6 pinned + 1 unpinned",
            passed: storage.pinnedItems.count == 6 && storage.historyItems.count == 1,
            detail: "pinned=\(storage.pinnedItems.count), unpinned=\(storage.historyItems.count)"
        )

        // Now UNPIN one of the older pinned items:
        // That pinned item becomes unpinned, which would create 2 unpinned items!
        // enforceCapacity() MUST immediately evict the older unpinned item to restore unpinned count to 1!
        let targetToUnpin = pinnedUUIDs.first!
        storage.togglePin(id: targetToUnpin)

        report(
            name: "Unpinning an item under capacity=1 instantly triggers enforcement keeping unpinned at 1",
            passed: storage.historyItems.count == 1,
            detail: "Expected unpinned count 1, got \(storage.historyItems.count)"
        )
        report(
            name: "Pinned items count decreases to 5",
            passed: storage.pinnedItems.count == 5,
            detail: "Expected 5 pinned items, got \(storage.pinnedItems.count)"
        )

        // Test 3.5: AppSettings capacity clamping boundary via settings property
        var testSettings = AppSettings()
        testSettings.capacity = -50
        storage.settings = testSettings
        report(
            name: "Assigning settings with capacity -50 clamps storage.capacity to 1",
            passed: storage.capacity == 1,
            detail: "Expected 1, got \(storage.capacity)"
        )
        report(
            name: "Assigning settings with capacity -50 clamps storage.settings.capacity to 1",
            passed: storage.settings.capacity == 1,
            detail: "CRITICAL BUG: storage.settings.capacity is \(storage.settings.capacity), desynchronized from storage.capacity (\(storage.capacity))"
        )

        // Test 3.6: Cold-start persistence of clamped capacity
        storage.flushDiskQueue()
        let reloadedStorage = StorageManager(baseDirectory: sandbox)
        report(
            name: "Cold-start reload persists clamped capacity 1 from disk",
            passed: reloadedStorage.capacity == 1,
            detail: "CRITICAL BUG: reloadedStorage.capacity is \(reloadedStorage.capacity) because settings.json was written with unclamped capacity"
        )

        // Test 3.8: Cold-start boot when settings.json on disk contains capacity 0
        let zeroSettingsDir = sandbox.appendingPathComponent("ZeroSettingsDir")
        try? FileManager.default.createDirectory(at: zeroSettingsDir, withIntermediateDirectories: true)
        let zeroSettingsJSON = "{\"capacity\": 0, \"hotKeyKeyCode\": 9, \"hotKeyModifiers\": 2048, \"pollIntervalMs\": 250, \"maxThumbnailPixelSize\": 180, \"launchAtLogin\": false}".data(using: .utf8)!
        try? zeroSettingsJSON.write(to: zeroSettingsDir.appendingPathComponent("settings.json"))

        let zeroBootStorage = StorageManager(baseDirectory: zeroSettingsDir)
        report(
            name: "StorageManager initialized with settings.json having capacity 0 clamps capacity to >= 1",
            passed: zeroBootStorage.capacity >= 1,
            detail: "CRITICAL BUG: zeroBootStorage.capacity initialized directly to \(zeroBootStorage.capacity) without clamping to minimum bound 1!"
        )
    }

    // ========================================================
    // SUITE 4: Extreme Interleaved Torture Stress
    // ========================================================
    private static func testExtremeInterleavedStress() {
        print("\n--- Suite 4: Extreme Interleaved Torture Stress ---")

        let sandbox = createSandbox()
        defer { cleanupSandbox(sandbox) }

        let storage = StorageManager(baseDirectory: sandbox, initialCapacity: 10)
        let queue = DispatchQueue(label: "torture.queue", attributes: .concurrent)
        let group = DispatchGroup()

        // 100 concurrent tasks rapidly alternating capacity between 1 and 20 while inserting clips
        for i in 0..<100 {
            group.enter()
            queue.async {
                if i % 5 == 0 {
                    storage.capacity = (i % 2 == 0) ? 1 : 20
                }
                let item = ClipItem(
                    id: UUID(),
                    contentType: .text,
                    textContent: "Torture Clip \(i)",
                    byteSize: 15,
                    isPinned: (i % 7 == 0)
                )
                storage.addClip(item: item, imageData: nil, thumbData: nil)
                _ = storage.items.count
                group.leave()
            }
        }

        let waitResult = group.wait(timeout: .now() + 15.0)
        report(
            name: "100 interleaved capacity-churn tasks complete without race or deadlock",
            passed: waitResult == .success,
            detail: "Timed out or deadlocked"
        )

        storage.flushDiskQueue()
        let unpinnedAfterTorture = storage.historyItems.count
        let capAfterTorture = storage.capacity
        report(
            name: "Storage invariant holds: unpinned items (\(unpinnedAfterTorture)) <= capacity (\(capAfterTorture))",
            passed: unpinnedAfterTorture <= capAfterTorture,
            detail: "Unpinned items \(unpinnedAfterTorture) exceeds capacity \(capAfterTorture)"
        )
        report(
            name: "Capacity remains valid safe bound (>= 1)",
            passed: capAfterTorture >= 1,
            detail: "Capacity \(capAfterTorture) was < 1"
        )
    }
}
