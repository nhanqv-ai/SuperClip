import Foundation
import CoreGraphics
import AppKit
import SwiftUI
import SuperClipCore
import SuperClip

@main
public struct M3AdversarialChallengeRunner {
    public static func main() {
        print("==================================================")
        print("  SuperClip M3 Search & Partitioning Challenger   ")
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

        // ==========================================
        // 1. SearchEngine Boundary & Diacritics
        // ==========================================
        print("\n--- Suite 1: SearchEngine Boundary & Diacritics ---")

        // 1.1 Empty & Whitespace Variations
        let sampleClip = ClipItem(
            contentType: .text,
            textContent: "The quick brown fox jumps over the lazy dog",
            byteSize: 43
        )

        report(
            name: "SearchEngine matches empty string query as true",
            passed: SearchEngine.matches(item: sampleClip, query: "")
        )
        report(
            name: "SearchEngine matches space-only query as true",
            passed: SearchEngine.matches(item: sampleClip, query: "   ")
        )
        report(
            name: "SearchEngine matches tab and newline query as true",
            passed: SearchEngine.matches(item: sampleClip, query: "\t\n\r  \n")
        )
        report(
            name: "SearchEngine filter with empty query returns identical array",
            passed: SearchEngine.filter(items: [sampleClip], query: "").count == 1
        )
        report(
            name: "SearchEngine filter with whitespace query returns identical array",
            passed: SearchEngine.filter(items: [sampleClip], query: "   \t  ").count == 1
        )

        // 1.2 Diacritics & Multilingual Folding
        let frenchClip = ClipItem(contentType: .text, textContent: "Déjà vu à l'hôtel de la Renaissance", byteSize: 40)
        report(
            name: "SearchEngine matches French accents without diacritics (hotel -> hôtel)",
            passed: SearchEngine.matches(item: frenchClip, query: "hotel")
        )
        report(
            name: "SearchEngine matches French accents without diacritics (deja -> Déjà)",
            passed: SearchEngine.matches(item: frenchClip, query: "deja")
        )

        let spanishClip = ClipItem(contentType: .text, textContent: "El niño comió piña en otoño", byteSize: 32)
        report(
            name: "SearchEngine matches Spanish n with tilde (nino -> niño)",
            passed: SearchEngine.matches(item: spanishClip, query: "nino")
        )
        report(
            name: "SearchEngine matches Spanish accents (comio -> comió)",
            passed: SearchEngine.matches(item: spanishClip, query: "comio")
        )

        let germanClip = ClipItem(contentType: .text, textContent: "Über den Wolken und schöne Grüsse", byteSize: 36)
        report(
            name: "SearchEngine matches German umlaut (uber -> Über)",
            passed: SearchEngine.matches(item: germanClip, query: "uber")
        )
        report(
            name: "SearchEngine matches German umlaut (schone -> schöne)",
            passed: SearchEngine.matches(item: germanClip, query: "schone")
        )

        let vietnameseClip = ClipItem(contentType: .text, textContent: "Tiếng Việt có dấu phức tạp và phong phú", byteSize: 45)
        report(
            name: "SearchEngine matches Vietnamese exact query with diacritics",
            passed: SearchEngine.matches(item: vietnameseClip, query: "Tiếng Việt")
        )
        report(
            name: "SearchEngine matches Vietnamese base letters without diacritics (Tieng Viet -> Tiếng Việt)",
            passed: SearchEngine.matches(item: vietnameseClip, query: "Tieng Viet")
        )

        let nordicClip = ClipItem(contentType: .text, textContent: "Smörgåsbord og blåbærsyltetøy i København", byteSize: 46)
        report(
            name: "SearchEngine matches Nordic characters (smorgasbord -> Smörgåsbord)",
            passed: SearchEngine.matches(item: nordicClip, query: "smorgasbord")
        )

        // Unicode Normalization (NFC vs NFD)
        let nfcClip = ClipItem(contentType: .text, textContent: "caf\u{00E9}", byteSize: 5) // precomposed é
        let nfdQuery = "cafe\u{0301}" // decomposed e + combining acute
        report(
            name: "SearchEngine matches NFC clip with NFD query",
            passed: SearchEngine.matches(item: nfcClip, query: nfdQuery)
        )
        let nfdClip = ClipItem(contentType: .text, textContent: "cafe\u{0301}", byteSize: 6)
        let nfcQuery = "caf\u{00E9}"
        report(
            name: "SearchEngine matches NFD clip with NFC query",
            passed: SearchEngine.matches(item: nfdClip, query: nfcQuery)
        )

        // 1.3 Special Regex Characters & ReDoS Resilience
        let codeClip = ClipItem(
            contentType: .text,
            textContent: "let pattern = /^[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,4}$/i; // regex.*+$^?{}()|[]\\\\",
            byteSize: 86
        )
        let regexQueries = [
            ".*", "[a-z]", "\\d+", "(foo|bar)", "^[a-z0-9", ".*+$^?{}()|[]\\\\",
            "\\", "\\\\", "???", "+++", "$$$", "(((", ")))", "{{{", "}}}", "(a+)+$"
        ]
        var allRegexPass = true
        var regexFailures: [String] = []
        for rq in regexQueries {
            let matches = SearchEngine.matches(item: codeClip, query: rq)
            // Queries that exist verbatim in codeClip must match
            if !matches && (rq == ".*" || rq == "\\" || rq == "\\\\" || rq == ".*+$^?{}()|[]\\\\") {
                allRegexPass = false
                regexFailures.append("query '\(rq)' did not match")
            }
        }
        report(
            name: "SearchEngine safely processes regex metacharacters without crashes or ReDoS",
            passed: allRegexPass,
            detail: regexFailures.joined(separator: ", ")
        )

        // Negative check: Plain text does not match regex metacharacter queries
        let plain = ClipItem(contentType: .text, textContent: "Ordinary English sentence with no symbols", byteSize: 41)
        report(
            name: "SearchEngine does not falsely match plain sentence against '.*'",
            passed: !SearchEngine.matches(item: plain, query: ".*")
        )
        report(
            name: "SearchEngine does not falsely match plain sentence against '[a-z]'",
            passed: !SearchEngine.matches(item: plain, query: "[a-z]")
        )

        // 1.4 Multi-token search behavior
        let multiTokenClip = ClipItem(
            contentType: .text,
            textContent: "SuperClip is an ultra-lightweight macOS clipboard manager written in Swift and SwiftUI",
            byteSize: 87
        )
        report(
            name: "SearchEngine matches multiple tokens in natural order",
            passed: SearchEngine.matches(item: multiTokenClip, query: "swift macos clipboard")
        )
        report(
            name: "SearchEngine matches multiple tokens in reversed order",
            passed: SearchEngine.matches(item: multiTokenClip, query: "SwiftUI ultra-lightweight SuperClip")
        )
        report(
            name: "SearchEngine matches multiple tokens with excessive whitespace",
            passed: SearchEngine.matches(item: multiTokenClip, query: "  swift    macos     swiftui  ")
        )
        report(
            name: "SearchEngine rejects multi-token query when one token is missing",
            passed: !SearchEngine.matches(item: multiTokenClip, query: "swift macos windows")
        )

        // 1.5 Extreme string sizes
        let largeContent = String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 2500) // ~112KB
        let largeClip = ClipItem(contentType: .text, textContent: largeContent, byteSize: largeContent.utf8.count)
        let largeQuery = String(repeating: "a", count: 1000)
        let startLarge = CFAbsoluteTimeGetCurrent()
        let largeMatch = SearchEngine.matches(item: largeClip, query: largeQuery)
        let largeDuration = CFAbsoluteTimeGetCurrent() - startLarge
        report(
            name: "SearchEngine handles 100KB clip against 1000-char query in under 50ms without crashing",
            passed: (!largeMatch && largeDuration < 0.05),
            detail: "Duration: \(largeDuration)s"
        )

