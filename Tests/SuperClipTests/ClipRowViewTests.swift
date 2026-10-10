import Foundation
import AppKit
import SuperClipCore

public struct ClipRowViewTests {
    public static func run(sandboxDir: URL) {
        TestHarness.startSuite("ClipRowView Presentation & Row Actions Tests")

        let storage = StorageManager(baseDirectory: sandboxDir, initialCapacity: 10)
        let testPB = NSPasteboard(name: .init("com.superclip.test.row.\(UUID().uuidString)"))
        let writer = PasteboardWriter(pasteboard: testPB)
        var dismissed = false
        let coordinator = ClipboardActionCoordinator(
            storageManager: storage,
            pasteboardWriter: writer,
            onDismiss: { dismissed = true }
        )

        // 1. Badge Assignment for first 9 rows
        for i in 0..<12 {
            let label = ShortcutNavigator.badgeLabel(forIndex: i)
            if i < 9 {
                TestHarness.assertEqual(label, "\(i + 1)", "Row \(i) receives badge \(i + 1)")
            } else {
                TestHarness.assertNil(label, "Row \(i) (>= 9) receives no badge")
            }
        }

        // 2. Row Action: Pin Toggle
        let item1 = ClipItem(id: UUID(), contentType: .text, textContent: "Toggle Pin Item", byteSize: 15, isPinned: false)
        storage.addClip(item: item1, imageData: nil, thumbData: nil)
        TestHarness.assertFalse(storage.items.first!.isPinned, "Initially unpinned")
        coordinator.togglePin(item: item1)
        TestHarness.assertTrue(storage.items.first!.isPinned, "Toggled to pinned")

        // 3. Row Action: Copy Button
        dismissed = false
        coordinator.copyItem(item: storage.items.first!, dismiss: true)
        TestHarness.assertEqual(testPB.string(forType: .string), "Toggle Pin Item", "Row copy wrote to pasteboard")
        TestHarness.assertTrue(dismissed, "Row copy dismissed panel")

        // 4. Row Action: Delete Item
        coordinator.deleteItem(item: storage.items.first!)
        TestHarness.assertEqual(storage.items.count, 0, "Item deleted permanently")

        // 5. Relative Time Formatter
        let now = Date()
        TestHarness.assertEqual(RelativeTimeFormatter.format(now), "Just now", "Instant timestamp formats to 'Just now'")

        // 6. Thumbnail Image Cache
        let dummyURL = URL(fileURLWithPath: "/tmp/dummy.png")
        let dummyImage = NSImage(size: NSSize(width: 10, height: 10))
        ThumbnailImageCache.shared.setImage(dummyImage, for: dummyURL)
        TestHarness.assertNotNil(ThumbnailImageCache.shared.image(for: dummyURL), "Cache returns stored image")
        ThumbnailImageCache.shared.removeImage(for: dummyURL)
        TestHarness.assertNil(ThumbnailImageCache.shared.image(for: dummyURL), "Cache returns nil after removal")
    }
}
