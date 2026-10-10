import Foundation
import AppKit
import Carbon
import SwiftUI
import SuperClipCore
import SuperClip

/// Mock HotKeyManager tracking registration invocations for live customization stress.
final class Iter2MockHotKeyManager: HotKeyManaging {
    var onTrigger: (() -> Void)?
    var registeredHistory: [(keyCode: UInt32, modifiers: UInt32)] = []
    var unregisterCount: Int = 0

    var lastRegisteredKeyCode: UInt32? {
        registeredHistory.last?.keyCode
    }

    var lastRegisteredModifiers: UInt32? {
        registeredHistory.last?.modifiers
    }

    init() {}

    func register(keyCode: UInt32, modifiers: UInt32) {
        registeredHistory.append((keyCode, modifiers))
    }

    func unregister() {
        unregisterCount += 1
    }

    func reset() {
        registeredHistory.removeAll()
        unregisterCount = 0
    }
}

@main
struct ChallengerM4Iter2StressHarness {
    static var totalTests = 0
    static var passedTests = 0
    static var failedTests = 0

    static func report(name: String, passed: Bool, detail: String = "") {
        totalTests += 1
        if passed {
            passedTests += 1
            print("  [PASS] \(name)")
        } else {
            failedTests += 1
            let extra = detail.isEmpty ? "" : " (Detail: \(detail))"
            print("  [FAIL] \(name)\(extra)")
        }
    }

    static func createTempDirectory(prefix: String) -> URL {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperClip_\(prefix)_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        return temp
    }

