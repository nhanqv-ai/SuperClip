import Foundation
import AppKit
import Carbon
import SwiftUI
import SuperClipCore
import SuperClip

/// Mock HotKeyManager tracking registration calls for deterministic unit testing.
public final class MockSettingsHotKeyManager: HotKeyManaging {
    public var onTrigger: (() -> Void)?
    public var lastRegisteredKeyCode: UInt32?
    public var lastRegisteredModifiers: UInt32?
    public var unregisterCount: Int = 0

    public init() {}

    public func register(keyCode: UInt32, modifiers: UInt32) {
        lastRegisteredKeyCode = keyCode
        lastRegisteredModifiers = modifiers
    }

    public func unregister() {
        unregisterCount += 1
    }
}

/// Comprehensive unit test suite for AppSettings persistence, capacity adjustment,
/// hotkey management, SettingsWindowController, and context menu (Milestone M4).
public struct SettingsTests {
    public static func run(sandboxDir: URL) {
        TestHarness.startSuite("Settings & Retention Capacity Management (M4)")

        // Test 1: AppSettings default values and initial state
        let defaultSettings = AppSettings()
        TestHarness.assertEqual(defaultSettings.capacity, 100, "AppSettings default capacity is 100")
        TestHarness.assertEqual(defaultSettings.hotKeyKeyCode, 9, "AppSettings default hotkey keyCode is 9 (kVK_ANSI_V)")
        TestHarness.assertEqual(defaultSettings.hotKeyModifiers, 2048, "AppSettings default modifiers is 2048 (optionKey)")
        TestHarness.assertEqual(defaultSettings.pollIntervalMs, 250, "AppSettings default poll interval is 250ms")
        TestHarness.assertEqual(defaultSettings.maxThumbnailPixelSize, 180, "AppSettings default max thumbnail size is 180px")

        // Test 2: AppSettings initializer boundary clamping
        let clampedLow = AppSettings(capacity: 2)
        TestHarness.assertEqual(clampedLow.capacity, 10, "AppSettings clamps capacity below 10 to minimum 10")
        let clampedHigh = AppSettings(capacity: 5000)
        TestHarness.assertEqual(clampedHigh.capacity, 1000, "AppSettings clamps capacity above 1000 to maximum 1000")

        // Test 3: AppSettings.maxItemCount alias property
        var aliasSettings = AppSettings()
        TestHarness.assertEqual(aliasSettings.maxItemCount, 100, "maxItemCount getter returns capacity")
        aliasSettings.maxItemCount = 200
        TestHarness.assertEqual(aliasSettings.capacity, 200, "maxItemCount setter updates capacity")

        // Test 4: StorageManager initial capacity binding
        let storageDir = sandboxDir.appendingPathComponent("SettingsTestRun")
        let storage = StorageManager(baseDirectory: storageDir, initialCapacity: 100)
        TestHarness.assertEqual(storage.capacity, 100, "StorageManager initializes with capacity 100")
        TestHarness.assertEqual(storage.settings.capacity, 100, "StorageManager.settings mirrors capacity 100")

        // Test 5: Populate items and test immediate capacity clamping
        for i in 1...5 {
            let item = ClipItem(
                id: UUID(),
                contentType: .text,
                textContent: "Pinned Item \(i)",
                byteSize: 15,
                createdAt: Date(),
                isPinned: true
            )
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }
        TestHarness.assertEqual(storage.pinnedItems.count, 5, "5 pinned items stored")

        for i in 1...20 {
            let item = ClipItem(
                id: UUID(),
                contentType: .text,
                textContent: "Unpinned History Clip \(i)",
                byteSize: 25,
                createdAt: Date(),
                isPinned: false
            )
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }
        TestHarness.assertEqual(storage.historyItems.count, 20, "20 unpinned history items stored")
        TestHarness.assertEqual(storage.items.count, 25, "Total stored items is 25 (5 pinned + 20 unpinned)")

        // Test 6: Immediate capacity reduction to 10 clamps unpinned items
        storage.capacity = 10
        TestHarness.assertEqual(storage.capacity, 10, "Capacity adjusted to 10")
        TestHarness.assertEqual(storage.settings.capacity, 10, "Settings capacity updated to 10")
        TestHarness.assertEqual(storage.historyItems.count, 10, "Unpinned items immediately clamped to capacity 10")
        TestHarness.assertEqual(storage.pinnedItems.count, 5, "100% of pinned items preserved after capacity reduction")
        TestHarness.assertEqual(storage.items.count, 15, "Total items is 15 (5 pinned + 10 unpinned)")

        // Test 7: Dynamic capacity expansion to 500
        storage.capacity = 500
        TestHarness.assertEqual(storage.capacity, 500, "Capacity increased to 500")
        TestHarness.assertEqual(storage.settings.capacity, 500, "Settings capacity increased to 500")

        // Test 8: Hotkey configuration and dynamic registration
        let mockHotKey = MockSettingsHotKeyManager()
        let newKeyCode: UInt32 = 9 // V
        let newModifiers: UInt32 = UInt32(cmdKey | shiftKey) // 256 | 512 = 768 (Cmd+Shift)

        var updatedSettings = storage.settings
        updatedSettings.hotKeyKeyCode = newKeyCode
        updatedSettings.hotKeyModifiers = newModifiers
        storage.settings = updatedSettings
        mockHotKey.register(keyCode: newKeyCode, modifiers: newModifiers)

        TestHarness.assertEqual(storage.settings.hotKeyKeyCode, newKeyCode, "Settings hotkey keyCode updated to Cmd+Shift+V")
        TestHarness.assertEqual(storage.settings.hotKeyModifiers, newModifiers, "Settings hotkey modifiers updated")
        TestHarness.assertEqual(mockHotKey.lastRegisteredKeyCode, newKeyCode, "MockHotKeyManager received registered keyCode")
        TestHarness.assertEqual(mockHotKey.lastRegisteredModifiers, newModifiers, "MockHotKeyManager received registered modifiers")

        // Test 9: Cold-start reload persistence of settings
        storage.flushDiskQueue()
        let coldStorage = StorageManager(baseDirectory: storageDir)
        TestHarness.assertEqual(coldStorage.capacity, 500, "Cold-start StorageManager restored persisted capacity 500")
        TestHarness.assertEqual(coldStorage.settings.hotKeyKeyCode, newKeyCode, "Cold-start StorageManager restored hotkey keyCode")
        TestHarness.assertEqual(coldStorage.settings.hotKeyModifiers, newModifiers, "Cold-start StorageManager restored hotkey modifiers")
        TestHarness.assertEqual(coldStorage.pinnedItems.count, 5, "Cold-start StorageManager restored all pinned items")

        // Test 10: Clear unpinned history action
        coldStorage.clearUnpinnedHistory()
        coldStorage.flushDiskQueue()
        TestHarness.assertEqual(coldStorage.historyItems.count, 0, "Zero unpinned items remain after clearUnpinnedHistory")
        TestHarness.assertEqual(coldStorage.pinnedItems.count, 5, "All 5 pinned items preserved after clearUnpinnedHistory")
        TestHarness.assertEqual(coldStorage.items.count, 5, "Total items equals pinned count after clearUnpinnedHistory")

        // Test 11: Hotkey helper utilities
        let optVFormatted = KeyCombinationHelper.formattedShortcut(keyCode: 9, modifiers: UInt32(optionKey))
        TestHarness.assertEqual(optVFormatted, "Option + V", "Formatted shortcut for Option+V is 'Option + V'")

        let cmdShiftVFormatted = KeyCombinationHelper.formattedShortcut(keyCode: 9, modifiers: UInt32(cmdKey | shiftKey))
        TestHarness.assertTrue(cmdShiftVFormatted.contains("Command"), "Formatted shortcut contains Command")
        TestHarness.assertTrue(cmdShiftVFormatted.contains("Shift"), "Formatted shortcut contains Shift")
        TestHarness.assertTrue(cmdShiftVFormatted.contains("V"), "Formatted shortcut contains V")

        TestHarness.assertTrue(KeyCombinationHelper.isValidHotKey(modifiers: UInt32(optionKey)), "Option modifier is valid hotkey")
        TestHarness.assertTrue(KeyCombinationHelper.isValidHotKey(modifiers: UInt32(cmdKey)), "Command modifier is valid hotkey")
        TestHarness.assertTrue(KeyCombinationHelper.isValidHotKey(modifiers: UInt32(controlKey)), "Control modifier is valid hotkey")
        TestHarness.assertFalse(KeyCombinationHelper.isValidHotKey(modifiers: 0), "Bare key without modifiers is invalid")
        TestHarness.assertFalse(KeyCombinationHelper.isValidHotKey(modifiers: UInt32(shiftKey)), "Bare Shift without Opt/Cmd/Ctrl is invalid")

        // Test 12: SF Symbols flat styling validation (0 emojis)
        let symbols = [
            "gearshape",
            "keyboard",
            "slider.horizontal.3",
            "internaldrive",
            "trash",
            "pin.fill",
            "folder",
            "arrow.counterclockwise",
            "xmark",
            "exclamationmark.triangle",
            "info.circle",
            "power",
            "doc.on.clipboard"
        ]
        for sym in symbols {
            let img = NSImage(systemSymbolName: sym, accessibilityDescription: nil)
            TestHarness.assertNotNil(img, "SF Symbol '\(sym)' is valid in AppKit")
        }

        // Test 13: SettingsWindowController properties and lifecycle
        var dismissalRequested = false
        let windowController = SettingsWindowController(
            storageManager: storage,
            hotKeyManager: mockHotKey,
            onPresentationDismissalRequested: {
                dismissalRequested = true
            }
        )
        guard let win = windowController.window else {
            TestHarness.assertTrue(false, "SettingsWindowController failed to create NSWindow")
            return
        }
        TestHarness.assertEqual(win.title, "SuperClip Settings", "Window title is 'SuperClip Settings'")
        TestHarness.assertTrue(win.styleMask.contains(.titled), "Window has .titled style mask")
        TestHarness.assertTrue(win.styleMask.contains(.closable), "Window has .closable style mask")
        TestHarness.assertFalse(win.isReleasedWhenClosed, "Window isReleasedWhenClosed is false")

        windowController.showSettings()
        TestHarness.assertTrue(dismissalRequested, "showSettings() triggered dismissal requested callback")
        windowController.close()

        // Test 14: StatusItemManager context menu structure and actions
        let statusItemMgr = StatusItemManager(hotKeyManager: mockHotKey)
        let menu = statusItemMgr.buildContextMenu()
        TestHarness.assertEqual(menu.items.count, 6, "Status item context menu contains 6 items (including separators)")

        let showItem = menu.items[0]
        TestHarness.assertEqual(showItem.title, "Show Clipboard History", "First item is 'Show Clipboard History'")

        let prefItem = menu.items[1]
        TestHarness.assertEqual(prefItem.title, "Preferences...", "Second item is 'Preferences...'")
        TestHarness.assertEqual(prefItem.keyEquivalent, ",", "Preferences shortcut key is ','")
        TestHarness.assertTrue(prefItem.keyEquivalentModifierMask.contains(.command), "Preferences shortcut modifier contains .command")

        TestHarness.assertTrue(menu.items[2].isSeparatorItem, "Third item is a separator")

        let clearItem = menu.items[3]
        TestHarness.assertEqual(clearItem.title, "Clear Unpinned History", "Fourth item is 'Clear Unpinned History'")

        TestHarness.assertTrue(menu.items[4].isSeparatorItem, "Fifth item is a separator")

        let quitItem = menu.items[5]
        TestHarness.assertEqual(quitItem.title, "Quit SuperClip", "Sixth item is 'Quit SuperClip'")
        TestHarness.assertEqual(quitItem.keyEquivalent, "q", "Quit shortcut key is 'q'")
        TestHarness.assertTrue(quitItem.keyEquivalentModifierMask.contains(.command), "Quit shortcut modifier contains .command")

        var openSettingsCalled = false
        var clearHistoryCalled = false
        statusItemMgr.onOpenSettingsRequested = { openSettingsCalled = true }
        statusItemMgr.onClearHistoryRequested = { clearHistoryCalled = true }

        if let act = prefItem.action {
            _ = prefItem.target?.perform(act, with: prefItem)
        }
        TestHarness.assertTrue(openSettingsCalled, "Preferences menu item triggered onOpenSettingsRequested")

        if let act = clearItem.action {
            _ = clearItem.target?.perform(act, with: clearItem)
        }
        TestHarness.assertTrue(clearHistoryCalled, "Clear history menu item triggered onClearHistoryRequested")

        // Test 15: AppDelegate lifecycle termination delegate
        let appDelegate = AppDelegate()
        let shouldTerminate = appDelegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared)
        TestHarness.assertFalse(shouldTerminate, "applicationShouldTerminateAfterLastWindowClosed returns false")
    }
}
