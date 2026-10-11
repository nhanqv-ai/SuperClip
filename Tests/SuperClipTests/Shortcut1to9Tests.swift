import Foundation
import AppKit
import SuperClipCore

public struct Shortcut1to9Tests {
    public static func run() {
        TestHarness.startSuite("Number Shortcuts 1..9 & Navigation Tests")

        // 1. Within Bounds Mapping
        let items5 = (1...5).map { i in
            ClipItem(id: UUID(), contentType: .text, textContent: "Item \(i)", byteSize: 10, isPinned: false)
        }
        for i in 1...5 {
            let target = ShortcutNavigator.targetItem(forShortcut: i, in: items5)
            TestHarness.assertNotNil(target, "Shortcut \(i) resolves to non-nil item")
            TestHarness.assertEqual(target?.textContent, "Item \(i)", "Shortcut \(i) maps to exact visible item")
        }

        // 2. Out of Bounds Mapping (Safe No-Op)
        let items3 = (1...3).map { i in
            ClipItem(id: UUID(), contentType: .text, textContent: "Clip \(i)", byteSize: 10, isPinned: false)
        }
        for i in 4...9 {
            let target = ShortcutNavigator.targetItem(forShortcut: i, in: items3)
            TestHarness.assertNil(target, "Shortcut \(i) on 3-item list safely returns nil (no-op)")
        }
        TestHarness.assertNil(ShortcutNavigator.targetItem(forShortcut: 0, in: items3), "Shortcut 0 returns nil")
        TestHarness.assertNil(ShortcutNavigator.targetItem(forShortcut: 10, in: items3), "Shortcut 10 returns nil")

        // 3. Dynamic Query Remapping
        let mixedItems = [
            ClipItem(id: UUID(), contentType: .text, textContent: "Apple Pie", byteSize: 10, isPinned: true),
            ClipItem(id: UUID(), contentType: .text, textContent: "Banana Bread", byteSize: 12, isPinned: true),
            ClipItem(id: UUID(), contentType: .text, textContent: "Cherry Tart", byteSize: 11, isPinned: false),
            ClipItem(id: UUID(), contentType: .text, textContent: "Banana Split", byteSize: 12, isPinned: false),
            ClipItem(id: UUID(), contentType: .text, textContent: "Date Palm", byteSize: 9, isPinned: false)
        ]
        let bananaVisible = ShortcutNavigator.resolveVisibleItems(items: mixedItems, query: "Banana")
        TestHarness.assertEqual(bananaVisible.count, 2, "Filtered visible items count is 2")
        let shortcut1Banana = ShortcutNavigator.targetItem(forShortcut: 1, in: bananaVisible)
        let shortcut2Banana = ShortcutNavigator.targetItem(forShortcut: 2, in: bananaVisible)
        let shortcut3Banana = ShortcutNavigator.targetItem(forShortcut: 3, in: bananaVisible)
        TestHarness.assertEqual(shortcut1Banana?.textContent, "Banana Bread", "Shortcut 1 maps to 1st filtered item")
        TestHarness.assertEqual(shortcut2Banana?.textContent, "Banana Split", "Shortcut 2 maps to 2nd filtered item")
        TestHarness.assertNil(shortcut3Banana, "Shortcut 3 is nil on 2-item filtered list")

        // 4. Command + 1..9 Event Parsing
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
        let parsedCmd1Focused = ShortcutNavigator.parseShortcut(from: cmd1Event, searchFieldHasFocus: true)
        let parsedCmd1Blurred = ShortcutNavigator.parseShortcut(from: cmd1Event, searchFieldHasFocus: false)
        TestHarness.assertEqual(parsedCmd1Focused, 1, "Command+1 triggers when search field has focus")
        TestHarness.assertEqual(parsedCmd1Blurred, 1, "Command+1 triggers when search field is blurred")

        // 5. Bare 1..9 Event Parsing (Focus Gated)
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
        let parsedBare1Focused = ShortcutNavigator.parseShortcut(from: bare1Event, searchFieldHasFocus: true)
        let parsedBare1Blurred = ShortcutNavigator.parseShortcut(from: bare1Event, searchFieldHasFocus: false)
        TestHarness.assertNil(parsedBare1Focused, "Bare 1 returns nil when search field has focus (enters text)")
        TestHarness.assertEqual(parsedBare1Blurred, 1, "Bare 1 triggers when list has focus")

        // 6. Option and Control Modifiers Ignored
        let opt1Event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .option,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\u{00A1}",
            charactersIgnoringModifiers: "1",
            isARepeat: false,
            keyCode: 18
        )!
        TestHarness.assertNil(ShortcutNavigator.parseShortcut(from: opt1Event, searchFieldHasFocus: false), "Option+1 ignored")

        // 7. Badge Labels
        TestHarness.assertEqual(ShortcutNavigator.badgeLabel(forIndex: 0), "1", "Index 0 badge is 1")
        TestHarness.assertEqual(ShortcutNavigator.badgeLabel(forIndex: 8), "9", "Index 8 badge is 9")
        TestHarness.assertNil(ShortcutNavigator.badgeLabel(forIndex: 9), "Index 9 badge is nil")

        // 8. Section-Aware Shortcuts (Option for Pinned, Command for Recent)
        let parsedOpt1 = ShortcutNavigator.parseSectionShortcut(from: opt1Event, searchFieldHasFocus: false)
        TestHarness.assertEqual(parsedOpt1?.section, .pinned, "Option+1 resolves to .pinned section")
        TestHarness.assertEqual(parsedOpt1?.digit, 1, "Option+1 resolves to digit 1")

        let parsedCmd1 = ShortcutNavigator.parseSectionShortcut(from: cmd1Event, searchFieldHasFocus: true)
        TestHarness.assertEqual(parsedCmd1?.section, .recent, "Command+1 resolves to .recent section")
        TestHarness.assertEqual(parsedCmd1?.digit, 1, "Command+1 resolves to digit 1")

        let pinnedClips = [
            ClipItem(id: UUID(), contentType: .text, textContent: "Pinned Alpha", isPinned: true),
            ClipItem(id: UUID(), contentType: .text, textContent: "Pinned Beta", isPinned: true)
        ]
        let recentClips = [
            ClipItem(id: UUID(), contentType: .text, textContent: "Recent Gamma", isPinned: false),
            ClipItem(id: UUID(), contentType: .text, textContent: "Recent Delta", isPinned: false)
        ]

        if let optRes = parsedOpt1 {
            let item = ShortcutNavigator.targetItem(forSectionShortcut: optRes, pinnedItems: pinnedClips, recentItems: recentClips)
            TestHarness.assertEqual(item?.textContent, "Pinned Alpha", "Option+1 selects 1st pinned clip")
        }
        if let cmdRes = parsedCmd1 {
            let item = ShortcutNavigator.targetItem(forSectionShortcut: cmdRes, pinnedItems: pinnedClips, recentItems: recentClips)
            TestHarness.assertEqual(item?.textContent, "Recent Gamma", "Command+1 selects 1st recent clip")
        }
    }
}
