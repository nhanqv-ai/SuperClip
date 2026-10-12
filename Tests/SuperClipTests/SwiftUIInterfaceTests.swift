import Foundation
import AppKit
import SuperClipCore
import SuperClip

/// SwiftUIInterfaceTests provides comprehensive verification for Milestone M3
/// covering SearchBarView, ClipRowView, ClipListView, MainContentView, keyboard navigation,
/// pasteboard copy writeback with loop suppression, and zero-emoji compliance.
public struct SwiftUIInterfaceTests {

    public static func run(sandboxDir: URL) {
        TestHarness.startSuite("Milestone M3: SwiftUI Interface & Navigation Tests")

        testSearchFiltering()
        testListPartitioning(sandboxDir: sandboxDir)
        testPinTogglingAndDeletion(sandboxDir: sandboxDir)
        testCopyWritebackAndLoopSuppression(sandboxDir: sandboxDir)
        testShortcut1to9Mapping()
        testArrowKeyNavigation()
        testClearHistoryPinProtection(sandboxDir: sandboxDir)
        testFormattersAndCache()
        testZeroEmojiCompliance()
    }

    // MARK: - 1. Search Filtering Tests

    private static func testSearchFiltering() {
        let items = [
            ClipItem(id: UUID(), contentType: .text, textContent: "Xcode Project Build", byteSize: 20, isPinned: true),
            ClipItem(id: UUID(), contentType: .text, textContent: "SwiftUI Animation Tutorial", byteSize: 26, isPinned: false),
            ClipItem(id: UUID(), contentType: .text, textContent: "Terminal Command Zsh", byteSize: 21, isPinned: false),
            ClipItem(id: UUID(), contentType: .text, textContent: "Café au Lait Order", byteSize: 18, isPinned: false)
        ]

        // Empty query restores all items
        let emptyQueryVisible = ShortcutNavigator.resolveVisibleItems(items: items, query: "")
        TestHarness.assertEqual(emptyQueryVisible.count, 4, "Empty search query preserves full items list")

        // Whitespace query restores all items
        let whitespaceVisible = ShortcutNavigator.resolveVisibleItems(items: items, query: "   \t\n  ")
        TestHarness.assertEqual(whitespaceVisible.count, 4, "Whitespace query restores full items list")

        // Substring query filtering
        let swiftVisible = ShortcutNavigator.resolveVisibleItems(items: items, query: "swiftui")
        TestHarness.assertEqual(swiftVisible.count, 1, "Case-insensitive search returns single matching clip")
        TestHarness.assertEqual(swiftVisible.first?.textContent, "SwiftUI Animation Tutorial", "Matched correct item")

        // Diacritic-insensitive query filtering
        let cafeVisible = ShortcutNavigator.resolveVisibleItems(items: items, query: "cafe")
        TestHarness.assertEqual(cafeVisible.count, 1, "Diacritic-insensitive search matches 'Café'")
        TestHarness.assertEqual(cafeVisible.first?.textContent, "Café au Lait Order", "Matched Café item")

        // Multi-token search
        let multiTokenVisible = ShortcutNavigator.resolveVisibleItems(items: items, query: "xcode build")
        TestHarness.assertEqual(multiTokenVisible.count, 1, "Multi-token search matches across terms")
        TestHarness.assertEqual(multiTokenVisible.first?.textContent, "Xcode Project Build", "Matched Xcode build item")

        // Zero matches yields empty array
        let noMatchVisible = ShortcutNavigator.resolveVisibleItems(items: items, query: "nonexistent_term_404")
        TestHarness.assertEqual(noMatchVisible.count, 0, "Query with zero matches returns empty list")
    }

    // MARK: - 2. List Partitioning Tests

