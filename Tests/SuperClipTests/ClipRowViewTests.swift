import Foundation
import AppKit
import SuperClipCore
import SuperClip

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

        // 7. Minimalist Single-Line Content Formatting
        let singleLineText = ClipItem(id: UUID(), contentType: .text, textContent: "Hello World")
        TestHarness.assertEqual(ClipRowView.formatContentText(for: singleLineText), "Hello World", "Single line text formats as-is")

        let multiLineText = ClipItem(id: UUID(), contentType: .text, textContent: "Line 1\r\nLine 2\nLine 3")
        TestHarness.assertEqual(ClipRowView.formatContentText(for: multiLineText), "Line 1 Line 2 Line 3", "Multi-line text replaces newlines with single line spaces")

        let whitespaceText = ClipItem(id: UUID(), contentType: .text, textContent: "  \n\t  ")
        let emptyText = ClipItem(id: UUID(), contentType: .text, textContent: "")

        let savedLang = LocalizationManager.shared.currentLanguage
        LocalizationManager.shared.setLanguage(.vietnamese)
        TestHarness.assertEqual(ClipRowView.formatContentText(for: whitespaceText), "(Khoảng trắng)", "Whitespace-only text displays as (Khoảng trắng) in Vietnamese")
        TestHarness.assertEqual(ClipRowView.formatContentText(for: emptyText), "(Empty)", "Empty text displays as (Empty)")
        let imageWithDims = ClipItem(id: UUID(), contentType: .image, imageWidth: 1920, imageHeight: 1080)
        TestHarness.assertEqual(ClipRowView.formatContentText(for: imageWithDims), "[Ảnh] 1920x1080", "Image with dimensions displays [Ảnh] <width>x<height>")

        let imageWithoutDims = ClipItem(id: UUID(), contentType: .image, imageWidth: nil, imageHeight: nil)
        TestHarness.assertEqual(ClipRowView.formatContentText(for: imageWithoutDims), "[Ảnh]", "Image without dimensions displays [Ảnh]")

        LocalizationManager.shared.setLanguage(.english)
        TestHarness.assertEqual(ClipRowView.formatContentText(for: whitespaceText), "(Whitespace)", "Whitespace-only text displays as (Whitespace) in English")
        TestHarness.assertEqual(ClipRowView.formatContentText(for: imageWithDims), "[Image] 1920x1080", "Image with dimensions displays [Image] in English")
        TestHarness.assertEqual(ClipRowView.formatContentText(for: imageWithoutDims), "[Image]", "Image without dimensions displays [Image] in English")
        LocalizationManager.shared.setLanguage(savedLang)

        // 8. Image Search Matching (supports [Ảnh], Ảnh, anh, and dimensions)
        TestHarness.assertTrue(SearchEngine.matches(item: imageWithDims, query: "Ảnh"), "SearchEngine matches image clip with query 'Ảnh'")
        TestHarness.assertTrue(SearchEngine.matches(item: imageWithDims, query: "anh"), "SearchEngine matches image clip with query 'anh' (diacritic insensitive)")
        TestHarness.assertTrue(SearchEngine.matches(item: imageWithDims, query: "[Ảnh]"), "SearchEngine matches image clip with query '[Ảnh]'")
        TestHarness.assertTrue(SearchEngine.matches(item: imageWithDims, query: "1920x1080"), "SearchEngine matches image clip with dimensions '1920x1080'")
        TestHarness.assertTrue(SearchEngine.matches(item: imageWithDims, query: "Image"), "SearchEngine matches image clip with query 'Image'")

        // 9. ClipRowView Callback Closures
        var selectedItem: ClipItem?
        var pinnedItem: ClipItem?
        var copiedItem: ClipItem?
        var deletedItem: ClipItem?

        let rowView = ClipRowView(
            item: singleLineText,
            shortcutIndex: 1,
            isSelected: false,
            onSelect: { selectedItem = $0 },
            onTogglePin: { pinnedItem = $0 },
            onCopy: { copiedItem = $0 },
            onDelete: { deletedItem = $0 }
        )
        rowView.onSelect?(singleLineText)
        rowView.onTogglePin?(singleLineText)
        rowView.onCopy?(singleLineText)
        rowView.onDelete?(singleLineText)

        TestHarness.assertEqual(selectedItem?.id, singleLineText.id, "onSelect invoked with target item")
        TestHarness.assertEqual(pinnedItem?.id, singleLineText.id, "onTogglePin invoked with target item")
        TestHarness.assertEqual(copiedItem?.id, singleLineText.id, "onCopy invoked with target item")
        TestHarness.assertEqual(deletedItem?.id, singleLineText.id, "onDelete invoked with target item")

        // 10. CopyClip-style Tooltip for Truncated / Long Text & Multiline
        let shortTextItem = ClipItem(id: UUID(), contentType: .text, textContent: "Short text")
        TestHarness.assertEqual(ClipRowView.textTooltip(for: shortTextItem), "", "Short text (< 28 chars) has empty tooltip")

        let longTextItem = ClipItem(
            id: UUID(),
            contentType: .text,
            textContent: "SuperClip_Verified_Copy_F95CC7A0-5B07-41B0-831C-A8A5A4F26931"
        )
        TestHarness.assertEqual(
            ClipRowView.textTooltip(for: longTextItem),
            "SuperClip_Verified_Copy_F95CC7A0-5B07-41B0-831C-A8A5A4F26931",
            "Long text displays full content in tooltip"
        )

        let multilineItem = ClipItem(id: UUID(), contentType: .text, textContent: "Line 1\nLine 2")
        TestHarness.assertEqual(
            ClipRowView.textTooltip(for: multilineItem),
            "Line 1\nLine 2",
            "Multiline text retains newlines in tooltip"
        )

        let whitespaceItem = ClipItem(id: UUID(), contentType: .text, textContent: "   \n\t  ")
        TestHarness.assertEqual(ClipRowView.textTooltip(for: whitespaceItem), "", "Whitespace text has empty tooltip")

        TestHarness.assertEqual(
            ClipRowView.textTooltip(for: imageWithDims),
            "",
            "Image clip returns empty text tooltip (handled by thumbnail preview panel)"
        )

        let hugeString = String(repeating: "A", count: 2500)
        let hugeItem = ClipItem(id: UUID(), contentType: .text, textContent: hugeString)
        let hugeTooltip = ClipRowView.textTooltip(for: hugeItem)
        TestHarness.assertEqual(hugeTooltip.count, 2003, "Huge string tooltip is capped at 2000 chars + ellipsis")
        TestHarness.assertTrue(hugeTooltip.hasSuffix("..."), "Huge string tooltip has ellipsis suffix")

        // 11. ThumbnailHoverPreviewPanel Lifecycle
        let previewPanel = ThumbnailHoverPreviewPanel.shared
        TestHarness.assertNotNil(previewPanel, "ThumbnailHoverPreviewPanel singleton is initialized")
        TestHarness.assertEqual(previewPanel.level, .popUpMenu, "ThumbnailHoverPreviewPanel level is popUpMenu")

        previewPanel.display(item: imageWithDims, thumbnailURL: nil)
        TestHarness.assertEqual(previewPanel.currentItemId, imageWithDims.id, "display sets currentItemId for image clip")

        previewPanel.show(for: shortTextItem, thumbnailURL: nil)
        TestHarness.assertNil(previewPanel.currentItemId, "show with text item resets currentItemId")

        previewPanel.hide()
        TestHarness.assertNil(previewPanel.currentItemId, "hide clears currentItemId")
    }
}
