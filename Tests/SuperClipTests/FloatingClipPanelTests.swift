import Foundation
import AppKit
import SwiftUI
import SuperClipCore

public struct FloatingClipPanelTests {
    public static func run() {
        TestHarness.startSuite("FloatingClipPanel Lifecycle & Dismissal")

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let panel = FloatingClipPanel(rootView: Text("Test Content"))

        // Test 1: Attribute verification
        TestHarness.assertTrue(panel.isFloatingPanel, "isFloatingPanel is true")
        TestHarness.assertEqual(panel.level, .floating, "level is .floating")
        TestHarness.assertTrue(panel.canBecomeKey, "canBecomeKey is true")
        TestHarness.assertTrue(panel.canBecomeMain, "canBecomeMain is true")
        TestHarness.assertFalse(panel.isOpaque, "isOpaque is false")
        TestHarness.assertEqual(panel.backgroundColor, .clear, "backgroundColor is .clear")
        TestHarness.assertTrue(panel.hasShadow, "hasShadow is true")
        TestHarness.assertTrue(panel.styleMask.contains(.nonactivatingPanel), "styleMask contains .nonactivatingPanel")

        // Test 2: Presentation & monitor activation
        let testRect = NSRect(x: 200, y: 200, width: 360, height: 480)
        panel.present(at: testRect)
        TestHarness.assertTrue(panel.isVisible, "Panel is visible after present()")
        TestHarness.assertEqual(panel.frame, testRect, "Panel frame matches presented rect")
        TestHarness.assertTrue(panel.hasActiveMonitors, "Event monitors are active when visible")

        // Test 3: Dismissal & monitor teardown
        var dismissCallbackFired = false
        panel.onDismiss = { dismissCallbackFired = true }
        panel.dismiss()
        TestHarness.assertFalse(panel.isVisible, "Panel is not visible after dismiss()")
        TestHarness.assertFalse(panel.hasActiveMonitors, "Event monitors are removed after dismiss()")
        TestHarness.assertTrue(dismissCallbackFired, "onDismiss callback was invoked")

        // Test 4: Idempotent dismissal
        var extraDismissCount = 0
        panel.onDismiss = { extraDismissCount += 1 }
        panel.dismiss()
        panel.dismiss()
        TestHarness.assertEqual(extraDismissCount, 0, "Redundant dismiss() does not fire extra callbacks")

        // Test 5: Escape key interception
        panel.present(at: testRect)
        TestHarness.assertTrue(panel.isVisible, "Panel is visible before Escape")
        if let escEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: panel.windowNumber,
            context: nil,
            characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}",
            isARepeat: false,
            keyCode: 53
        ) {
            panel.sendEvent(escEvent)
        }
        TestHarness.assertFalse(panel.isVisible, "Escape key dismisses panel immediately")
        TestHarness.assertFalse(panel.hasActiveMonitors, "Monitors cleaned up after Escape dismissal")

        // Test 6: Item selection dismissal
        panel.present(at: testRect)
        var selectedItem: ClipItem?
        panel.onItemSelected = { selectedItem = $0 }
        let dummyItem = ClipItem(contentType: .text, textContent: "Selected Item Content")
        panel.handleItemSelection(dummyItem)
        TestHarness.assertFalse(panel.isVisible, "handleItemSelection dismisses panel immediately")
        TestHarness.assertEqual(selectedItem?.textContent, "Selected Item Content", "onItemSelected receives selected item")

        // Test 7: Toggle presentation
        panel.toggleNearCursor(size: NSSize(width: 360, height: 480))
        TestHarness.assertTrue(panel.isVisible, "toggleNearCursor presents panel when hidden")
        panel.toggleNearCursor(size: NSSize(width: 360, height: 480))
        TestHarness.assertFalse(panel.isVisible, "toggleNearCursor dismisses panel when visible")
    }
}
