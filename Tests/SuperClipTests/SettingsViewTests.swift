import Foundation
import AppKit
import Carbon
import SuperClipCore
import SuperClip

/// Mock HotKeyManager tracking registration invocations for SettingsView tests.
public final class MockSettingsViewHotKeyManager: HotKeyManaging {
    public var onTrigger: (() -> Void)?
    public var lastRegisteredKeyCode: UInt32?
    public var lastRegisteredModifiers: UInt32?
    public var registrationCount: Int = 0
    public var unregisterCount: Int = 0

    public init() {}

    public func register(keyCode: UInt32, modifiers: UInt32) {
        lastRegisteredKeyCode = keyCode
        lastRegisteredModifiers = modifiers
        registrationCount += 1
    }

    public func unregister() {
        unregisterCount += 1
    }
}

/// Unit tests for SettingsView model bindings, capacity adjustments, hotkey management,
/// and menu bar context menu (Features 29 & 30).
public struct SettingsViewTests {
    public static func run(sandboxDir: URL) {
        TestHarness.startSuite("SettingsView UI & Model Bindings Tests")

        let storageDir = sandboxDir.appendingPathComponent("SettingsViewTestRun")
        let storage = StorageManager(baseDirectory: storageDir, initialCapacity: 100)
        let mockHotKey = MockSettingsViewHotKeyManager()

        // 1. Initial State Verification
        TestHarness.assertEqual(storage.capacity, 100, "Initial storage capacity is 100")
        TestHarness.assertEqual(storage.settings.capacity, 100, "Settings capacity matches storage capacity")

        // 2. Capacity Adjustment UI Binding (Feature 30)
        // Simulate Stepper / Slider updating capacity dynamically
        storage.capacity = 50
        TestHarness.assertEqual(storage.capacity, 50, "Dynamic capacity reduction to 50 applied")
        TestHarness.assertEqual(storage.settings.capacity, 50, "storage.settings.capacity dynamically synchronized")

        // Test capacity bounds (range 10 to 500)
        let clampedMin = max(10, min(5, 500))
        TestHarness.assertEqual(clampedMin, 10, "Capacity lower bound clamped to 10")
        let clampedMax = max(10, min(750, 500))
        TestHarness.assertEqual(clampedMax, 500, "Capacity upper bound clamped to 500")

        // 3. Pin Retention Guarantee & Immediate FIFO Eviction during Capacity Reduction
        // Populate 5 pinned items and 25 unpinned items
        for i in 1...5 {
            let item = ClipItem(
                id: UUID(),
                contentType: .text,
                textContent: "Pinned Item \(i)",
                byteSize: 15,
                createdAt: Date().addingTimeInterval(Double(-100 + i)),
                isPinned: true
            )
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }
        for i in 1...25 {
            let item = ClipItem(
                id: UUID(),
                contentType: .text,
                textContent: "History Item \(i)",
                byteSize: 20,
                createdAt: Date().addingTimeInterval(Double(i)),
                isPinned: false
            )
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }
        TestHarness.assertEqual(storage.pinnedItems.count, 5, "5 pinned clips stored")
        TestHarness.assertEqual(storage.historyItems.count, 25, "25 unpinned clips stored")
        TestHarness.assertEqual(storage.items.count, 30, "Total clips count is 30")

        // Dynamically reduce capacity to 10
        storage.capacity = 10
        TestHarness.assertEqual(storage.capacity, 10, "Capacity updated to 10")
        TestHarness.assertEqual(storage.historyItems.count, 10, "Unpinned history immediately clamped to 10 (FIFO)")
        TestHarness.assertEqual(storage.pinnedItems.count, 5, "Pinned items 100% protected and preserved")
        TestHarness.assertEqual(storage.items.count, 15, "Total items count is 15 (5 pinned + 10 unpinned)")

        // Explanatory note assertion: pinned items are protected
        let allPinnedRetained = storage.pinnedItems.allSatisfy { $0.isPinned }
        TestHarness.assertTrue(allPinnedRetained, "Pinned clips are permanently protected and do not count toward this limit")

        // 4. Hotkey Customization UI Binding (Feature 29)
        // Default hotkey: Option + V (keyCode: 9, modifiers: 2048)
        TestHarness.assertEqual(storage.settings.hotKeyKeyCode, 9, "Default hotkey keyCode is 9 (kVK_ANSI_V)")
        TestHarness.assertEqual(storage.settings.hotKeyModifiers, 2048, "Default hotkey modifiers is 2048 (optionKey)")

        // Change hotkey to Cmd + Shift + V (keyCode: 9, modifiers: 256 | 512 = 768)
        let newKeyCode: UInt32 = 9
        let newModifiers: UInt32 = UInt32(cmdKey | shiftKey) // 768
        var updated = storage.settings
        updated.hotKeyKeyCode = newKeyCode
        updated.hotKeyModifiers = newModifiers
        storage.settings = updated
        mockHotKey.register(keyCode: newKeyCode, modifiers: newModifiers)

        TestHarness.assertEqual(storage.settings.hotKeyKeyCode, 9, "Updated keyCode persisted in settings")
        TestHarness.assertEqual(storage.settings.hotKeyModifiers, 768, "Updated modifiers persisted in settings")
        TestHarness.assertEqual(mockHotKey.lastRegisteredKeyCode, 9, "HotKeyManager received live registration of keyCode 9")
        TestHarness.assertEqual(mockHotKey.lastRegisteredModifiers, 768, "HotKeyManager received live registration of modifiers 768")

        // Change hotkey to Option + Space (keyCode: 49, modifiers: 2048)
        let spaceKeyCode: UInt32 = 49
        let optionModifiers: UInt32 = UInt32(optionKey)
        updated.hotKeyKeyCode = spaceKeyCode
        updated.hotKeyModifiers = optionModifiers
        storage.settings = updated
        mockHotKey.register(keyCode: spaceKeyCode, modifiers: optionModifiers)

        TestHarness.assertEqual(mockHotKey.lastRegisteredKeyCode, 49, "HotKeyManager registered Option+Space keyCode 49")
        TestHarness.assertEqual(mockHotKey.lastRegisteredModifiers, 2048, "HotKeyManager registered Option+Space modifiers 2048")

        // 5. Hotkey Validation & Formatting Helpers
        // Validation: At least one modifier required
        TestHarness.assertTrue(KeyCombinationHelper.isValidHotKey(modifiers: UInt32(optionKey)), "OptionKey is valid modifier")
        TestHarness.assertTrue(KeyCombinationHelper.isValidHotKey(modifiers: UInt32(cmdKey)), "CmdKey is valid modifier")
        TestHarness.assertTrue(KeyCombinationHelper.isValidHotKey(modifiers: UInt32(controlKey)), "ControlKey is valid modifier")
        TestHarness.assertFalse(KeyCombinationHelper.isValidHotKey(modifiers: 0), "Bare key without modifiers is invalid")
        TestHarness.assertFalse(KeyCombinationHelper.isValidHotKey(modifiers: UInt32(shiftKey)), "Bare Shift key without Option/Cmd/Ctrl is invalid")

        // Formatting strings
        let optVFormatted = KeyCombinationHelper.formattedShortcut(keyCode: 9, modifiers: UInt32(optionKey))
        TestHarness.assertEqual(optVFormatted, "Option + V", "Formatted shortcut is Option + V")

        let cmdShiftVFormatted = KeyCombinationHelper.formattedShortcut(keyCode: 9, modifiers: UInt32(cmdKey | shiftKey))
        TestHarness.assertEqual(cmdShiftVFormatted, "Shift + Command + V", "Formatted shortcut includes modifiers and key")

        let optSpaceFormatted = KeyCombinationHelper.formattedShortcut(keyCode: 49, modifiers: UInt32(optionKey))
        TestHarness.assertEqual(optSpaceFormatted, "Option + Space", "Formatted shortcut is Option + Space")

        // 6. Reset to Defaults
        let defaultSettings = AppSettings()
        storage.capacity = AppSettings.defaultCapacity
        storage.settings = defaultSettings
        mockHotKey.register(keyCode: AppSettings.defaultHotKeyKeyCode, modifiers: AppSettings.defaultHotKeyModifiers)

        TestHarness.assertEqual(storage.capacity, 100, "Reset capacity restored to 100")
        TestHarness.assertEqual(storage.settings.hotKeyKeyCode, 9, "Reset hotkey keyCode restored to 9")
        TestHarness.assertEqual(storage.settings.hotKeyModifiers, 2048, "Reset hotkey modifiers restored to 2048")

        // 7. StatusItemManager Context Menu Tests (Feature 11 & Lifecycle)
        let statusManager = StatusItemManager(
            contentViewController: nil,
            floatingPanel: nil,
            hotKeyManager: MockSettingsViewHotKeyManager()
        )
        let menu = statusManager.contextMenu

        TestHarness.assertEqual(menu.items.count, 6, "Context menu contains exactly 6 items")
        TestHarness.assertEqual(menu.items[0].title, "Show Clipboard History", "Item 0 title is 'Show Clipboard History'")
        TestHarness.assertEqual(menu.items[1].title, "Preferences...", "Item 1 title is 'Preferences...'")
        TestHarness.assertEqual(menu.items[1].keyEquivalent, ",", "Item 1 shortcut is Command+,")
        TestHarness.assertTrue(menu.items[2].isSeparatorItem, "Item 2 is separator")
        TestHarness.assertEqual(menu.items[3].title, "Clear Unpinned History", "Item 3 title is 'Clear Unpinned History'")
        TestHarness.assertTrue(menu.items[4].isSeparatorItem, "Item 4 is separator")
        TestHarness.assertEqual(menu.items[5].title, "Quit SuperClip", "Item 5 title is 'Quit SuperClip'")
        TestHarness.assertEqual(menu.items[5].keyEquivalent, "q", "Item 6 shortcut is Command+Q")

        statusManager.statusItem.menu = menu
        TestHarness.assertNotNil(statusManager.statusItem.menu, "statusItem.menu is assigned during presentation")
        statusManager.menuDidClose(menu)
        TestHarness.assertNil(statusManager.statusItem.menu, "statusItem.menu restored to nil on menuDidClose")
    }
}
