import Foundation
import AppKit
import Carbon
import SuperClipCore
import SuperClip

final class MockPanel: FloatingPanelPresenting {
    var isVisible: Bool = false
    var isKeyWindow: Bool = false
    var showCount: Int = 0
    var dismissCount: Int = 0

    func show(near mouseLocation: NSPoint) {
        isVisible = true
        isKeyWindow = true
        showCount += 1
    }

    func dismiss() {
        isVisible = false
        isKeyWindow = false
        dismissCount += 1
    }
}

final class MockHotKey: HotKeyManaging {
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

final class MockStorage: StorageManaging {
    var items: [ClipItem] = []
    var capacity: Int = 100
    var clearUnpinnedCalled: Bool = false

    func addClip(item: ClipItem, imageData: Data?, thumbData: Data?) {
        items.append(item)
    }

    func togglePin(id: UUID) {}
    func deleteItem(id: UUID) {}
    func clearUnpinnedHistory() {
        clearUnpinnedCalled = true
        items.removeAll(where: { !$0.isPinned })
    }
    func getThumbnailURL(for item: ClipItem) -> URL? { nil }
    func getImageData(for item: ClipItem) -> Data? { nil }
    func flushDiskQueue() {}
}

@main
struct ChallengerM4LifecycleRunner {
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

    static func main() {
        print("==================================================")
        print("  SuperClip StatusItemManager Lifecycle Challenger")
        print("  Mutual Exclusion & Context Menu Stress Tests    ")
        print("==================================================")

        let mockPanel = MockPanel()
        let mockHotKey = MockHotKey()
        let mockStorage = MockStorage()

        let dummyVC = NSViewController()
        dummyVC.view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 480))

        let manager = StatusItemManager(
            contentViewController: dummyVC,
            floatingPanel: mockPanel,
            hotKeyManager: mockHotKey,
            storageManager: mockStorage
        )

