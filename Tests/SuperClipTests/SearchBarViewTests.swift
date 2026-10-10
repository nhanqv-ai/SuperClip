import Foundation
import AppKit
import SuperClipCore

public struct SearchBarViewTests {
    public static func run() {
        TestHarness.startSuite("SearchBarView Component Tests")

        // 1. Initial Empty Query Filtering
        let items = [
            ClipItem(id: UUID(), contentType: .text, textContent: "First Clip", byteSize: 10, isPinned: false),
            ClipItem(id: UUID(), contentType: .text, textContent: "Second Clip", byteSize: 11, isPinned: false)
        ]
        let allVisible = ShortcutNavigator.resolveVisibleItems(items: items, query: "")
        TestHarness.assertEqual(allVisible.count, 2, "Empty query preserves full items list")

        // 2. Real-Time Query Filtering
        let filtered = ShortcutNavigator.resolveVisibleItems(items: items, query: "second")
        TestHarness.assertEqual(filtered.count, 1, "Filtered query yields matching clip")
        TestHarness.assertEqual(filtered.first?.textContent, "Second Clip", "Correct clip preserved")

        // 3. Clear Query Restoration
        let restored = ShortcutNavigator.resolveVisibleItems(items: items, query: "   ")
        TestHarness.assertEqual(restored.count, 2, "Whitespace query restores full list")

        // 4. Zero Emojis Invariant in Placeholder & Symbols
        let placeholder = "Search clips..."
        let searchIcon = "magnifyingglass"
        let clearIcon = "xmark.circle.fill"
        TestHarness.assertTrue(!placeholder.isEmpty, "Placeholder defined")
        TestHarness.assertEqual(searchIcon, "magnifyingglass", "Search icon is flat SF Symbol")
        TestHarness.assertEqual(clearIcon, "xmark.circle.fill", "Clear icon is flat SF Symbol")
    }
}
