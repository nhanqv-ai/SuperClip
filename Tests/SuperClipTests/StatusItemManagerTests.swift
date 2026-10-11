import Foundation
import AppKit
import Carbon
import SuperClipCore

private final class MockFloatingPanel: FloatingPanelPresenting {
    var isVisible: Bool = false
    var isKeyWindow: Bool = false
    var dismissCalled: Int = 0
    var showCalled: Int = 0
    var lastPoint: NSPoint?

    func show(near mouseLocation: NSPoint) {
        isVisible = true
        isKeyWindow = true
        showCalled += 1
        lastPoint = mouseLocation
    }

    func dismiss() {
        isVisible = false
        isKeyWindow = false
        dismissCalled += 1
    }
}

private final class MockHotKeyManager: HotKeyManaging {
    var onTrigger: (() -> Void)?
    var registered: Bool = false
    var registeredKeyCode: UInt32 = 0
    var registeredModifiers: UInt32 = 0

    func register(keyCode: UInt32, modifiers: UInt32) {
        registered = true
        registeredKeyCode = keyCode
        registeredModifiers = modifiers
    }

    func unregister() {
        registered = false
    }
}

public struct StatusItemManagerTests {
    public static func run() {
        TestHarness.startSuite("StatusItemManager & Dual Presentation Coordination")

        let testVC = NSViewController()
        testVC.view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 480))

        let mockPanel = MockFloatingPanel()
        let mockHotKey = MockHotKeyManager()
        let manager = StatusItemManager(
            contentViewController: testVC,
            floatingPanel: mockPanel,
            hotKeyManager: mockHotKey
        )

        // Anchor status button to an active host window so AppKit popover.show succeeds in CLI
        let hostWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        hostWindow.orderFrontRegardless()
        if let btn = manager.statusItem.button {
            hostWindow.contentView?.addSubview(btn)
        }

        // Test 1: Status item configuration in system menu bar
        guard let button = manager.statusItem.button else {
            TestHarness.recordFail("Status button presence", reason: "statusItem.button was nil")
            return
        }
        TestHarness.assertNotNil(button.image, "Status button has image")
        TestHarness.assertTrue(button.image?.isTemplate == true, "Status button image has isTemplate = true")
        TestHarness.assertEqual(button.toolTip, "SuperClip - Clipboard History (Option+V)", "Tooltip matches invariant without emojis")

        // Test 2: HotKey initialization
        TestHarness.assertTrue(mockHotKey.registered, "HotKey registered on init")
        TestHarness.assertEqual(mockHotKey.registeredKeyCode, 9, "Registered keyCode is Option+V (9)")
        TestHarness.assertEqual(mockHotKey.registeredModifiers, 2048, "Registered modifier is optionKey (2048)")

        // Test 3: NSPopover attributes
        TestHarness.assertEqual(manager.popover.behavior, .transient, "NSPopover behavior is .transient")
        TestHarness.assertFalse(manager.popover.animates, "Popover animates is false for synchronous mutual exclusion")
        TestHarness.assertEqual(manager.popover.contentSize.width, 360, "Popover content width is 360")
        TestHarness.assertEqual(manager.popover.contentSize.height, 480, "Popover content height is 480")
        TestHarness.assertFalse(manager.popover.isShown, "Popover initially not shown")

        // Test 4: HotKey triggers floating panel presentation
        mockHotKey.onTrigger?()
        TestHarness.assertEqual(mockPanel.showCalled, 1, "Panel show called on hotkey")
        TestHarness.assertTrue(mockPanel.isVisible, "Panel is visible after hotkey")

        // Test 5: Mutual exclusion - showPopover dismisses floating panel
        manager.showPopover()
        TestHarness.assertTrue(manager.popover.isShown, "Popover is genuinely shown when anchored to host window")
        TestHarness.assertEqual(mockPanel.dismissCalled, 1, "Floating panel dismissed when popover opens")
        TestHarness.assertFalse(mockPanel.isVisible, "Floating panel is no longer visible")

        // Test 6: HotKey trigger closes popover and shows floating panel
        manager.handleHotKeyTrigger()
        TestHarness.assertFalse(manager.popover.isShown, "Popover closed synchronously on hotkey trigger")
        TestHarness.assertEqual(mockPanel.showCalled, 2, "Floating panel shown on hotkey trigger")
        TestHarness.assertTrue(mockPanel.isVisible, "Floating panel is visible after hotkey")

        // Test 7: Toggle behavior - repeated hotkey while key dismisses panel
        mockPanel.isVisible = true
        mockPanel.isKeyWindow = true
        manager.handleHotKeyTrigger()
        TestHarness.assertEqual(mockPanel.dismissCalled, 2, "Floating panel toggled closed on repeated hotkey")
        TestHarness.assertFalse(mockPanel.isVisible, "Panel dismissed")

        // Test 8: DismissAll closes both presentations
        mockPanel.isVisible = true
        var dismissCallbackFired = false
        manager.onDismissRequested = { dismissCallbackFired = true }
        manager.dismissAll()
        TestHarness.assertFalse(mockPanel.isVisible, "dismissAll dismissed floating panel")
        TestHarness.assertFalse(manager.popover.isShown, "dismissAll dismissed popover")
        TestHarness.assertTrue(dismissCallbackFired, "onDismissRequested fired on dismissAll")

        // Test 9: Transient toggle bounce debounce (250ms window)
        let now = ProcessInfo.processInfo.systemUptime
        manager.setLastPopoverCloseTimestampForTesting(now)
        // Click status button within 250ms of close
        manager.statusItemClicked(nil)
        TestHarness.assertFalse(manager.popover.isShown, "Debounce prevents immediate reopen within 250ms")

        // Test 10: HotKey update
        manager.updateHotKey(keyCode: 8, modifiers: 4096)
        TestHarness.assertTrue(mockHotKey.registered, "HotKey re-registered after update")
        TestHarness.assertEqual(mockHotKey.registeredKeyCode, 8, "Updated keyCode matches")
        TestHarness.assertEqual(mockHotKey.registeredModifiers, 4096, "Updated modifiers match")

        // Test 11: Initialization from StorageManager with saved custom hotkey
        let customHotKeyDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let customStorage = StorageManager(baseDirectory: customHotKeyDir)
        var customSettings = customStorage.settings
        customSettings.hotKeyKeyCode = 49 // Space
        customSettings.hotKeyModifiers = UInt32(optionKey) // Option
        customStorage.settings = customSettings

        let mockHotKey2 = MockHotKeyManager()
        let customManager = StatusItemManager(
            hotKeyManager: mockHotKey2,
            storageManager: customStorage
        )
        TestHarness.assertTrue(mockHotKey2.registered, "HotKey registered on init with custom storage")
        TestHarness.assertEqual(mockHotKey2.registeredKeyCode, 49, "Registered keyCode is custom Option+Space (49)")
        TestHarness.assertEqual(mockHotKey2.registeredModifiers, UInt32(optionKey), "Registered modifier is optionKey")
        TestHarness.assertEqual(
            customManager.statusItem.button?.toolTip,
            "SuperClip - Clipboard History (Option + Space)",
            "Status button tooltip reflects custom registered shortcut"
        )

        // Test 12: Dynamic runtime update of status button tooltip on settings mutation
        var dynamicSettings = customStorage.settings
        dynamicSettings.hotKeyKeyCode = 9 // V
        dynamicSettings.hotKeyModifiers = UInt32(cmdKey | shiftKey) // Cmd + Shift
        customStorage.settings = dynamicSettings

        RunLoop.current.run(until: Date().addingTimeInterval(0.05))

        TestHarness.assertEqual(
            customManager.statusItem.button?.toolTip,
            "SuperClip - Clipboard History (Shift + Command + V)",
            "Status button tooltip dynamically reflects live settings mutation"
        )

        hostWindow.orderOut(nil)
    }
}
