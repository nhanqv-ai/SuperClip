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
        var maskedItem: ClipItem?
        var copiedItem: ClipItem?
        var deletedItem: ClipItem?

        let rowView = ClipRowView(
            item: singleLineText,
            shortcutIndex: 1,
            isSelected: false,
            onSelect: { selectedItem = $0 },
            onTogglePin: { pinnedItem = $0 },
            onToggleMask: { maskedItem = $0 },
            onCopy: { copiedItem = $0 },
            onDelete: { deletedItem = $0 }
        )
        rowView.onSelect?(singleLineText)
        rowView.onTogglePin?(singleLineText)
        rowView.onToggleMask?(singleLineText)
        rowView.onCopy?(singleLineText)
        rowView.onDelete?(singleLineText)

        TestHarness.assertEqual(selectedItem?.id, singleLineText.id, "onSelect invoked with target item")
        TestHarness.assertEqual(pinnedItem?.id, singleLineText.id, "onTogglePin invoked with target item")
        TestHarness.assertEqual(maskedItem?.id, singleLineText.id, "onToggleMask invoked with target item")
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
        TestHarness.assertNil(previewPanel.currentItemId, "show with short text item resets currentItemId")

        previewPanel.displayText(item: longTextItem, text: "Long text tooltip preview")
        TestHarness.assertEqual(previewPanel.currentItemId, longTextItem.id, "displayText sets currentItemId for long text item")

        previewPanel.hide(immediate: true)
        TestHarness.assertNil(previewPanel.currentItemId, "hide clears currentItemId")

        let breakable = TextPreviewHostView.formatBreakableText("SuperClip_Verified_Copy_2BF12BB8")
        TestHarness.assertTrue(breakable.contains("\u{200B}"), "formatBreakableText inserts zero-width spaces for unbroken delimiter tokens")

        // 12. Sensitive Information Masking (R1-R4)
        let cleartextPassword = "super_secret_master_password_98765"
        let maskedTextItem = ClipItem(
            id: UUID(),
            contentType: .text,
            textContent: cleartextPassword,
            byteSize: cleartextPassword.utf8.count,
            isPinned: false,
            isMasked: true
        )
        let maskedImageItem = ClipItem(
            id: UUID(),
            contentType: .image,
            imageWidth: 800,
            imageHeight: 600,
            byteSize: 1024,
            isPinned: false,
            isMasked: true
        )

        // R2 Presentation: masked content text
        TestHarness.assertEqual(
            ClipRowView.formatContentText(for: maskedTextItem),
            "••••••••",
            "ClipRowView formats masked text item as '••••••••'"
        )
        TestHarness.assertEqual(
            ClipRowView.formatContentText(for: maskedImageItem),
            "••••••••",
            "ClipRowView formats masked image item as '••••••••'"
        )

        // R2 Tooltip Concealment: suppresses raw text and renders masked bullet string
        let maskedTooltip = ClipRowView.textTooltip(for: maskedTextItem)
        TestHarness.assertEqual(maskedTooltip, "••••••••", "Tooltip generation returns '••••••••' for masked text")
        TestHarness.assertFalse(maskedTooltip.contains(cleartextPassword), "Tooltip conceals raw cleartext password")

        let maskedImageTooltip = ClipRowView.textTooltip(for: maskedImageItem)
        TestHarness.assertEqual(maskedImageTooltip, "••••••••", "Tooltip generation returns '••••••••' for masked image")

        // R2 Hover Preview Panel suppresses cleartext
        previewPanel.display(item: maskedTextItem, thumbnailURL: nil)
        TestHarness.assertEqual(previewPanel.currentItemId, maskedTextItem.id, "previewPanel display sets currentItemId for masked clip")
        previewPanel.hide(immediate: true)

        // Verify displayText and displayImage defend against cleartext leak for masked items
        previewPanel.displayText(item: maskedTextItem, text: cleartextPassword)
        TestHarness.assertEqual(previewPanel.currentItemId, maskedTextItem.id, "displayText sets currentItemId")
        TestHarness.assertTrue(previewPanel.currentIsMasked, "displayText for maskedTextItem sets currentIsMasked == true")
        TestHarness.assertFalse(previewPanel.currentIsImage, "displayText sets currentIsImage == false")
        previewPanel.hide(immediate: true)

        previewPanel.displayImage(item: maskedImageItem, thumbnailURL: nil)
        TestHarness.assertEqual(previewPanel.currentItemId, maskedImageItem.id, "displayImage sets currentItemId")
        TestHarness.assertTrue(previewPanel.currentIsMasked, "displayImage for maskedImageItem sets currentIsMasked == true")
        TestHarness.assertFalse(previewPanel.currentIsImage, "displayImage for maskedImageItem diverts to text preview")
        previewPanel.hide(immediate: true)

        // Verify live transition from unmasked to masked while previewPanel is visible (text)
        let liveTextItem = ClipItem(id: UUID(), contentType: .text, textContent: "LiveCleartextSecret123", isMasked: false)
        previewPanel.displayText(item: liveTextItem, text: "LiveCleartextSecret123")
        TestHarness.assertEqual(previewPanel.currentItemId, liveTextItem.id, "previewPanel showing unmasked live item")
        TestHarness.assertFalse(previewPanel.currentIsMasked, "previewPanel currentIsMasked is false")
        TestHarness.assertFalse(previewPanel.currentIsImage, "previewPanel currentIsImage is false")

        let liveTextMasked = liveTextItem.toggledMasked()
        previewPanel.show(for: liveTextMasked, thumbnailURL: nil)
        TestHarness.assertEqual(previewPanel.currentItemId, liveTextItem.id, "previewPanel preserves item id across live mask transition")
        TestHarness.assertTrue(previewPanel.currentIsMasked, "previewPanel transitioned to currentIsMasked == true while visible")
        TestHarness.assertFalse(previewPanel.currentIsImage, "previewPanel currentIsImage remains false")

        // Transition back to unmasked while visible
        previewPanel.show(for: liveTextItem, thumbnailURL: nil)
        TestHarness.assertFalse(previewPanel.currentIsMasked, "previewPanel transitioned back to unmasked while visible")
        previewPanel.hide(immediate: true)

        // Verify live transition from unmasked image to masked while previewPanel is visible
        let liveImgItem = ClipItem(id: UUID(), contentType: .image, imageWidth: 200, imageHeight: 200, isMasked: false)
        previewPanel.displayImage(item: liveImgItem, thumbnailURL: nil)
        TestHarness.assertEqual(previewPanel.currentItemId, liveImgItem.id, "previewPanel showing unmasked image")
        TestHarness.assertFalse(previewPanel.currentIsMasked, "previewPanel image currentIsMasked is false")
        TestHarness.assertTrue(previewPanel.currentIsImage, "previewPanel image currentIsImage is true")

        let liveImgMasked = liveImgItem.toggledMasked()
        previewPanel.show(for: liveImgMasked, thumbnailURL: nil)
        TestHarness.assertEqual(previewPanel.currentItemId, liveImgItem.id, "previewPanel preserves item id across image mask transition")
        TestHarness.assertTrue(previewPanel.currentIsMasked, "previewPanel image transitioned to masked while visible")
        TestHarness.assertFalse(previewPanel.currentIsImage, "previewPanel transitioned from image to text tooltip card")

        // Transition back to unmasked image while visible
        previewPanel.show(for: liveImgItem, thumbnailURL: nil)
        TestHarness.assertFalse(previewPanel.currentIsMasked, "previewPanel transitioned back to unmasked image")
        TestHarness.assertTrue(previewPanel.currentIsImage, "previewPanel transitioned back to image card")
        previewPanel.hide(immediate: true)

        // R3 Copy & Pasteboard: writing masked item copies ORIGINAL unmasked cleartext
        let maskPB = NSPasteboard(name: .init("com.superclip.test.mask.\(UUID().uuidString)"))
        let maskWriter = PasteboardWriter(pasteboard: maskPB)
        let maskCoordinator = ClipboardActionCoordinator(
            storageManager: storage,
            pasteboardWriter: maskWriter,
            onDismiss: { dismissed = true }
        )

        dismissed = false
        maskCoordinator.copyItem(item: maskedTextItem, dismiss: true)
        TestHarness.assertEqual(
            maskPB.string(forType: .string),
            cleartextPassword,
            "Copying masked item writes original unmasked text to pasteboard"
        )
        TestHarness.assertTrue(dismissed, "Copying masked item dismissed panel")

        // Verify direct writeClip also writes original unmasked text
        maskPB.clearContents()
        let writeResult = maskWriter.writeClip(maskedTextItem, storageManager: storage)
        TestHarness.assertTrue(writeResult, "writeClip succeeded for masked item")
        TestHarness.assertEqual(
            maskPB.string(forType: .string),
            cleartextPassword,
            "writeClip writes raw unmasked content to pasteboard"
        )

        // Verify writeClip for masked image writes original image data to pasteboard
        let fakeImageData = "FAKE_IMAGE_DATA_FOR_MASKED_TEST".data(using: .utf8)!
        let maskedImageWithData = ClipItem(
            id: UUID(),
            contentType: .image,
            imageWidth: 100,
            imageHeight: 100,
            byteSize: fakeImageData.count,
            isPinned: false,
            isMasked: true
        )
        storage.addClip(item: maskedImageWithData, imageData: fakeImageData, thumbData: fakeImageData)
        storage.flushDiskQueue()

        maskPB.clearContents()
        let imageWriteResult = maskWriter.writeClip(maskedImageWithData, storageManager: storage)
        TestHarness.assertTrue(imageWriteResult, "writeClip succeeded for masked image item")
        TestHarness.assertEqual(
            maskPB.data(forType: .png),
            fakeImageData,
            "writeClip writes raw unmasked image data to pasteboard"
        )

        // Verify localization keys for mask/reveal
        TestHarness.assertEqual(
            LocalizationManager.shared.tr(.maskClip),
            "Mask Sensitive Information",
            "English mask tooltip matches"
        )
        TestHarness.assertEqual(
            LocalizationManager.shared.tr(.revealClip),
            "Reveal Sensitive Information",
            "English reveal tooltip matches"
        )

        // 13. displayTitle Masking Invariant
        TestHarness.assertEqual(maskedTextItem.displayTitle, "••••••••", "displayTitle returns bullets for masked text")
        TestHarness.assertEqual(maskedImageItem.displayTitle, "••••••••", "displayTitle returns bullets for masked image")
        let unmaskedClone = maskedTextItem.toggledMasked()
        TestHarness.assertEqual(unmaskedClone.displayTitle, cleartextPassword, "displayTitle restores cleartext on unmasking")

        // 14. SearchEngine Masked Query Matching
        TestHarness.assertTrue(
            SearchEngine.matches(item: maskedTextItem, query: "••••••••"),
            "SearchEngine matches masked text item with bullet query"
        )
        TestHarness.assertTrue(
            SearchEngine.matches(item: maskedTextItem, query: "****"),
            "SearchEngine matches masked text item with asterisk query"
        )
        TestHarness.assertTrue(
            SearchEngine.matches(item: maskedTextItem, query: cleartextPassword),
            "SearchEngine matches masked text item with original content query"
        )
        TestHarness.assertTrue(
            SearchEngine.matches(item: maskedImageItem, query: "••••••••"),
            "SearchEngine matches masked image item with bullet query"
        )
        TestHarness.assertTrue(
            SearchEngine.matches(item: maskedImageItem, query: "****"),
            "SearchEngine matches masked image item with asterisk query"
        )

        // 15. Native NSSecureTextField Writeback & Zero Metadata Leak Verification (ISSUE-4)
        maskPB.clearContents()
        _ = maskWriter.writeClip(maskedTextItem, storageManager: storage)
        TestHarness.assertTrue(
            maskPB.types?.contains(.string) ?? false,
            "Pasteboard declares .string type"
        )
        let nonPlainTextTypes = maskPB.types?.filter { $0 != .string && $0.rawValue != "NSStringPboardType" } ?? []
        TestHarness.assertEqual(
            nonPlainTextTypes.count,
            0,
            "Pasteboard contains strictly plain string types with no rich text, HTML, or metadata leakage"
        )
        TestHarness.assertFalse(
            maskPB.types?.contains(.rtf) ?? false,
            "Pasteboard contains zero rich text formatting (RTF)"
        )
        TestHarness.assertFalse(
            maskPB.types?.contains(.html) ?? false,
            "Pasteboard contains zero HTML markup formatting"
        )
        let secureField = NSSecureTextField()
        if let stringPayload = maskPB.string(forType: .string) {
            secureField.stringValue = stringPayload
        }
        TestHarness.assertEqual(
            secureField.stringValue,
            cleartextPassword,
            "NSSecureTextField directly ingests unmasked cleartext payload without loss or corruption"
        )

        // 16. Rapid Sequential Mask Toggling Concurrency Stress (ISSUE-2)
        let stressClip = ClipItem(id: UUID(), contentType: .text, textContent: "StressSecret456", isMasked: false)
        storage.addClip(item: stressClip, imageData: nil, thumbData: nil)
        storage.flushDiskQueue()

        let toggleCount = 60
        let group = DispatchGroup()
        for _ in 0..<toggleCount {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                storage.toggleMaskItem(id: stressClip.id)
                group.leave()
            }
        }
        _ = group.wait(timeout: .now() + 5.0)
        storage.flushDiskQueue()

        // With an even number of toggles (60), the final state must equal initial state (false)
        let currentInMem = storage.items.first(where: { $0.id == stressClip.id })?.isMasked
        TestHarness.assertNotNil(currentInMem, "Stress clip retained in memory")
        TestHarness.assertEqual(currentInMem, false, "Even number of concurrent toggles restores initial isMasked state in memory")

        // Reload storage from disk to verify disk persistence integrity under concurrent writes
        let coldStorage = StorageManager(baseDirectory: sandboxDir, initialCapacity: 10)
        let onDiskMasked = coldStorage.items.first(where: { $0.id == stressClip.id })?.isMasked
        TestHarness.assertEqual(onDiskMasked, currentInMem, "Disk metadata matches in-memory state after concurrent burst toggling")
    }
}