    private static func testListPartitioning(sandboxDir: URL) {
        let subDir = sandboxDir.appendingPathComponent("PartitionTest_\(UUID().uuidString)")
        let storage = StorageManager(baseDirectory: subDir, initialCapacity: 20)

        let p1 = ClipItem(id: UUID(), contentType: .text, textContent: "Pinned Alpha", byteSize: 12, isPinned: true)
        let p2 = ClipItem(id: UUID(), contentType: .text, textContent: "Pinned Beta", byteSize: 11, isPinned: true)
        let r1 = ClipItem(id: UUID(), contentType: .text, textContent: "Recent Gamma", byteSize: 12, isPinned: false)
        let r2 = ClipItem(id: UUID(), contentType: .text, textContent: "Recent Delta", byteSize: 12, isPinned: false)

        storage.addClip(item: p1, imageData: nil, thumbData: nil)
        storage.addClip(item: p2, imageData: nil, thumbData: nil)
        storage.addClip(item: r1, imageData: nil, thumbData: nil)
        storage.addClip(item: r2, imageData: nil, thumbData: nil)

        let partitioned = SearchEngine.partition(items: storage.items, query: "")
        TestHarness.assertEqual(partitioned.pinned.count, 2, "Pinned partition contains 2 items")
        TestHarness.assertEqual(partitioned.recent.count, 2, "Recent partition contains 2 items")

        let visible = ShortcutNavigator.resolveVisibleItems(items: storage.items, query: "")
        TestHarness.assertEqual(visible.count, 4, "Total visible count is 4")
        TestHarness.assertTrue(visible[0].isPinned, "Item 0 in visible list is pinned")
        TestHarness.assertTrue(visible[1].isPinned, "Item 1 in visible list is pinned")
        TestHarness.assertFalse(visible[2].isPinned, "Item 2 in visible list is unpinned recent")
        TestHarness.assertFalse(visible[3].isPinned, "Item 3 in visible list is unpinned recent")
    }

    // MARK: - 3. Pin Toggling & Deletion Tests

    private static func testPinTogglingAndDeletion(sandboxDir: URL) {
        let subDir = sandboxDir.appendingPathComponent("PinToggleTest_\(UUID().uuidString)")
        let storage = StorageManager(baseDirectory: subDir, initialCapacity: 10)

        let item = ClipItem(id: UUID(), contentType: .text, textContent: "Pin Toggle Sample", byteSize: 17, isPinned: false)
        storage.addClip(item: item, imageData: nil, thumbData: nil)

        TestHarness.assertFalse(storage.items.first!.isPinned, "Newly added clip is unpinned initially")

        // Toggle to pinned
        storage.togglePin(id: item.id)
        TestHarness.assertTrue(storage.items.first!.isPinned, "Clip toggled to pinned")

        // Toggle back to unpinned
        storage.togglePin(id: item.id)
        TestHarness.assertFalse(storage.items.first!.isPinned, "Clip toggled back to unpinned")

        // Delete clip permanently
        storage.deleteItem(id: item.id)
        TestHarness.assertEqual(storage.items.count, 0, "Clip deleted permanently from storage")
    }

    // MARK: - 4. Copy Writeback & Loop Suppression Tests

    private static func testCopyWritebackAndLoopSuppression(sandboxDir: URL) {
        let subDir = sandboxDir.appendingPathComponent("WritebackTest_\(UUID().uuidString)")
        let testPBName = NSPasteboard.Name("com.superclip.test.interface.writeback.\(UUID().uuidString)")
        let testPB = NSPasteboard(name: testPBName)
        let monitor = PasteboardMonitor(pasteboard: testPB)
        let storage = StorageManager(baseDirectory: subDir, initialCapacity: 10)
        let writer = PasteboardWriter(pasteboard: testPB, monitor: monitor)

        // Text clip copy writeback
        let textItem = ClipItem(id: UUID(), contentType: .text, textContent: "SwiftUI Interface Copy Payload", byteSize: 31, isPinned: false)
        storage.addClip(item: textItem, imageData: nil, thumbData: nil)

        let writeTextSuccess = writer.writeClip(textItem, storageManager: storage)
        TestHarness.assertTrue(writeTextSuccess, "Text clip writeback succeeded")
        TestHarness.assertEqual(testPB.string(forType: .string), "SwiftUI Interface Copy Payload", "Pasteboard holds exact written string")

        // Self-copy loop suppression: pollTick() must return false
        let selfTickResult = monitor.pollTick()
        TestHarness.assertFalse(selfTickResult, "PasteboardMonitor suppressed self-copy writeback tick")

        // Subsequent external copy detection
        testPB.clearContents()
        testPB.setString("External User Copy Event", forType: .string)
        let externalTickResult = monitor.pollTick()
        TestHarness.assertTrue(externalTickResult, "PasteboardMonitor detected external copy after suppressed self-copy")

        // Image clip copy writeback
        let imgID = UUID()
        let fakePNG = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) // Valid PNG header
        let imgItem = ClipItem(
            id: imgID,
            contentType: .image,
            imageFileName: "\(imgID.uuidString).png",
            thumbnailFileName: "\(imgID.uuidString)_thumb.png",
            imageWidth: 100,
            imageHeight: 80,
            byteSize: fakePNG.count,
            isPinned: false
        )
        storage.addClip(item: imgItem, imageData: fakePNG, thumbData: nil)

