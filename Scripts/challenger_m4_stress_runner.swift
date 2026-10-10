import Foundation
import AppKit
import Carbon
import SwiftUI
import SuperClipCore
import SuperClip

final class MockSettingsHotKeyManager: HotKeyManaging {
    var onTrigger: (() -> Void)?
    var lastRegisteredKeyCode: UInt32?
    var lastRegisteredModifiers: UInt32?
    var unregisterCount: Int = 0

    init() {}

    func register(keyCode: UInt32, modifiers: UInt32) {
        lastRegisteredKeyCode = keyCode
        lastRegisteredModifiers = modifiers
    }

    func unregister() {
        unregisterCount += 1
    }
}

@main
struct ChallengerM4StressRunner {
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
        print("==================================================")
        print("  SuperClip Challenger M4 Empirical Stress Runner ")
        print("  Target: Settings & Retention Capacity (M4)      ")
        print("==================================================")

        let sandbox = createTempDirectory(prefix: "ChallengerM4")
        defer { cleanupTempDirectory(sandbox) }

        // ==========================================
        // Suite 1: Dynamic Capacity Scaling & Pin Invariant Under Load
        // ==========================================
        print("\n--- Suite 1: Dynamic Capacity Scaling & Pin Retention Under Load ---")

        // 1.1: Asymmetric contraction: 50 pinned items, 150 unpinned items. Capacity scaled from 100 to 10.
        let store1Dir = sandbox.appendingPathComponent("Store1_Asymmetric")
        let store1 = StorageManager(baseDirectory: store1Dir, initialCapacity: 100)

        for i in 1...50 {
            let item = ClipItem(
                id: UUID(),
                contentType: .text,
                textContent: "Pinned Anchor Item \(i)",
                byteSize: 30,
                createdAt: Date(),
                isPinned: true
            )
            store1.addClip(item: item, imageData: nil, thumbData: nil)
        }
        for i in 1...150 {
            let item = ClipItem(
                id: UUID(),
                contentType: .text,
                textContent: "Unpinned History Clip \(i)",
                byteSize: 30,
                createdAt: Date(),
                isPinned: false
            )
            store1.addClip(item: item, imageData: nil, thumbData: nil)
        }

        let pinnedBeforeContraction = store1.pinnedItems.count
        let unpinnedBeforeContraction = store1.historyItems.count
        report(
            name: "Initial store setup: exactly 50 pinned and 100 unpinned clips (clamped by initial capacity 100)",
            passed: (pinnedBeforeContraction == 50 && unpinnedBeforeContraction == 100),
            detail: "pinned=\(pinnedBeforeContraction), unpinned=\(unpinnedBeforeContraction)"
        )

        // Rapid contraction to 10
        store1.capacity = 10
        let pinnedAfterContraction = store1.pinnedItems.count
        let unpinnedAfterContraction = store1.historyItems.count
        let totalAfterContraction = store1.items.count

        report(
            name: "Contraction to 10 preserves 100% of pinned items (50 pinned retained)",
            passed: (pinnedAfterContraction == 50),
            detail: "pinnedAfter=\(pinnedAfterContraction), expected 50"
        )
        report(
            name: "Contraction to 10 trims unpinned history to exactly 10 clips",
            passed: (unpinnedAfterContraction == 10),
            detail: "unpinnedAfter=\(unpinnedAfterContraction), expected 10"
        )
        report(
            name: "Total items count equals 60 (50 pinned + 10 unpinned)",
            passed: (totalAfterContraction == 60),
            detail: "totalAfter=\(totalAfterContraction), expected 60"
        )

        // 1.2: Extreme contraction below pinned count with 0 unpinned items
        let store2Dir = sandbox.appendingPathComponent("Store2_ZeroUnpinned")
        let store2 = StorageManager(baseDirectory: store2Dir, initialCapacity: 100)

        for i in 1...30 {
            let item = ClipItem(
                id: UUID(),
                contentType: .text,
                textContent: "Pure Pinned Item \(i)",
                byteSize: 25,
                createdAt: Date(),
                isPinned: true
            )
            store2.addClip(item: item, imageData: nil, thumbData: nil)
        }

