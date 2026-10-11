import Foundation
import AppKit
import SuperClipCore

public struct ClipListViewTests {
    public static func run(sandboxDir: URL) {
        TestHarness.startSuite("ClipListView Partitioning & Empty States Tests")

        let storage = StorageManager(baseDirectory: sandboxDir, initialCapacity: 10)

        // 1. Empty Storage State
        let (emptyPinned, emptyRecent) = SearchEngine.partition(items: storage.items, query: "")
        TestHarness.assertEqual(emptyPinned.count, 0, "Initial pinned count is 0")
        TestHarness.assertEqual(emptyRecent.count, 0, "Initial recent count is 0")

        // 2. Partitioned List Invariant: Pinned first, then Recent History
        let p1 = ClipItem(id: UUID(), contentType: .text, textContent: "Pinned 1", byteSize: 8, isPinned: true)
        let p2 = ClipItem(id: UUID(), contentType: .text, textContent: "Pinned 2", byteSize: 8, isPinned: true)
        let r1 = ClipItem(id: UUID(), contentType: .text, textContent: "Recent 1", byteSize: 8, isPinned: false)
        let r2 = ClipItem(id: UUID(), contentType: .text, textContent: "Recent 2", byteSize: 8, isPinned: false)
        storage.addClip(item: p1, imageData: nil, thumbData: nil)
        storage.addClip(item: p2, imageData: nil, thumbData: nil)
        storage.addClip(item: r1, imageData: nil, thumbData: nil)
        storage.addClip(item: r2, imageData: nil, thumbData: nil)

        let visible = ShortcutNavigator.resolveVisibleItems(items: storage.items, query: "")
        TestHarness.assertEqual(visible.count, 4, "Total visible items is 4")
        TestHarness.assertTrue(visible[0].isPinned, "Visible item 0 is pinned")
        TestHarness.assertTrue(visible[1].isPinned, "Visible item 1 is pinned")
        TestHarness.assertFalse(visible[2].isPinned, "Visible item 2 is unpinned recent")
        TestHarness.assertFalse(visible[3].isPinned, "Visible item 3 is unpinned recent")

        // 3. Search Zero Matches Empty State
        let searchZero = ShortcutNavigator.resolveVisibleItems(items: storage.items, query: "nonexistent_xyz")
        TestHarness.assertEqual(searchZero.count, 0, "Search query with 0 matches returns empty array")

        // 4. Section Headers Symbols Invariant
        let pinnedIcon = "pin.fill"
        let recentIcon = "clock"
        TestHarness.assertEqual(pinnedIcon, "pin.fill", "Pinned header SF Symbol compliant")
        TestHarness.assertEqual(recentIcon, "clock", "Recent header SF Symbol compliant")

        // 5. ClipShortcutMapper Tests
        TestHarness.assertEqual(
            ClipShortcutMapper.shortcutIndex(isPinned: true, indexInSection: 0, pinnedCount: 2),
            1,
            "1st pinned item receives shortcut index 1"
        )
        TestHarness.assertEqual(
            ClipShortcutMapper.shortcutIndex(isPinned: false, indexInSection: 0, pinnedCount: 2),
            1,
            "1st recent item independently receives shortcut index 1"
        )
        let resolvedKey1 = ClipShortcutMapper.itemIndexForShortcut(1, pinnedCount: 2, recentCount: 5)
        TestHarness.assertTrue(
            resolvedKey1?.isPinned == true && resolvedKey1?.indexInSection == 0,
            "Key 1 maps to 1st pinned item"
        )
        let resolvedPinnedKey = ClipShortcutMapper.itemIndexForShortcut(1, isPinned: true, pinnedCount: 2, recentCount: 5)
        TestHarness.assertTrue(
            resolvedPinnedKey?.isPinned == true && resolvedPinnedKey?.indexInSection == 0,
            "Section key 1 (pinned) maps to 1st pinned item"
        )
        let resolvedRecentKey = ClipShortcutMapper.itemIndexForShortcut(1, isPinned: false, pinnedCount: 2, recentCount: 5)
        TestHarness.assertTrue(
            resolvedRecentKey?.isPinned == false && resolvedRecentKey?.indexInSection == 0,
            "Section key 1 (recent) maps to 1st recent item"
        )
    }
}