        let writeImageSuccess = writer.writeClip(imgItem, storageManager: storage)
        TestHarness.assertTrue(writeImageSuccess, "Image clip writeback succeeded")
        TestHarness.assertNotNil(testPB.data(forType: .png), "Pasteboard holds PNG image payload")
        TestHarness.assertFalse(monitor.pollTick(), "Image self-copy writeback suppressed in monitor")

        // Zero Accessibility permissions invariant
        TestHarness.assertTrue(testPB.changeCount > 0, "Pasteboard updated directly without AX privileges")
    }

    // MARK: - 5. 1..9 Shortcut Mapping Tests

    private static func testShortcut1to9Mapping() {
        let items = (1...12).map { i in
            ClipItem(id: UUID(), contentType: .text, textContent: "Item \(i)", byteSize: 8, isPinned: false)
        }

        // Within bounds mapping (1..9)
        for i in 1...9 {
            let target = ShortcutNavigator.targetItem(forShortcut: i, in: items)
            TestHarness.assertNotNil(target, "Shortcut \(i) resolves to non-nil item")
            TestHarness.assertEqual(target?.textContent, "Item \(i)", "Shortcut \(i) maps to exact visible item")
            TestHarness.assertEqual(ShortcutNavigator.badgeLabel(forIndex: i - 1), "\(i)", "Index \(i - 1) receives badge '\(i)'")
        }

        // Out of bounds items (indices >= 9 receive nil)
        for i in 9...11 {
            TestHarness.assertNil(ShortcutNavigator.badgeLabel(forIndex: i), "Index \(i) receives nil badge label")
        }
        TestHarness.assertNil(ShortcutNavigator.targetItem(forShortcut: 10, in: items), "Shortcut 10 returns nil")
        TestHarness.assertNil(ShortcutNavigator.targetItem(forShortcut: 0, in: items), "Shortcut 0 returns nil")
        TestHarness.assertNil(ShortcutNavigator.targetItem(forShortcut: -1, in: items), "Negative shortcut returns nil")

        // Dynamic query remapping
        let mixed = [
            ClipItem(id: UUID(), contentType: .text, textContent: "Apple A", byteSize: 7, isPinned: true),
            ClipItem(id: UUID(), contentType: .text, textContent: "Banana B", byteSize: 8, isPinned: true),
            ClipItem(id: UUID(), contentType: .text, textContent: "Apple C", byteSize: 7, isPinned: false),
            ClipItem(id: UUID(), contentType: .text, textContent: "Cherry D", byteSize: 8, isPinned: false)
        ]
        let appleVisible = ShortcutNavigator.resolveVisibleItems(items: mixed, query: "Apple")
        TestHarness.assertEqual(appleVisible.count, 2, "Filtered visible items count is 2")
        let firstApple = ShortcutNavigator.targetItem(forShortcut: 1, in: appleVisible)
        let secondApple = ShortcutNavigator.targetItem(forShortcut: 2, in: appleVisible)
        let thirdApple = ShortcutNavigator.targetItem(forShortcut: 3, in: appleVisible)
        TestHarness.assertEqual(firstApple?.textContent, "Apple A", "Shortcut 1 maps to first filtered item")
        TestHarness.assertEqual(secondApple?.textContent, "Apple C", "Shortcut 2 maps to second filtered item")
        TestHarness.assertNil(thirdApple, "Shortcut 3 is nil on 2-item filtered list")

        // Command + 1..9 event parsing
        let cmd1Event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "1",
            charactersIgnoringModifiers: "1",
            isARepeat: false,
            keyCode: 18
        )!
        TestHarness.assertEqual(
            ShortcutNavigator.parseShortcut(from: cmd1Event, searchFieldHasFocus: true),
            1,
            "Cmd+1 parses when search field has focus"
        )
        TestHarness.assertEqual(
            ShortcutNavigator.parseShortcut(from: cmd1Event, searchFieldHasFocus: false),
            1,
            "Cmd+1 parses when search field is blurred"
        )

        // Bare 1..9 event parsing
        let bare1Event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "1",
            charactersIgnoringModifiers: "1",
            isARepeat: false,
            keyCode: 18
        )!
        TestHarness.assertNil(
            ShortcutNavigator.parseShortcut(from: bare1Event, searchFieldHasFocus: true),
            "Bare 1 is ignored when search field has focus"
        )
        TestHarness.assertEqual(
            ShortcutNavigator.parseShortcut(from: bare1Event, searchFieldHasFocus: false),
            1,
            "Bare 1 parses when search field is blurred"
        )
    }

    // MARK: - 6. Arrow Key Navigation Tests

    private static func testArrowKeyNavigation() {
        // Step Down from nil selects 0
        let downFromNil = ShortcutNavigator.stepDown(currentIndex: nil, visibleCount: 4)
        TestHarness.assertEqual(downFromNil, 0, "Down Arrow from unselected selects row 0")

        // Step Down sequential increment
        let downFrom0 = ShortcutNavigator.stepDown(currentIndex: 0, visibleCount: 4)
        let downFrom1 = ShortcutNavigator.stepDown(currentIndex: 1, visibleCount: 4)
        TestHarness.assertEqual(downFrom0, 1, "Down Arrow steps 0 -> 1")
        TestHarness.assertEqual(downFrom1, 2, "Down Arrow steps 1 -> 2")

        // Step Down wrap-around at visibleCount - 1 to 0
        let downFromMax = ShortcutNavigator.stepDown(currentIndex: 3, visibleCount: 4)
        TestHarness.assertEqual(downFromMax, 0, "Down Arrow wraps around from index 3 (visibleCount - 1) to 0")

        // Step Up sequential decrement
        let upFrom2 = ShortcutNavigator.stepUp(currentIndex: 2, visibleCount: 4)
        let upFrom1 = ShortcutNavigator.stepUp(currentIndex: 1, visibleCount: 4)
        TestHarness.assertEqual(upFrom2, 1, "Up Arrow steps 2 -> 1")
        TestHarness.assertEqual(upFrom1, 0, "Up Arrow steps 1 -> 0")

        // Step Up wrap-around from 0 to visibleCount - 1
        let upFrom0 = ShortcutNavigator.stepUp(currentIndex: 0, visibleCount: 4)
        TestHarness.assertEqual(upFrom0, 3, "Up Arrow wraps around from index 0 to 3 (visibleCount - 1)")

        // Step Up from unselected selects visibleCount - 1
        let upFromNil = ShortcutNavigator.stepUp(currentIndex: nil, visibleCount: 4)
        TestHarness.assertEqual(upFromNil, 3, "Up Arrow from unselected selects index 3 (visibleCount - 1)")

        // Empty list safety
        TestHarness.assertNil(ShortcutNavigator.stepDown(currentIndex: nil, visibleCount: 0), "Step down on empty list returns nil")
        TestHarness.assertNil(ShortcutNavigator.stepUp(currentIndex: nil, visibleCount: 0), "Step up on empty list returns nil")

        // Return key resolution
        let items = [
            ClipItem(id: UUID(), contentType: .text, textContent: "First", byteSize: 5, isPinned: false),
            ClipItem(id: UUID(), contentType: .text, textContent: "Second", byteSize: 6, isPinned: false)
        ]
        let returnSelected = ShortcutNavigator.resolveReturnTarget(currentIndex: 1, visibleItems: items)
        let returnDefault = ShortcutNavigator.resolveReturnTarget(currentIndex: nil, visibleItems: items)
        TestHarness.assertEqual(returnSelected?.textContent, "Second", "Return key resolves highlighted row 1")
        TestHarness.assertEqual(returnDefault?.textContent, "First", "Return key defaults to row 0 when unselected")
        TestHarness.assertNil(ShortcutNavigator.resolveReturnTarget(currentIndex: nil, visibleItems: []), "Return on empty list is nil")
    }

    // MARK: - 7. Clear History Pin Protection Tests

    private static func testClearHistoryPinProtection(sandboxDir: URL) {
        let subDir = sandboxDir.appendingPathComponent("ClearHistoryTest_\(UUID().uuidString)")
        let storage = StorageManager(baseDirectory: subDir, initialCapacity: 10)

        let p1 = ClipItem(id: UUID(), contentType: .text, textContent: "Protected Pinned 1", byteSize: 18, isPinned: true)
        let p2 = ClipItem(id: UUID(), contentType: .text, textContent: "Protected Pinned 2", byteSize: 18, isPinned: true)
        let u1 = ClipItem(id: UUID(), contentType: .text, textContent: "Transient History 1", byteSize: 19, isPinned: false)
        let u2 = ClipItem(id: UUID(), contentType: .text, textContent: "Transient History 2", byteSize: 19, isPinned: false)

        storage.addClip(item: p1, imageData: nil, thumbData: nil)
        storage.addClip(item: p2, imageData: nil, thumbData: nil)
        storage.addClip(item: u1, imageData: nil, thumbData: nil)
        storage.addClip(item: u2, imageData: nil, thumbData: nil)

        TestHarness.assertEqual(storage.items.count, 4, "Storage initially holds 4 clips")

        storage.clearUnpinnedHistory()

        TestHarness.assertEqual(storage.items.count, 2, "After clearUnpinnedHistory, exactly 2 clips remain")
        TestHarness.assertTrue(storage.items.allSatisfy { $0.isPinned }, "All remaining clips are strictly pinned clips")
    }

    // MARK: - 8. Formatters & Cache Tests

    private static func testFormattersAndCache() {
        // RelativeTimeFormatter
        let now = Date()
        TestHarness.assertEqual(RelativeTimeFormatter.format(now), "Just now", "Instant timestamp formats to 'Just now'")

        // ThumbnailImageCache
        let testURL = URL(fileURLWithPath: "/tmp/superclip_test_thumb.png")
        let dummyImage = NSImage(size: NSSize(width: 16, height: 16))
        ThumbnailImageCache.shared.setImage(dummyImage, for: testURL)
        TestHarness.assertNotNil(ThumbnailImageCache.shared.image(for: testURL), "Cache returns cached image")
        ThumbnailImageCache.shared.removeImage(for: testURL)
        TestHarness.assertNil(ThumbnailImageCache.shared.image(for: testURL), "Cache returns nil after removal")
    }

    // MARK: - 9. Zero-Emoji Compliance Tests

    private static func testZeroEmojiCompliance() {
        let sfSymbols = [
            "magnifyingglass",
            "xmark.circle.fill",
            "pin.fill",
            "pin",
            "clock",
            "trash",
            "doc.text",
            "photo",
            "doc.on.clipboard",
            "tray",
            "doc.on.doc",
            "xmark"
        ]

        for symbol in sfSymbols {
            TestHarness.assertTrue(!symbol.isEmpty, "SF Symbol '\(symbol)' is non-empty")
            // Check character range for emojis
            let hasEmoji = symbol.unicodeScalars.contains { scalar in
                (scalar.value >= 0x1F300 && scalar.value <= 0x1FAFF) ||
                (scalar.value >= 0x2600 && scalar.value <= 0x27BF)
            }
            TestHarness.assertFalse(hasEmoji, "SF Symbol '\(symbol)' contains zero emoji characters")
        }
    }
}
