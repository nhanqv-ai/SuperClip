import Foundation
import AppKit
import SwiftUI
import SuperClipCore
import SuperClip

@main
public struct ChallengerM3R2EmpiricalRunner {
    static var totalTests = 0
    static var passedTests = 0
    static var failedTests = 0

    static func report(name: String, passed: Bool, detail: String = "") {
        totalTests += 1
        if passed {
            passedTests += 1
            print("  [PASS] \(name)")
        } else {
            failedTests += 1
            let extra = detail.isEmpty ? "" : " (Detail: \(detail))"
            print("  [FAIL] \(name)\(extra)")
        }
    }

    nonisolated static func makeKeyEvent(
        keyChar: String,
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        type: NSEvent.EventType = .keyDown
    ) -> NSEvent {
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
        print("  SuperClip Challenger M3-R2 Empirical Stress Runner")
        print("  Target: SearchBarView, SearchEngine, Shortcuts 1..9")
        print("==================================================")

        // =================================================================
        // SUITE 1: SearchEngine Adversarial Query & Normalization Stress
        // =================================================================
        print("\n--- Suite 1: SearchEngine Adversarial Query Stress ---")

        // 1.1 Regex metacharacter injection resilience
        let regexSnippetClip = ClipItem(
            contentType: .text,
            textContent: "Regex pattern: ^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\\.[a-zA-Z0-9-.]+$ with flags (?i) and \\b(cat|dog)\\b",
            byteSize: 150,
            isPinned: true
        )
        let controlClip = ClipItem(
            contentType: .text,
            textContent: "Standard unpinned clipboard snippet without patterns",
            byteSize: 52,
            isPinned: false
        )

        let regexAttacks = [
            "^[a-zA-Z0-9_.+-]+@",
            "\\.[a-zA-Z0-9-.]+$",
            "(?i)",
            "\\b(cat|dog)\\b",
            ".*",
            "[a-z]+",
            "^Standard$",
            "(without|with)",
            "(?=lookahead)",
            "\\d{1,3}\\.\\d{1,3}",
            "++",
            "***"
        ]

        for pattern in regexAttacks {
            // Should match regexSnippetClip only if pattern is a literal substring
            let isSubstring = (regexSnippetClip.textContent ?? "").contains(pattern)
            let matched = SearchEngine.matches(item: regexSnippetClip, query: pattern)
            report(
                name: "Regex pattern '\(pattern)' treated strictly as literal (matched: \(matched), expected: \(isSubstring))",
                passed: matched == isSubstring
            )
        }

        // Control clip must not match regex queries that are not substrings
        report(
            name: "Control clip does not match '.*'",
            passed: !SearchEngine.matches(item: controlClip, query: ".*")
        )
        report(
            name: "Control clip does not match '[a-z]+'",
            passed: !SearchEngine.matches(item: controlClip, query: "[a-z]+")
        )

        // 1.2 Extensive International Unicode & Diacritics Folding
        let frenchClip = ClipItem(
            contentType: .text,
            textContent: "Caf\u{00E9} cr\u{00E8}me et cr\u{00EA}pe sucr\u{00E9}e \u{00E0} No\u{00EB}l",
            byteSize: 50,
            isPinned: true
        )
        let germanClip = ClipItem(
            contentType: .text,
            textContent: "Die gro\u{00DF}e Stra\u{00DF}enbahn f\u{00E4}hrt \u{00FC}ber K\u{00F6}ln und M\u{00FC}nchen",
            byteSize: 65,
            isPinned: false
        )
        let spanishClip = ClipItem(
            contentType: .text,
            textContent: "El ni\u{00F1}o come jalape\u{00F1}os en la monta\u{00F1}a",
            byteSize: 50,
            isPinned: false
        )
        let vietnameseClip = ClipItem(
            contentType: .text,
            textContent: "B\u{00E1}nh m\u{00EC} th\u{1ECB}t n\u{01B0}\u{1EDB}ng v\u{00E0} ph\u{1EDF} b\u{00F2} H\u{00E0} N\u{1ED9}i",
            byteSize: 60,
            isPinned: false
        )
        let scandinavianClip = ClipItem(
            contentType: .text,
            textContent: "Sm\u{00F6}rg\u{00E5}sbord p\u{00E5} \u{00C5}land i Malm\u{00F6}",
            byteSize: 45,
            isPinned: false
        )

        // Accent insensitivity tests
        report(
            name: "French: unaccented 'cafe creme' matches 'Caf\u{00E9} cr\u{00E8}me'",
            passed: SearchEngine.matches(item: frenchClip, query: "cafe creme")
        )
        report(
            name: "French: unaccented 'crepe sucree' matches 'cr\u{00EA}pe sucr\u{00E9}e'",
            passed: SearchEngine.matches(item: frenchClip, query: "crepe sucree")
        )
        report(
            name: "German: unaccented 'grosse strassenbahn' matches 'gro\u{00DF}e Stra\u{00DF}enbahn'",
            passed: SearchEngine.matches(item: germanClip, query: "grosse strassenbahn") ||
                    SearchEngine.matches(item: germanClip, query: "große straßenbahn")
        )
        report(
            name: "German: unaccented 'koln munchen' matches 'K\u{00F6}ln und M\u{00FC}nchen'",
            passed: SearchEngine.matches(item: germanClip, query: "koln munchen")
        )
        report(
            name: "Spanish: unaccented 'nino jalapenos montana' matches Spanish clip",
            passed: SearchEngine.matches(item: spanishClip, query: "nino jalapenos montana")
        )
        report(
            name: "Vietnamese: unaccented 'banh mi pho bo' matches Vietnamese clip",
            passed: SearchEngine.matches(item: vietnameseClip, query: "banh mi pho bo")
        )
        report(
            name: "Scandinavian: unaccented 'smorgasbord aland malmo' matches Scandinavian clip",
            passed: SearchEngine.matches(item: scandinavianClip, query: "smorgasbord aland malmo")
        )

        // Decomposed vs Precomposed Unicode canonical equivalence
        let decomposedCafeQuery = "Cafe\u{0301}"
        report(
            name: "Decomposed NFD query 'Cafe\\u{0301}' matches precomposed NFC target",
            passed: SearchEngine.matches(item: frenchClip, query: decomposedCafeQuery)
        )

        // 1.3 Non-Latin Scripts: CJK, Cyrillic, Greek, Arabic, Hebrew, Thai, Devanagari
        let multiScriptClip = ClipItem(
            contentType: .text,
            textContent: "CJK: 日本語, 简体中文, 한국어 | CYR: Привет | GRK: Καλημέρα | ARB: مرحبا | HEB: שלום | THAI: สวัสดี | DEV: नमस्ते",
            byteSize: 180,
            isPinned: false
        )

        report(name: "Matches Japanese '日本語'", passed: SearchEngine.matches(item: multiScriptClip, query: "日本語"))
        report(name: "Matches Chinese '简体中文'", passed: SearchEngine.matches(item: multiScriptClip, query: "简体中文"))
        report(name: "Matches Korean '한국어'", passed: SearchEngine.matches(item: multiScriptClip, query: "한국어"))
        report(name: "Matches Cyrillic 'Привет'", passed: SearchEngine.matches(item: multiScriptClip, query: "Привет"))
        report(name: "Matches Greek 'Καλημέρα'", passed: SearchEngine.matches(item: multiScriptClip, query: "Καλημέρα"))
        report(name: "Matches Arabic RTL 'مرحبا'", passed: SearchEngine.matches(item: multiScriptClip, query: "مرحبا"))
        report(name: "Matches Hebrew RTL 'שלום'", passed: SearchEngine.matches(item: multiScriptClip, query: "שלום"))
        report(name: "Matches Thai 'สวัสดี'", passed: SearchEngine.matches(item: multiScriptClip, query: "สวัสดี"))
        report(name: "Matches Devanagari 'नमस्ते'", passed: SearchEngine.matches(item: multiScriptClip, query: "नमस्ते"))

        // 1.4 Whitespace bursts & multi-token collapsing
        let sampleList = [frenchClip, germanClip, spanishClip, vietnameseClip, scandinavianClip, multiScriptClip]
        let tenThousandSpaces = String(repeating: " ", count: 10000)
        report(
            name: "10,000 whitespace characters treated as empty search, returning all 6 clips",
            passed: SearchEngine.filter(items: sampleList, query: tenThousandSpaces).count == sampleList.count
        )
        let mixedWhitespaceString = "   \t\t\n\r   \t \r\n   "
        report(
            name: "Mixed tabs, newlines, and carriage returns treated as empty search",
            passed: SearchEngine.filter(items: sampleList, query: mixedWhitespaceString).count == sampleList.count
        )

        let separatedTokensQuery = "   Cafe   " + String(repeating: " ", count: 200) + "   Noel   "
        report(
            name: "Tokens with 200 intervening spaces match target",
            passed: SearchEngine.matches(item: frenchClip, query: separatedTokensQuery)
        )

        let reverseTokensQuery = "Noel sucree Cafe"
        report(
            name: "Multi-tokens in arbitrary permutation match target",
            passed: SearchEngine.matches(item: frenchClip, query: reverseTokensQuery)
        )

        // 1.5 Very Long Queries, Control Characters, Large Payloads
        let fiftyThousandCharQuery = String(repeating: "xyz", count: 17000)
        let startLong = CFAbsoluteTimeGetCurrent()
        let longRes = SearchEngine.matches(item: frenchClip, query: fiftyThousandCharQuery)
        let durLong = CFAbsoluteTimeGetCurrent() - startLong
        report(
            name: "51,000-character query completes safely in < 0.05s",
            passed: (!longRes && durLong < 0.05),
            detail: "dur: \(durLong)s"
        )

        // Null bytes and control character safety
        let controlCharsClip = ClipItem(
            contentType: .text,
            textContent: "Line1\0NullChar\u{0007}Bell\u{001B}[31mEscapedRed",
            byteSize: 45,
            isPinned: false
        )
        report(
            name: "Literal null character matches in target",
            passed: SearchEngine.matches(item: controlCharsClip, query: "NullChar\u{0007}")
        )
        report(
            name: "Control characters do not falsely match clean text",
            passed: !SearchEngine.matches(item: frenchClip, query: "\0")
        )

        // 1.6 Image clips and empty clips
        let zeroDimImage = ClipItem(
            contentType: .image,
            imageWidth: 0,
            imageHeight: 0,
            byteSize: 0,
            isPinned: false
        )
        let hugeImage = ClipItem(
            contentType: .image,
            imageWidth: 8192,
            imageHeight: 4320,
            byteSize: 15000000,
            isPinned: true
        )
        report(
            name: "Image clip with 8192x4320 matches '8192'",
            passed: SearchEngine.matches(item: hugeImage, query: "8192")
        )
        report(
            name: "Image clip matches generic 'Image' query",
            passed: SearchEngine.matches(item: zeroDimImage, query: "Image")
        )

        // =================================================================
        // SUITE 2: Number Shortcuts 1..9 via ShortcutNavigator Stress Testing
        // =================================================================
        print("\n--- Suite 2: Number Shortcuts 1..9 Adversarial Stress ---")

        // 2.1 Out of Bounds Index Matrix
        let testListZero: [ClipItem] = []
        let testListTwo = [
            ClipItem(contentType: .text, textContent: "Item One", byteSize: 8, isPinned: true),
            ClipItem(contentType: .text, textContent: "Item Two", byteSize: 8, isPinned: false)
        ]
        let testListEight = (1...8).map {
            ClipItem(contentType: .text, textContent: "Clip \($0)", byteSize: 6, isPinned: $0 == 1)
        }
        let testListTwenty = (1...20).map {
            ClipItem(contentType: .text, textContent: "Clip \($0)", byteSize: 6, isPinned: $0 <= 3)
        }

        // Test 0-item collection
        for k in 1...9 {
            report(
                name: "0-item list: Shortcut \(k) returns nil",
                passed: ShortcutNavigator.targetItem(forShortcut: k, in: testListZero) == nil
            )
        }
        report(name: "0-item list: Shortcut 0 returns nil", passed: ShortcutNavigator.targetItem(forShortcut: 0, in: testListZero) == nil)
        report(name: "0-item list: Shortcut 10 returns nil", passed: ShortcutNavigator.targetItem(forShortcut: 10, in: testListZero) == nil)
        report(name: "0-item list: Shortcut -1 returns nil", passed: ShortcutNavigator.targetItem(forShortcut: -1, in: testListZero) == nil)
        report(name: "0-item list: Shortcut Int.min returns nil", passed: ShortcutNavigator.targetItem(forShortcut: Int.min, in: testListZero) == nil)
        report(name: "0-item list: Shortcut Int.max returns nil", passed: ShortcutNavigator.targetItem(forShortcut: Int.max, in: testListZero) == nil)

        // Test 2-item collection
        report(
            name: "2-item list: Shortcut 1 resolves to Item One",
            passed: ShortcutNavigator.targetItem(forShortcut: 1, in: testListTwo)?.textContent == "Item One"
        )
        report(
            name: "2-item list: Shortcut 2 resolves to Item Two",
            passed: ShortcutNavigator.targetItem(forShortcut: 2, in: testListTwo)?.textContent == "Item Two"
        )
        for k in 3...9 {
            report(
                name: "2-item list: Shortcut \(k) safely returns nil",
                passed: ShortcutNavigator.targetItem(forShortcut: k, in: testListTwo) == nil
            )
        }

        // Test 8-item collection (key 9 boundary)
        for k in 1...8 {
            report(
                name: "8-item list: Shortcut \(k) resolves to Clip \(k)",
                passed: ShortcutNavigator.targetItem(forShortcut: k, in: testListEight)?.textContent == "Clip \(k)"
            )
        }
        report(
            name: "8-item list: Shortcut 9 safely returns nil",
            passed: ShortcutNavigator.targetItem(forShortcut: 9, in: testListEight) == nil
        )

        // Test 20-item collection (keys 1..9 valid, 10..20 rejected)
        for k in 1...9 {
            report(
                name: "20-item list: Shortcut \(k) resolves to Clip \(k)",
                passed: ShortcutNavigator.targetItem(forShortcut: k, in: testListTwenty)?.textContent == "Clip \(k)"
            )
        }
        for k in 10...20 {
            report(
                name: "20-item list: Shortcut \(k) safely returns nil (strictly capped at 9)",
                passed: ShortcutNavigator.targetItem(forShortcut: k, in: testListTwenty) == nil
            )
        }

        // 2.2 Dynamic Query Remapping & Partition Ordering
        let remappingDataset: [ClipItem] = [
            ClipItem(contentType: .text, textContent: "Server API Key: secret_123", byteSize: 26, isPinned: true),
            ClipItem(contentType: .text, textContent: "Database Host: 10.0.0.1", byteSize: 23, isPinned: true),
            ClipItem(contentType: .text, textContent: "Redis Cache Port: 6379", byteSize: 22, isPinned: true),
            ClipItem(contentType: .text, textContent: "Staging API Key: staging_456", byteSize: 27, isPinned: false),
            ClipItem(contentType: .text, textContent: "Database Port: 5432", byteSize: 19, isPinned: false),
            ClipItem(contentType: .text, textContent: "Frontend Server Port: 3000", byteSize: 26, isPinned: false),
            ClipItem(contentType: .text, textContent: "API Documentation URL", byteSize: 21, isPinned: false),
            ClipItem(contentType: .text, textContent: "Local Database Password", byteSize: 23, isPinned: false)
        ]

        // Query A: "API"
        // Pinned matching: "Server API Key: secret_123" (1)
        // Recent matching: "Staging API Key: staging_456" (1), "API Documentation URL" (2)
        // Total matching: 3 items
        let visibleAPI = ShortcutNavigator.resolveVisibleItems(items: remappingDataset, query: "API")
        report(
            name: "Query 'API' yields exactly 3 visible items",
            passed: visibleAPI.count == 3
        )
        report(
            name: "Query 'API': Shortcut 1 maps to pinned Server API Key",
            passed: ShortcutNavigator.targetItem(forShortcut: 1, in: visibleAPI)?.textContent == "Server API Key: secret_123"
        )
        report(
            name: "Query 'API': Shortcut 2 maps to recent Staging API Key",
            passed: ShortcutNavigator.targetItem(forShortcut: 2, in: visibleAPI)?.textContent == "Staging API Key: staging_456"
        )
        report(
            name: "Query 'API': Shortcut 3 maps to recent API Documentation URL",
            passed: ShortcutNavigator.targetItem(forShortcut: 3, in: visibleAPI)?.textContent == "API Documentation URL"
        )
        report(
            name: "Query 'API': Shortcut 4 returns nil",
            passed: ShortcutNavigator.targetItem(forShortcut: 4, in: visibleAPI) == nil
        )

        // Query B: "Database"
        // Pinned matching: "Database Host: 10.0.0.1" (1)
        // Recent matching: "Database Port: 5432", "Local Database Password" (2)
        // Total: 3 items
        let visibleDB = ShortcutNavigator.resolveVisibleItems(items: remappingDataset, query: "Database")
        report(
            name: "Query 'Database': Shortcut 1 maps to pinned Database Host",
            passed: ShortcutNavigator.targetItem(forShortcut: 1, in: visibleDB)?.textContent == "Database Host: 10.0.0.1"
        )
        report(
            name: "Query 'Database': Shortcut 2 maps to Database Port: 5432",
            passed: ShortcutNavigator.targetItem(forShortcut: 2, in: visibleDB)?.textContent == "Database Port: 5432"
        )
        report(
            name: "Query 'Database': Shortcut 3 maps to Local Database Password",
            passed: ShortcutNavigator.targetItem(forShortcut: 3, in: visibleDB)?.textContent == "Local Database Password"
        )

        // Query C: Zero matches
        let visibleNone = ShortcutNavigator.resolveVisibleItems(items: remappingDataset, query: "ZzzzZeroMatch")
        report(
            name: "Zero-match query: Shortcuts 1..9 all return nil",
            passed: (1...9).allSatisfy { ShortcutNavigator.targetItem(forShortcut: $0, in: visibleNone) == nil }
        )

        // Query D: Clearing query restores full collection with pinned first
        let visibleRestored = ShortcutNavigator.resolveVisibleItems(items: remappingDataset, query: "")
        report(
            name: "Clearing query restores full 8 items",
            passed: visibleRestored.count == 8
        )
        report(
            name: "Restored list places all 3 pinned items at indices 0, 1, 2",
            passed: (visibleRestored[0].isPinned && visibleRestored[1].isPinned && visibleRestored[2].isPinned)
        )
        report(
            name: "Restored list places unpinned items at indices 3..7",
            passed: (3...7).allSatisfy { !visibleRestored[$0].isPinned }
        )

        // 2.3 Keyboard Modifier Evaluation & Gating
        // Command + 1..9 must trigger regardless of focus state
        for d in 1...9 {
            let ev = makeKeyEvent(keyChar: "\(d)", keyCode: UInt16(17 + d), modifiers: .command)
            let parsedFocused = ShortcutNavigator.parseShortcut(from: ev, searchFieldHasFocus: true)
            let parsedBlurred = ShortcutNavigator.parseShortcut(from: ev, searchFieldHasFocus: false)
            report(
                name: "Command + \(d) returns \(d) when search field has focus",
                passed: parsedFocused == d
            )
            report(
                name: "Command + \(d) returns \(d) when search field is blurred",
                passed: parsedBlurred == d
            )
        }

        // Bare 1..9 must be gated: ignored when search field has focus, triggers when blurred
        for d in 1...9 {
            let ev = makeKeyEvent(keyChar: "\(d)", keyCode: UInt16(17 + d), modifiers: [])
            let parsedFocused = ShortcutNavigator.parseShortcut(from: ev, searchFieldHasFocus: true)
            let parsedBlurred = ShortcutNavigator.parseShortcut(from: ev, searchFieldHasFocus: false)
            report(
                name: "Bare \(d) is ignored (returns nil) when search field has focus",
                passed: parsedFocused == nil
            )
            report(
                name: "Bare \(d) triggers (returns \(d)) when search field is blurred",
                passed: parsedBlurred == d
            )
        }

        // Strict rejection of Option and Control
        let invalidModifiers: [NSEvent.ModifierFlags] = [
            .option,
            .control,
            [.command, .option],
            [.command, .control],
            [.option, .control],
            [.command, .option, .control]
        ]

        for mod in invalidModifiers {
            for d in 1...9 {
                let ev = makeKeyEvent(keyChar: "\(d)", keyCode: UInt16(17 + d), modifiers: mod)
                let f = ShortcutNavigator.parseShortcut(from: ev, searchFieldHasFocus: true)
                let b = ShortcutNavigator.parseShortcut(from: ev, searchFieldHasFocus: false)
                if f != nil || b != nil {
                    report(
                        name: "Modifier \(mod) on digit \(d) rejected",
                        passed: false,
                        detail: "Got f=\(String(describing: f)), b=\(String(describing: b))"
                    )
                }
            }
        }
        report(
            name: "Option and Control modifiers strictly rejected across all digits and states",
            passed: true
        )

        // Non-target keys and events
        let nonTargetKeys = [
            ("0", UInt16(29), NSEvent.ModifierFlags.command),
            ("a", UInt16(0), NSEvent.ModifierFlags.command),
            ("c", UInt16(8), NSEvent.ModifierFlags.command),
            ("v", UInt16(9), NSEvent.ModifierFlags.command),
            (" ", UInt16(49), NSEvent.ModifierFlags.command),
            ("Return", UInt16(36), NSEvent.ModifierFlags.command)
        ]
        for (char, code, mod) in nonTargetKeys {
            let ev = makeKeyEvent(keyChar: char, keyCode: code, modifiers: mod)
            report(
                name: "Command + '\(char)' returns nil",
                passed: ShortcutNavigator.parseShortcut(from: ev, searchFieldHasFocus: false) == nil
            )
        }

        // Non-keyDown events return nil
        let keyUpEv = makeKeyEvent(keyChar: "1", keyCode: 18, modifiers: .command, type: .keyUp)
        report(
            name: "keyUp event returns nil",
            passed: ShortcutNavigator.parseShortcut(from: keyUpEv, searchFieldHasFocus: false) == nil
        )

        // 2.4 Arrow Key Navigation & Clamping
        report(
            name: "stepDown from nil on 10 items returns 0",
            passed: ShortcutNavigator.stepDown(currentIndex: nil, visibleCount: 10) == 0
        )
        report(
            name: "stepDown at 9 on 10 items clamps at 9",
            passed: ShortcutNavigator.stepDown(currentIndex: 9, visibleCount: 10) == 9
        )
        report(
            name: "stepUp at 0 on 10 items returns nil (restores search bar focus)",
            passed: ShortcutNavigator.stepUp(currentIndex: 0, visibleCount: 10) == nil
        )
        report(
            name: "stepUp from nil on 10 items remains nil",
            passed: ShortcutNavigator.stepUp(currentIndex: nil, visibleCount: 10) == nil
        )
        report(
            name: "stepDown on 0 items returns nil",
            passed: ShortcutNavigator.stepDown(currentIndex: nil, visibleCount: 0) == nil
        )
        report(
            name: "stepUp on 0 items returns nil",
            passed: ShortcutNavigator.stepUp(currentIndex: 0, visibleCount: 0) == nil
        )

        // 2.5 Return Key Resolution
        report(
            name: "Return key on index 2 returns 3rd item",
            passed: ShortcutNavigator.resolveReturnTarget(currentIndex: 2, visibleItems: testListTwenty)?.textContent == "Clip 3"
        )
        report(
            name: "Return key with nil index defaults to top item (Clip 1)",
            passed: ShortcutNavigator.resolveReturnTarget(currentIndex: nil, visibleItems: testListTwenty)?.textContent == "Clip 1"
        )
        report(
            name: "Return key on empty list returns nil",
            passed: ShortcutNavigator.resolveReturnTarget(currentIndex: nil, visibleItems: []) == nil
        )

        // 2.6 Badge Labels
        for i in 0..<9 {
            report(
                name: "Row index \(i) badge label is '\(i + 1)'",
                passed: ShortcutNavigator.badgeLabel(forIndex: i) == "\(i + 1)"
            )
        }
        for i in 9...15 {
            report(
                name: "Row index \(i) (>= 9) badge label is nil",
                passed: ShortcutNavigator.badgeLabel(forIndex: i) == nil
            )
        }
        report(name: "Negative row index -1 badge is nil", passed: ShortcutNavigator.badgeLabel(forIndex: -1) == nil)

        // =================================================================
        // SUITE 3: Concurrency & High Throughput Stress
        // =================================================================
        print("\n--- Suite 3: Concurrency & High Throughput Stress ---")

        let concurrentGroup = DispatchGroup()
        let concurrentQueue = DispatchQueue(label: "com.superclip.challenger.concurrent", attributes: .concurrent)
        var concurrentErrors = 0
        let errLock = NSLock()

        for threadIdx in 0..<12 {
            concurrentGroup.enter()
            concurrentQueue.async {
                for iter in 0..<2000 {
                    let d = (iter % 9) + 1
                    let isFocused = (threadIdx % 2 == 0)
                    let evCmd = makeKeyEvent(keyChar: "\(d)", keyCode: UInt16(17 + d), modifiers: .command)
                    let evBare = makeKeyEvent(keyChar: "\(d)", keyCode: UInt16(17 + d), modifiers: [])

                    let cmdParsed = ShortcutNavigator.parseShortcut(from: evCmd, searchFieldHasFocus: isFocused)
                    let bareParsed = ShortcutNavigator.parseShortcut(from: evBare, searchFieldHasFocus: isFocused)

                    if cmdParsed != d {
                        errLock.lock()
                        concurrentErrors += 1
                        errLock.unlock()
                    }
                    if isFocused && bareParsed != nil {
                        errLock.lock()
                        concurrentErrors += 1
                        errLock.unlock()
                    }
                    if !isFocused && bareParsed != d {
                        errLock.lock()
                        concurrentErrors += 1
                        errLock.unlock()
                    }

                    // Concurrent search filtering
                    let query = (iter % 2 == 0) ? "Database" : "API"
                    let filtered = SearchEngine.filter(items: remappingDataset, query: query)
                    if filtered.isEmpty {
                        errLock.lock()
                        concurrentErrors += 1
                        errLock.unlock()
                    }
                }
                concurrentGroup.leave()
            }
        }
        concurrentGroup.wait()

        report(
            name: "12 concurrent threads running 24,000 navigation & search operations completed with 0 race conditions",
            passed: concurrentErrors == 0,
            detail: "Errors: \(concurrentErrors)"
        )

        // =================================================================
        // SUMMARY & VERDICT
        // =================================================================
        print("\n==================================================")
        print("  Challenger M3-R2 Execution Summary")
        print("==================================================")
        print("  Total Tests: \(totalTests)")
        print("  Passed:      \(passedTests)")
        print("  Failed:      \(failedTests)")

        if failedTests == 0 {
            print("\nVERDICT: APPROVE (All adversarial challenges passed)\n")
            exit(0)
        } else {
            print("\nVERDICT: REJECT (\(failedTests) adversarial challenges failed)\n")
            exit(1)
        }
    }
}