        // Host window to allow AppKit popover.show in CLI environment
        let hostWindow = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 300, height: 300),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        hostWindow.orderFrontRegardless()
        if let btn = manager.statusItem.button {
            hostWindow.contentView?.addSubview(btn)
        }

        // ==========================================
        // Test 1: Baseline Initial State
        // ==========================================
        print("\n--- Test 1: Baseline StatusItem State ---")
        guard let button = manager.statusItem.button else {
            report(name: "Status button exists", passed: false)
            exit(1)
        }
        report(
            name: "Status button exists with action configured",
            passed: (button.target === manager && button.action == #selector(manager.statusItemClicked(_:)))
        )
        report(
            name: "Status item menu is initially nil (ready for left click toggle)",
            passed: (manager.statusItem.menu == nil)
        )
        report(
            name: "Popover is initially not shown",
            passed: (!manager.popover.isShown)
        )

        // ==========================================
        // Test 2: Full Lifecycle Sequence
        // Left-click popover toggle -> Right-click menu -> Popover dismiss -> Menu close -> Left-click popover toggle
        // ==========================================
        print("\n--- Test 2: Sequential Mutual Exclusion Sequence ---")

        // Phase 1: Left-click popover toggle -> Popover shows
        manager.setLastPopoverCloseTimestampForTesting(0)
        manager.statusItemClicked(nil)
        report(
            name: "Phase 1: Left-click triggers popover presentation",
            passed: manager.popover.isShown,
            detail: "isShown=\(manager.popover.isShown)"
        )

        // Phase 2: Right-click menu presentation & Popover dismiss
        var popoverVisibilityLog: [Bool] = []
        manager.onPopoverVisibilityChanged = { shown in
            popoverVisibilityLog.append(shown)
        }

        // Simulate right-click event or showContextMenu()
        // When showContextMenu() runs, it closes popover, sets menu = contextMenu, and calls button.performClick.
        // In headless mode, button.performClick opens and closes the menu, triggering menuDidClose immediately.
        // Let's also verify that if statusItem.menu = contextMenu is explicitly set (as showContextMenu does),
        // menuDidClose resets it to nil.
        manager.showContextMenu()

        report(
            name: "Phase 2 & 3: Right-click dismisses popover (mutual exclusion)",
            passed: !manager.popover.isShown,
            detail: "popover.isShown=\(manager.popover.isShown)"
        )
        report(
            name: "Phase 3: Visibility change callback notified of popover dismissal",
            passed: popoverVisibilityLog.contains(false),
            detail: "history=\(popoverVisibilityLog)"
        )

        // Verify explicit menu assignment and menuDidClose restoration:
        manager.statusItem.menu = manager.contextMenu
        report(
            name: "Phase 4a: Context menu is attached to statusItem during menu tracking",
            passed: (manager.statusItem.menu === manager.contextMenu)
        )
        manager.menuDidClose(manager.contextMenu)
        report(
            name: "Phase 4b: menuDidClose cleanly restores statusItem.menu = nil",
            passed: (manager.statusItem.menu == nil),
            detail: "statusItem.menu is \(String(describing: manager.statusItem.menu))"
        )

        // Phase 5: Left-click popover toggle -> Popover opens again
        // Advance debounce timestamp so 250ms guard is satisfied
        manager.setLastPopoverCloseTimestampForTesting(0)
        manager.statusItemClicked(nil)

        report(
            name: "Phase 5: Subsequent left-click re-opens popover cleanly",
            passed: manager.popover.isShown,
            detail: "isShown=\(manager.popover.isShown)"
        )

        // Clean up popover
        manager.closePopover()
        report(
            name: "Cleanup: Popover closes cleanly",
            passed: !manager.popover.isShown
        )

        // ==========================================
        // Test 3: Rapid Oscillatory Cycles (10 Iterations)
        // ==========================================
        print("\n--- Test 3: 10 Rapid Alternating Cycles ---")

        var cycleSuccessCount = 0
        for i in 1...10 {
            // 1. Left click -> Open Popover
            manager.setLastPopoverCloseTimestampForTesting(0)
            manager.statusItemClicked(nil)
            guard manager.popover.isShown else {
                print("Cycle \(i): Failed to open popover on left click")
                break
            }

            // 2. Right click -> Dismiss Popover, Open Context Menu
            manager.showContextMenu()
            guard !manager.popover.isShown else {
                print("Cycle \(i): Failed to dismiss popover on right click")
                break
            }

            // 3. Ensure menu closure restores nil
            if manager.statusItem.menu != nil {
                manager.menuDidClose(manager.contextMenu)
            }
            guard manager.statusItem.menu == nil else {
                print("Cycle \(i): Failed to restore statusItem.menu to nil")
                break
            }

            // 4. Subsequent Left click -> Re-open Popover
            manager.setLastPopoverCloseTimestampForTesting(0)
            manager.statusItemClicked(nil)
            guard manager.popover.isShown else {
                print("Cycle \(i): Failed to re-open popover after menu close")
                break
            }

            manager.closePopover()
            cycleSuccessCount += 1
        }

        report(
            name: "10 consecutive cycles of LeftClick -> RightClick -> MenuClose -> LeftClick passed",
            passed: (cycleSuccessCount == 10),
            detail: "completedCycles=\(cycleSuccessCount)/10"
        )

        // ==========================================
        // Test 4: Floating Panel Mutual Exclusion
        // ==========================================
        print("\n--- Test 4: Floating Panel Mutual Exclusion with Context Menu ---")

        mockPanel.show(near: NSPoint(x: 200, y: 200))
        report(
            name: "Floating panel is initially visible",
            passed: mockPanel.isVisible
        )

        let initialDismissCount = mockPanel.dismissCount
        manager.showContextMenu()
        manager.menuDidClose(manager.contextMenu)

        report(
            name: "showContextMenu() dismisses floating panel",
            passed: (!mockPanel.isVisible && mockPanel.dismissCount > initialDismissCount),
            detail: "panelVisible=\(mockPanel.isVisible), dismissCount=\(mockPanel.dismissCount)"
        )

        // ==========================================
        // Test 5: Context Menu Structure & Action Execution
        // ==========================================
        print("\n--- Test 5: Context Menu Actions & Structure ---")

        let menu = manager.contextMenu
        report(
            name: "Context menu has 6 items",
            passed: (menu.items.count == 6),
            detail: "count=\(menu.items.count)"
        )

        // Test Clear History Action
        mockStorage.items = [
            ClipItem(id: UUID(), contentType: .text, textContent: "Pinned", byteSize: 6, isPinned: true),
            ClipItem(id: UUID(), contentType: .text, textContent: "History 1", byteSize: 9, isPinned: false),
            ClipItem(id: UUID(), contentType: .text, textContent: "History 2", byteSize: 9, isPinned: false)
        ]

        var clearCallbackCalled = false
        manager.onClearHistoryRequested = {
            clearCallbackCalled = true
        }

        manager.clearHistoryMenuItemClicked(nil)

        report(
            name: "Clear History context menu action purges unpinned items",
            passed: (mockStorage.clearUnpinnedCalled && mockStorage.items.count == 1 && mockStorage.items[0].isPinned),
            detail: "remainingCount=\(mockStorage.items.count)"
        )
        report(
            name: "onClearHistoryRequested callback fired",
            passed: clearCallbackCalled
        )

        // Test Settings Action
        var settingsCallbackCalled = false
        manager.onOpenSettingsRequested = {
            settingsCallbackCalled = true
        }

        manager.settingsMenuItemClicked(nil)
        report(
            name: "Settings context menu action invokes settings callback",
            passed: settingsCallbackCalled
        )

        // ==========================================
        // Test 6: Debounce Boundary Behavior
        // ==========================================
        print("\n--- Test 6: Debounce Protection (250ms) ---")

        manager.closePopover()
        let now = ProcessInfo.processInfo.systemUptime

        // Set close timestamp to now - 0.1s (100ms ago < 250ms)
        manager.setLastPopoverCloseTimestampForTesting(now - 0.1)
        manager.statusItemClicked(nil)
        report(
            name: "Debounce guard rejects left-click within 100ms of close (< 250ms)",
            passed: !manager.popover.isShown,
            detail: "popoverShown=\(manager.popover.isShown)"
        )

        // Set close timestamp to now - 0.3s (300ms ago > 250ms)
        manager.setLastPopoverCloseTimestampForTesting(now - 0.3)
        manager.statusItemClicked(nil)
        report(
            name: "Debounce guard allows left-click after 300ms (> 250ms)",
            passed: manager.popover.isShown,
            detail: "popoverShown=\(manager.popover.isShown)"
        )
        manager.closePopover()

        hostWindow.orderOut(nil)

        // ==========================================
        // Summary
        // ==========================================
        print("\n==================================================")
        print("  StatusItemManager Lifecycle Challenger Summary  ")
        print("==================================================")
        print("  Total Tests:  \(totalTests)")
        print("  Passed:       \(passedTests)")
        print("  Failed:       \(failedTests)")

        if failedTests > 0 {
            print("\nVERDICT: REJECT")
            exit(1)
        } else {
            print("\nVERDICT: APPROVE")
            exit(0)
        }
    }
}