        // ==========================================
        // 2. Partitioning Across Extreme Item Counts
        // ==========================================
        print("\n--- Suite 2: Partitioning Across Extreme Item Counts ---")

        // 2.1 0 items
        let emptyPartition = SearchEngine.partition(items: [], query: "")
        report(
            name: "Partitioning 0 items with empty query yields empty pinned and recent lists",
            passed: (emptyPartition.pinned.isEmpty && emptyPartition.recent.isEmpty)
        )
        let emptyPartitionFiltered = SearchEngine.partition(items: [], query: "search")
        report(
            name: "Partitioning 0 items with query yields empty pinned and recent lists",
            passed: (emptyPartitionFiltered.pinned.isEmpty && emptyPartitionFiltered.recent.isEmpty)
        )

        // 2.2 1 item (pinned)
        let singlePinned = ClipItem(contentType: .text, textContent: "Single Pinned Clip", byteSize: 18, isPinned: true)
        let p1 = SearchEngine.partition(items: [singlePinned], query: "")
        report(
            name: "Partitioning 1 pinned item yields 1 pinned, 0 recent",
            passed: (p1.pinned.count == 1 && p1.recent.isEmpty)
        )
        let p1Match = SearchEngine.partition(items: [singlePinned], query: "Single")
        report(
            name: "Partitioning 1 pinned item matching query preserves pinned",
            passed: (p1Match.pinned.count == 1 && p1Match.recent.isEmpty)
        )
        let p1Miss = SearchEngine.partition(items: [singlePinned], query: "NonExistent")
        report(
            name: "Partitioning 1 pinned item missing query yields 0 pinned, 0 recent",
            passed: (p1Miss.pinned.isEmpty && p1Miss.recent.isEmpty)
        )

