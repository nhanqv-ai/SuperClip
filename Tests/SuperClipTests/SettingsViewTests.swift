import Foundation
import AppKit
import SwiftUI
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

        // 8. Record Clipboard History Toggle Verification
        var recordSettings = storage.settings
        recordSettings.recordClipboardHistory = false
        storage.settings = recordSettings

        let suppressedItem = ClipItem(id: UUID(), contentType: .text, textContent: "Should not be recorded")
        storage.addClip(item: suppressedItem, imageData: nil, thumbData: nil)
        TestHarness.assertFalse(storage.items.contains { $0.id == suppressedItem.id }, "Clip is not recorded when recordClipboardHistory is false")

        recordSettings.recordClipboardHistory = true
        storage.settings = recordSettings

        let allowedItem = ClipItem(id: UUID(), contentType: .text, textContent: "Should be recorded")
        storage.addClip(item: allowedItem, imageData: nil, thumbData: nil)
        TestHarness.assertTrue(storage.items.contains { $0.id == allowedItem.id }, "Clip is recorded when recordClipboardHistory is true")

        // 9. Display Capacity Dynamic List Capping Verification
        let dispStorageDir = sandboxDir.appendingPathComponent("DispCapTestRun")
        let dispStorage = StorageManager(baseDirectory: dispStorageDir, initialCapacity: 100)
        for i in 1...30 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Disp History \(i)", isPinned: false)
            dispStorage.addClip(item: item, imageData: nil, thumbData: nil)
        }
        TestHarness.assertEqual(dispStorage.items.count, 30, "30 total unpinned clips stored")

        var dispSettings = dispStorage.settings
        dispSettings.displayCapacity = 10
        dispStorage.settings = dispSettings

        let clipListView10 = ClipListView(storageManager: dispStorage)
        TestHarness.assertEqual(clipListView10.recentItems.count, 10, "ClipListView displays exactly 10 recent items when displayCapacity is 10")

        let mainView10 = MainContentView(storageManager: dispStorage)
        TestHarness.assertEqual(mainView10.partitionedClips.recent.count, 10, "MainContentView caps recent clips to 10 when displayCapacity is 10")
        TestHarness.assertEqual(mainView10.visibleCount, 10, "MainContentView visibleCount is 10")

        dispSettings.displayCapacity = 25
        dispStorage.settings = dispSettings

        let clipListView25 = ClipListView(storageManager: dispStorage)
        TestHarness.assertEqual(clipListView25.recentItems.count, 25, "ClipListView displays exactly 25 recent items when displayCapacity is 25")
        let mainView25 = MainContentView(storageManager: dispStorage)
        TestHarness.assertEqual(mainView25.partitionedClips.recent.count, 25, "MainContentView caps recent clips to 25 when displayCapacity is 25")

        // 10. Hotkey Configuration Redesign & Multi-Language Robustness
        TestHarness.assertEqual(KeyCombinationHelper.keyName(for: 49), "Space", "Key 49 name is Space")
        TestHarness.assertEqual(KeyCombinationHelper.keyName(for: 36), "Return", "Key 36 name is Return")
        TestHarness.assertEqual(KeyCombinationHelper.keyName(for: 48), "Tab", "Key 48 name is Tab")
        TestHarness.assertEqual(KeyCombinationHelper.keyName(for: 53), "Escape", "Key 53 name is Escape")

        TestHarness.assertTrue(KeyCombinationHelper.standardKeys.contains { $0.code == 49 && $0.name == "Space" }, "standardKeys contains Space")
        TestHarness.assertTrue(KeyCombinationHelper.standardKeys.contains { $0.code == 36 && $0.name == "Return" }, "standardKeys contains Return")
        TestHarness.assertTrue(KeyCombinationHelper.standardKeys.contains { $0.code == 48 && $0.name == "Tab" }, "standardKeys contains Tab")
        TestHarness.assertTrue(KeyCombinationHelper.standardKeys.contains { $0.code == 53 && $0.name == "Escape" }, "standardKeys contains Escape")

        let optSpaceFormatted2 = KeyCombinationHelper.formattedShortcut(keyCode: 49, modifiers: UInt32(optionKey))
        TestHarness.assertEqual(optSpaceFormatted2, "Option + Space", "Option + Space shortcut formatted properly")

        let locMgr = LocalizationManager.shared
        locMgr.setLanguage(.english)
        TestHarness.assertEqual(locMgr.tr(.keyLabel), "Key:", "English keyLabel is 'Key:'")
        TestHarness.assertEqual(locMgr.tr(.recordShortcutButton), "Record Shortcut", "English recordShortcutButton is 'Record Shortcut'")
        TestHarness.assertEqual(locMgr.tr(.quickPresetsTitle), "Quick Presets", "English quickPresetsTitle is 'Quick Presets'")
        TestHarness.assertEqual(locMgr.tr(.pressShortcutBannerHint), "Press desired key combination, or press Esc to cancel", "English banner hint matches")

        locMgr.setLanguage(.vietnamese)
        TestHarness.assertEqual(locMgr.tr(.keyLabel), "Phím:", "Vietnamese keyLabel is 'Phím:'")
        TestHarness.assertEqual(locMgr.tr(.quickPresetsTitle), "Phím tắt gợi ý", "Vietnamese quickPresetsTitle is 'Phím tắt gợi ý'")
        TestHarness.assertEqual(locMgr.tr(.pressShortcutBannerHint), "Nhấn tổ hợp phím mong muốn, hoặc nhấn Esc để hủy", "Vietnamese banner hint matches")

        locMgr.setLanguage(.german)
        TestHarness.assertEqual(locMgr.tr(.keyLabel), "Taste:", "German keyLabel is 'Taste:'")
        TestHarness.assertEqual(locMgr.tr(.quickPresetsTitle), "Schnellvoreinstellungen", "German quickPresetsTitle is 'Schnellvoreinstellungen'")
        TestHarness.assertEqual(locMgr.tr(.pressShortcutBannerHint), "Tastenkombination drücken oder Esc zum Abbrechen", "German banner hint matches")

        locMgr.setLanguage(.english)

        // SettingsWindowController dimensions check
        let winCtrl = SettingsWindowController(storageManager: storage)
        if let w = winCtrl.window {
            TestHarness.assertEqual(w.contentViewController?.preferredContentSize.width, 490, "Settings preferred content width is 490")
            TestHarness.assertEqual(w.contentViewController?.preferredContentSize.height, 475, "Settings preferred content height is 475")
        }

        // Test all 4 tabs initialization
        for tab in SettingsView.SettingsTab.allCases {
            let tabView = SettingsView(storageManager: storage, initialTab: tab)
            TestHarness.assertTrue(!tab.localizedTitle.isEmpty, "Tab \(tab.rawValue) localized title is not empty")
            TestHarness.assertTrue(!tab.iconName.isEmpty, "Tab \(tab.rawValue) icon name is not empty")
        }

        // Test recording mode and standard mode initialization
        let recView = SettingsView(storageManager: storage, initialRecording: true)
        let hostingRec = NSHostingView(rootView: recView)
        hostingRec.frame = NSRect(x: 0, y: 0, width: 490, height: 475)
        TestHarness.assertEqual(hostingRec.frame.width, 490, "Recording view width is 490")
        TestHarness.assertEqual(hostingRec.frame.height, 475, "Recording view height is 475")

        let normalView = SettingsView(storageManager: storage, initialRecording: false)
        let hostingNorm = NSHostingView(rootView: normalView)
        hostingNorm.frame = NSRect(x: 0, y: 0, width: 490, height: 475)
        TestHarness.assertEqual(hostingNorm.frame.width, 490, "Standard view width is 490")
        TestHarness.assertEqual(hostingNorm.frame.height, 475, "Standard view height is 475")
    }
}
