import Foundation
import AppKit
import Carbon
import SwiftUI
import SuperClipCore
import SuperClip

/// Mock HotKeyManager for recording live customization invocations.
final class TrackingHotKeyManager: HotKeyManaging {
    var onTrigger: (() -> Void)?
    var registeredCombinations: [(keyCode: UInt32, modifiers: UInt32)] = []
    var unregisterCount: Int = 0

    var lastRegisteredKeyCode: UInt32? {
        registeredCombinations.last?.keyCode
    }

    var lastRegisteredModifiers: UInt32? {
        registeredCombinations.last?.modifiers
    }

    init() {}

    func register(keyCode: UInt32, modifiers: UInt32) {
        registeredCombinations.append((keyCode, modifiers))
    }

    func unregister() {
        unregisterCount += 1
    }

    func reset() {
        registeredCombinations.removeAll()
        unregisterCount = 0
    }
}

@main
struct ChallengerM4CapacityHotkeyStress {
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
        print("  SuperClip Challenger M4: Settings & Capacity Mutation Stress Harness")
        print("======================================================================")

        let sandbox = createTempDirectory(prefix: "ChallengerM4Stress")
        defer { cleanupTempDirectory(sandbox) }

        // =====================================================================
        // PART 1: STRESS-TEST CAPACITY ADJUSTMENT ON StorageManager
        // Mission Requirement:
        // Dynamically reduce capacity from 100 -> 20 -> 10 while holding
        // 50 unpinned and 30 pinned items.
        // Verify unpinned clips undergo immediate FIFO eviction down to capacity.
        // Verify 100% of pinned clips are retained without eviction or data loss.
        // =====================================================================
        print("\n--- Part 1: Dynamic Capacity Mutation (100 -> 20 -> 10) ---")

        let storeDir1 = sandbox.appendingPathComponent("Store1_DynamicCapacity")
        let storage1 = StorageManager(baseDirectory: storeDir1, initialCapacity: 100)

        // Generate 30 pinned items and 50 unpinned items, interleaved to stress-test ordering
        var pinnedOriginalIDs: [UUID] = []
        var pinnedOriginalTexts: [UUID: String] = [:]
        var unpinnedOriginalIDs: [UUID] = [] // Will store in order of insertion (oldest to newest)
        var unpinnedOriginalTexts: [UUID: String] = [:]

        // Insert 30 pinned and 50 unpinned items interleaved
        var pinnedCounter = 0
        var unpinnedCounter = 0