        store2.capacity = 10
        report(
            name: "Contraction to 10 with 0 unpinned items evicts 0 pinned items (30/30 preserved)",
            passed: (store2.pinnedItems.count == 30 && store2.historyItems.isEmpty && store2.items.count == 30),
            detail: "pinned=\(store2.pinnedItems.count), history=\(store2.historyItems.count)"
        )

        // 1.3: Boundary capacity clamps (1, 0, negative)
        store2.capacity = 1
        report(
            name: "Capacity set to 1 clamps to 1 and preserves all 30 pinned items",
            passed: (store2.capacity == 1 && store2.pinnedItems.count == 30),
            detail: "capacity=\(store2.capacity), pinned=\(store2.pinnedItems.count)"
        )

        store2.capacity = 0
        report(
            name: "Capacity set to 0 clamps safely to 1 without crash",
            passed: (store2.capacity == 1),
            detail: "capacity=\(store2.capacity)"
        )

        store2.capacity = -50
        report(
            name: "Capacity set to negative (-50) clamps safely to 1",
            passed: (store2.capacity == 1),
            detail: "capacity=\(store2.capacity)"
        )

        // 1.4: High-frequency oscillatory scaling under concurrent load
        let store3Dir = sandbox.appendingPathComponent("Store3_Oscillation")
        let store3 = StorageManager(baseDirectory: store3Dir, initialCapacity: 100)

        let initialPinnedCount = 20
        var initialPinnedIDs = Set<UUID>()
        for i in 1...initialPinnedCount {
            let id = UUID()
            initialPinnedIDs.insert(id)
            let item = ClipItem(
                id: id,
                contentType: .text,
                textContent: "Anchor Pinned \(i)",
                byteSize: 20,
                createdAt: Date(),
                isPinned: true
            )
            store3.addClip(item: item, imageData: nil, thumbData: nil)
        }

        let group1_4 = DispatchGroup()
        let queue1_4 = DispatchQueue(label: "oscillation.concurrent", attributes: .concurrent)

        // Worker A: Rapid text clip additions
        group1_4.enter()
        queue1_4.async {
            for i in 1...100 {
                let item = ClipItem(
                    id: UUID(),
                    contentType: .text,
                    textContent: "Oscillation Text Clip \(i)",
                    byteSize: 30,
                    createdAt: Date(),
                    isPinned: false
                )
                store3.addClip(item: item, imageData: nil, thumbData: nil)
            }
            group1_4.leave()
        }

        // Worker B: Rapid image clip additions
        let dummyPNG = createDummyPNG()
        group1_4.enter()
        queue1_4.async {
            for _ in 1...50 {
                let id = UUID()
                let item = ClipItem(
                    id: id,
                    contentType: .image,
                    textContent: nil,
                    imageFileName: "\(id.uuidString).png",
                    thumbnailFileName: "thumb_\(id.uuidString).png",
                    byteSize: dummyPNG.count,
                    createdAt: Date(),
                    isPinned: false
                )
                store3.addClip(item: item, imageData: dummyPNG, thumbData: dummyPNG)
            }
            group1_4.leave()
        }

        // Worker C: Rapid capacity oscillations (10 <-> 500)
        group1_4.enter()
        queue1_4.async {
            let capacities = [10, 50, 20, 250, 15, 500, 30, 100, 10]
            for _ in 1...10 {
                for cap in capacities {
                    store3.capacity = cap
                    Thread.sleep(forTimeInterval: 0.001)
                }
            }
            store3.capacity = 25 // Final target capacity
            group1_4.leave()
        }

        group1_4.wait()
        store3.flushDiskQueue()

        let survivingPinnedIDs = Set(store3.pinnedItems.map { $0.id })
        let allAnchorsSurvived = initialPinnedIDs.isSubset(of: survivingPinnedIDs)
        let unpinnedCountUnderFinalCap = store3.historyItems.count <= 25

        report(
            name: "All 20 anchor pinned items survived 90 rapid capacity oscillations under heavy load",
            passed: allAnchorsSurvived,
            detail: "surviving anchors: \(survivingPinnedIDs.intersection(initialPinnedIDs).count)/20"
        )
        report(
            name: "Unpinned history clamped within final target capacity 25 under oscillation",
            passed: unpinnedCountUnderFinalCap,
            detail: "historyCount=\(store3.historyItems.count), expected <= 25"
        )

