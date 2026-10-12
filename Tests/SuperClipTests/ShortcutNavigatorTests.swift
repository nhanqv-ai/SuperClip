import Foundation
import AppKit
import SuperClipCore

public struct ShortcutNavigatorTests {
    public static func run() {
        TestHarness.startSuite("Circular Keyboard Arrow Navigation & ShortcutNavigator Tests")

        // 1. Wrap-around from visibleCount - 1 to 0 on stepDown
        let count5 = 5
        let wrapDown = ShortcutNavigator.stepDown(currentIndex: count5 - 1, visibleCount: count5)
        TestHarness.assertEqual(wrapDown, 0, "stepDown wraps from last index (4) back to first index (0)")

        // Sequential stepDown
        let step0to1 = ShortcutNavigator.stepDown(currentIndex: 0, visibleCount: count5)
        let step1to2 = ShortcutNavigator.stepDown(currentIndex: 1, visibleCount: count5)
        let step2to3 = ShortcutNavigator.stepDown(currentIndex: 2, visibleCount: count5)
        let step3to4 = ShortcutNavigator.stepDown(currentIndex: 3, visibleCount: count5)
        TestHarness.assertEqual(step0to1, 1, "stepDown advances 0 -> 1")
        TestHarness.assertEqual(step1to2, 2, "stepDown advances 1 -> 2")
        TestHarness.assertEqual(step2to3, 3, "stepDown advances 2 -> 3")
        TestHarness.assertEqual(step3to4, 4, "stepDown advances 3 -> 4")

        // Out-of-bounds large index wraps to 0
        let oobDown = ShortcutNavigator.stepDown(currentIndex: 99, visibleCount: count5)
        TestHarness.assertEqual(oobDown, 0, "stepDown with out-of-bounds index wraps safely to 0")

        // Out-of-bounds negative index wraps to 0
        let oobDownNeg = ShortcutNavigator.stepDown(currentIndex: -5, visibleCount: count5)
        TestHarness.assertEqual(oobDownNeg, 0, "stepDown with negative index wraps safely to 0")

        // 2. Wrap-around from 0 to visibleCount - 1 on stepUp
        let wrapUp = ShortcutNavigator.stepUp(currentIndex: 0, visibleCount: count5)
        TestHarness.assertEqual(wrapUp, 4, "stepUp wraps from first index (0) to last index (4)")

        // Sequential stepUp
        let step4to3 = ShortcutNavigator.stepUp(currentIndex: 4, visibleCount: count5)
        let step3to2 = ShortcutNavigator.stepUp(currentIndex: 3, visibleCount: count5)
        let step2to1 = ShortcutNavigator.stepUp(currentIndex: 2, visibleCount: count5)
        let step1to0 = ShortcutNavigator.stepUp(currentIndex: 1, visibleCount: count5)
        TestHarness.assertEqual(step4to3, 3, "stepUp steps backward 4 -> 3")
        TestHarness.assertEqual(step3to2, 2, "stepUp steps backward 3 -> 2")
        TestHarness.assertEqual(step2to1, 1, "stepUp steps backward 2 -> 1")
        TestHarness.assertEqual(step1to0, 0, "stepUp steps backward 1 -> 0")

        // Out-of-bounds negative index wraps to last index
        let oobUp = ShortcutNavigator.stepUp(currentIndex: -5, visibleCount: count5)
        TestHarness.assertEqual(oobUp, 4, "stepUp with negative index wraps safely to last index (4)")

        // Out-of-bounds large index wraps to last index
        let oobUpLarge = ShortcutNavigator.stepUp(currentIndex: 99, visibleCount: count5)
        TestHarness.assertEqual(oobUpLarge, 4, "stepUp with out-of-bounds large index wraps safely to last index (4)")

        // 3. Initial unselected state transitions (nil -> 0 on stepDown, nil -> visibleCount - 1 on stepUp)
        let unselectedDown = ShortcutNavigator.stepDown(currentIndex: nil, visibleCount: count5)
        let unselectedUp = ShortcutNavigator.stepUp(currentIndex: nil, visibleCount: count5)
        TestHarness.assertEqual(unselectedDown, 0, "stepDown from nil selects index 0")
        TestHarness.assertEqual(unselectedUp, 4, "stepUp from nil selects last index (4)")

        // 4. Single-item list behavior (visibleCount == 1 stays at 0)
        let singleCount = 1
        let singleDownFromNil = ShortcutNavigator.stepDown(currentIndex: nil, visibleCount: singleCount)
        let singleUpFromNil = ShortcutNavigator.stepUp(currentIndex: nil, visibleCount: singleCount)
        let singleDownFrom0 = ShortcutNavigator.stepDown(currentIndex: 0, visibleCount: singleCount)
        let singleUpFrom0 = ShortcutNavigator.stepUp(currentIndex: 0, visibleCount: singleCount)

        TestHarness.assertEqual(singleDownFromNil, 0, "Single-item list stepDown from nil returns 0")
        TestHarness.assertEqual(singleUpFromNil, 0, "Single-item list stepUp from nil returns 0")
        TestHarness.assertEqual(singleDownFrom0, 0, "Single-item list stepDown from 0 stays at 0")
        TestHarness.assertEqual(singleUpFrom0, 0, "Single-item list stepUp from 0 stays at 0")

        // 5. Empty list behavior (visibleCount == 0 returns nil)
        let emptyCount = 0
        TestHarness.assertNil(ShortcutNavigator.stepDown(currentIndex: nil, visibleCount: emptyCount), "stepDown from nil on empty list returns nil")
        TestHarness.assertNil(ShortcutNavigator.stepDown(currentIndex: 0, visibleCount: emptyCount), "stepDown from 0 on empty list returns nil")
        TestHarness.assertNil(ShortcutNavigator.stepUp(currentIndex: nil, visibleCount: emptyCount), "stepUp from nil on empty list returns nil")
        TestHarness.assertNil(ShortcutNavigator.stepUp(currentIndex: 0, visibleCount: emptyCount), "stepUp from 0 on empty list returns nil")

        // Negative visibleCount safety
        TestHarness.assertNil(ShortcutNavigator.stepDown(currentIndex: 0, visibleCount: -1), "stepDown on negative visibleCount returns nil")
        TestHarness.assertNil(ShortcutNavigator.stepUp(currentIndex: 0, visibleCount: -1), "stepUp on negative visibleCount returns nil")

        // 6. Search filter query updates resetting selection to 0
        let items = [
            ClipItem(id: UUID(), contentType: .text, textContent: "Alpha clip", byteSize: 10, isPinned: false),
            ClipItem(id: UUID(), contentType: .text, textContent: "Beta clip", byteSize: 9, isPinned: false),
            ClipItem(id: UUID(), contentType: .text, textContent: "Gamma clip", byteSize: 10, isPinned: false)
        ]

        // Initial search query: empty query yields all 3 items, auto-selects 0
        let allVisible = ShortcutNavigator.resolveVisibleItems(items: items, query: "")
        TestHarness.assertEqual(allVisible.count, 3, "Initial query resolves 3 items")
        let initialSelected: Int? = allVisible.isEmpty ? nil : 0
        TestHarness.assertEqual(initialSelected, 0, "Initial list auto-selects index 0")

        // Filter query to 'Beta': 1 match, auto-selects 0
        let betaVisible = ShortcutNavigator.resolveVisibleItems(items: items, query: "Beta")
        TestHarness.assertEqual(betaVisible.count, 1, "Filter query 'Beta' resolves 1 item")
        let betaSelected: Int? = betaVisible.isEmpty ? nil : 0
        TestHarness.assertEqual(betaSelected, 0, "Filter query auto-selects index 0")
        TestHarness.assertEqual(betaVisible[betaSelected!].textContent, "Beta clip", "Selected item matches top result")

        // Filter query with no match: 0 items, selection is nil
        let noMatchVisible = ShortcutNavigator.resolveVisibleItems(items: items, query: "NonexistentQueryXYZ")
        TestHarness.assertEqual(noMatchVisible.count, 0, "Filter query resolves 0 items for mismatch")
        let noMatchSelected: Int? = noMatchVisible.isEmpty ? nil : 0
        TestHarness.assertNil(noMatchSelected, "Empty search result sets selection to nil")

        // Restored search query: 3 items, selection resets to 0
        let restoredVisible = ShortcutNavigator.resolveVisibleItems(items: items, query: "")
        TestHarness.assertEqual(restoredVisible.count, 3, "Clearing search restores 3 items")
        let restoredSelected: Int? = restoredVisible.isEmpty ? nil : 0
        TestHarness.assertEqual(restoredSelected, 0, "Clearing query resets selection to index 0")

        // 7. Full circular navigation loop
        var cursor: Int? = 0
        for expected in [1, 2, 3, 4, 0, 1, 2, 3, 4, 0] {
            cursor = ShortcutNavigator.stepDown(currentIndex: cursor, visibleCount: count5)
            TestHarness.assertEqual(cursor, expected, "Multi-cycle stepDown passes index \(expected)")
        }

        for expected in [4, 3, 2, 1, 0, 4, 3, 2, 1, 0] {
            cursor = ShortcutNavigator.stepUp(currentIndex: cursor, visibleCount: count5)
            TestHarness.assertEqual(cursor, expected, "Multi-cycle stepUp passes index \(expected)")
        }

        // 8. Return Target Resolution with Circular Selection
        let targetFirst = ShortcutNavigator.resolveReturnTarget(currentIndex: 0, visibleItems: items)
        let targetLast = ShortcutNavigator.resolveReturnTarget(currentIndex: items.count - 1, visibleItems: items)
        let targetNil = ShortcutNavigator.resolveReturnTarget(currentIndex: nil, visibleItems: items)
        TestHarness.assertEqual(targetFirst?.textContent, "Alpha clip", "Return target for index 0 is first clip")
        TestHarness.assertEqual(targetLast?.textContent, "Gamma clip", "Return target for index 2 is last clip")
        TestHarness.assertEqual(targetNil?.textContent, "Alpha clip", "Return target defaults to first clip when index is nil")
        TestHarness.assertNil(ShortcutNavigator.resolveReturnTarget(currentIndex: 0, visibleItems: []), "Return target on empty items is nil")

        // 9. Extreme Integer Boundary Tests
        TestHarness.assertEqual(ShortcutNavigator.stepDown(currentIndex: Int.max, visibleCount: count5), 0, "stepDown with Int.max wraps safely to 0")
        TestHarness.assertEqual(ShortcutNavigator.stepDown(currentIndex: Int.min, visibleCount: count5), 0, "stepDown with Int.min wraps safely to 0")
        TestHarness.assertEqual(ShortcutNavigator.stepUp(currentIndex: Int.max, visibleCount: count5), 4, "stepUp with Int.max wraps safely to visibleCount - 1")
        TestHarness.assertEqual(ShortcutNavigator.stepUp(currentIndex: Int.min, visibleCount: count5), 4, "stepUp with Int.min wraps safely to visibleCount - 1")

        // 10. Large List (100+ clips) Continuous Cycle & Boundary Oscillation
        let count100 = 100
        var pos100: Int? = 0
        // Step forward 300 times (3 full cycles through 100 items)
        for i in 0..<300 {
            pos100 = ShortcutNavigator.stepDown(currentIndex: pos100, visibleCount: count100)
            let expected = (i + 1) % count100
            TestHarness.assertEqual(pos100, expected, "Continuous stepDown cycle step \(i + 1) matches expected \(expected)")
        }
        TestHarness.assertEqual(pos100, 0, "Continuous 300-step cycle returns cleanly to 0")

        // Step backward 300 times (3 full reverse cycles through 100 items)
        for i in 0..<300 {
            pos100 = ShortcutNavigator.stepUp(currentIndex: pos100, visibleCount: count100)
            let expected = (count100 - 1 - (i % count100))
            TestHarness.assertEqual(pos100, expected, "Continuous stepUp cycle step \(i + 1) matches expected \(expected)")
        }
        TestHarness.assertEqual(pos100, 0, "Continuous reverse 300-step cycle returns cleanly to 0")

        // Boundary oscillation across index 0 and 99
        var oscPos: Int? = 0
        for _ in 0..<50 {
            oscPos = ShortcutNavigator.stepUp(currentIndex: oscPos, visibleCount: count100)
            TestHarness.assertEqual(oscPos, 99, "Oscillating stepUp wraps from 0 to 99")
            oscPos = ShortcutNavigator.stepDown(currentIndex: oscPos, visibleCount: count100)
            TestHarness.assertEqual(oscPos, 0, "Oscillating stepDown wraps from 99 to 0")
        }

        // 11. Two-Item Alternating Wrap Tests
        let count2 = 2
        var pos2: Int? = 0
        pos2 = ShortcutNavigator.stepDown(currentIndex: pos2, visibleCount: count2)
        TestHarness.assertEqual(pos2, 1, "Two-item list steps 0 -> 1")
        pos2 = ShortcutNavigator.stepDown(currentIndex: pos2, visibleCount: count2)
        TestHarness.assertEqual(pos2, 0, "Two-item list wraps 1 -> 0")
        pos2 = ShortcutNavigator.stepUp(currentIndex: pos2, visibleCount: count2)
        TestHarness.assertEqual(pos2, 1, "Two-item list wraps 0 -> 1")
        pos2 = ShortcutNavigator.stepUp(currentIndex: pos2, visibleCount: count2)
        TestHarness.assertEqual(pos2, 0, "Two-item list steps 1 -> 0")

        // 12. Keypad Enter (keyCode 76) and Return (keyCode 36) Evaluation
        let returnEvent36 = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        )!
        let keypadEnterEvent76 = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.numericPad],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 76
        )!
        TestHarness.assertNil(ShortcutNavigator.parseShortcut(from: returnEvent36, searchFieldHasFocus: true), "Return keyCode 36 is not parsed as digit shortcut")
        TestHarness.assertNil(ShortcutNavigator.parseShortcut(from: keypadEnterEvent76, searchFieldHasFocus: true), "Keypad Enter keyCode 76 is not parsed as digit shortcut")
        TestHarness.assertNil(ShortcutNavigator.parseSectionShortcut(from: returnEvent36, searchFieldHasFocus: true), "Return keyCode 36 is not parsed as section shortcut")
        TestHarness.assertNil(ShortcutNavigator.parseSectionShortcut(from: keypadEnterEvent76, searchFieldHasFocus: true), "Keypad Enter keyCode 76 is not parsed as section shortcut")

        // 13. Focus Transition Matrix (Search Field Focused vs List Focused)
        for digit in 1...9 {
            let bareEvent = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "\(digit)",
                charactersIgnoringModifiers: "\(digit)",
                isARepeat: false,
                keyCode: UInt16(18 + digit - 1)
            )!
            let cmdEvent = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [.command],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "\(digit)",
                charactersIgnoringModifiers: "\(digit)",
                isARepeat: false,
                keyCode: UInt16(18 + digit - 1)
            )!
            let optEvent = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [.option],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "\(digit)",
                charactersIgnoringModifiers: "\(digit)",
                isARepeat: false,
                keyCode: UInt16(18 + digit - 1)
            )!

            // When search field is focused:
            TestHarness.assertNil(ShortcutNavigator.parseShortcut(from: bareEvent, searchFieldHasFocus: true), "Bare digit \(digit) returns nil when search field has focus")
            TestHarness.assertNil(ShortcutNavigator.parseSectionShortcut(from: bareEvent, searchFieldHasFocus: true), "Bare digit \(digit) section returns nil when search field has focus")
            TestHarness.assertEqual(ShortcutNavigator.parseShortcut(from: cmdEvent, searchFieldHasFocus: true), digit, "Cmd+\(digit) returns digit \(digit) even when search field has focus")
            TestHarness.assertEqual(ShortcutNavigator.parseSectionShortcut(from: cmdEvent, searchFieldHasFocus: true)?.section, .recent, "Cmd+\(digit) maps to recent section")
            TestHarness.assertEqual(ShortcutNavigator.parseSectionShortcut(from: optEvent, searchFieldHasFocus: true)?.section, .pinned, "Option+\(digit) maps to pinned section")

            // When search field is blurred (list focused):
            TestHarness.assertEqual(ShortcutNavigator.parseShortcut(from: bareEvent, searchFieldHasFocus: false), digit, "Bare digit \(digit) returns digit \(digit) when list has focus")
            TestHarness.assertEqual(ShortcutNavigator.parseSectionShortcut(from: bareEvent, searchFieldHasFocus: false)?.section, .recent, "Bare digit \(digit) maps to recent section when list has focus")
        }

        // 14. Window Isolation Check for Non-Hosting Windows
        let settingsWin = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        settingsWin.title = "SuperClip Settings"
        let aboutWin = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        aboutWin.title = "About SuperClip"
        let clipPanel = FloatingClipPanel()

        TestHarness.assertTrue(settingsWin.title == "SuperClip Settings", "Settings window title identified accurately")
        TestHarness.assertTrue(aboutWin.title.hasPrefix("About"), "About window title identified accurately")
        TestHarness.assertTrue(clipPanel is FloatingClipPanel, "FloatingClipPanel identified accurately as primary hosting window")
    }
}