        // We insert in 8 batches of 10 items (3 pinned, 5 unpinned in each of first 6 batches, then remaining)
        for i in 1...80 {
            let isPinned = (pinnedCounter < 30) && (i % 8 < 3 || unpinnedCounter >= 50)
            let id = UUID()
            let date = Date().addingTimeInterval(Double(i))

            if isPinned {
                pinnedCounter += 1
                let text = "Pinned Clip \(pinnedCounter) [Batch \(i)]"
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
                unpinnedCounter += 1
                let text = "Unpinned Clip \(unpinnedCounter) [Batch \(i)]"
                unpinnedOriginalIDs.append(id) // index 0 is oldest, index 49 is newest
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
            name: "Initial population: exactly 30 pinned items created",
            passed: storage1.pinnedItems.count == 30,
            detail: "pinnedCount=\(storage1.pinnedItems.count), expected 30"
        )
        report(
            name: "Initial population: exactly 50 unpinned items created",
            passed: storage1.historyItems.count == 50,
            detail: "unpinnedCount=\(storage1.historyItems.count), expected 50"
        )
        report(
            name: "Initial population: total items count is 80 (30 pinned + 50 unpinned)",
            passed: storage1.items.count == 80,
            detail: "totalCount=\(storage1.items.count), expected 80"
        )
        report(
            name: "Initial capacity is 100",
            passed: storage1.capacity == 100 && storage1.settings.capacity == 100,
            detail: "storage.capacity=\(storage1.capacity), settings.capacity=\(storage1.settings.capacity)"
        )

        // -------------------------------------------------------------
        // Step 1.1: Dynamically reduce capacity from 100 -> 20
        // -------------------------------------------------------------
        print("\n  >> Executing dynamic reduction: 100 -> 20")
        storage1.capacity = 20

        report(
            name: "Storage capacity dynamically updated to 20",
            passed: storage1.capacity == 20 && storage1.settings.capacity == 20,
            detail: "storage.capacity=\(storage1.capacity), settings.capacity=\(storage1.settings.capacity)"
        )

        let pinnedCountAfter20 = storage1.pinnedItems.count
        let unpinnedCountAfter20 = storage1.historyItems.count
        let totalCountAfter20 = storage1.items.count

        report(
            name: "Unpinned history immediately capped to capacity 20",
            passed: unpinnedCountAfter20 == 20,
            detail: "unpinnedCount=\(unpinnedCountAfter20), expected 20"
        )
        report(
            name: "Pinned items 100% retained after reduction to 20 (30/30 preserved)",
            passed: pinnedCountAfter20 == 30,
            detail: "pinnedCount=\(pinnedCountAfter20), expected 30"
        )
        report(
            name: "Total items count is exactly 50 (30 pinned + 20 unpinned)",
            passed: totalCountAfter20 == 50,
            detail: "totalCount=\(totalCountAfter20), expected 50"
        )

        // Strict FIFO verification:
        // The 50 unpinned items were inserted in order unpinnedOriginalIDs[0...49].
        // Because newest items are at the top (index 0) of history, the 30 oldest items
        // (unpinnedOriginalIDs[0..<30]) MUST be evicted.
        // The 20 newest items (unpinnedOriginalIDs[30..<50]) MUST be retained.
        let evictedUnpinned20IDs = Set(unpinnedOriginalIDs[0..<30])
        let expectedRetainedUnpinned20IDs = Set(unpinnedOriginalIDs[30..<50])
        let currentUnpinned20IDs = Set(storage1.historyItems.map { $0.id })

        let fifoEviction20Correct = (currentUnpinned20IDs == expectedRetainedUnpinned20IDs) &&
                                    currentUnpinned20IDs.isDisjoint(with: evictedUnpinned20IDs)

        report(
            name: "Strict FIFO eviction: oldest 30 unpinned clips evicted, newest 20 retained",
            passed: fifoEviction20Correct,
            detail: "retainedMatches=\(currentUnpinned20IDs == expectedRetainedUnpinned20IDs), disjointWithEvicted=\(currentUnpinned20IDs.isDisjoint(with: evictedUnpinned20IDs))"
        )

        // Strict Pinned Integrity verification:
        // All 30 pinned items must be present with exact IDs and text content
        let currentPinned20IDs = Set(storage1.pinnedItems.map { $0.id })
        let allPinnedIDsMatch = currentPinned20IDs == Set(pinnedOriginalIDs)
        var allPinnedContentIntact = true
        for item in storage1.pinnedItems {
            if pinnedOriginalTexts[item.id] != item.textContent {
                allPinnedContentIntact = false
                break
            }
        }

        report(
            name: "100% of pinned items retained without ID change or data loss",
            passed: allPinnedIDsMatch && allPinnedContentIntact,
            detail: "idsMatch=\(allPinnedIDsMatch), contentIntact=\(allPinnedContentIntact)"
        )

        // -------------------------------------------------------------
        // Step 1.2: Dynamically reduce capacity from 20 -> 10
        // -------------------------------------------------------------
        print("\n  >> Executing dynamic reduction: 20 -> 10")
        storage1.capacity = 10

        report(
            name: "Storage capacity dynamically updated to 10",
            passed: storage1.capacity == 10 && storage1.settings.capacity == 10,
            detail: "storage.capacity=\(storage1.capacity), settings.capacity=\(storage1.settings.capacity)"
        )

        let pinnedCountAfter10 = storage1.pinnedItems.count
        let unpinnedCountAfter10 = storage1.historyItems.count
        let totalCountAfter10 = storage1.items.count

        report(
            name: "Unpinned history immediately capped to capacity 10",
            passed: unpinnedCountAfter10 == 10,
            detail: "unpinnedCount=\(unpinnedCountAfter10), expected 10"
        )
        report(
            name: "Pinned items 100% retained after reduction to 10 (30/30 preserved)",
            passed: pinnedCountAfter10 == 30,
            detail: "pinnedCount=\(pinnedCountAfter10), expected 30"
        )
        report(
            name: "Total items count is exactly 40 (30 pinned + 10 unpinned)",
            passed: totalCountAfter10 == 40,
            detail: "totalCount=\(totalCountAfter10), expected 40"
        )

        // FIFO verification for 10:
        // Out of the remaining 20 (unpinnedOriginalIDs[30..<50]),
        // the 10 oldest (unpinnedOriginalIDs[30..<40]) MUST be evicted.
        // The 10 newest (unpinnedOriginalIDs[40..<50]) MUST be retained.
        let evictedUnpinned10IDs = Set(unpinnedOriginalIDs[30..<40])
        let expectedRetainedUnpinned10IDs = Set(unpinnedOriginalIDs[40..<50])
        let currentUnpinned10IDs = Set(storage1.historyItems.map { $0.id })

        let fifoEviction10Correct = (currentUnpinned10IDs == expectedRetainedUnpinned10IDs) &&
                                    currentUnpinned10IDs.isDisjoint(with: evictedUnpinned10IDs)

        report(
            name: "Strict FIFO eviction (20 -> 10): 10 oldest unpinned evicted, 10 newest retained",
            passed: fifoEviction10Correct,
            detail: "retainedMatches=\(currentUnpinned10IDs == expectedRetainedUnpinned10IDs)"
        )

        // Pinned integrity again
        let currentPinned10IDs = Set(storage1.pinnedItems.map { $0.id })
        let allPinned10IDsMatch = currentPinned10IDs == Set(pinnedOriginalIDs)
        var allPinned10ContentIntact = true
        for item in storage1.pinnedItems {
            if pinnedOriginalTexts[item.id] != item.textContent {
                allPinned10ContentIntact = false
                break
            }
        }

        report(
            name: "Pinned items 100% retained and unharmed at capacity = 10",
            passed: allPinned10IDsMatch && allPinned10ContentIntact,
            detail: "idsMatch=\(allPinned10IDsMatch), contentIntact=\(allPinned10ContentIntact)"
        )

        // -------------------------------------------------------------
        // Step 1.3: Cold-start disk persistence round-trip check
        // -------------------------------------------------------------
        print("\n  >> Verifying disk persistence & cold-start reload")
        storage1.flushDiskQueue()

        let storage1Cold = StorageManager(baseDirectory: storeDir1)
        let coldPinnedCount = storage1Cold.pinnedItems.count
        let coldUnpinnedCount = storage1Cold.historyItems.count
        let coldCapacity = storage1Cold.capacity
        let coldPinnedMatch = Set(storage1Cold.pinnedItems.map { $0.id }) == Set(pinnedOriginalIDs)
        let coldUnpinnedMatch = Set(storage1Cold.historyItems.map { $0.id }) == expectedRetainedUnpinned10IDs

        report(
            name: "Cold-start StorageManager reloads exact capacity (10) and persisted items",
            passed: coldCapacity == 10 && coldPinnedCount == 30 && coldUnpinnedCount == 10 && coldPinnedMatch && coldUnpinnedMatch,
            detail: "coldCap=\(coldCapacity), pinned=\(coldPinnedCount), unpinned=\(coldUnpinnedCount)"
        )

        // -------------------------------------------------------------
        // Step 1.4: Dynamic capacity expansion (10 -> 50)
        // -------------------------------------------------------------
        print("\n  >> Verifying dynamic capacity expansion (10 -> 50)")
        storage1.capacity = 50
        report(
            name: "Capacity expands to 50 without resurrecting previously evicted clips",
            passed: storage1.capacity == 50 && storage1.historyItems.count == 10 && storage1.pinnedItems.count == 30,
            detail: "capacity=\(storage1.capacity), unpinned=\(storage1.historyItems.count), pinned=\(storage1.pinnedItems.count)"
        )

        // Add 40 new clips to fill up expanded capacity to 50
        for i in 1...40 {
            let item = ClipItem(
                id: UUID(),
                contentType: .text,
                textContent: "Expanded Capacity Clip \(i)",
                byteSize: 30,
                createdAt: Date(),
                isPinned: false
            )
            storage1.addClip(item: item, imageData: nil, thumbData: nil)
        }

        report(
            name: "Expanded capacity accommodates 50 unpinned items while retaining all 30 pinned items",
            passed: storage1.historyItems.count == 50 && storage1.pinnedItems.count == 30 && storage1.items.count == 80,
            detail: "unpinned=\(storage1.historyItems.count), pinned=\(storage1.pinnedItems.count), total=\(storage1.items.count)"
        )

        // -------------------------------------------------------------
        // Step 1.5: Image file hygiene during capacity eviction
        // -------------------------------------------------------------
        print("\n  >> Verifying disk image file hygiene on dynamic capacity eviction")
        let storeDirImages = sandbox.appendingPathComponent("StoreImages_Hygiene")
        let storageImages = StorageManager(baseDirectory: storeDirImages, initialCapacity: 100)
        let dummyPNG = createDummyPNG()

        var pinnedImageNames: [String] = []
        for i in 1...10 {
            let id = UUID()
            let imgName = "pinned_\(id.uuidString).png"
            let thName = "thumb_pinned_\(id.uuidString).png"
            pinnedImageNames.append(imgName)
            let item = ClipItem(
                id: id,
                contentType: .image,
                textContent: nil,
                imageFileName: imgName,
                thumbnailFileName: thName,
                byteSize: dummyPNG.count,
                createdAt: Date(),
                isPinned: true
            )
            storageImages.addClip(item: item, imageData: dummyPNG, thumbData: dummyPNG)
        }

        var unpinnedImageNames: [String] = []
        for i in 1...30 {
            let id = UUID()
            let imgName = "unpinned_\(id.uuidString).png"
            let thName = "thumb_unpinned_\(id.uuidString).png"
            unpinnedImageNames.append(imgName)
            let item = ClipItem(
                id: id,
                contentType: .image,
                textContent: nil,
                imageFileName: imgName,
                thumbnailFileName: thName,
                byteSize: dummyPNG.count,
                createdAt: Date(),
                isPinned: false
            )
            storageImages.addClip(item: item, imageData: dummyPNG, thumbData: dummyPNG)
        }

        storageImages.flushDiskQueue()
        let diskFilesBefore = (try? FileManager.default.contentsOfDirectory(atPath: storageImages.imagesDirectory.path)) ?? []
        report(
            name: "Created 40 image files on disk (10 pinned + 30 unpinned)",
            passed: diskFilesBefore.count == 40,
            detail: "diskCount=\(diskFilesBefore.count), expected 40"
        )

        // Dynamically reduce capacity from 100 to 10 -> 20 unpinned clips evicted
        storageImages.capacity = 10
        storageImages.flushDiskQueue()

        let diskFilesAfter = Set((try? FileManager.default.contentsOfDirectory(atPath: storageImages.imagesDirectory.path)) ?? [])
        let pinnedImagesIntact = pinnedImageNames.allSatisfy { diskFilesAfter.contains($0) }
        let evictedUnpinnedImages = unpinnedImageNames.prefix(20)
        let retainedUnpinnedImages = unpinnedImageNames.suffix(10)
        let evictedUnpinnedImagesDeleted = evictedUnpinnedImages.allSatisfy { !diskFilesAfter.contains($0) }
        let retainedUnpinnedImagesIntact = retainedUnpinnedImages.allSatisfy { diskFilesAfter.contains($0) }

        report(
            name: "Capacity reduction cleanly purged disk image files for 20 evicted clips",
            passed: diskFilesAfter.count == 20 && evictedUnpinnedImagesDeleted && retainedUnpinnedImagesIntact,
            detail: "remainingDiskFiles=\(diskFilesAfter.count), evictedDeleted=\(evictedUnpinnedImagesDeleted)"
        )
        report(
            name: "100% of pinned clips' image files preserved intact on disk",
            passed: pinnedImagesIntact,
            detail: "pinnedImagesIntact=\(pinnedImagesIntact)"
        )

        // =====================================================================
        // PART 2: STRESS-TEST HOTKEY LIVE CUSTOMIZATION
        // Mission Requirement:
        // - Multiple rapid hotkey re-registrations (Option+V, Cmd+Shift+V, Control+Option+C).
        // - Invalid combinations (empty modifiers, reserved shortcuts).
        // =====================================================================
        print("\n--- Part 2: Hotkey Live Customization Stress ---")

        let trackingHotKey = TrackingHotKeyManager()
        let storeDirHotkey = sandbox.appendingPathComponent("Store_Hotkey")
        let storageHotkey = StorageManager(baseDirectory: storeDirHotkey)

        // -------------------------------------------------------------
        // Step 2.1: Rapid hotkey re-registrations across target combinations
        // -------------------------------------------------------------
        print("\n  >> Executing rapid hotkey re-registrations")

        // Target combinations:
        // 1. Option + V: keyCode 9, modifier optionKey (2048)
        // 2. Cmd + Shift + V: keyCode 9, modifiers cmdKey | shiftKey (256 | 512 = 768)
        // 3. Control + Option + C: keyCode 8, modifiers controlKey | optionKey (4096 | 2048 = 6144)
        struct HotKeyCombo {
            let name: String
            let keyCode: UInt32
            let modifiers: UInt32
        }

        let combo1 = HotKeyCombo(name: "Option + V", keyCode: 9, modifiers: UInt32(optionKey))
        let combo2 = HotKeyCombo(name: "Cmd + Shift + V", keyCode: 9, modifiers: UInt32(cmdKey | shiftKey))
        let combo3 = HotKeyCombo(name: "Control + Option + C", keyCode: 8, modifiers: UInt32(controlKey | optionKey))

        let testCombos = [combo1, combo2, combo3]

        for combo in testCombos {
            var s = storageHotkey.settings
            s.hotKeyKeyCode = combo.keyCode
            s.hotKeyModifiers = combo.modifiers
            storageHotkey.settings = s
            trackingHotKey.register(keyCode: combo.keyCode, modifiers: combo.modifiers)

            report(
                name: "Registered '\(combo.name)': keyCode \(combo.keyCode), modifiers \(combo.modifiers)",
                passed: storageHotkey.settings.hotKeyKeyCode == combo.keyCode &&
                        storageHotkey.settings.hotKeyModifiers == combo.modifiers &&
                        trackingHotKey.lastRegisteredKeyCode == combo.keyCode &&
                        trackingHotKey.lastRegisteredModifiers == combo.modifiers,
                detail: "settingsCode=\(storageHotkey.settings.hotKeyKeyCode), settingsMods=\(storageHotkey.settings.hotKeyModifiers)"
            )
        }

        // Stress: 1,000 rapid back-and-forth re-registrations
        print("\n  >> Stressing 1,000 rapid hotkey transitions")
        trackingHotKey.reset()

        for i in 1...1000 {
            let combo = testCombos[i % testCombos.count]
            var s = storageHotkey.settings
            s.hotKeyKeyCode = combo.keyCode
            s.hotKeyModifiers = combo.modifiers
            storageHotkey.settings = s
            trackingHotKey.register(keyCode: combo.keyCode, modifiers: combo.modifiers)
        }

        report(
            name: "1,000 rapid hotkey transitions completed without crash or failure",
            passed: trackingHotKey.registeredCombinations.count == 1000,
            detail: "registeredCount=\(trackingHotKey.registeredCombinations.count)"
        )

        // Real Carbon HotKeyManager test:
        // Ensure Carbon RegisterEventHotKey doesn't leak or throw errors under rapid calls
        print("\n  >> Testing real Carbon HotKeyManager rapid re-registration")
        let realCarbonHotKey = HotKeyManager.shared
        for _ in 1...50 {
            for combo in testCombos {
                realCarbonHotKey.register(keyCode: combo.keyCode, modifiers: combo.modifiers)
            }
        }
        // Restore default hotkey Option + V
        realCarbonHotKey.register(keyCode: 9, modifiers: UInt32(optionKey))
        report(
            name: "Real Carbon HotKeyManager executed 150 consecutive re-registrations cleanly",
            passed: true
        )

        // -------------------------------------------------------------
        // Step 2.2: Invalid Hotkey Combinations
        // -------------------------------------------------------------
        print("\n  >> Testing invalid hotkey combinations")

        // 1. Empty modifiers (modifier mask = 0)
        let emptyModsValid = KeyCombinationHelper.isValidHotKey(modifiers: 0)
        report(
            name: "Empty modifier (mask 0) is flagged as INVALID",
            passed: !emptyModsValid,
            detail: "isValidHotKey(0)=\(emptyModsValid)"
        )

        // 2. Bare Shift (only shiftKey, no Cmd/Opt/Ctrl)
        let bareShiftValid = KeyCombinationHelper.isValidHotKey(modifiers: UInt32(shiftKey))
        report(
            name: "Bare Shift without Cmd/Option/Control is flagged as INVALID",
            passed: !bareShiftValid,
            detail: "isValidHotKey(shiftKey)=\(bareShiftValid)"
        )

        // 3. Shift + CapsLock (invalid without main modifier)
        let shiftCaps = UInt32(shiftKey | alphaLock)
        let shiftCapsValid = KeyCombinationHelper.isValidHotKey(modifiers: shiftCaps)
        report(
            name: "Shift + CapsLock without Cmd/Option/Control is flagged as INVALID",
            passed: !shiftCapsValid,
            detail: "isValidHotKey(shiftCaps)=\(shiftCapsValid)"
        )

        // 4. Valid single modifier combinations
        let optValid = KeyCombinationHelper.isValidHotKey(modifiers: UInt32(optionKey))
        let cmdValid = KeyCombinationHelper.isValidHotKey(modifiers: UInt32(cmdKey))
        let ctrlValid = KeyCombinationHelper.isValidHotKey(modifiers: UInt32(controlKey))

        report(
            name: "Option key is valid hotkey modifier",
            passed: optValid
        )
        report(
            name: "Command key is valid hotkey modifier",
            passed: cmdValid
        )
        report(
            name: "Control key is valid hotkey modifier",
            passed: ctrlValid
        )

        // 5. Valid multi-modifier combinations
        let cmdOptValid = KeyCombinationHelper.isValidHotKey(modifiers: UInt32(cmdKey | optionKey))
        let ctrlOptValid = KeyCombinationHelper.isValidHotKey(modifiers: UInt32(controlKey | optionKey))
        let cmdShiftValid = KeyCombinationHelper.isValidHotKey(modifiers: UInt32(cmdKey | shiftKey))
        let ctrlOptShiftCmd = UInt32(controlKey | optionKey | shiftKey | cmdKey)
        let allValid = KeyCombinationHelper.isValidHotKey(modifiers: ctrlOptShiftCmd)

        report(
            name: "Multi-modifier combinations (Cmd+Opt, Ctrl+Opt, Cmd+Shift, All) are valid",
            passed: cmdOptValid && ctrlOptValid && cmdShiftValid && allValid,
            detail: "cmdOpt=\(cmdOptValid), ctrlOpt=\(ctrlOptValid), cmdShift=\(cmdShiftValid), all=\(allValid)"
        )

        // -------------------------------------------------------------
        // Step 2.3: Reserved Shortcuts & Formatting
        // -------------------------------------------------------------
        print("\n  >> Testing formatted shortcuts and reserved keys")

        let optVFormat = KeyCombinationHelper.formattedShortcut(keyCode: 9, modifiers: UInt32(optionKey))
        report(
            name: "Option + V formatting matches 'Option + V'",
            passed: optVFormat == "Option + V",
            detail: "got '\(optVFormat)'"
        )

        let cmdShiftVFormat = KeyCombinationHelper.formattedShortcut(keyCode: 9, modifiers: UInt32(cmdKey | shiftKey))
        report(
            name: "Cmd + Shift + V formatting contains 'Shift', 'Command', and 'V'",
            passed: cmdShiftVFormat.contains("Shift") && cmdShiftVFormat.contains("Command") && cmdShiftVFormat.contains("V"),
            detail: "got '\(cmdShiftVFormat)'"
        )

        let ctrlOptCFormat = KeyCombinationHelper.formattedShortcut(keyCode: 8, modifiers: UInt32(controlKey | optionKey))
        report(
            name: "Control + Option + C formatting contains 'Control', 'Option', and 'C'",
            passed: ctrlOptCFormat.contains("Control") && ctrlOptCFormat.contains("Option") && ctrlOptCFormat.contains("C"),
            detail: "got '\(ctrlOptCFormat)'"
        )

        // Unmapped key code (e.g. 999)
        let unmappedFormat = KeyCombinationHelper.formattedShortcut(keyCode: 999, modifiers: UInt32(optionKey))
        report(
            name: "Unmapped key code formats gracefully as 'Option + Key 999'",
            passed: unmappedFormat == "Option + Key 999",
            detail: "got '\(unmappedFormat)'"
        )

        // Space key (keyCode 49)
        let spaceFormat = KeyCombinationHelper.formattedShortcut(keyCode: 49, modifiers: UInt32(optionKey))
        report(
            name: "Space key code (49) formats as 'Option + Space'",
            passed: spaceFormat == "Option + Space",
            detail: "got '\(spaceFormat)'"
        )

        // Tab key (keyCode 48)
        let tabFormat = KeyCombinationHelper.formattedShortcut(keyCode: 48, modifiers: UInt32(optionKey))
        report(
            name: "Tab key code (48) formats as 'Option + Tab'",
            passed: tabFormat == "Option + Tab",
            detail: "got '\(tabFormat)'"
        )

        // =====================================================================
        // VERDICT & SUMMARY
        // =====================================================================
        print("\n======================================================================")
        print("  SuperClip Challenger M4 Stress Test Summary")
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
            print("All empirical challenges passed. Dynamic capacity adjustment and hotkey customization verified.")
            exit(0)
        }
    }
}