        // 2.3 1 item (unpinned)
        let singleUnpinned = ClipItem(contentType: .text, textContent: "Single Unpinned Clip", byteSize: 20, isPinned: false)
        let u1 = SearchEngine.partition(items: [singleUnpinned], query: "")
        report(
            name: "Partitioning 1 unpinned item yields 0 pinned, 1 recent",
            passed: (u1.pinned.isEmpty && u1.recent.count == 1)
        )

        // 2.4 100 items (all pinned)
        var allPinned100: [ClipItem] = []
        for i in 1...100 {
            allPinned100.append(ClipItem(
                contentType: .text,
                textContent: "Pinned Item #\(i)",
                byteSize: 15,
                isPinned: true
            ))
        }
        let partAllPinned = SearchEngine.partition(items: allPinned100, query: "")
        report(
            name: "Partitioning 100 all-pinned items yields 100 pinned and 0 recent",
            passed: (partAllPinned.pinned.count == 100 && partAllPinned.recent.isEmpty)
        )

        // 2.5 100 items (none pinned)
        var allUnpinned100: [ClipItem] = []
        for i in 1...100 {
            allUnpinned100.append(ClipItem(
                contentType: .text,
                textContent: "Recent History Item #\(i)",
                byteSize: 25,
                isPinned: false
            ))
        }
        let partAllUnpinned = SearchEngine.partition(items: allUnpinned100, query: "")
        report(
            name: "Partitioning 100 unpinned items yields 0 pinned and 100 recent",
            passed: (partAllUnpinned.pinned.isEmpty && partAllUnpinned.recent.count == 100)
        )

        // 2.6 Mixed combinations: 5 pinned + 95 unpinned
        let mixed100 = Array(allPinned100.prefix(5)) + Array(allUnpinned100.prefix(95))
        let partMixed = SearchEngine.partition(items: mixed100, query: "")
        report(
            name: "Partitioning 5 pinned + 95 unpinned items yields exactly 5 pinned and 95 recent",
            passed: (partMixed.pinned.count == 5 && partMixed.recent.count == 95)
        )