        // 1.5: Disk asset hygiene upon capacity eviction
        let store4Dir = sandbox.appendingPathComponent("Store4_DiskCleanup")
        let store4 = StorageManager(baseDirectory: store4Dir, initialCapacity: 100)

        var pinnedImageNames: [String] = []
        for _ in 1...5 {
            let id = UUID()
            let imgName = "\(id.uuidString).png"
            let thName = "thumb_\(id.uuidString).png"
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
            store4.addClip(item: item, imageData: dummyPNG, thumbData: dummyPNG)
        }

        var unpinnedImageNames: [String] = []
        for _ in 1...20 {
            let id = UUID()
            let imgName = "\(id.uuidString).png"
            let thName = "thumb_\(id.uuidString).png"
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
            store4.addClip(item: item, imageData: dummyPNG, thumbData: dummyPNG)
        }

        store4.flushDiskQueue()
        let initialImageFiles = (try? FileManager.default.contentsOfDirectory(atPath: store4.imagesDirectory.path)) ?? []
        report(
            name: "StorageManager created 25 image files on disk before eviction",
            passed: (initialImageFiles.count == 25),
            detail: "imageFilesCount=\(initialImageFiles.count), expected 25"
        )

        // Drop capacity to 5 -> exactly 15 unpinned clips and their disk files must be purged
        store4.capacity = 5
        store4.flushDiskQueue()

        let remainingImageFiles = Set((try? FileManager.default.contentsOfDirectory(atPath: store4.imagesDirectory.path)) ?? [])
        let pinnedImagesRetainedOnDisk = pinnedImageNames.allSatisfy { remainingImageFiles.contains($0) }
        // In FIFO order, the first 15 added items (prefix) were oldest and therefore evicted
        let evictedImages = unpinnedImageNames.prefix(15)
        let retainedUnpinnedImages = unpinnedImageNames.suffix(5)
        let evictedImagesRemovedFromDisk = evictedImages.allSatisfy { !remainingImageFiles.contains($0) }
        let retainedUnpinnedImagesOnDisk = retainedUnpinnedImages.allSatisfy { remainingImageFiles.contains($0) }

        report(
            name: "Evicted unpinned clips had their disk image files purged (total remaining: 10)",
            passed: (remainingImageFiles.count == 10 && evictedImagesRemovedFromDisk && retainedUnpinnedImagesOnDisk),
            detail: "remainingImages=\(remainingImageFiles.count), evictedRemoved=\(evictedImagesRemovedFromDisk)"
        )
        report(
            name: "100% of pinned clips' image files preserved intact on disk",
            passed: pinnedImagesRetainedOnDisk,
            detail: "pinnedRetained: \(pinnedImagesRetainedOnDisk)"
        )

        // ==========================================
        // Suite 2: Settings Persistence & Serialization Roundtrips
        // ==========================================
        print("\n--- Suite 2: Settings Persistence & Serialization Roundtrips ---")

        // 2.1: Full fidelity serialization roundtrip
        let store5Dir = sandbox.appendingPathComponent("Store5_Serialization")
        let store5 = StorageManager(baseDirectory: store5Dir)

        let targetSettings = AppSettings(
            capacity: 320,
            hotKeyKeyCode: 13, // W
            hotKeyModifiers: UInt32(cmdKey | optionKey | controlKey),
            pollIntervalMs: 150,
            maxThumbnailPixelSize: 256,
            launchAtLogin: true
        )

        store5.settings = targetSettings
        store5.flushDiskQueue()

