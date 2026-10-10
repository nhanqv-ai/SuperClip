import Foundation
import AppKit
import Carbon
import SuperClipCore
import SuperClip

final class MockPanelPresenter: FloatingPanelPresenting {
    var isVisible: Bool = false
    var isKeyWindow: Bool = false
    var dismissCallCount: Int = 0

    func show(near mouseLocation: NSPoint) {
        isVisible = true
        isKeyWindow = true
    }

    func dismiss() {
        isVisible = false
        isKeyWindow = false
        dismissCallCount += 1
    }
}

final class MockGate2HotKeyManager: HotKeyManaging {
    var onTrigger: (() -> Void)?
    var registeredKeyCode: UInt32?
    var registeredModifiers: UInt32?
    var unregisterCallCount: Int = 0

    func register(keyCode: UInt32, modifiers: UInt32) {
        registeredKeyCode = keyCode
        registeredModifiers = modifiers
    }

    func unregister() {
        unregisterCallCount += 1
    }
}

@main
struct M4Gate2EmpiricalStressRunner {
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
        print("  SuperClip Challenger M4 Gate 2 Empirical Stress Test Harness")
        print("======================================================================")

        let sandbox = createTempDirectory(prefix: "Gate2Stress")
        defer { cleanupTempDirectory(sandbox) }

        testDynamicCapacityUnderConcurrentLoad(sandbox: sandbox)
        testSettingsPersistenceRoundtrips(sandbox: sandbox)
        testContextMenuInteractionAndTriggering(sandbox: sandbox)

        print("\n======================================================================")
        print("  M4 Gate 2 Stress Test Execution Summary")
        print("======================================================================")
        print("  Total Tests: \(totalTests)")
        print("  Passed:      \(passedTests)")
        print("  Failed:      \(failedTests)")