        // ==========================================
        // 3. ClipShortcutMapper & ShortcutNavigator
        // ==========================================
        print("\n--- Suite 3: ClipShortcutMapper & ShortcutNavigator ---")

        // 3.1 ClipShortcutMapper across 100 all-pinned items
        var badgesAllPinned: [Int?] = []
        for i in 0..<100 {
            let badge = ClipShortcutMapper.shortcutIndex(
                isPinned: true,
                indexInSection: i,
                pinnedCount: 100
            )
            badgesAllPinned.append(badge)
        }
        let first9AllPinned = badgesAllPinned.prefix(9).compactMap { $0 }
        let remaining91AllPinned = badgesAllPinned.suffix(91).compactMap { $0 }
        report(
            name: "ClipShortcutMapper assigns 1..9 to first 9 items in 100 pinned collection",
            passed: (first9AllPinned == Array(1...9))
        )
        report(
            name: "ClipShortcutMapper assigns nil to items 10..100 in 100 pinned collection",
            passed: remaining91AllPinned.isEmpty
        )

        // 3.2 ClipShortcutMapper across mixed 5 pinned + 95 unpinned
        var mixedBadges: [Int?] = []
        // First 5 pinned
        for i in 0..<5 {
            mixedBadges.append(ClipShortcutMapper.shortcutIndex(
                isPinned: true,
                indexInSection: i,
                pinnedCount: 5
            ))
        }
        // Then 95 unpinned
        for i in 0..<95 {
            mixedBadges.append(ClipShortcutMapper.shortcutIndex(
                isPinned: false,
                indexInSection: i,
                pinnedCount: 5
            ))
        }
        let expected1to9 = Array(1...9)
        let actual1to9 = mixedBadges.prefix(9).compactMap { $0 }
        let remainingMixed = mixedBadges.suffix(91).compactMap { $0 }
        report(
            name: "ClipShortcutMapper correctly chains shortcuts across 5 pinned (1..5) and recent (6..9)",
            passed: (actual1to9 == expected1to9)
        )
        report(
            name: "ClipShortcutMapper assigns nil to items 10..100 in mixed partition",
            passed: remainingMixed.isEmpty
        )

        // 3.3 Reverse lookup itemIndexForShortcut
        let reverseKey1 = ClipShortcutMapper.itemIndexForShortcut(1, pinnedCount: 5, recentCount: 95)
        let reverseKey5 = ClipShortcutMapper.itemIndexForShortcut(5, pinnedCount: 5, recentCount: 95)
        let reverseKey6 = ClipShortcutMapper.itemIndexForShortcut(6, pinnedCount: 5, recentCount: 95)
        let reverseKey9 = ClipShortcutMapper.itemIndexForShortcut(9, pinnedCount: 5, recentCount: 95)
        let reverseKey10 = ClipShortcutMapper.itemIndexForShortcut(10, pinnedCount: 5, recentCount: 95)
        let reverseKey0 = ClipShortcutMapper.itemIndexForShortcut(0, pinnedCount: 5, recentCount: 95)
        report(
            name: "Reverse shortcut 1 maps to pinned item index 0",
            passed: (reverseKey1?.isPinned == true && reverseKey1?.indexInSection == 0)
        )
        report(
            name: "Reverse shortcut 5 maps to pinned item index 4",
            passed: (reverseKey5?.isPinned == true && reverseKey5?.indexInSection == 4)
        )
        report(
            name: "Reverse shortcut 6 maps to recent item index 0",
            passed: (reverseKey6?.isPinned == false && reverseKey6?.indexInSection == 0)
        )
        report(
            name: "Reverse shortcut 9 maps to recent item index 3",
            passed: (reverseKey9?.isPinned == false && reverseKey9?.indexInSection == 3)
        )
        report(
            name: "Reverse shortcut out of range (0, 10) returns nil",
            passed: (reverseKey0 == nil && reverseKey10 == nil)
        )