        // Read raw JSON file directly from disk
        let rawData = try? Data(contentsOf: store5.settingsURL)
        report(
            name: "settings.json exists on disk and is non-empty",
            passed: (rawData != nil && !rawData!.isEmpty),
            detail: "bytes=\(rawData?.count ?? 0)"
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let deserializedSettings = try? decoder.decode(AppSettings.self, from: rawData!)

        report(
            name: "settings.json deserializes byte-for-byte matching target settings",
            passed: (deserializedSettings == targetSettings),
            detail: "deserialized=\(String(describing: deserializedSettings))"
        )

        // 2.2: Cold start instance reload
        let store5Cold = StorageManager(baseDirectory: store5Dir)
        let coldMatches = (store5Cold.capacity == 320) &&
                          (store5Cold.settings.hotKeyKeyCode == 13) &&
                          (store5Cold.settings.hotKeyModifiers == UInt32(cmdKey | optionKey | controlKey)) &&
                          (store5Cold.settings.pollIntervalMs == 150) &&
                          (store5Cold.settings.maxThumbnailPixelSize == 256) &&
                          (store5Cold.settings.launchAtLogin == true)

        report(
            name: "Cold-start StorageManager restores exact persisted settings from disk",
            passed: coldMatches,
            detail: "coldCapacity=\(store5Cold.capacity), hotkey=\(store5Cold.settings.hotKeyKeyCode)"
        )

        // 2.3: Resilience to corrupted settings.json
        let storeCorruptDir = sandbox.appendingPathComponent("Store_Corrupt")
        try? FileManager.default.createDirectory(at: storeCorruptDir, withIntermediateDirectories: true)
        let corruptFile = storeCorruptDir.appendingPathComponent("settings.json")
        try? "MALFORMED_JSON_CONTENT{{{;;;".data(using: .utf8)?.write(to: corruptFile)

        let storeCorrupt = StorageManager(baseDirectory: storeCorruptDir)
        report(
            name: "StorageManager gracefully recovers from corrupted settings.json to default settings",
            passed: (storeCorrupt.capacity == AppSettings.defaultCapacity &&
                     storeCorrupt.settings.hotKeyKeyCode == AppSettings.defaultHotKeyKeyCode),
            detail: "capacity=\(storeCorrupt.capacity), hotkey=\(storeCorrupt.settings.hotKeyKeyCode)"
        )

        // 2.4: Resilience to empty 0-byte settings.json
        let storeEmptyDir = sandbox.appendingPathComponent("Store_Empty")
        try? FileManager.default.createDirectory(at: storeEmptyDir, withIntermediateDirectories: true)
        let emptyFile = storeEmptyDir.appendingPathComponent("settings.json")
        try? Data().write(to: emptyFile)

        let storeEmpty = StorageManager(baseDirectory: storeEmptyDir)
        report(
            name: "StorageManager gracefully recovers from 0-byte settings.json to default settings",
            passed: (storeEmpty.capacity == AppSettings.defaultCapacity),
            detail: "capacity=\(storeEmpty.capacity)"
        )

        // 2.5: AppSettings initializer boundary clamping
        let lowSettings = AppSettings(capacity: 2, pollIntervalMs: 10, maxThumbnailPixelSize: 10)
        report(
            name: "AppSettings clamps lower boundaries: capacity=10, poll=50ms, thumb=60px",
            passed: (lowSettings.capacity == 10 && lowSettings.pollIntervalMs == 50 && lowSettings.maxThumbnailPixelSize == 60),
            detail: "cap=\(lowSettings.capacity), poll=\(lowSettings.pollIntervalMs), thumb=\(lowSettings.maxThumbnailPixelSize)"
        )

        let highSettings = AppSettings(capacity: 9999, pollIntervalMs: 9999, maxThumbnailPixelSize: 9999)
        report(
            name: "AppSettings clamps upper boundaries: capacity=1000, poll=2000ms, thumb=512px",
            passed: (highSettings.capacity == 1000 && highSettings.pollIntervalMs == 2000 && highSettings.maxThumbnailPixelSize == 512),
            detail: "cap=\(highSettings.capacity), poll=\(highSettings.pollIntervalMs), thumb=\(highSettings.maxThumbnailPixelSize)"
        )

        // ==========================================
        // Suite 3: Multi-Threaded Concurrency Stress
        // ==========================================
        print("\n--- Suite 3: Multi-Threaded Concurrency Stress ---")

        let store6Dir = sandbox.appendingPathComponent("Store6_Concurrency")
        let store6 = StorageManager(baseDirectory: store6Dir, initialCapacity: 100)

        // Seed 20 initial pinned items
        var pinnedSeeds = Set<UUID>()
        for i in 1...20 {
            let id = UUID()
            pinnedSeeds.insert(id)
            let item = ClipItem(
                id: id,
                contentType: .text,
                textContent: "Seed Pinned \(i)",
                byteSize: 20,
                createdAt: Date(),
                isPinned: true
            )
            store6.addClip(item: item, imageData: nil, thumbData: nil)
        }

        let concGroup = DispatchGroup()
        let concQueue = DispatchQueue(label: "concurrency.stress", attributes: .concurrent)
        let iterations = 100

        // Thread Group A: Concurrent settings mutations
        for _ in 1...5 {
            concGroup.enter()
            concQueue.async {
                for i in 1...iterations {
                    let newSettings = AppSettings(
                        capacity: (i % 40) * 10 + 10,
                        hotKeyKeyCode: UInt32(i % 50),
                        hotKeyModifiers: UInt32(optionKey)
                    )
                    store6.settings = newSettings
                }
                concGroup.leave()
            }
        }

        // Thread Group B: Concurrent direct capacity mutations
        for _ in 1...5 {
            concGroup.enter()
            concQueue.async {
                for i in 1...iterations {
                    store6.capacity = (i % 45) * 10 + 10
                }
                concGroup.leave()
            }
        }

        // Thread Group C: Concurrent clip insertions
        for t in 1...5 {
            concGroup.enter()
            concQueue.async {
                for i in 1...iterations {
                    let item = ClipItem(
                        id: UUID(),
                        contentType: .text,
                        textContent: "Thread \(t) Clip \(i)",
                        byteSize: 30,
                        createdAt: Date(),
                        isPinned: false
                    )
                    store6.addClip(item: item, imageData: nil, thumbData: nil)
                }
                concGroup.leave()
            }
        }

        // Thread Group D: Concurrent pin toggling on existing items
        for _ in 1...5 {
            concGroup.enter()
            concQueue.async {
                for _ in 1...iterations {
                    let currentItems = store6.items
                    if let target = currentItems.randomElement(), !pinnedSeeds.contains(target.id) {
                        store6.togglePin(id: target.id)
                    }
                }
                concGroup.leave()
            }
        }

        // Thread Group E: Concurrent reader threads
        for _ in 1...5 {
            concGroup.enter()
            concQueue.async {
                for _ in 1...iterations {
                    _ = store6.items
                    _ = store6.pinnedItems
                    _ = store6.historyItems
                    _ = store6.capacity
                    _ = store6.settings
                }
                concGroup.leave()
            }
        }

        concGroup.wait()
        store6.flushDiskQueue()

        let survivingSeeds = Set(store6.pinnedItems.map { $0.id })
        let allSeedsRetained = pinnedSeeds.isSubset(of: survivingSeeds)
        let finalHistoryValid = store6.historyItems.count <= store6.capacity
        let finalCapacitySynced = store6.capacity == store6.settings.capacity
        let partitionIntegrity = store6.items.count == (store6.pinnedItems.count + store6.historyItems.count)

        report(
            name: "Zero crashes or deadlocks across 2,500 multi-threaded concurrent mutations",
            passed: true
        )
        report(
            name: "All 20 initial pinned seeds survived concurrent settings mutations and clip insertions",
            passed: allSeedsRetained,
            detail: "surviving seeds: \(survivingSeeds.intersection(pinnedSeeds).count)/20"
        )
        report(
            name: "Final unpinned history respects final capacity (count: \(store6.historyItems.count), cap: \(store6.capacity))",
            passed: finalHistoryValid,
            detail: "historyCount=\(store6.historyItems.count), capacity=\(store6.capacity)"
        )
        report(
            name: "StorageManager.capacity and StorageManager.settings.capacity remain synchronized",
            passed: finalCapacitySynced,
            detail: "capacity=\(store6.capacity), settings.capacity=\(store6.settings.capacity)"
        )
        report(
            name: "Partition integrity: total items strictly equals pinned items + history items",
            passed: partitionIntegrity,
            detail: "total=\(store6.items.count), pinned=\(store6.pinnedItems.count), history=\(store6.historyItems.count)"
        )

        // ==========================================
        // Suite 4: Hotkey Helper & KeyCombination Validation
        // ==========================================
        print("\n--- Suite 4: Key Combination & Hotkey Validation ---")

        // 4.1: Valid combinations
        report(
            name: "Option modifier is valid hotkey modifier",
            passed: KeyCombinationHelper.isValidHotKey(modifiers: UInt32(optionKey))
        )
        report(
            name: "Command modifier is valid hotkey modifier",
            passed: KeyCombinationHelper.isValidHotKey(modifiers: UInt32(cmdKey))
        )
        report(
            name: "Control modifier is valid hotkey modifier",
            passed: KeyCombinationHelper.isValidHotKey(modifiers: UInt32(controlKey))
        )
        report(
            name: "Command + Option combination is valid hotkey modifier",
            passed: KeyCombinationHelper.isValidHotKey(modifiers: UInt32(cmdKey | optionKey))
        )

        // 4.2: Invalid combinations
        report(
            name: "Modifier mask 0 (bare key) is invalid",
            passed: !KeyCombinationHelper.isValidHotKey(modifiers: 0)
        )
        report(
            name: "Bare Shift without Cmd/Opt/Ctrl is invalid",
            passed: !KeyCombinationHelper.isValidHotKey(modifiers: UInt32(shiftKey))
        )

        // 4.3: Formatting
        let optV = KeyCombinationHelper.formattedShortcut(keyCode: 9, modifiers: UInt32(optionKey))
        report(
            name: "Option+V formats to 'Option + V'",
            passed: (optV == "Option + V"),
            detail: "got '\(optV)'"
        )

        let cmdShiftV = KeyCombinationHelper.formattedShortcut(keyCode: 9, modifiers: UInt32(cmdKey | shiftKey))
        report(
            name: "Cmd+Shift+V formats correctly with Shift and Command",
            passed: (cmdShiftV.contains("Command") && cmdShiftV.contains("Shift") && cmdShiftV.contains("V")),
            detail: "got '\(cmdShiftV)'"
        )

        let unmappedKey = KeyCombinationHelper.formattedShortcut(keyCode: 999, modifiers: UInt32(optionKey))
        report(
            name: "Unmapped key code formats as 'Option + Key 999'",
            passed: (unmappedKey == "Option + Key 999"),
            detail: "got '\(unmappedKey)'"
        )

        // ==========================================
        // Suite 5: SettingsWindowController & Lifecycle
        // ==========================================
        print("\n--- Suite 5: SettingsWindowController & Lifecycle Coordination ---")

        let mockHotKey = MockSettingsHotKeyManager()
        var dismissalCalled = false
        let windowCtrl = SettingsWindowController(
            storageManager: store1,
            hotKeyManager: mockHotKey,
            onPresentationDismissalRequested: {
                dismissalCalled = true
            }
        )

        guard let win = windowCtrl.window else {
            report(name: "SettingsWindowController creates NSWindow", passed: false)
            return
        }

        report(
            name: "Settings window title is 'SuperClip Settings'",
            passed: (win.title == "SuperClip Settings"),
            detail: "title='\(win.title)'"
        )
        report(
            name: "Settings window isReleasedWhenClosed is false",
            passed: (!win.isReleasedWhenClosed),
            detail: "isReleasedWhenClosed=\(win.isReleasedWhenClosed)"
        )
        report(
            name: "Settings window styleMask contains .titled and .closable",
            passed: (win.styleMask.contains(.titled) && win.styleMask.contains(.closable))
        )

        // Background thread invocation of showSettings()
        let bgShowGroup = DispatchGroup()
        bgShowGroup.enter()
        DispatchQueue.global().async {
            windowCtrl.showSettings()
            bgShowGroup.leave()
        }
        bgShowGroup.wait()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        report(
            name: "showSettings() called from background thread dispatches to main thread safely",
            passed: dismissalCalled,
            detail: "dismissalCalled=\(dismissalCalled)"
        )

        windowCtrl.close()

        // Agent mode lifecycle
        let appDelegate = AppDelegate()
        let terminatePolicy = appDelegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared)
        report(
            name: "AppDelegate.applicationShouldTerminateAfterLastWindowClosed returns false (LSUIElement mode)",
            passed: (!terminatePolicy),
            detail: "shouldTerminate=\(terminatePolicy)"
        )

        // ==========================================
        // Summary Verdict
        // ==========================================
        print("\n==================================================")
        print("  SuperClip Challenger M4 Execution Summary       ")
        print("==================================================")
        print("  Total Challenges: \(totalTests)")
        print("  Passed:           \(passedTests)")
        print("  Failed:           \(failedTests)")

        if failedTests > 0 {
            print("\nVERDICT: REJECT (Found \(failedTests) critical/high defects in settings & capacity)")
            exit(1)
        } else {
            print("\nVERDICT: APPROVE (All adversarial M4 challenges passed)")
            exit(0)
        }
    }
}