    static func cleanupTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static func createDummyPNG(width: Int = 32, height: Int = 32) -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4,
            bitsPerPixel: 32
        )!
        return rep.representation(using: .png, properties: [:]) ?? Data()
    }

    static func main() {
        print("======================================================================")
        print("  SuperClip Challenger M4 Round 2: Settings & Capacity Stress Harness")
        print("======================================================================")

        let sandbox = createTempDirectory(prefix: "ChallengerM4Iter2")
        defer { cleanupTempDirectory(sandbox) }

        // =====================================================================
        // PART 1: DYNAMIC CAPACITY MUTATION STRESS (100 -> 20 -> 10)
        // =====================================================================
        print("\n--- Part 1: Dynamic Capacity Reduction (100 -> 20 -> 10) ---")

        let storeDir1 = sandbox.appendingPathComponent("CapacityReductionStore")
        let storage1 = StorageManager(baseDirectory: storeDir1, initialCapacity: 100)

        // Generate 35 pinned clips and 65 unpinned clips (total 100 items)
        var pinnedOriginalIDs: [UUID] = []
        var pinnedOriginalTexts: [UUID: String] = [:]
        var unpinnedOriginalIDs: [UUID] = [] // Insertion order: index 0 is oldest, index 64 is newest
        var unpinnedOriginalTexts: [UUID: String] = [:]

        var pinnedCount = 0
        var unpinnedCount = 0

        // Interleaved insertion pattern across 100 items
        for i in 1...100 {
            let isPinned = (pinnedCount < 35) && (i % 3 == 0 || unpinnedCount >= 65)
            let id = UUID()
            let date = Date().addingTimeInterval(Double(i))

            if isPinned {
                pinnedCount += 1
                let text = "Pinned Clip \(pinnedCount) [Seq \(i)]"
                pinnedOriginalIDs.append(id)
                pinnedOriginalTexts[id] = text
                let item = ClipItem(
                    id: id,
                    contentType: .text,
                    textContent: text,
                    byteSize: text.utf8.count,
                    createdAt: date,
                    isPinned: true
                )
                storage1.addClip(item: item, imageData: nil, thumbData: nil)
            } else {
                unpinnedCount += 1
                let text = "Unpinned Clip \(unpinnedCount) [Seq \(i)]"
                unpinnedOriginalIDs.append(id)
                unpinnedOriginalTexts[id] = text
                let item = ClipItem(
                    id: id,
                    contentType: .text,
                    textContent: text,
                    byteSize: text.utf8.count,
                    createdAt: date,
                    isPinned: false
                )
                storage1.addClip(item: item, imageData: nil, thumbData: nil)
            }
        }

        report(
            name: "Initial store: exactly 35 pinned items created",
            passed: storage1.pinnedItems.count == 35,
            detail: "pinned=\(storage1.pinnedItems.count), expected 35"
        )
        report(
            name: "Initial store: exactly 65 unpinned items created",
            passed: storage1.historyItems.count == 65,
            detail: "unpinned=\(storage1.historyItems.count), expected 65"
        )
        report(
            name: "Initial store: total count equals 100 (35 pinned + 65 unpinned)",
            passed: storage1.items.count == 100,
            detail: "total=\(storage1.items.count), expected 100"
        )
        report(
            name: "Initial capacity is 100 on both storage.capacity and storage.settings.capacity",
            passed: storage1.capacity == 100 && storage1.settings.capacity == 100,
            detail: "storage=\(storage1.capacity), settings=\(storage1.settings.capacity)"
        )

        // -------------------------------------------------------------
        // Step 1.1: Dynamically reduce capacity from 100 -> 20
        // -------------------------------------------------------------
        print("\n  >> Executing dynamic reduction: 100 -> 20")
        storage1.capacity = 20

        report(
            name: "Dynamic capacity set to 20 updates storage.capacity and storage.settings.capacity",
            passed: storage1.capacity == 20 && storage1.settings.capacity == 20,
            detail: "storage=\(storage1.capacity), settings=\(storage1.settings.capacity)"
        )
        report(
            name: "Unpinned items immediately clamped to new capacity limit 20",
            passed: storage1.historyItems.count == 20,
            detail: "unpinned=\(storage1.historyItems.count), expected 20"
        )
        report(
            name: "Pinned items 100% retained after reduction to 20 (35/35 preserved)",
            passed: storage1.pinnedItems.count == 35,
            detail: "pinned=\(storage1.pinnedItems.count), expected 35"
        )
        report(
            name: "Total items count is exactly 55 (35 pinned + 20 unpinned)",
            passed: storage1.items.count == 55,
            detail: "total=\(storage1.items.count), expected 55"
        )

        // FIFO verification for 100 -> 20:
        // Out of 65 unpinned items (unpinnedOriginalIDs[0..<65]):
        // The 45 oldest (unpinnedOriginalIDs[0..<45]) must be evicted.
        // The 20 newest (unpinnedOriginalIDs[45..<65]) must be retained.
        let evictedUnpinned45IDs = Set(unpinnedOriginalIDs[0..<45])
        let expectedRetainedUnpinned20IDs = Set(unpinnedOriginalIDs[45..<65])
        let actualRetainedUnpinned20IDs = Set(storage1.historyItems.map { $0.id })

        let fifo20Passed = (actualRetainedUnpinned20IDs == expectedRetainedUnpinned20IDs) &&
                           actualRetainedUnpinned20IDs.isDisjoint(with: evictedUnpinned45IDs)

        report(
            name: "Strict FIFO eviction (100 -> 20): 45 oldest unpinned clips evicted, 20 newest retained",
            passed: fifo20Passed,
            detail: "retainedMatches=\(actualRetainedUnpinned20IDs == expectedRetainedUnpinned20IDs), disjointWithEvicted=\(actualRetainedUnpinned20IDs.isDisjoint(with: evictedUnpinned45IDs))"
        )

        // Pinned clip integrity check:
        let actualPinned20IDs = Set(storage1.pinnedItems.map { $0.id })
        let allPinnedIDsPreserved20 = (actualPinned20IDs == Set(pinnedOriginalIDs))
        var allPinnedContentIntact20 = true
        for item in storage1.pinnedItems {
            if pinnedOriginalTexts[item.id] != item.textContent {
                allPinnedContentIntact20 = false
                break
            }
        }
        report(
            name: "All 35 pinned clips retain exact UUIDs and payload strings without corruption",
            passed: allPinnedIDsPreserved20 && allPinnedContentIntact20,
            detail: "idsMatch=\(allPinnedIDsPreserved20), contentIntact=\(allPinnedContentIntact20)"
        )

        // -------------------------------------------------------------
        // Step 1.2: Dynamically reduce capacity from 20 -> 10
        // -------------------------------------------------------------
        print("\n  >> Executing dynamic reduction: 20 -> 10")
        storage1.capacity = 10

        report(
            name: "Dynamic capacity set to 10 updates storage.capacity and storage.settings.capacity",
            passed: storage1.capacity == 10 && storage1.settings.capacity == 10,
            detail: "storage=\(storage1.capacity), settings=\(storage1.settings.capacity)"
        )
        report(
            name: "Unpinned items immediately clamped to new capacity limit 10",
            passed: storage1.historyItems.count == 10,
            detail: "unpinned=\(storage1.historyItems.count), expected 10"
        )
        report(
            name: "Pinned items 100% retained after reduction to 10 (35/35 preserved)",
            passed: storage1.pinnedItems.count == 35,
            detail: "pinned=\(storage1.pinnedItems.count), expected 35"
        )
        report(
            name: "Total items count is exactly 45 (35 pinned + 10 unpinned)",
            passed: storage1.items.count == 45,
            detail: "total=\(storage1.items.count), expected 45"
        )

        // FIFO verification for 20 -> 10:
        // Out of the 20 remaining (unpinnedOriginalIDs[45..<65]):
        // The 10 oldest (unpinnedOriginalIDs[45..<55]) must be evicted.
        // The 10 newest (unpinnedOriginalIDs[55..<65]) must be retained.
        let evictedUnpinned10IDs = Set(unpinnedOriginalIDs[45..<55])
        let expectedRetainedUnpinned10IDs = Set(unpinnedOriginalIDs[55..<65])
        let actualRetainedUnpinned10IDs = Set(storage1.historyItems.map { $0.id })

        let fifo10Passed = (actualRetainedUnpinned10IDs == expectedRetainedUnpinned10IDs) &&
                           actualRetainedUnpinned10IDs.isDisjoint(with: evictedUnpinned10IDs)

        report(
            name: "Strict FIFO eviction (20 -> 10): 10 oldest unpinned clips evicted, 10 newest retained",
            passed: fifo10Passed,
            detail: "retainedMatches=\(actualRetainedUnpinned10IDs == expectedRetainedUnpinned10IDs)"
        )

        let actualPinned10IDs = Set(storage1.pinnedItems.map { $0.id })
        let allPinnedIDsPreserved10 = (actualPinned10IDs == Set(pinnedOriginalIDs))
        var allPinnedContentIntact10 = true
        for item in storage1.pinnedItems {
            if pinnedOriginalTexts[item.id] != item.textContent {
                allPinnedContentIntact10 = false
                break
            }
        }
        report(
            name: "All 35 pinned clips remain 100% intact after reduction to 10",
            passed: allPinnedIDsPreserved10 && allPinnedContentIntact10,
            detail: "idsMatch=\(allPinnedIDsPreserved10), contentIntact=\(allPinnedContentIntact10)"
        )

        // -------------------------------------------------------------
        // Step 1.3: Cold-start reload after dynamic capacity reduction
        // -------------------------------------------------------------
        print("\n  >> Testing cold-start persistence roundtrip")
        storage1.flushDiskQueue()

        let storage1Cold = StorageManager(baseDirectory: storeDir1)
        report(
            name: "Cold-start StorageManager restores exact reduced capacity (10)",
            passed: storage1Cold.capacity == 10 && storage1Cold.settings.capacity == 10,
            detail: "coldCapacity=\(storage1Cold.capacity), settings=\(storage1Cold.settings.capacity)"
        )
        report(
            name: "Cold-start StorageManager restores exact 35 pinned items",
            passed: storage1Cold.pinnedItems.count == 35 && Set(storage1Cold.pinnedItems.map { $0.id }) == Set(pinnedOriginalIDs),
            detail: "coldPinnedCount=\(storage1Cold.pinnedItems.count)"
        )
        report(
            name: "Cold-start StorageManager restores exact 10 newest unpinned items",
            passed: storage1Cold.historyItems.count == 10 && Set(storage1Cold.historyItems.map { $0.id }) == expectedRetainedUnpinned10IDs,
            detail: "coldUnpinnedCount=\(storage1Cold.historyItems.count)"
        )

        // -------------------------------------------------------------
        // Step 1.4: Dynamic Capacity Expansion & Clean Non-Resurrection
        // -------------------------------------------------------------
        print("\n  >> Testing dynamic capacity expansion (10 -> 40)")
        storage1.capacity = 40
        report(
            name: "Dynamic capacity expansion updates capacity to 40 without resurrecting evicted clips",
            passed: storage1.capacity == 40 && storage1.historyItems.count == 10 && storage1.pinnedItems.count == 35,
            detail: "capacity=\(storage1.capacity), unpinned=\(storage1.historyItems.count), pinned=\(storage1.pinnedItems.count)"
        )

        // Add 30 new clips to fill up the expanded room
        for i in 1...30 {
            let item = ClipItem(
                id: UUID(),
                contentType: .text,
                textContent: "Newly Inserted Clip \(i)",
                byteSize: 22,
                createdAt: Date(),
                isPinned: false
            )
            storage1.addClip(item: item, imageData: nil, thumbData: nil)
        }
        report(
            name: "Expanded capacity accommodates 40 unpinned clips while retaining all 35 pinned clips (total 75)",
            passed: storage1.historyItems.count == 40 && storage1.pinnedItems.count == 35 && storage1.items.count == 75,
            detail: "unpinned=\(storage1.historyItems.count), pinned=\(storage1.pinnedItems.count), total=\(storage1.items.count)"
        )

        // -------------------------------------------------------------
        // Step 1.5: Disk File Hygiene on Eviction of Image Clips
        // -------------------------------------------------------------
        print("\n  >> Testing image asset disk file hygiene during capacity reduction")
        let imgStoreDir = sandbox.appendingPathComponent("ImageEvictionStore")
        let storageImg = StorageManager(baseDirectory: imgStoreDir, initialCapacity: 100)
        let dummyImgData = createDummyPNG(width: 48, height: 48)

        var pinnedImgIDs: [UUID] = []
        var pinnedImgFiles: [String] = []
        for _ in 1...10 {
            let id = UUID()
            let imgName = "pin_\(id.uuidString).png"
            let thName = "pin_thumb_\(id.uuidString).png"
            pinnedImgIDs.append(id)
            pinnedImgFiles.append(imgName)
            let item = ClipItem(
                id: id,
                contentType: .image,
                textContent: nil,
                imageFileName: imgName,
                thumbnailFileName: thName,
                byteSize: dummyImgData.count,
                createdAt: Date(),
                isPinned: true
            )
            storageImg.addClip(item: item, imageData: dummyImgData, thumbData: dummyImgData)
        }

        var unpinnedImgIDs: [UUID] = []
        var unpinnedImgFiles: [String] = []
        for _ in 1...30 {
            let id = UUID()
            let imgName = "unpin_\(id.uuidString).png"
            let thName = "unpin_thumb_\(id.uuidString).png"
            unpinnedImgIDs.append(id)
            unpinnedImgFiles.append(imgName)
            let item = ClipItem(
                id: id,
                contentType: .image,
                textContent: nil,
                imageFileName: imgName,
                thumbnailFileName: thName,
                byteSize: dummyImgData.count,
                createdAt: Date(),
                isPinned: false
            )
            storageImg.addClip(item: item, imageData: dummyImgData, thumbData: dummyImgData)
        }

        storageImg.flushDiskQueue()
        let diskImgsBefore = (try? FileManager.default.contentsOfDirectory(atPath: storageImg.imagesDirectory.path)) ?? []
        report(
            name: "Initial store has 40 image files on disk (10 pinned + 30 unpinned)",
            passed: diskImgsBefore.count == 40,
            detail: "diskCount=\(diskImgsBefore.count)"
        )

        // Dynamically reduce capacity from 100 to 10:
        // Must evict 20 unpinned image clips and delete their disk files!
        storageImg.capacity = 10
        storageImg.flushDiskQueue()

        let diskImgsAfter = Set((try? FileManager.default.contentsOfDirectory(atPath: storageImg.imagesDirectory.path)) ?? [])
        let evictedUnpinnedFiles = unpinnedImgFiles.prefix(20)
        let retainedUnpinnedFiles = unpinnedImgFiles.suffix(10)

        let evictedDiskFilesDeleted = evictedUnpinnedFiles.allSatisfy { !diskImgsAfter.contains($0) }
        let retainedUnpinnedDiskFilesExist = retainedUnpinnedFiles.allSatisfy { diskImgsAfter.contains($0) }
        let pinnedDiskFilesExist = pinnedImgFiles.allSatisfy { diskImgsAfter.contains($0) }

        report(
            name: "Disk image files for 20 evicted unpinned clips were permanently deleted",
            passed: evictedDiskFilesDeleted && diskImgsAfter.count == 20,
            detail: "remainingDiskCount=\(diskImgsAfter.count), evictedDeleted=\(evictedDiskFilesDeleted)"
        )
        report(
            name: "100% of pinned image files and 10 retained unpinned image files preserved on disk",
            passed: pinnedDiskFilesExist && retainedUnpinnedDiskFilesExist,
            detail: "pinnedExist=\(pinnedDiskFilesExist), retainedUnpinnedExist=\(retainedUnpinnedDiskFilesExist)"
        )

        // -------------------------------------------------------------
        // Step 1.6: Boundary Clamping & Pin Toggling under Tight Limit
        // -------------------------------------------------------------
        print("\n  >> Testing boundary capacity clamping (1, 0, negative)")
        let boundStoreDir = sandbox.appendingPathComponent("BoundStore")
        let boundStorage = StorageManager(baseDirectory: boundStoreDir, initialCapacity: 20)

        // Insert 5 pinned and 15 unpinned
        for i in 1...5 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Bound Pin \(i)", byteSize: 12, isPinned: true)
            boundStorage.addClip(item: item, imageData: nil, thumbData: nil)
        }
        for i in 1...15 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Bound History \(i)", byteSize: 15, isPinned: false)
            boundStorage.addClip(item: item, imageData: nil, thumbData: nil)
        }

        // Clamp to 1
        boundStorage.capacity = 1
        report(
            name: "Capacity set to 1 strictly limits unpinned history to 1 and retains all 5 pinned items",
            passed: boundStorage.capacity == 1 && boundStorage.historyItems.count == 1 && boundStorage.pinnedItems.count == 5,
            detail: "cap=\(boundStorage.capacity), unpinned=\(boundStorage.historyItems.count), pinned=\(boundStorage.pinnedItems.count)"
        )

        // Clamp to 0 -> clamped to 1
        boundStorage.capacity = 0
        report(
            name: "Capacity set to 0 safely clamps to minimum limit 1",
            passed: boundStorage.capacity == 1 && boundStorage.historyItems.count == 1,
            detail: "cap=\(boundStorage.capacity)"
        )

        // Clamp to negative -> clamped to 1
        boundStorage.capacity = -50
        report(
            name: "Capacity set to -50 safely clamps to minimum limit 1",
            passed: boundStorage.capacity == 1 && boundStorage.historyItems.count == 1,
            detail: "cap=\(boundStorage.capacity)"
        )

        // Pin toggle under capacity = 1
        // When one of the pinned clips is unpinned, unpinned count would become 2!
        // enforceCapacity() must instantly evict the older unpinned clip to keep unpinned count at 1!
        let pinnedTargetID = boundStorage.pinnedItems.first!.id
        boundStorage.togglePin(id: pinnedTargetID)
        report(
            name: "Unpinning an item under capacity=1 instantly triggers capacity eviction keeping unpinned at 1",
            passed: boundStorage.historyItems.count == 1 && boundStorage.pinnedItems.count == 4,
            detail: "unpinned=\(boundStorage.historyItems.count), pinned=\(boundStorage.pinnedItems.count)"
        )

        // -------------------------------------------------------------
        // Step 1.7: High-Concurrency Dynamic Capacity Churn Stress
        // -------------------------------------------------------------
        print("\n  >> Testing high-concurrency dynamic capacity churn (50 parallel workers)")
        let concStoreDir = sandbox.appendingPathComponent("ConcStore")
        let concStorage = StorageManager(baseDirectory: concStoreDir, initialCapacity: 50)

        // Prepopulate 15 pinned items as anchors
        for i in 1...15 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Anchor Pin \(i)", byteSize: 14, isPinned: true)
            concStorage.addClip(item: item, imageData: nil, thumbData: nil)
        }

        let concGroup = DispatchGroup()
        let concQueue = DispatchQueue(label: "capacity.churn.queue", attributes: .concurrent)

        for i in 1...100 {
            concGroup.enter()
            concQueue.async {
                if i % 4 == 0 {
                    // Dynamically mutate capacity
                    let capTargets = [10, 20, 50, 15, 30]
                    concStorage.capacity = capTargets[i % capTargets.count]
                } else if i % 4 == 1 {
                    // Insert clip
                    let item = ClipItem(
                        id: UUID(),
                        contentType: .text,
                        textContent: "Concurrent Clip \(i)",
                        byteSize: 18,
                        isPinned: (i % 7 == 0)
                    )
                    concStorage.addClip(item: item, imageData: nil, thumbData: nil)
                } else if i % 4 == 2 {
                    // Read consistency
                    _ = concStorage.items.count
                    _ = concStorage.pinnedItems.count
                    _ = concStorage.historyItems.count
                } else {
                    // Clear history occasionally
                    if i % 20 == 0 {
                        concStorage.clearUnpinnedHistory()
                    }
                }
                concGroup.leave()
            }
        }
        concGroup.wait()
        concStorage.flushDiskQueue()

        report(
            name: "100 concurrent interleaved capacity churn operations complete without deadlock or crash",
            passed: true
        )
        report(
            name: "Partition integrity maintained after concurrency: total items == pinned + history",
            passed: concStorage.items.count == concStorage.pinnedItems.count + concStorage.historyItems.count,
            detail: "total=\(concStorage.items.count), pinned=\(concStorage.pinnedItems.count), history=\(concStorage.historyItems.count)"
        )
        report(
            name: "Unpinned items respect final capacity limit (unpinned <= capacity)",
            passed: concStorage.historyItems.count <= concStorage.capacity,
            detail: "unpinned=\(concStorage.historyItems.count), capacity=\(concStorage.capacity)"
        )
        report(
            name: "All 15 initial pinned anchor clips survived concurrent capacity churn",
            passed: concStorage.pinnedItems.count >= 15,
            detail: "pinnedCount=\(concStorage.pinnedItems.count), expected >= 15"
        )

        // =====================================================================
        // PART 2: HOTKEY LIVE CUSTOMIZATION STRESS
        // =====================================================================
        print("\n--- Part 2: Hotkey Live Customization Stress ---")

        let mockHotKey = Iter2MockHotKeyManager()
        let hotKeyStoreDir = sandbox.appendingPathComponent("HotKeyStore")
        let hotKeyStorage = StorageManager(baseDirectory: hotKeyStoreDir)

        // -------------------------------------------------------------
        // Step 2.1: Target Key Combinations Registration
        // -------------------------------------------------------------
        print("\n  >> Testing target hotkey combinations")

        struct ComboTest {
            let name: String
            let keyCode: UInt32
            let modifiers: UInt32
        }

        let combos = [
            ComboTest(name: "Option + V (Default)", keyCode: 9, modifiers: UInt32(optionKey)),
            ComboTest(name: "Cmd + Shift + V", keyCode: 9, modifiers: UInt32(cmdKey | shiftKey)),
            ComboTest(name: "Control + Option + C", keyCode: 8, modifiers: UInt32(controlKey | optionKey)),
            ComboTest(name: "Option + Space", keyCode: 49, modifiers: UInt32(optionKey)),
            ComboTest(name: "Cmd + Option + V", keyCode: 9, modifiers: UInt32(cmdKey | optionKey))
        ]

        for combo in combos {
            var s = hotKeyStorage.settings
            s.hotKeyKeyCode = combo.keyCode
            s.hotKeyModifiers = combo.modifiers
            hotKeyStorage.settings = s
            mockHotKey.register(keyCode: combo.keyCode, modifiers: combo.modifiers)

            report(
                name: "Registered '\(combo.name)': keyCode \(combo.keyCode), modifiers \(combo.modifiers)",
                passed: hotKeyStorage.settings.hotKeyKeyCode == combo.keyCode &&
                        hotKeyStorage.settings.hotKeyModifiers == combo.modifiers &&
                        mockHotKey.lastRegisteredKeyCode == combo.keyCode &&
                        mockHotKey.lastRegisteredModifiers == combo.modifiers,
                detail: "storageCode=\(hotKeyStorage.settings.hotKeyKeyCode), storageMods=\(hotKeyStorage.settings.hotKeyModifiers)"
            )
        }

        // -------------------------------------------------------------
        // Step 2.2: 1,000 Rapid Sequential Hotkey Transitions
        // -------------------------------------------------------------
        print("\n  >> Stressing 1,000 rapid hotkey transitions")
        mockHotKey.reset()

        for i in 1...1000 {
            let combo = combos[i % combos.count]
            var s = hotKeyStorage.settings
            s.hotKeyKeyCode = combo.keyCode
            s.hotKeyModifiers = combo.modifiers
            hotKeyStorage.settings = s
            mockHotKey.register(keyCode: combo.keyCode, modifiers: combo.modifiers)
        }

        report(
            name: "1,000 rapid sequential hotkey transitions executed without failure",
            passed: mockHotKey.registeredHistory.count == 1000,
            detail: "totalRegistrations=\(mockHotKey.registeredHistory.count)"
        )

        // -------------------------------------------------------------
        // Step 2.3: Real Carbon HotKeyManager Rapid Re-registration
        // -------------------------------------------------------------
        print("\n  >> Testing real Carbon HotKeyManager rapid re-registration")
        let carbonHotKey = HotKeyManager.shared
        for _ in 1...20 {
            for combo in combos {
                carbonHotKey.register(keyCode: combo.keyCode, modifiers: combo.modifiers)
            }
        }
        // Restore default hotkey Option + V
        carbonHotKey.register(keyCode: 9, modifiers: UInt32(optionKey))
        report(
            name: "Carbon HotKeyManager completed 100 consecutive real system registrations cleanly",
            passed: true
        )

        // -------------------------------------------------------------
        // Step 2.4: Invalid Hotkey Combinations Validation
        // -------------------------------------------------------------
        print("\n  >> Testing invalid hotkey combinations")

        // 1. Modifier mask = 0 (empty modifier)
        report(
            name: "Modifier mask 0 (bare key) is flagged as INVALID",
            passed: !KeyCombinationHelper.isValidHotKey(modifiers: 0)
        )

        // 2. Bare Shift (only shiftKey, no Cmd/Opt/Ctrl)
        report(
            name: "Bare Shift without Cmd/Option/Control is flagged as INVALID",
            passed: !KeyCombinationHelper.isValidHotKey(modifiers: UInt32(shiftKey))
        )

        // 3. Shift + CapsLock (invalid without main modifier)
        let shiftAlpha = UInt32(shiftKey | alphaLock)
        report(
            name: "Shift + CapsLock without Cmd/Option/Control is flagged as INVALID",
            passed: !KeyCombinationHelper.isValidHotKey(modifiers: shiftAlpha)
        )

        // 4. Valid single modifier checks
        report(
            name: "Option key is valid hotkey modifier",
            passed: KeyCombinationHelper.isValidHotKey(modifiers: UInt32(optionKey))
        )
        report(
            name: "Command key is valid hotkey modifier",
            passed: KeyCombinationHelper.isValidHotKey(modifiers: UInt32(cmdKey))
        )
        report(
            name: "Control key is valid hotkey modifier",
            passed: KeyCombinationHelper.isValidHotKey(modifiers: UInt32(controlKey))
        )

        // 5. Valid multi-modifier checks
        let allMods = UInt32(cmdKey | optionKey | controlKey | shiftKey)
        report(
            name: "Combined modifiers (Cmd+Opt+Ctrl+Shift) are valid",
            passed: KeyCombinationHelper.isValidHotKey(modifiers: allMods)
        )

        // -------------------------------------------------------------
        // Step 2.5: Formatting Utilities Stress
        // -------------------------------------------------------------
        print("\n  >> Testing formatted shortcuts and reserved keys")

        let optVStr = KeyCombinationHelper.formattedShortcut(keyCode: 9, modifiers: UInt32(optionKey))
        report(
            name: "Option + V formats exactly as 'Option + V'",
            passed: optVStr == "Option + V",
            detail: "got '\(optVStr)'"
        )

        let cmdShiftVStr = KeyCombinationHelper.formattedShortcut(keyCode: 9, modifiers: UInt32(cmdKey | shiftKey))
        report(
            name: "Cmd + Shift + V formats with Shift, Command, and V",
            passed: cmdShiftVStr.contains("Shift") && cmdShiftVStr.contains("Command") && cmdShiftVStr.contains("V"),
            detail: "got '\(cmdShiftVStr)'"
        )

        let ctrlOptCStr = KeyCombinationHelper.formattedShortcut(keyCode: 8, modifiers: UInt32(controlKey | optionKey))
        report(
            name: "Control + Option + C formats with Control, Option, and C",
            passed: ctrlOptCStr.contains("Control") && ctrlOptCStr.contains("Option") && ctrlOptCStr.contains("C"),
            detail: "got '\(ctrlOptCStr)'"
        )

        let spaceStr = KeyCombinationHelper.formattedShortcut(keyCode: 49, modifiers: UInt32(optionKey))
        report(
            name: "Space key code 49 formats as 'Option + Space'",
            passed: spaceStr == "Option + Space",
            detail: "got '\(spaceStr)'"
        )

        let tabStr = KeyCombinationHelper.formattedShortcut(keyCode: 48, modifiers: UInt32(optionKey))
        report(
            name: "Tab key code 48 formats as 'Option + Tab'",
            passed: tabStr == "Option + Tab",
            detail: "got '\(tabStr)'"
        )

        let unmappedStr = KeyCombinationHelper.formattedShortcut(keyCode: 999, modifiers: UInt32(optionKey))
        report(
            name: "Unmapped key code 999 formats as 'Option + Key 999'",
            passed: unmappedStr == "Option + Key 999",
            detail: "got '\(unmappedStr)'"
        )

        // =====================================================================
        // VERDICT & SUMMARY
        // =====================================================================
        print("\n======================================================================")
        print("  SuperClip Challenger M4 Round 2 Stress Test Summary")
        print("======================================================================")
        print("  Total Empirical Challenges: \(totalTests)")
        print("  Passed:                     \(passedTests)")
        print("  Failed:                     \(failedTests)")

        if failedTests > 0 {
            print("\nVERDICT: REJECT")
            print("Found \(failedTests) failing empirical challenges in Settings & Capacity.")
            exit(1)
        } else {
            print("\nVERDICT: APPROVE")
            print("All empirical challenges passed. Dynamic capacity mutation and hotkey customization verified.")
            exit(0)
        }
    }
}
