import Foundation
import CoreGraphics
import AppKit
import SwiftUI
import SuperClipCore
import SuperClip

@main
public struct SearchNavigationAdversarialHarness {
    nonisolated public static func makeKeyEvent(keyChar: String, keyCode: UInt16, modifiers: NSEvent.ModifierFlags, type: NSEvent.EventType = .keyDown) -> NSEvent {
        return NSEvent.keyEvent(
            with: type,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: keyChar,
            charactersIgnoringModifiers: keyChar,
            isARepeat: false,
            keyCode: keyCode
        )!
    }

    public static func main() {
        print("==================================================")
        print("  SuperClip Search & Navigation Adversarial Harness")
        print("==================================================")

        var totalTests = 0
        var passedTests = 0
        var failedTests = 0

        func report(name: String, passed: Bool, detail: String = "") {
            totalTests += 1
            if passed {
                passedTests += 1
                print("  [PASS] \(name)")
            } else {
                failedTests += 1
                print("  [FAIL] \(name): \(detail)")
            }
        }

        // =================================================================
        // SUITE 1: SearchBarView & SearchEngine Adversarial Stress Testing
        // =================================================================
        print("\n--- Suite 1: SearchEngine Adversarial Query Stress ---")

        // 1.1: Complex regex metacharacters in query
        let codeClip = ClipItem(
            contentType: .text,
            textContent: "let regex = try NSRegularExpression(pattern: \"^[a-z0-9_.+-]+@[a-z0-9-]+\\\\.[a-z0-9-.]+$\", options: [.caseInsensitive])",
            byteSize: 120,
            isPinned: true
        )
        let mathClip = ClipItem(
            contentType: .text,
            textContent: "Formula: f(x) = (x + y) * [z / w] ^ {2} | delta > 0.05",
            byteSize: 60,
            isPinned: false
        )
        let plainClip = ClipItem(
            contentType: .text,
            textContent: "Plain vanilla documentation for clipboard manager features",
            byteSize: 62,
            isPinned: false
        )
        let clipsList = [codeClip, mathClip, plainClip]

        report(
            name: "SearchEngine matches literal bracket pattern '^[a-z0-9'",
            passed: SearchEngine.matches(item: codeClip, query: "^[a-z0-9")
        )
        report(
            name: "SearchEngine matches literal escaped backslash '\\\\.[a-z'",
            passed: SearchEngine.matches(item: codeClip, query: "\\.[a-z")
        )
        report(
            name: "SearchEngine matches literal math tokens '(x + y)'",
            passed: SearchEngine.matches(item: mathClip, query: "(x + y)")
        )
        report(
            name: "SearchEngine matches literal pipe and braces '| delta > 0.05'",
            passed: SearchEngine.matches(item: mathClip, query: "| delta > 0.05")
        )
        report(
            name: "SearchEngine does not falsely match plain clip with '.*'",
            passed: !SearchEngine.matches(item: plainClip, query: ".*")
        )
        report(
            name: "SearchEngine does not falsely match plain clip with '[a-z]+'",
            passed: !SearchEngine.matches(item: plainClip, query: "[a-z]+")
        )
        report(
            name: "SearchEngine does not falsely match plain clip with '^Plain$'",
            passed: !SearchEngine.matches(item: plainClip, query: "^Plain$")
        )
        report(
            name: "SearchEngine does not falsely match plain clip with '(vanilla|chocolate)'",
            passed: !SearchEngine.matches(item: plainClip, query: "(vanilla|chocolate)")
        )

        // 1.2: Unicode normalization, diacritics, and international scripts
        let accentedFrenchClip = ClipItem(
            contentType: .text,
            textContent: "Commander un caf\u{00E9} au lait et une cr\u{00E8}me br\u{00FB}l\u{00E9}e \u{00E0} Paris",
            byteSize: 60,
            isPinned: true
        )
        let spanishClip = ClipItem(
            contentType: .text,
            textContent: "Ma\u{00F1}ana por la tarde en el ca\u{00F1}\u{00F3}n profundo",
            byteSize: 50,
            isPinned: false
        )
        let germanClip = ClipItem(
            contentType: .text,
            textContent: "Gro\u{00DF}e \u{00DC}berraschung in M\u{00FC}nchen am Stra\u{00DF}enrand",
            byteSize: 58,
            isPinned: false
        )
        let vietnameseClip = ClipItem(
            contentType: .text,
            textContent: "Ti\u{1EBF}ng Vi\u{1EC7}t c\u{00F3} d\u{1EA5}u v\u{00E0} thanh \u{0111}i\u{1EC7}u ph\u{1EE9}c t\u{1EA1}p",
            byteSize: 64,
            isPinned: false
        )

        // Diacritic folding tests
        report(
            name: "Unaccented query 'cafe' matches accented 'caf\u{00E9}'",
            passed: SearchEngine.matches(item: accentedFrenchClip, query: "cafe")
        )
        report(
            name: "Unaccented query 'creme brulee' matches 'cr\u{00E8}me br\u{00FB}l\u{00E9}e'",
            passed: SearchEngine.matches(item: accentedFrenchClip, query: "creme brulee")
        )
        report(
            name: "Decomposed query matches precomposed target string",
            passed: SearchEngine.matches(item: accentedFrenchClip, query: "cafe\u{0301}")
        )
        report(
            name: "Unaccented query 'manana canon' matches 'Ma\u{00F1}ana ca\u{00F1}\u{00F3}n'",
            passed: SearchEngine.matches(item: spanishClip, query: "manana canon")
        )
        report(
            name: "Unaccented query 'munchen' matches 'M\u{00FC}nchen'",
            passed: SearchEngine.matches(item: germanClip, query: "munchen")
        )
        report(
            name: "Unaccented query 'tieng viet' matches Vietnamese string",
            passed: SearchEngine.matches(item: vietnameseClip, query: "tieng viet")
        )

        // CJK and RTL scripts
        let cjkClip = ClipItem(
            contentType: .text,
            textContent: "\u{4E00}\u{671F}\u{4E00}\u{4F1A} \u{65E5}\u{672C}\u{8A9E} \u{D55C}\u{AD6D}\u{C5B4} \u{7B80}\u{4F53}\u{4E2D}\u{6587}",
            byteSize: 50,
            isPinned: false
        )
        let hebrewClip = ClipItem(
            contentType: .text,
            textContent: "\u{05E9}\u{05DC}\u{05D5}\u{05DD} \u{05E2}\u{05D5}\u{05DC}\u{05DD} Hebrew clipboard text item",
            byteSize: 45,
            isPinned: false
        )
        report(
            name: "SearchEngine matches Japanese Kanji query",
            passed: SearchEngine.matches(item: cjkClip, query: "\u{65E5}\u{672C}\u{8A9E}")
        )
        report(
            name: "SearchEngine matches Korean Hangul query",
            passed: SearchEngine.matches(item: cjkClip, query: "\u{D55C}\u{AD6D}\u{C5B4}")
        )
        report(
            name: "SearchEngine matches Hebrew RTL query",
            passed: SearchEngine.matches(item: hebrewClip, query: "\u{05E9}\u{05DC}\u{05D5}\u{05DD}")
        )

        // 1.3: External emoji payloads and non-BMP surrogate stability
        let externalEmojiClip = ClipItem(
            contentType: .text,
            textContent: "Deployment Status: SUCCESS \u{1F680} and database migration \u{1F525} complete \u{2705}",
            byteSize: 85,
            isPinned: true
        )
        report(
            name: "SearchEngine matches ASCII token in clip containing external emojis",
            passed: SearchEngine.matches(item: externalEmojiClip, query: "SUCCESS migration")
        )
        report(
            name: "SearchEngine matches literal emoji query without crash",
            passed: SearchEngine.matches(item: externalEmojiClip, query: "\u{1F680}")
        )
        report(
            name: "SearchEngine returns false on non-matching emoji query without crash",
            passed: !SearchEngine.matches(item: externalEmojiClip, query: "\u{1F4A9}")
        )

        // 1.4: Whitespace bursts and multi-token collapsing
        let burstWhitespaceQuery = String(repeating: " ", count: 5000)
        report(
            name: "5000-space query is treated as empty query restoring all items",
            passed: SearchEngine.filter(items: clipsList, query: burstWhitespaceQuery).count == clipsList.count
        )
        let mixedWhitespaceQuery = "\t\r\n   \t  \r\n   "
        report(
            name: "Mixed tabs, newlines, carriage returns treated as empty query",
            passed: SearchEngine.filter(items: clipsList, query: mixedWhitespaceQuery).count == clipsList.count
        )
        let multiTokenBurst = "vanilla" + String(repeating: " ", count: 50) + "documentation"
        report(
            name: "Multi-token query with 50 intervening spaces matches target",
            passed: SearchEngine.matches(item: plainClip, query: multiTokenBurst)
        )
        report(
            name: "Multi-token query in reverse order matches target",
            passed: SearchEngine.matches(item: plainClip, query: "documentation vanilla plain")
        )
        report(
            name: "Multi-token query with repeated tokens matches target",
            passed: SearchEngine.matches(item: plainClip, query: "vanilla vanilla vanilla")
        )
        report(
            name: "Multi-token query fails when single token is absent",
            passed: !SearchEngine.matches(item: plainClip, query: "vanilla documentation absent_token_xyz")
        )

        // 1.5: Very long queries and payload sizes
        let ultraLongQuery = String(repeating: "a", count: 20000)
        let startLong = CFAbsoluteTimeGetCurrent()
        let longMatch = SearchEngine.matches(item: plainClip, query: ultraLongQuery)
        let durLong = CFAbsoluteTimeGetCurrent() - startLong
        report(
            name: "20,000-character query completes safely without hang (< 0.1s)",
            passed: (!longMatch && durLong < 0.1),
            detail: "Match: \(longMatch), Duration: \(durLong)s"
        )

        let nullByteClip = ClipItem(
            contentType: .text,
            textContent: "Prefix\0NullByte\0Suffix",
            byteSize: 22,
            isPinned: false
        )
        report(
            name: "SearchEngine matches null byte substring literally",
            passed: SearchEngine.matches(item: nullByteClip, query: "\0NullByte\0")
        )
        report(
            name: "SearchEngine does not match null byte against clean plain text",
            passed: !SearchEngine.matches(item: plainClip, query: "\0")
        )

        // 1.6: Image clips displayTitle filtering
        let imageClipA = ClipItem(
            contentType: .image,
            imageWidth: 2560,
            imageHeight: 1440,
            byteSize: 500000,
            isPinned: false
        )
        let imageClipB = ClipItem(
            contentType: .image,
            imageWidth: 800,
            imageHeight: 600,
            byteSize: 120000,
            isPinned: true
        )
        let mixedClips = [codeClip, mathClip, plainClip, imageClipA, imageClipB]

        report(
            name: "Query '2560' matches 2560x1440 image clip title",
            passed: SearchEngine.matches(item: imageClipA, query: "2560")
        )
        report(
            name: "Query '800' matches 800x600 image clip title",
            passed: SearchEngine.matches(item: imageClipB, query: "800")
        )
        report(
            name: "Query 'Image' matches both image clips",
            passed: SearchEngine.filter(items: mixedClips, query: "Image").count == 2
        )
        report(
            name: "Query 'documentation' excludes image clips",
            passed: SearchEngine.filter(items: mixedClips, query: "documentation").count == 1
        )

        // 1.7: Rapid text oscillation & partitioned invariance
        var oscillationPassed = true
        let queries = ["vanilla", "", "regex", "Image", "   ", "2560", "cafe", "nonexistent"]
        for i in 0..<1000 {
            let q = queries[i % queries.count]
            let (pinned, recent) = SearchEngine.partition(items: mixedClips, query: q)
            let filtered = SearchEngine.filter(items: mixedClips, query: q)
            if (pinned.count + recent.count) != filtered.count {
                oscillationPassed = false
            }
            if !pinned.allSatisfy({ $0.isPinned }) {
                oscillationPassed = false
            }
            if !recent.allSatisfy({ !$0.isPinned }) {
                oscillationPassed = false
            }
        }
        report(
            name: "SearchEngine maintains partition invariants across 1,000 rapid query oscillations",
            passed: oscillationPassed
        )

        // =================================================================
        // SUITE 2: Number Shortcuts 1..9 & ShortcutNavigator Stress Testing
        // =================================================================
        print("\n--- Suite 2: Number Shortcuts 1..9 Adversarial Stress ---")

        // 2.1: Out-of-bounds mapping across empty, small, and oversized collections
        let emptyClips: [ClipItem] = []
        for key in 1...9 {
            let target = ShortcutNavigator.targetItem(forShortcut: key, in: emptyClips)
            report(
                name: "Shortcut \(key) on empty collection returns nil (no-op)",
                passed: target == nil
            )
        }
        report(
            name: "Shortcut 0 returns nil on empty collection",
            passed: ShortcutNavigator.targetItem(forShortcut: 0, in: emptyClips) == nil
        )
        report(
            name: "Shortcut 10 returns nil on empty collection",
            passed: ShortcutNavigator.targetItem(forShortcut: 10, in: emptyClips) == nil
        )
        report(
            name: "Negative shortcut -5 returns nil",
            passed: ShortcutNavigator.targetItem(forShortcut: -5, in: emptyClips) == nil
        )
        report(
            name: "Int.min shortcut returns nil",
            passed: ShortcutNavigator.targetItem(forShortcut: Int.min, in: emptyClips) == nil
        )
        report(
            name: "Int.max shortcut returns nil",
            passed: ShortcutNavigator.targetItem(forShortcut: Int.max, in: emptyClips) == nil
        )

        // Small 2-item collection
        let twoClips = [
            ClipItem(contentType: .text, textContent: "Alpha", byteSize: 10, isPinned: true),
            ClipItem(contentType: .text, textContent: "Beta", byteSize: 10, isPinned: false)
        ]
        report(
            name: "Shortcut 1 on 2-item list resolves to Alpha",
            passed: ShortcutNavigator.targetItem(forShortcut: 1, in: twoClips)?.textContent == "Alpha"
        )
        report(
            name: "Shortcut 2 on 2-item list resolves to Beta",
            passed: ShortcutNavigator.targetItem(forShortcut: 2, in: twoClips)?.textContent == "Beta"
        )
        for key in 3...9 {
            let target = ShortcutNavigator.targetItem(forShortcut: key, in: twoClips)
            report(
                name: "Shortcut \(key) on 2-item list safely returns nil",
                passed: target == nil
            )
        }

        // 8-item collection (key 9 out of bounds)
        let eightClips = (1...8).map { i in
            ClipItem(contentType: .text, textContent: "Item \(i)", byteSize: 10, isPinned: i <= 2)
        }
        for key in 1...8 {
            let target = ShortcutNavigator.targetItem(forShortcut: key, in: eightClips)
            report(
                name: "Shortcut \(key) on 8-item list resolves to Item \(key)",
                passed: target?.textContent == "Item \(key)"
            )
        }
        report(
            name: "Shortcut 9 on 8-item list safely returns nil",
            passed: ShortcutNavigator.targetItem(forShortcut: 9, in: eightClips) == nil
        )

        // Oversized 50-item collection
        let fiftyClips = (1...50).map { i in
            ClipItem(contentType: .text, textContent: "Row \(i)", byteSize: 10, isPinned: false)
        }
        for key in 1...9 {
            let target = ShortcutNavigator.targetItem(forShortcut: key, in: fiftyClips)
            report(
                name: "Shortcut \(key) on 50-item list resolves to Row \(key)",
                passed: target?.textContent == "Row \(key)"
            )
        }
        report(
            name: "Shortcut 10 on 50-item list returns nil",
            passed: ShortcutNavigator.targetItem(forShortcut: 10, in: fiftyClips) == nil
        )
        report(
            name: "Shortcut 50 on 50-item list returns nil",
            passed: ShortcutNavigator.targetItem(forShortcut: 50, in: fiftyClips) == nil
        )

        // 2.2: Dynamic query remapping with pinned partition priority
        let testItems = [
            ClipItem(contentType: .text, textContent: "Database URL: postgres://localhost", byteSize: 35, isPinned: true),
            ClipItem(contentType: .text, textContent: "Redis Port: 6379", byteSize: 16, isPinned: true),
            ClipItem(contentType: .text, textContent: "App Port: 8080", byteSize: 14, isPinned: false),
            ClipItem(contentType: .text, textContent: "Database Password: secret", byteSize: 25, isPinned: false),
            ClipItem(contentType: .text, textContent: "API Endpoint: /v1/users", byteSize: 23, isPinned: false),
            ClipItem(contentType: .text, textContent: "Database Host: 127.0.0.1", byteSize: 24, isPinned: false)
        ]

        // Dynamic query 1: "Database" -> Matches 1 pinned + 2 recent = 3 items
        let dbVisible = ShortcutNavigator.resolveVisibleItems(items: testItems, query: "Database")
        report(
            name: "Visible items count for 'Database' is exactly 3",
            passed: dbVisible.count == 3
        )
        report(
            name: "Dynamic Shortcut 1 maps to pinned Database URL",
            passed: ShortcutNavigator.targetItem(forShortcut: 1, in: dbVisible)?.textContent == "Database URL: postgres://localhost"
        )
        report(
            name: "Dynamic Shortcut 2 maps to first recent match (Database Password)",
            passed: ShortcutNavigator.targetItem(forShortcut: 2, in: dbVisible)?.textContent == "Database Password: secret"
        )
        report(
            name: "Dynamic Shortcut 3 maps to second recent match (Database Host)",
            passed: ShortcutNavigator.targetItem(forShortcut: 3, in: dbVisible)?.textContent == "Database Host: 127.0.0.1"
        )
        report(
            name: "Dynamic Shortcut 4 on 3-item result returns nil",
            passed: ShortcutNavigator.targetItem(forShortcut: 4, in: dbVisible) == nil
        )

        // Dynamic query 2: "Port" -> Matches 1 pinned (Redis 6379) + 1 recent (App 8080) = 2 items
        let portVisible = ShortcutNavigator.resolveVisibleItems(items: testItems, query: "Port")
        report(
            name: "Dynamic Shortcut 1 maps to pinned Redis Port",
            passed: ShortcutNavigator.targetItem(forShortcut: 1, in: portVisible)?.textContent == "Redis Port: 6379"
        )
        report(
            name: "Dynamic Shortcut 2 maps to unpinned App Port",
            passed: ShortcutNavigator.targetItem(forShortcut: 2, in: portVisible)?.textContent == "App Port: 8080"
        )
        report(
            name: "Dynamic Shortcut 3 on 2-item port list returns nil",
            passed: ShortcutNavigator.targetItem(forShortcut: 3, in: portVisible) == nil
        )

        // Dynamic query 3: "Nonexistent" -> 0 items
        let noneVisible = ShortcutNavigator.resolveVisibleItems(items: testItems, query: "Nonexistent")
        report(
            name: "Shortcuts 1..9 on zero-match search all return nil",
            passed: (1...9).allSatisfy { ShortcutNavigator.targetItem(forShortcut: $0, in: noneVisible) == nil }
        )

        // Dynamic query 4: Restoration via empty query
        let restoredVisible = ShortcutNavigator.resolveVisibleItems(items: testItems, query: "")
        report(
            name: "Clearing query restores full 6 items with pinned items first",
            passed: (restoredVisible.count == 6 &&
                     ShortcutNavigator.targetItem(forShortcut: 1, in: restoredVisible)?.textContent == "Database URL: postgres://localhost" &&
                     ShortcutNavigator.targetItem(forShortcut: 2, in: restoredVisible)?.textContent == "Redis Port: 6379")
        )

        // 2.3: Key Modifier Handling (parseShortcut)
        // Test Command + 1..9 across both focus states
        var cmdParsedPassed = true
        for d in 1...9 {
            let ev = makeKeyEvent(keyChar: "\(d)", keyCode: UInt16(17 + d), modifiers: .command)
            let f = ShortcutNavigator.parseShortcut(from: ev, searchFieldHasFocus: true)
            let b = ShortcutNavigator.parseShortcut(from: ev, searchFieldHasFocus: false)
            if f != d || b != d {
                cmdParsedPassed = false
            }
        }
        report(
            name: "Command + 1..9 triggers unconditionally across both focused and blurred states",
            passed: cmdParsedPassed
        )

        // Test Bare 1..9 focus gating
        var bareParsedPassed = true
        for d in 1...9 {
            let ev = makeKeyEvent(keyChar: "\(d)", keyCode: UInt16(17 + d), modifiers: [])
            let f = ShortcutNavigator.parseShortcut(from: ev, searchFieldHasFocus: true)
            let b = ShortcutNavigator.parseShortcut(from: ev, searchFieldHasFocus: false)
            if f != nil || b != d {
                bareParsedPassed = false
            }
        }
        report(
            name: "Bare 1..9 is gated: returns nil when search field has focus, returns digit when blurred",
            passed: bareParsedPassed
        )

        // Test Rejection of Option and Control modifiers
        var modifierRejectionPassed = true
        let badModifierCombos: [NSEvent.ModifierFlags] = [
            .option,
            .control,
            [.command, .option],
            [.command, .control],
            [.option, .control],
            [.command, .option, .control]
        ]
        for combo in badModifierCombos {
            for d in 1...9 {
                let ev = makeKeyEvent(keyChar: "\(d)", keyCode: UInt16(17 + d), modifiers: combo)
                if ShortcutNavigator.parseShortcut(from: ev, searchFieldHasFocus: false) != nil ||
                   ShortcutNavigator.parseShortcut(from: ev, searchFieldHasFocus: true) != nil {
                    modifierRejectionPassed = false
                }
            }
        }
        report(
            name: "Option and Control modifiers are strictly rejected across all shortcut digits",
            passed: modifierRejectionPassed
        )

        // Non-target keys with Command
        report(
            name: "Command + 0 returns nil",
            passed: ShortcutNavigator.parseShortcut(
                from: makeKeyEvent(keyChar: "0", keyCode: 29, modifiers: .command),
                searchFieldHasFocus: false
            ) == nil
        )
        report(
            name: "Command + A returns nil",
            passed: ShortcutNavigator.parseShortcut(
                from: makeKeyEvent(keyChar: "a", keyCode: 0, modifiers: .command),
                searchFieldHasFocus: false
            ) == nil
        )
        report(
            name: "Command + V returns nil",
            passed: ShortcutNavigator.parseShortcut(
                from: makeKeyEvent(keyChar: "v", keyCode: 9, modifiers: .command),
                searchFieldHasFocus: false
            ) == nil
        )
        report(
            name: "Command + Space returns nil",
            passed: ShortcutNavigator.parseShortcut(
                from: makeKeyEvent(keyChar: " ", keyCode: 49, modifiers: .command),
                searchFieldHasFocus: false
            ) == nil
        )

        // Non-keyDown events
        let keyUpEvent = makeKeyEvent(keyChar: "1", keyCode: 18, modifiers: .command, type: .keyUp)
        report(
            name: "keyUp event returns nil",
            passed: ShortcutNavigator.parseShortcut(from: keyUpEvent, searchFieldHasFocus: false) == nil
        )

        // 2.4: Rapid Sequential & Concurrent Triggers
        let startRapid = CFAbsoluteTimeGetCurrent()
        var rapidCorrect = true
        for i in 0..<20000 {
            let digit = (i % 9) + 1
            let ev = makeKeyEvent(keyChar: "\(digit)", keyCode: UInt16(18 + digit), modifiers: .command)
            if ShortcutNavigator.parseShortcut(from: ev, searchFieldHasFocus: false) != digit {
                rapidCorrect = false
            }
        }
        let durRapid = CFAbsoluteTimeGetCurrent() - startRapid
        report(
            name: "20,000 sequential shortcut parses execute deterministically in < 0.2s",
            passed: (rapidCorrect && durRapid < 0.2),
            detail: "Duration: \(durRapid)s"
        )

        // Concurrent multi-threaded stress
        let concurrentGroup = DispatchGroup()
        let concurrentQueue = DispatchQueue(label: "com.superclip.adversarial.shortcuts", attributes: .concurrent)
        var concurrentFailures = 0
        let failureLock = NSLock()

        for t in 0..<10 {
            concurrentGroup.enter()
            concurrentQueue.async {
                for i in 0..<1000 {
                    let d = (i % 9) + 1
                    let ev = makeKeyEvent(keyChar: "\(d)", keyCode: UInt16(18 + d), modifiers: .command)
                    let parsed = ShortcutNavigator.parseShortcut(from: ev, searchFieldHasFocus: (t % 2 == 0))
                    let target = ShortcutNavigator.targetItem(forShortcut: d, in: testItems)
                    if parsed != d || (d <= testItems.count && target == nil) {
                        failureLock.lock()
                        concurrentFailures += 1
                        failureLock.unlock()
                    }
                }
                concurrentGroup.leave()
            }
        }
        concurrentGroup.wait()
        report(
            name: "10 concurrent threads parsing 10,000 shortcuts encounter zero race conditions",
            passed: concurrentFailures == 0,
            detail: "Concurrent failures: \(concurrentFailures)"
        )

        // 2.5: Arrow Key Navigation and Return Key Selection Boundaries
        report(
            name: "stepDown from unselected (nil) on 5 items selects index 0",
            passed: ShortcutNavigator.stepDown(currentIndex: nil, visibleCount: 5) == 0
        )
        report(
            name: "stepDown increments 0 -> 1 -> 2 -> 3 -> 4",
            passed: (ShortcutNavigator.stepDown(currentIndex: 0, visibleCount: 5) == 1 &&
                     ShortcutNavigator.stepDown(currentIndex: 1, visibleCount: 5) == 2 &&
                     ShortcutNavigator.stepDown(currentIndex: 2, visibleCount: 5) == 3 &&
                     ShortcutNavigator.stepDown(currentIndex: 3, visibleCount: 5) == 4)
        )
        report(
            name: "stepDown wraps around at index 4 (visibleCount - 1) to 0",
            passed: ShortcutNavigator.stepDown(currentIndex: 4, visibleCount: 5) == 0
        )
        report(
            name: "stepDown wraps when currentIndex is out-of-bounds large",
            passed: ShortcutNavigator.stepDown(currentIndex: 99, visibleCount: 5) == 0
        )
        report(
            name: "stepDown on empty list returns nil",
            passed: ShortcutNavigator.stepDown(currentIndex: nil, visibleCount: 0) == nil
        )
        report(
            name: "stepUp decrements 4 -> 3 -> 2 -> 1 -> 0",
            passed: (ShortcutNavigator.stepUp(currentIndex: 4, visibleCount: 5) == 3 &&
                     ShortcutNavigator.stepUp(currentIndex: 1, visibleCount: 5) == 0)
        )
        report(
            name: "stepUp from index 0 wraps to visibleCount - 1 (index 4)",
            passed: ShortcutNavigator.stepUp(currentIndex: 0, visibleCount: 5) == 4
        )
        report(
            name: "stepUp from nil selects visibleCount - 1 (index 4)",
            passed: ShortcutNavigator.stepUp(currentIndex: nil, visibleCount: 5) == 4
        )
        report(
            name: "stepUp on empty list returns nil",
            passed: ShortcutNavigator.stepUp(currentIndex: 0, visibleCount: 0) == nil
        )

        // Return key resolution
        report(
            name: "resolveReturnTarget on highlighted index returns matching item",
            passed: ShortcutNavigator.resolveReturnTarget(currentIndex: 1, visibleItems: testItems)?.textContent == testItems[1].textContent
        )
        report(
            name: "resolveReturnTarget with nil index defaults to top visible item",
            passed: ShortcutNavigator.resolveReturnTarget(currentIndex: nil, visibleItems: testItems)?.textContent == testItems[0].textContent
        )
        report(
            name: "resolveReturnTarget with out-of-bounds index falls back to top item",
            passed: ShortcutNavigator.resolveReturnTarget(currentIndex: 999, visibleItems: testItems)?.textContent == testItems[0].textContent
        )
        report(
            name: "resolveReturnTarget on empty list returns nil",
            passed: ShortcutNavigator.resolveReturnTarget(currentIndex: nil, visibleItems: []) == nil
        )

        // Badge labels
        let badgeTests = (0...8).allSatisfy { ShortcutNavigator.badgeLabel(forIndex: $0) == "\($0 + 1)" } &&
                         ShortcutNavigator.badgeLabel(forIndex: 9) == nil &&
                         ShortcutNavigator.badgeLabel(forIndex: 10) == nil &&
                         ShortcutNavigator.badgeLabel(forIndex: -1) == nil
        report(
            name: "badgeLabel produces '1'..'9' for indices 0..8, and nil for all other indices",
            passed: badgeTests
        )

        // =================================================================
        // SUMMARY & VERDICT
        // =================================================================
        print("\n==================================================")
        print("  Adversarial Challenge Execution Summary")
        print("==================================================")
        print("  Total Challenges: \(totalTests)")
        print("  Passed:           \(passedTests)")
        print("  Failed:           \(failedTests)")

        if failedTests == 0 {
            print("\nVERDICT: APPROVE (All adversarial challenges passed)\n")
            exit(0)
        } else {
            print("\nVERDICT: REJECT (\(failedTests) adversarial challenges failed)\n")
            exit(1)
        }
    }
}
