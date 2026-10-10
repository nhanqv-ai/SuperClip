import Foundation
import AppKit
import SuperClipCore

public struct MainClipViewTests {
    public static func run(sandboxDir: URL) {
        TestHarness.startSuite("MainClipView Root Container Integration Tests")

        let storage = StorageManager(baseDirectory: sandboxDir, initialCapacity: 10)
        let testPB = NSPasteboard(name: .init("com.superclip.test.main.\(UUID().uuidString)"))
        let writer = PasteboardWriter(pasteboard: testPB)
        var dismissed = false
        let coordinator = ClipboardActionCoordinator(
            storageManager: storage,
            pasteboardWriter: writer,
            onDismiss: { dismissed = true }
        )

        // 1. Populate initial clips
        for i in 1...3 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Main Clip \(i)", byteSize: 11, isPinned: false)
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }
        TestHarness.assertEqual(storage.items.count, 3, "Storage holds 3 items")

        // 2. Shortcut Invocation from Main Container
        let visible = ShortcutNavigator.resolveVisibleItems(items: storage.items, query: "")
        if let target = ShortcutNavigator.targetItem(forShortcut: 1, in: visible) {
            dismissed = false
            coordinator.selectAndCopy(item: target)
            TestHarness.assertEqual(testPB.string(forType: .string), "Main Clip 3", "Shortcut 1 selected top clip")
            TestHarness.assertTrue(dismissed, "onDismiss fired on shortcut copy")
        } else {
            TestHarness.assertTrue(false, "Shortcut 1 failed to resolve target")
        }

        // 3. Clear Unpinned History Action
        coordinator.clearUnpinned()
        TestHarness.assertEqual(storage.items.count, 0, "Clear unpinned history emptied storage")
    }
}