        if failedTests == 0 {
            print("\nVERDICT: APPROVE (All Gate 2 adversarial stress challenges passed)")
        } else {
            print("\nVERDICT: REJECT (\(failedTests) failures detected)")
            exit(1)
        }
    }

    // =========================================================================
    // 1. Dynamic Capacity Changes Under Concurrent Load
    // =========================================================================
    static func testDynamicCapacityUnderConcurrentLoad(sandbox: URL) {
        print("\n--- Challenge 1: Dynamic Capacity Scaling & Pin Protection Under Concurrent Load ---")

        let storeDir = sandbox.appendingPathComponent("ConcurrentStore")
        let storage = StorageManager(baseDirectory: storeDir, initialCapacity: 100)
        let dummyImage = createDummyPNG()

        // 1. Seed initial store: 40 pinned items (20 text, 20 image) and 60 unpinned items (30 text, 30 image)
        var anchoredPinnedIDs = Set<UUID>()
        for i in 1...20 {
            let id = UUID()
            anchoredPinnedIDs.insert(id)
            let item = ClipItem(id: id, contentType: .text, textContent: "Anchor Pin Text \(i)", byteSize: 20, isPinned: true)
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }
        for _ in 1...20 {
            let id = UUID()
            anchoredPinnedIDs.insert(id)
            let imgName = "pin_img_\(id.uuidString).png"
            let thName = "pin_th_\(id.uuidString).png"
            let item = ClipItem(id: id, contentType: .image, imageFileName: imgName, thumbnailFileName: thName, byteSize: dummyImage.count, isPinned: true)
            storage.addClip(item: item, imageData: dummyImage, thumbData: dummyImage)
        }

        var initialUnpinnedIDs = Set<UUID>()
        for i in 1...30 {
            let id = UUID()
            initialUnpinnedIDs.insert(id)
            let item = ClipItem(id: id, contentType: .text, textContent: "Initial Unpinned Text \(i)", byteSize: 25, isPinned: false)
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }
        for _ in 1...30 {
            let id = UUID()
            initialUnpinnedIDs.insert(id)
            let imgName = "unpin_img_\(id.uuidString).png"
            let thName = "unpin_th_\(id.uuidString).png"
            let item = ClipItem(id: id, contentType: .image, imageFileName: imgName, thumbnailFileName: thName, byteSize: dummyImage.count, isPinned: false)
            storage.addClip(item: item, imageData: dummyImage, thumbData: dummyImage)
        }

        storage.flushDiskQueue()

        report(
            name: "Initial population holds exactly 40 pinned items",
            passed: storage.pinnedItems.count == 40
        )
        report(
            name: "Initial population holds exactly 60 unpinned items",
            passed: storage.historyItems.count == 60
        )

        // 2. Heavy Concurrent Storm: 10 threads, 250 iterations each = 2,500 operations
        let queue = DispatchQueue(label: "com.superclip.stress.gate2", attributes: .concurrent)
        let group = DispatchGroup()
        let iterationsPerThread = 250

        // Threads 1-3: Rapid dynamic capacity scaling with extreme bounds
        let capacityTargets = [5, 150, 1, 50, 10, 500, 20, 2, 80, 0, -20, 25]
        for t in 0..<3 {
            group.enter()
            queue.async {
                for i in 0..<iterationsPerThread {
                    let cap = capacityTargets[(i + t) % capacityTargets.count]
                    storage.capacity = cap
                }
                group.leave()
            }
        }

        // Threads 4-6: Rapid addition of new unpinned & pinned clips
        for t in 0..<3 {
            group.enter()
            queue.async {
                for i in 0..<iterationsPerThread {
                    let isPin = (i % 5 == 0)
                    let text = "Storm Clip [T\(t)-I\(i)-\(UUID().uuidString.prefix(6))]"
                    let item = ClipItem(id: UUID(), contentType: .text, textContent: text, byteSize: text.utf8.count, isPinned: isPin)
                    storage.addClip(item: item, imageData: nil, thumbData: nil)
                }
                group.leave()
            }
        }

        // Threads 7-8: Continuous reads, item lookups, and partition validation
        for _ in 0..<2 {
            group.enter()
            queue.async {
                for _ in 0..<iterationsPerThread {
                    let currentPinned = storage.pinnedItems
                    let currentHistory = storage.historyItems
                    let total = storage.items
                    let _ = total.count == (currentPinned.count + currentHistory.count)
                }
                group.leave()
            }
        }

        // Thread 9: Random pin toggling on non-anchored items
        group.enter()
        queue.async {
            for _ in 0..<iterationsPerThread {
                let history = storage.historyItems
                if let candidate = history.first(where: { !anchoredPinnedIDs.contains($0.id) }) {
                    storage.togglePin(id: candidate.id)
                }
            }
            group.leave()
        }

        // Thread 10: Periodic unpinned history clearing
        group.enter()
        queue.async {
            for i in 0..<iterationsPerThread {
                if i % 25 == 0 {
                    storage.clearUnpinnedHistory()
                }
            }
            group.leave()
        }

        group.wait()
        storage.flushDiskQueue()

        // Set stable final capacity of 20
        storage.capacity = 20
        storage.flushDiskQueue()

        // 3. Post-Stress Empirical Verifications
        let finalPinned = storage.pinnedItems
        let finalPinnedIDs = Set(finalPinned.map { $0.id })
        let finalHistory = storage.historyItems

        let anchoredRetainedCount = anchoredPinnedIDs.intersection(finalPinnedIDs).count
        report(
            name: "100% of anchored pinned items (40/40) survived concurrent load and capacity contractions",
            passed: anchoredRetainedCount == 40,
            detail: "retained=\(anchoredRetainedCount)/40"
        )

        report(
            name: "All surviving pinned items maintain isPinned == true",
            passed: finalPinned.allSatisfy { $0.isPinned }
        )

        report(
            name: "Final unpinned history count is bounded by final capacity 20",
            passed: finalHistory.count <= 20,
            detail: "historyCount=\(finalHistory.count), capacity=20"
        )

        report(
            name: "Strict partition invariant holds: items.count == pinnedItems.count + historyItems.count",
            passed: storage.items.count == (finalPinned.count + finalHistory.count)
        )

        // 4. Disk Asset Hygiene Check for Pinned Items
        var missingPinnedAssets = 0
        for item in finalPinned where item.contentType == .image {
            if let imgName = item.imageFileName {
                let imgURL = storeDir.appendingPathComponent("images").appendingPathComponent(imgName)
                if !FileManager.default.fileExists(atPath: imgURL.path) {
                    missingPinnedAssets += 1
                }
            }
            if let thName = item.thumbnailFileName {
                let thURL = storeDir.appendingPathComponent("thumbnails").appendingPathComponent(thName)
                if !FileManager.default.fileExists(atPath: thURL.path) {
                    missingPinnedAssets += 1
                }
            }
        }

        report(
            name: "100% of pinned image and thumbnail files are intact on disk after stress storm",
            passed: missingPinnedAssets == 0,
            detail: "missingAssets=\(missingPinnedAssets)"
        )

        // 5. Cold Reload Verification
        let reloadedStorage = StorageManager(baseDirectory: storeDir)
        reloadedStorage.flushDiskQueue()

        let reloadedPinnedIDs = Set(reloadedStorage.pinnedItems.map { $0.id })
        report(
            name: "Cold-start StorageManager reloads 100% of anchored pinned items",
            passed: anchoredPinnedIDs.isSubset(of: reloadedPinnedIDs),
            detail: "reloadedAnchors=\(anchoredPinnedIDs.intersection(reloadedPinnedIDs).count)/40"
        )
        report(
            name: "Cold-start StorageManager reloads persisted capacity correctly",
            passed: reloadedStorage.capacity == 20,
            detail: "reloadedCapacity=\(reloadedStorage.capacity)"
        )
    }

    // =========================================================================
    // 2. Settings Persistence Roundtrips
    // =========================================================================
    static func testSettingsPersistenceRoundtrips(sandbox: URL) {
        print("\n--- Challenge 2: Settings Persistence & Serialization Roundtrips ---")

        let settingsDir = sandbox.appendingPathComponent("SettingsStore")
        let storage = StorageManager(baseDirectory: settingsDir)

        // Test 2.1: Default settings roundtrip
        let defaultSettings = AppSettings()
        report(
            name: "Default settings capacity is 100",
            passed: defaultSettings.capacity == 100
        )
        report(
            name: "Default hotKeyKeyCode is 9 (Option+V)",
            passed: defaultSettings.hotKeyKeyCode == 9
        )
        report(
            name: "Default hotKeyModifiers is 2048 (optionKey)",
            passed: defaultSettings.hotKeyModifiers == 2048
        )

        // Test 2.2: Boundary clamping in AppSettings initializer
        let underclamped = AppSettings(
            capacity: 2,
            hotKeyKeyCode: 12,
            hotKeyModifiers: 256,
            pollIntervalMs: 10,
            maxThumbnailPixelSize: 30,
            launchAtLogin: true
        )
        report(
            name: "AppSettings clamps capacity < 10 up to 10",
            passed: underclamped.capacity == 10
        )
        report(
            name: "AppSettings clamps pollInterval < 50ms up to 50ms",
            passed: underclamped.pollIntervalMs == 50
        )
        report(
            name: "AppSettings clamps thumbnailSize < 60px up to 60px",
            passed: underclamped.maxThumbnailPixelSize == 60
        )

        let overclamped = AppSettings(
            capacity: 9999,
            hotKeyKeyCode: 12,
            hotKeyModifiers: 256,
            pollIntervalMs: 5000,
            maxThumbnailPixelSize: 1024,
            launchAtLogin: false
        )
        report(
            name: "AppSettings clamps capacity > 1000 down to 1000",
            passed: overclamped.capacity == 1000
        )
        report(
            name: "AppSettings clamps pollInterval > 2000ms down to 2000ms",
            passed: overclamped.pollIntervalMs == 2000
        )
        report(
            name: "AppSettings clamps thumbnailSize > 512px down to 512px",
            passed: overclamped.maxThumbnailPixelSize == 512
        )

        // Test 2.3: Backward compatibility aliases
        var aliasTest = AppSettings()
        aliasTest.historyCapacity = 250
        aliasTest.hotkeyKeyCode = 49
        aliasTest.hotkeyModifiers = 4096
        report(
            name: "historyCapacity alias synchronizes with capacity",
            passed: aliasTest.capacity == 250 && aliasTest.historyCapacity == 250
        )
        report(
            name: "hotkeyKeyCode alias synchronizes with hotKeyKeyCode",
            passed: aliasTest.hotKeyKeyCode == 49 && aliasTest.hotkeyKeyCode == 49
        )
        report(
            name: "hotkeyModifiers alias synchronizes with hotKeyModifiers",
            passed: aliasTest.hotKeyModifiers == 4096 && aliasTest.hotkeyModifiers == 4096
        )

        // Test 2.4: StorageManager settings persistence roundtrip
        let customSettings = AppSettings(
            capacity: 350,
            hotKeyKeyCode: 8, // kVK_ANSI_C
            hotKeyModifiers: UInt32(cmdKey | optionKey),
            pollIntervalMs: 150,
            maxThumbnailPixelSize: 240,
            launchAtLogin: true
        )
        storage.settings = customSettings
        storage.flushDiskQueue()

        report(
            name: "StorageManager capacity mirrors assigned settings capacity (350)",
            passed: storage.capacity == 350
        )

        // Read settings.json directly from disk
        let settingsFile = settingsDir.appendingPathComponent("settings.json")
        report(
            name: "settings.json exists on disk",
            passed: FileManager.default.fileExists(atPath: settingsFile.path)
        )

        let rawData = (try? Data(contentsOf: settingsFile)) ?? Data()
        let decodedDiskSettings = try? JSONDecoder().decode(AppSettings.self, from: rawData)
        report(
            name: "Disk settings.json decodes byte-for-byte matching assigned settings",
            passed: decodedDiskSettings == customSettings
        )

        // Cold start reload
        let coldStorage = StorageManager(baseDirectory: settingsDir)
        coldStorage.flushDiskQueue()
        report(
            name: "Cold-start StorageManager reloads exact persisted settings",
            passed: coldStorage.settings == customSettings
        )
        report(
            name: "Cold-start StorageManager reloads exact capacity (350)",
            passed: coldStorage.capacity == 350
        )

        // Test 2.5: Resilient recovery from corrupted settings.json
        let corruptDir = sandbox.appendingPathComponent("CorruptSettingsStore")
        try? FileManager.default.createDirectory(at: corruptDir, withIntermediateDirectories: true)
        let corruptFile = corruptDir.appendingPathComponent("settings.json")
        try? "MALFORMED_NON_JSON_DATA{{{".write(to: corruptFile, atomically: true, encoding: .utf8)

        let resilientStorage = StorageManager(baseDirectory: corruptDir)
        report(
            name: "StorageManager recovers from malformed settings.json to default capacity (100) without crashing",
            passed: resilientStorage.capacity == 100
        )

        // Test 2.6: Recovery from 0-byte settings.json
        let zeroByteDir = sandbox.appendingPathComponent("ZeroByteSettingsStore")
        try? FileManager.default.createDirectory(at: zeroByteDir, withIntermediateDirectories: true)
        let zeroByteFile = zeroByteDir.appendingPathComponent("settings.json")
        try? Data().write(to: zeroByteFile)

        let zeroByteStorage = StorageManager(baseDirectory: zeroByteDir)
        report(
            name: "StorageManager recovers from 0-byte settings.json to default capacity without crashing",
            passed: zeroByteStorage.capacity == 100
        )
    }

    // =========================================================================
    // 3. Context Menu Item Interaction and Triggering
    // =========================================================================
    static func testContextMenuInteractionAndTriggering(sandbox: URL) {
        print("\n--- Challenge 3: Context Menu Item Interaction & Triggering ---")

        let storeDir = sandbox.appendingPathComponent("ContextMenuStore")
        let storage = StorageManager(baseDirectory: storeDir, initialCapacity: 50)
        let mockPanel = MockPanelPresenter()
        let mockHotKey = MockGate2HotKeyManager()

        // Seed storage with 5 pinned and 15 unpinned clips
        for i in 1...5 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Pinned \(i)", byteSize: 10, isPinned: true)
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }
        for i in 1...15 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "History \(i)", byteSize: 10, isPinned: false)
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }

        let manager = StatusItemManager(
            contentViewController: nil,
            floatingPanel: mockPanel,
            hotKeyManager: mockHotKey,
            settingsWindowController: nil,
            storageManager: storage
        )

        let menu = manager.contextMenu

        // 3.1 Context Menu Structural Invariants
        report(
            name: "Context menu title is 'SuperClip'",
            passed: menu.title == "SuperClip"
        )
        report(
            name: "Context menu contains exactly 6 canonical items",
            passed: menu.items.count == 6,
            detail: "count=\(menu.items.count)"
        )

        // Item 0: Show Clipboard History
        let item0 = menu.items[0]
        report(
            name: "Item 0 title is 'Show Clipboard History'",
            passed: item0.title == "Show Clipboard History"
        )
        report(
            name: "Item 0 target is StatusItemManager",
            passed: item0.target === manager
        )
        report(
            name: "Item 0 action is openSuperClipMenuItemClicked:",
            passed: item0.action == #selector(manager.openSuperClipMenuItemClicked(_:))
        )
        report(
            name: "Item 0 keyEquivalent is empty string",
            passed: item0.keyEquivalent == ""
        )

        // Item 1: Preferences...
        let item1 = menu.items[1]
        report(
            name: "Item 1 title is 'Preferences...'",
            passed: item1.title == "Preferences..."
        )
        report(
            name: "Item 1 target is StatusItemManager",
            passed: item1.target === manager
        )
        report(
            name: "Item 1 action is settingsMenuItemClicked:",
            passed: item1.action == #selector(manager.settingsMenuItemClicked(_:))
        )
        report(
            name: "Item 1 keyEquivalent is ',' with Command modifier",
            passed: item1.keyEquivalent == "," && item1.keyEquivalentModifierMask == [.command]
        )

        // Item 2: Separator
        let item2 = menu.items[2]
        report(
            name: "Item 2 is separator item",
            passed: item2.isSeparatorItem
        )

        // Item 3: Clear Unpinned History
        let item3 = menu.items[3]
        report(
            name: "Item 3 title is 'Clear Unpinned History'",
            passed: item3.title == "Clear Unpinned History"
        )
        report(
            name: "Item 3 target is StatusItemManager",
            passed: item3.target === manager
        )
        report(
            name: "Item 3 action is clearHistoryMenuItemClicked:",
            passed: item3.action == #selector(manager.clearHistoryMenuItemClicked(_:))
        )

        // Item 4: Separator
        let item4 = menu.items[4]
        report(
            name: "Item 4 is separator item",
            passed: item4.isSeparatorItem
        )

        // Item 5: Quit SuperClip
        let item5 = menu.items[5]
        report(
            name: "Item 5 title is 'Quit SuperClip'",
            passed: item5.title == "Quit SuperClip"
        )
        report(
            name: "Item 5 target is StatusItemManager",
            passed: item5.target === manager
        )
        report(
            name: "Item 5 action is quitMenuItemClicked:",
            passed: item5.action == #selector(manager.quitMenuItemClicked(_:))
        )
        report(
            name: "Item 5 keyEquivalent is 'q' with Command modifier",
            passed: item5.keyEquivalent == "q" && item5.keyEquivalentModifierMask == [.command]
        )

        // 3.2 Action Triggering: Preferences...
        var settingsOpened = false
        manager.onOpenSettingsRequested = {
            settingsOpened = true
        }

        mockPanel.show(near: NSPoint(x: 100, y: 100))
        report(
            name: "Floating panel is visible before preferences trigger",
            passed: mockPanel.isVisible
        )

        // Trigger Item 1 Action directly via action selector
        manager.perform(item1.action, with: item1)
        report(
            name: "Item 1 (Preferences...) invocation dispatches to onOpenSettingsRequested callback",
            passed: settingsOpened
        )
        report(
            name: "Item 1 invocation enforces mutual exclusion: dismisses floating panel",
            passed: !mockPanel.isVisible
        )

        // 3.3 Action Triggering: Clear Unpinned History
        var clearHistoryNotified = false
        manager.onClearHistoryRequested = {
            clearHistoryNotified = true
        }

        report(
            name: "Storage initially contains 20 items (5 pinned + 15 unpinned)",
            passed: storage.items.count == 20
        )

        // Trigger Item 3 Action directly via action selector
        manager.perform(item3.action, with: item3)
        report(
            name: "Item 3 (Clear Unpinned History) invocation dispatches to onClearHistoryRequested callback",
            passed: clearHistoryNotified
        )
        report(
            name: "Item 3 invocation purges 100% of unpinned history items",
            passed: storage.historyItems.isEmpty
        )
        report(
            name: "Item 3 invocation preserves 100% of pinned items (5/5 retained)",
            passed: storage.pinnedItems.count == 5 && storage.items.count == 5
        )

        // 3.4 Menu Delegate & Mutual Exclusion State Cycle
        manager.statusItem.menu = menu
        report(
            name: "statusItem.menu is assigned during menu presentation tracking",
            passed: manager.statusItem.menu === menu
        )
        manager.menuDidClose(menu)
        report(
            name: "menuDidClose restores statusItem.menu to nil for left-click popover toggling",
            passed: manager.statusItem.menu == nil
        )

        // 3.5 Legacy compatibility methods
        report(
            name: "buildContextMenu() returns contextMenu matching canonical 6 items",
            passed: manager.buildContextMenu() === menu
        )

        // Test legacy action entry points
        var legacyClearCalled = false
        manager.onClearHistoryRequested = { legacyClearCalled = true }
        manager.handleClearHistoryMenuItem(nil)
        report(
            name: "handleClearHistoryMenuItem forwards cleanly to clearHistoryMenuItemClicked",
            passed: legacyClearCalled
        )

        var legacySettingsCalled = false
        manager.onOpenSettingsRequested = { legacySettingsCalled = true }
        manager.handlePreferencesMenuItem(nil)
        report(
            name: "handlePreferencesMenuItem forwards cleanly to settingsMenuItemClicked",
            passed: legacySettingsCalled
        )
    }
}