        // 3.4 ShortcutNavigator targetItem resolution
        let visible100 = ShortcutNavigator.resolveVisibleItems(items: mixed100, query: "")
        report(
            name: "ShortcutNavigator resolves unified visible items count as 100",
            passed: visible100.count == 100
        )
        let nav1 = ShortcutNavigator.targetItem(forShortcut: 1, in: visible100)
        let nav9 = ShortcutNavigator.targetItem(forShortcut: 9, in: visible100)
        let nav10 = ShortcutNavigator.targetItem(forShortcut: 10, in: visible100)
        let nav0 = ShortcutNavigator.targetItem(forShortcut: 0, in: visible100)
        report(
            name: "ShortcutNavigator targetItem 1 maps to first visible item",
            passed: nav1?.id == visible100[0].id
        )
        report(
            name: "ShortcutNavigator targetItem 9 maps to 9th visible item",
            passed: nav9?.id == visible100[8].id
        )
        report(
            name: "ShortcutNavigator targetItem out of range returns nil",
            passed: (nav10 == nil && nav0 == nil)
        )

        // 3.5 Arrow key stepping boundaries
        report(
            name: "stepDown on empty list returns nil",
            passed: ShortcutNavigator.stepDown(currentIndex: nil, visibleCount: 0) == nil
        )
        report(
            name: "stepUp on empty list returns nil",
            passed: ShortcutNavigator.stepUp(currentIndex: nil, visibleCount: 0) == nil
        )
        report(
            name: "stepDown clamps strictly at visibleCount - 1 (index 99)",
            passed: ShortcutNavigator.stepDown(currentIndex: 99, visibleCount: 100) == 99
        )
        report(
            name: "stepUp from index 0 returns nil to restore search focus",
            passed: ShortcutNavigator.stepUp(currentIndex: 0, visibleCount: 100) == nil
        )

        // ==========================================
        // 4. Clear History Boundary Stress (100 Pinned Survival)
        // ==========================================
        print("\n--- Suite 4: Clear History Boundary Stress ---")

        let sandboxDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SuperClip_M3_Adversarial_\(UUID().uuidString)", isDirectory: true)

        let storage = StorageManager(baseDirectory: sandboxDir, initialCapacity: 200)

        // Insert 100 pinned clips
        var pinnedUUIDs: [UUID] = []
        for i in 1...100 {
            let item = ClipItem(
                contentType: .text,
                textContent: "Permanent Pinned Secret Code #\(i) [KEY-\(UUID().uuidString)]",
                byteSize: 60,
                isPinned: true
            )
            pinnedUUIDs.append(item.id)
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }

        // Insert 100 unpinned clips
        for i in 1...100 {
            let item = ClipItem(
                contentType: .text,
                textContent: "Ephemeral Recent History Entry #\(i)",
                byteSize: 35,
                isPinned: false
            )
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }

        storage.flushDiskQueue()

        report(
            name: "StorageManager holds 200 items before clearing history",
            passed: storage.items.count == 200
        )
        report(
            name: "StorageManager holds exactly 100 pinned items before clearing history",
            passed: storage.pinnedItems.count == 100
        )
        report(
            name: "StorageManager holds exactly 100 unpinned items before clearing history",
            passed: storage.historyItems.count == 100
        )

        // TRIGGER CLEAR HISTORY
        storage.clearUnpinnedHistory()
        storage.flushDiskQueue()

        let remainingItems = storage.items
        report(
            name: "StorageManager in-memory items count is exactly 100 after clearUnpinnedHistory",
            passed: remainingItems.count == 100
        )
        report(
            name: "StorageManager historyItems is exactly 0 after clearUnpinnedHistory",
            passed: storage.historyItems.isEmpty
        )

        let allRemainingArePinned = remainingItems.allSatisfy { $0.isPinned }
        report(
            name: "Every single surviving item in StorageManager has isPinned == true",
            passed: allRemainingArePinned
        )

        let survivingUUIDSet = Set(remainingItems.map { $0.id })
        let originalPinnedSet = Set(pinnedUUIDs)
        let allPinnedSurvived = (survivingUUIDSet == originalPinnedSet)
        report(
            name: "All 100 original pinned UUIDs survived complete history purge intact",
            passed: allPinnedSurvived
        )

        // DISK PERSISTENCE VERIFICATION: Reload fresh StorageManager from disk
        let reloadedStorage = StorageManager(baseDirectory: sandboxDir, initialCapacity: 200)
        let reloadedItems = reloadedStorage.items
        report(
            name: "Reloaded StorageManager from metadata.json contains exactly 100 items",
            passed: reloadedItems.count == 100
        )
        let reloadedUUIDSet = Set(reloadedItems.map { $0.id })
        report(
            name: "Reloaded disk metadata matches exactly the 100 pinned items",
            passed: (reloadedUUIDSet == originalPinnedSet)
        )
        report(
            name: "All reloaded items on disk have isPinned == true",
            passed: reloadedItems.allSatisfy { $0.isPinned }
        )

        // Subsequent unpinned insertions + secondary clear
        for i in 1...25 {
            let item = ClipItem(
                contentType: .text,
                textContent: "Second wave ephemeral clip #\(i)",
                byteSize: 30,
                isPinned: false
            )
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }
        report(
            name: "StorageManager count increased to 125 after 2nd wave insertions",
            passed: storage.items.count == 125
        )
        storage.clearUnpinnedHistory()
        storage.flushDiskQueue()
        report(
            name: "100 pinned items survive a second clearUnpinnedHistory cycle",
            passed: (storage.items.count == 100 && Set(storage.items.map { $0.id }) == originalPinnedSet)
        )

        // Clean up sandbox
        try? FileManager.default.removeItem(at: sandboxDir)

        // ==========================================
        // 5. Image Clip Partitioning & Search
        // ==========================================
        print("\n--- Suite 5: Image Clip Partitioning & Search ---")

        let imageClipPinned = ClipItem(
            contentType: .image,
            textContent: nil,
            imageFileName: "img1.png",
            thumbnailFileName: "th1.png",
            imageWidth: 800,
            imageHeight: 600,
            byteSize: 2048,
            isPinned: true
        )
        let imageClipRecent = ClipItem(
            contentType: .image,
            textContent: nil,
            imageFileName: "img2.png",
            thumbnailFileName: "th2.png",
            imageWidth: 1920,
            imageHeight: 1080,
            byteSize: 4096,
            isPinned: false
        )

        report(
            name: "SearchEngine matches image clip by display title dimension (800x600)",
            passed: SearchEngine.matches(item: imageClipPinned, query: "800x600")
        )
        report(
            name: "SearchEngine matches image clip by display title dimension (1920x1080)",
            passed: SearchEngine.matches(item: imageClipRecent, query: "1920x1080")
        )
        report(
            name: "SearchEngine matches image clip by 'Image' token",
            passed: SearchEngine.matches(item: imageClipPinned, query: "Image")
        )

        let imagePartition = SearchEngine.partition(items: [imageClipPinned, imageClipRecent], query: "")
        report(
            name: "Image clips partition cleanly into pinned and recent",
            passed: (imagePartition.pinned.count == 1 && imagePartition.recent.count == 1)
        )

        // ==========================================
        // Summary Verdict
        // ==========================================
        print("\n==================================================")
        print("  M3 Adversarial Challenge Summary                ")
        print("==================================================")
        print("  Total Challenges: \(totalTests)")
        print("  Passed:           \(passedTests)")
        print("  Failed:           \(failedTests)")

        if failedTests > 0 {
            print("\nVERDICT: REJECT (Found \(failedTests) critical/high defects in search & partitioning)")
            exit(1)
        } else {
            print("\nVERDICT: APPROVE (All M3 adversarial challenges passed)")
            exit(0)
        }
    }
}
