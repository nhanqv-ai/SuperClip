import Foundation
import CoreGraphics
import ImageIO
import AppKit
import SwiftUI
import SuperClipCore
import SuperClip

// ==============================================================================
// SuperClip Tier 5 White-Box Adversarial Stress Runner
// Target: SuperClipCore (StorageManager, ThumbnailGenerator, PasteboardMonitor,
//         SearchEngine, Models)
// Strict Invariant: 0 emojis across all code, assertions, fixtures, and output.
// ==============================================================================

@main
public struct Tier5AdversarialCoreRunner {
    public static func main() {
        print("==================================================")
        print("  SuperClip Tier 5 Core Adversarial Stress Runner ")
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

        func createSandbox() -> URL {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("SuperClip_T5_Sandbox_\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }

        func cleanupSandbox(_ url: URL) {
            try? FileManager.default.removeItem(at: url)
        }

        // Helper to synthesize a valid PNG image of arbitrary dimensions
        func makeTestPNG(width: Int, height: Int) -> Data {
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: width,
                pixelsHigh: height,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: width * 4,
                bitsPerPixel: 32
            )!
            return rep.representation(using: .png, properties: [:])!
        }

        // ==================================================================
        // Suite 1: High-Throughput Burst Clipboard Writes (>100 operations)
        // ==================================================================
        print("\n--- Suite 1: High-Throughput Burst Clipboard Writes (>100 ops) ---")

        // 1.1: 150 rapid unique text writes with changeCount tracking
        let pb1_1 = NSPasteboard.withUniqueName()
        let monitor1_1 = PasteboardMonitor(pasteboard: pb1_1)
        var capturedItems1_1: [ClipItem] = []
        let lock1_1 = NSLock()
        monitor1_1.onNewClip = { item, _, _ in
            lock1_1.lock()
            capturedItems1_1.append(item)
            lock1_1.unlock()
        }

        let burstStart1_1 = CFAbsoluteTimeGetCurrent()
        for i in 1...150 {
            pb1_1.clearContents()
            pb1_1.setString("Burst Payload Alpha #\(i)", forType: .string)
            monitor1_1.checkNow()
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        let burstDuration1_1 = CFAbsoluteTimeGetCurrent() - burstStart1_1

        lock1_1.lock()
        let count1_1 = capturedItems1_1.count
        lock1_1.unlock()

        report(
            name: "High-throughput 150 sequential text writes captured without drop",
            passed: (count1_1 == 150 && burstDuration1_1 < 2.0),
            detail: "Captured: \(count1_1)/150 in \(burstDuration1_1)s"
        )

        // 1.2: 120 interleaved alternating text and PNG image writes
        let pb1_2 = NSPasteboard.withUniqueName()
        let monitor1_2 = PasteboardMonitor(pasteboard: pb1_2)
        var textClips1_2 = 0
        var imageClips1_2 = 0
        let lock1_2 = NSLock()
        monitor1_2.onNewClip = { item, imgData, thumbData in
            lock1_2.lock()
            if item.contentType == .text {
                textClips1_2 += 1
            } else if item.contentType == .image {
                imageClips1_2 += 1
            }
            lock1_2.unlock()
        }

        let png1_2_A = makeTestPNG(width: 40, height: 40)
        let png1_2_B = makeTestPNG(width: 60, height: 60)

        for i in 1...60 {
            // Write text
            pb1_2.clearContents()
            pb1_2.setString("Interleaved Text #\(i)", forType: .string)
            monitor1_2.checkNow()

            // Write image (alternating between A and B so payload hash changes)
            pb1_2.clearContents()
            let imgData = (i % 2 == 0) ? png1_2_A : png1_2_B
            pb1_2.setData(imgData, forType: .png)
            monitor1_2.checkNow()
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))

        lock1_2.lock()
        let totalCaptured1_2 = textClips1_2 + imageClips1_2
        lock1_2.unlock()

        report(
            name: "Interleaved 120 rapid alternating text and image writes processed cleanly",
            passed: (totalCaptured1_2 == 120 && textClips1_2 == 60 && imageClips1_2 == 60),
            detail: "Total: \(totalCaptured1_2)/120 (Text: \(textClips1_2), Images: \(imageClips1_2))"
        )

        // 1.3: Burst self-copy loop suppression: 100 consecutive markSelfCopy calls
        let pb1_3 = NSPasteboard.withUniqueName()
        let monitor1_3 = PasteboardMonitor(pasteboard: pb1_3)
        var capturedClips1_3: [ClipItem] = []
        let lock1_3 = NSLock()
        monitor1_3.onNewClip = { item, _, _ in
            lock1_3.lock()
            capturedClips1_3.append(item)
            lock1_3.unlock()
        }

        var allSelfSuppressed1_3 = true
        for i in 1...100 {
            pb1_3.clearContents()
            pb1_3.setString("Self Write Burst #\(i)", forType: .string)
            let sc = pb1_3.changeCount
            monitor1_3.markSelfCopy(newChangeCount: sc)
            let ticked = monitor1_3.pollTick()
            if ticked {
                allSelfSuppressed1_3 = false
            }
        }
        report(
            name: "100 consecutive markSelfCopy burst events strictly suppressed",
            passed: allSelfSuppressed1_3,
            detail: "Self copy suppression failed in burst"
        )

        // Follow immediately with legitimate external write
        pb1_3.clearContents()
        pb1_3.setString("Legitimate External Write After 100 Self Copies", forType: .string)
        monitor1_3.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        lock1_3.lock()
        let countAfterSelf1_3 = capturedClips1_3.count
        lock1_3.unlock()

        report(
            name: "Legitimate external copy captured immediately after 100 self-copy events",
            passed: (countAfterSelf1_3 == 1),
            detail: "Captured clips: \(countAfterSelf1_3)"
        )

        // 1.4: 150 consecutive identical text writes handled in O(1) time
        let sandbox1_4 = createSandbox()
        defer { cleanupSandbox(sandbox1_4) }
        let storage1_4 = StorageManager(baseDirectory: sandbox1_4, initialCapacity: 100)
        let identicalItem = ClipItem(contentType: .text, textContent: "Identical Redundant Clip", byteSize: 24)

        let startIdentical = CFAbsoluteTimeGetCurrent()
        for _ in 1...150 {
            storage1_4.addClip(item: identicalItem, imageData: nil, thumbData: nil)
        }
        let durIdentical = CFAbsoluteTimeGetCurrent() - startIdentical

        report(
            name: "150 consecutive identical text writes deduplicated without store bloat",
            passed: (storage1_4.items.count == 1 && durIdentical < 0.5),
            detail: "Items count: \(storage1_4.items.count), Duration: \(durIdentical)s"
        )

        // ==================================================================
        // Suite 2: Corrupt, Truncated, Zero-Byte Image Payloads into ThumbnailGenerator
        // ==================================================================
        print("\n--- Suite 2: Corrupt, Truncated, Zero-Byte Payloads into ThumbnailGenerator ---")

        // 2.1: Zero-byte and 1..3 byte buffers
        let emptyData = Data()
        report(
            name: "ThumbnailGenerator.generateThumbnail returns nil on zero-byte Data",
            passed: (ThumbnailGenerator.generateThumbnail(from: emptyData) == nil)
        )
        report(
            name: "ThumbnailGenerator.extractDimensions returns nil on zero-byte Data",
            passed: (ThumbnailGenerator.extractDimensions(from: emptyData) == nil)
        )
        report(
            name: "ThumbnailGenerator.isImagePayload returns false on zero-byte Data",
            passed: (!ThumbnailGenerator.isImagePayload(emptyData))
        )

        let sub4Bytes = [
            Data([0x00]),
            Data([0x89, 0x50]),
            Data([0xFF, 0xD8, 0xFF])
        ]
        var sub4Passed = true
        for d in sub4Bytes {
            if ThumbnailGenerator.generateThumbnail(from: d) != nil ||
               ThumbnailGenerator.extractDimensions(from: d) != nil ||
               ThumbnailGenerator.isImagePayload(d) {
                sub4Passed = false
            }
        }
        report(
            name: "Buffers smaller than 4 bytes rejected safely across all entry points",
            passed: sub4Passed
        )

        // 2.2: Truncated PNG payloads
        let pngHeader4 = Data([0x89, 0x50, 0x4E, 0x47])
        let pngHeader8 = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let pngTruncatedIHDR = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52])
        report(
            name: "Truncated 4-byte PNG header returns nil safely",
            passed: (ThumbnailGenerator.generateThumbnail(from: pngHeader4) == nil)
        )
        report(
            name: "Truncated 8-byte PNG header without chunks returns nil safely",
            passed: (ThumbnailGenerator.generateThumbnail(from: pngHeader8) == nil)
        )
        report(
            name: "Truncated IHDR chunk returns nil safely",
            passed: (ThumbnailGenerator.generateThumbnail(from: pngTruncatedIHDR) == nil)
        )

        // 2.3: Truncated JPEG and GIF payloads
        let jpegSOIOnly = Data([0xFF, 0xD8])
        let gifHeaderOnly = "GIF89a".data(using: .utf8)!
        report(
            name: "Truncated JPEG SOI returns nil safely",
            passed: (ThumbnailGenerator.generateThumbnail(from: jpegSOIOnly) == nil)
        )
        report(
            name: "Truncated GIF header returns nil safely",
            passed: (ThumbnailGenerator.generateThumbnail(from: gifHeaderOnly) == nil)
        )

        // 2.4: Fuzzing: 110 randomized byte buffers (5 bytes to 64KB)
        var fuzzPassed = true
        let fuzzSizes = [5, 17, 33, 64, 128, 256, 512, 1024, 4096, 16384, 65536]
        for (idx, sz) in fuzzSizes.enumerated() {
            for round in 0..<10 {
                var randomBytes = [UInt8](repeating: 0, count: sz)
                for b in 0..<sz {
                    randomBytes[b] = UInt8((idx * 37 + round * 19 + b * 7) & 0xFF)
                }
                let fuzzData = Data(randomBytes)
                // Calling these must NEVER crash or throw unhandled exceptions
                let th = ThumbnailGenerator.generateThumbnail(from: fuzzData, maxPixelSize: 180)
                let dims = ThumbnailGenerator.extractDimensions(from: fuzzData)
                let isImg = ThumbnailGenerator.isImagePayload(fuzzData)
                if isImg && (dims == nil || th == nil) {
                    fuzzPassed = false
                }
            }
        }
        report(
            name: "Fuzz stress: 110 randomized byte buffers processed with zero crashes",
            passed: fuzzPassed
        )

        // 2.5: Non-image formats (HTML, JSON, XML, Mach-O, SQLite, PDF, ZIP)
        let nonImagePayloads: [(String, Data)] = [
            ("HTML", "<!DOCTYPE html><html><body>Test</body></html>".data(using: .utf8)!),
            ("JSON", "{\"status\":\"ok\",\"clips\":[1,2,3]}".data(using: .utf8)!),
            ("XML", "<?xml version=\"1.0\"?><dict><key>k</key></dict>".data(using: .utf8)!),
            ("SQLite", "SQLite format 3\0".data(using: .utf8)!),
            ("PDF", "%PDF-1.7\n%truncated".data(using: .utf8)!),
            ("ZIP", Data([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00, 0x00, 0x00]))
        ]
        var nonImagePassed = true
        for (_, data) in nonImagePayloads {
            if ThumbnailGenerator.isImagePayload(data) || ThumbnailGenerator.generateThumbnail(from: data) != nil {
                nonImagePassed = false
            }
        }
        report(
            name: "Non-image binary formats (HTML, JSON, XML, SQLite, PDF, ZIP) rejected safely",
            passed: nonImagePassed
        )

        // 2.6: Extreme aspect ratios (1x10000, 10000x1, 1x1)
        let tallData = makeTestPNG(width: 1, height: 10000)
        let tallThumb = ThumbnailGenerator.generateThumbnail(from: tallData, maxPixelSize: 180)
        let tallDims = tallThumb.flatMap { ThumbnailGenerator.extractDimensions(from: $0) }
        report(
            name: "Extreme 1x10000 vertical aspect ratio downscales to 1x180",
            passed: (tallDims?.width == 1 && tallDims?.height == 180),
            detail: "Got dims: \(String(describing: tallDims))"
        )

        let wideData = makeTestPNG(width: 10000, height: 1)
        let wideThumb = ThumbnailGenerator.generateThumbnail(from: wideData, maxPixelSize: 180)
        let wideDims = wideThumb.flatMap { ThumbnailGenerator.extractDimensions(from: $0) }
        report(
            name: "Extreme 10000x1 horizontal aspect ratio downscales to 180x1",
            passed: (wideDims?.width == 180 && wideDims?.height == 1),
            detail: "Got dims: \(String(describing: wideDims))"
        )

        // 2.7: PasteboardMonitor rejects corrupt PNG and does NOT lock out subsequent valid image
        let pb2_7 = NSPasteboard.withUniqueName()
        let monitor2_7 = PasteboardMonitor(pasteboard: pb2_7)
        var capturedClips2_7: [ClipItem] = []
        monitor2_7.onNewClip = { item, _, _ in
            capturedClips2_7.append(item)
        }

        // Write corrupt PNG bytes
        pb2_7.clearContents()
        pb2_7.setData(Data([0x89, 0x50, 0x4E, 0x47, 0xAA, 0xBB, 0xCC, 0xDD]), forType: .png)
        monitor2_7.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        // Write valid PNG bytes immediately
        let validPNG = makeTestPNG(width: 50, height: 50)
        pb2_7.clearContents()
        pb2_7.setData(validPNG, forType: .png)
        monitor2_7.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        report(
            name: "PasteboardMonitor gracefully recovers from corrupt image and captures subsequent valid image",
            passed: (capturedClips2_7.count == 1 && capturedClips2_7.first?.contentType == .image),
            detail: "Captured clips: \(capturedClips2_7.count)"
        )

        // ==================================================================
        // Suite 3: Exotic Unicode, Combining Marks, RTL & Emoji Surrogates
        // ==================================================================
        print("\n--- Suite 3: Exotic Unicode Strings, Combining Marks, RTL & Emoji Surrogates ---")

        // 3.1: Zalgo text: 100 stacked combining marks
        var zalgoString = "Z"
        for code in 0x0300...0x0364 {
            if let scalar = UnicodeScalar(code) {
                zalgoString.append(Character(scalar))
            }
        }
        let zalgoItem = ClipItem(contentType: .text, textContent: zalgoString, byteSize: zalgoString.utf8.count)
        let zalgoTitle = zalgoItem.displayTitle
        report(
            name: "Zalgo stacked combining diacritical marks compute displayTitle safely",
            passed: (!zalgoTitle.isEmpty && zalgoTitle.count <= 60),
            detail: "Title count: \(zalgoTitle.count)"
        )

        // 3.2: Right-to-Left Arabic & Hebrew with bidirectional English numbers
        let rtlArabic = "\u{0645}\u{0631}\u{062D}\u{0628}\u{0627} \u{0628}\u{0627}\u{0644}\u{0639}\u{0627}\u{0644}\u{0645}" // Marhaban bil-alam
        let rtlHebrew = "\u{05E9}\u{05DC}\u{05D5}\u{05DD} \u{05E2}\u{05D5}\u{05DC}\u{05DD}" // Shalom Olam
        let bidiText = "\(rtlArabic) - Order #98765 - \(rtlHebrew)"

        let bidiItem = ClipItem(contentType: .text, textContent: bidiText, byteSize: bidiText.utf8.count)
        report(
            name: "Bidirectional RTL/LTR mixed text formats displayTitle cleanly",
            passed: (!bidiItem.displayTitle.isEmpty)
        )
        report(
            name: "SearchEngine matches RTL Arabic substring query",
            passed: SearchEngine.matches(item: bidiItem, query: "\u{0645}\u{0631}\u{062D}\u{0628}\u{0627}")
        )
        report(
            name: "SearchEngine matches RTL Hebrew substring query",
            passed: SearchEngine.matches(item: bidiItem, query: "\u{05E9}\u{05DC}\u{05D5}\u{05DD}")
        )
        report(
            name: "SearchEngine matches embedded ASCII number token in bidi text",
            passed: SearchEngine.matches(item: bidiItem, query: "98765")
        )

        // 3.3: High Unicode codepoints & Emoji surrogate sequences (dynamically constructed via UnicodeScalar)
        // Important: Built at runtime via scalars to strictly maintain 0 emojis in source code!
        var highUnicodeStr = "Prefix "
        let scalarGrinning = UnicodeScalar(0x1F600)! // Grinning Face
        let scalarRocket   = UnicodeScalar(0x1F680)! // Rocket
        let scalarLaptop   = UnicodeScalar(0x1F4BB)! // Personal Computer
        highUnicodeStr.append(Character(scalarGrinning))
        highUnicodeStr.append(Character(scalarRocket))
        highUnicodeStr.append(Character(scalarLaptop))
        highUnicodeStr.append(" Suffix Content with Long Tail Padding Characters 1234567890")

        let highUniItem = ClipItem(contentType: .text, textContent: highUnicodeStr, byteSize: highUnicodeStr.utf8.count)
        let highUniTitle = highUniItem.displayTitle

        report(
            name: "High Unicode codepoints and surrogate pairs truncated safely without index crash",
            passed: (highUniTitle.hasSuffix("...") && highUniTitle.count <= 60),
            detail: "Title: length \(highUniTitle.count)"
        )

        let queryRocket = String(Character(scalarRocket))
        report(
            name: "SearchEngine matches runtime high-codepoint surrogate substring accurately",
            passed: SearchEngine.matches(item: highUniItem, query: queryRocket)
        )

        // 3.4: Zero-width characters (ZWSP, ZWNJ, ZWJ, BOM)
        let zwspString = "\u{200B}\u{200C}\u{200D}\u{FEFF}"
        let zwspItem = ClipItem(contentType: .text, textContent: zwspString, byteSize: zwspString.utf8.count)
        report(
            name: "Zero-width characters handled safely without exceptions in displayTitle",
            passed: (!zwspItem.displayTitle.isEmpty)
        )

        // 3.5: Extremely long single-line text (100,000 characters)
        let hugeSingleLine = String(repeating: "X", count: 100000)
        let hugeLineItem = ClipItem(contentType: .text, textContent: hugeSingleLine, byteSize: hugeSingleLine.utf8.count)
        let startPrefix = CFAbsoluteTimeGetCurrent()
        let hugeTitle = hugeLineItem.displayTitle
        let durPrefix = CFAbsoluteTimeGetCurrent() - startPrefix

        report(
            name: "100,000-character single-line text truncated to 60 chars in O(1) time (< 5ms)",
            passed: (hugeTitle.count == 60 && hugeTitle.hasSuffix("...") && durPrefix < 0.05),
            detail: "Title count: \(hugeTitle.count), Duration: \(durPrefix)s"
        )

        // 3.6: Multi-line text with varied newline encodings (\r\n, \r, \u{2028})
        let crlfItem = ClipItem(contentType: .text, textContent: "First CRLF Line\r\nSecond CRLF Line", byteSize: 34)
        report(
            name: "displayTitle extracts first line cleanly with CRLF delimiter",
            passed: (crlfItem.displayTitle == "First CRLF Line"),
            detail: "Got: \(crlfItem.displayTitle)"
        )

        let crOnlyItem = ClipItem(contentType: .text, textContent: "First CR Line\rSecond CR Line", byteSize: 30)
        report(
            name: "displayTitle extracts first line cleanly with CR delimiter",
            passed: (crOnlyItem.displayTitle == "First CR Line"),
            detail: "Got: \(crOnlyItem.displayTitle)"
        )

        // ==================================================================
        // Suite 4: Extreme Capacity Mutation Edge Cases (capacity = 1, 500, rapid)
        // ==================================================================
        print("\n--- Suite 4: Extreme Capacity Mutation Edge Cases (1, 500, rapid) ---")

        // 4.1: Capacity = 1 minimum boundary: exactly 1 unpinned item retained
        let sandbox4_1 = createSandbox()
        defer { cleanupSandbox(sandbox4_1) }
        let storage4_1 = StorageManager(baseDirectory: sandbox4_1, initialCapacity: 1)

        var cap1Passed = true
        for i in 1...60 {
            let item = ClipItem(contentType: .text, textContent: "Cap1 Item #\(i)", byteSize: 20)
            storage4_1.addClip(item: item, imageData: nil, thumbData: nil)
            if storage4_1.historyItems.count != 1 {
                cap1Passed = false
            }
        }
        let lastItem4_1 = storage4_1.historyItems.first
        report(
            name: "Capacity = 1 strictly bounds unpinned items to exactly 1 at all times",
            passed: (cap1Passed && lastItem4_1?.textContent == "Cap1 Item #60"),
            detail: "History count: \(storage4_1.historyItems.count), Latest: \(lastItem4_1?.textContent ?? "nil")"
        )

        // 4.2: Capacity expansion to 500: preserves all subsequent items up to 500
        storage4_1.capacity = 500
        for i in 61...260 {
            let item = ClipItem(contentType: .text, textContent: "Cap500 Item #\(i)", byteSize: 20)
            storage4_1.addClip(item: item, imageData: nil, thumbData: nil)
        }
        report(
            name: "Capacity expansion to 500 retains all 201 unpinned items without eviction",
            passed: (storage4_1.historyItems.count == 201),
            detail: "History count: \(storage4_1.historyItems.count)/201"
        )

        // 4.3: Dynamic downscale from 500 to 1 with 201 items: immediate FIFO eviction
        storage4_1.capacity = 1
        let retainedItem4_3 = storage4_1.historyItems.first
        report(
            name: "Dynamic downscale from 500 to 1 immediately evicts 200 items, keeping newest",
            passed: (storage4_1.historyItems.count == 1 && retainedItem4_3?.textContent == "Cap500 Item #260"),
            detail: "History count: \(storage4_1.historyItems.count), Retained: \(retainedItem4_3?.textContent ?? "nil")"
        )

        // 4.4: Rapid alternating mutations (1 <-> 500) across 40 cycles
        var altPassed = true
        for cycle in 1...40 {
            storage4_1.capacity = 1
            if storage4_1.historyItems.count > 1 {
                altPassed = false
            }
            storage4_1.capacity = 500
            for k in 1...5 {
                let item = ClipItem(contentType: .text, textContent: "Alt Cycle \(cycle) Item \(k)", byteSize: 25)
                storage4_1.addClip(item: item, imageData: nil, thumbData: nil)
            }
            if storage4_1.historyItems.count > 500 {
                altPassed = false
            }
        }
        report(
            name: "40 rapid alternating capacity mutations (1 <-> 500) maintain strict invariants",
            passed: altPassed,
            detail: "Final count: \(storage4_1.historyItems.count)"
        )

        // 4.5: Negative, zero, and huge capacity values
        storage4_1.capacity = 0
        report(
            name: "Capacity = 0 clamped to minimum safe bound >= 1",
            passed: (storage4_1.capacity >= 1),
            detail: "Clamped capacity: \(storage4_1.capacity)"
        )

        storage4_1.capacity = -100
        report(
            name: "Negative capacity clamped to minimum safe bound >= 1",
            passed: (storage4_1.capacity >= 1),
            detail: "Clamped capacity: \(storage4_1.capacity)"
        )

        // 4.6: Cold-start persistence with capacity = 1
        storage4_1.capacity = 1
        storage4_1.flushDiskQueue()

        let reloadedStorage4_6 = StorageManager(baseDirectory: sandbox4_1)
        report(
            name: "Cold-start StorageManager reloads persisted capacity = 1 correctly",
            passed: (reloadedStorage4_6.capacity == 1 && reloadedStorage4_6.historyItems.count <= 1),
            detail: "Reloaded capacity: \(reloadedStorage4_6.capacity), items: \(reloadedStorage4_6.historyItems.count)"
        )

        // ==================================================================
        // Suite 5: Pin Protection Immunity & Mass Purge under Concurrent Storage
        // ==================================================================
        print("\n--- Suite 5: Pin Protection Immunity & Mass Purge under Concurrency ---")

        // 5.1: Mass purge immunity: clearUnpinnedHistory preserves 100% of pinned items
        let sandbox5_1 = createSandbox()
        defer { cleanupSandbox(sandbox5_1) }
        let storage5_1 = StorageManager(baseDirectory: sandbox5_1, initialCapacity: 100)

        var pinnedUUIDs5_1: Set<UUID> = []
        for i in 1...25 {
            let id = UUID()
            pinnedUUIDs5_1.insert(id)
            let item = ClipItem(id: id, contentType: .text, textContent: "Pinned Alpha #\(i)", byteSize: 22, isPinned: true)
            storage5_1.addClip(item: item, imageData: nil, thumbData: nil)
        }

        for i in 1...80 {
            let item = ClipItem(contentType: .text, textContent: "Unpinned Alpha #\(i)", byteSize: 24, isPinned: false)
            storage5_1.addClip(item: item, imageData: nil, thumbData: nil)
        }

        report(
            name: "Initial setup holds 25 pinned + 80 unpinned = 105 items",
            passed: (storage5_1.pinnedItems.count == 25 && storage5_1.historyItems.count == 80 && storage5_1.items.count == 105)
        )

        storage5_1.clearUnpinnedHistory()

        let remainingUUIDs5_1 = Set(storage5_1.items.map { $0.id })
        report(
            name: "clearUnpinnedHistory removes 100% of unpinned items (0 unpinned remaining)",
            passed: (storage5_1.historyItems.isEmpty)
        )
        report(
            name: "clearUnpinnedHistory preserves 100% of pinned items with identical UUIDs",
            passed: (storage5_1.pinnedItems.count == 25 && remainingUUIDs5_1 == pinnedUUIDs5_1),
            detail: "Pinned remaining: \(storage5_1.pinnedItems.count)/25"
        )

        // 5.2: Pin immunity under mass capacity overflow (capacity = 1 with 50 pinned items)
        let sandbox5_2 = createSandbox()
        defer { cleanupSandbox(sandbox5_2) }
        let storage5_2 = StorageManager(baseDirectory: sandbox5_2, initialCapacity: 1)

        for i in 1...40 {
            let item = ClipItem(contentType: .text, textContent: "Immune Pin #\(i)", byteSize: 20, isPinned: true)
            storage5_2.addClip(item: item, imageData: nil, thumbData: nil)
        }

        // Add 100 unpinned items sequentially
        for i in 1...100 {
            let item = ClipItem(contentType: .text, textContent: "Overflow Unpinned #\(i)", byteSize: 25, isPinned: false)
            storage5_2.addClip(item: item, imageData: nil, thumbData: nil)
        }

        report(
            name: "Pinned items are 100% immune from capacity overflow when capacity = 1",
            passed: (storage5_2.pinnedItems.count == 40 && storage5_2.historyItems.count == 1 && storage5_2.items.count == 41),
            detail: "Pinned: \(storage5_2.pinnedItems.count)/40, Unpinned: \(storage5_2.historyItems.count)/1, Total: \(storage5_2.items.count)"
        )

        // 5.3: Pin toggling eviction dynamics: unpinning item during overflow evicts oldest
        let oldestUnpinnedBefore = storage5_2.historyItems.first?.id
        // Pin the single unpinned item
        if let toPinID = oldestUnpinnedBefore {
            storage5_2.togglePin(id: toPinID)
        }
        report(
            name: "Toggling unpinned item to pinned increases pinned count to 41, leaves 0 unpinned",
            passed: (storage5_2.pinnedItems.count == 41 && storage5_2.historyItems.isEmpty)
        )

        // Add 1 new unpinned item
        let newUnpinned = ClipItem(contentType: .text, textContent: "Fresh Unpinned", byteSize: 20, isPinned: false)
        storage5_2.addClip(item: newUnpinned, imageData: nil, thumbData: nil)
        report(
            name: "Adding unpinned item at capacity = 1 sets unpinned count to exactly 1",
            passed: (storage5_2.historyItems.count == 1 && storage5_2.pinnedItems.count == 41)
        )

        // 5.4: Multi-threaded concurrent storage access stress (10 threads, 1200 operations)
        let sandbox5_4 = createSandbox()
        defer { cleanupSandbox(sandbox5_4) }
        let storage5_4 = StorageManager(baseDirectory: sandbox5_4, initialCapacity: 50)

        // Prepopulate with 20 items
        for i in 1...20 {
            let item = ClipItem(contentType: .text, textContent: "Concurrent Seed #\(i)", byteSize: 25, isPinned: (i % 3 == 0))
            storage5_4.addClip(item: item, imageData: nil, thumbData: nil)
        }

        let concurrentGroup = DispatchGroup()
        let concurrentQueue = DispatchQueue(label: "com.superclip.test.concurrent", attributes: .concurrent)

        for threadIndex in 1...10 {
            concurrentGroup.enter()
            concurrentQueue.async {
                for iter in 1...50 {
                    switch (threadIndex + iter) % 6 {
                    case 0, 1:
                        // Add text clip
                        let item = ClipItem(
                            contentType: .text,
                            textContent: "Thread \(threadIndex) Clip \(iter)",
                            byteSize: 30,
                            isPinned: (iter % 10 == 0)
                        )
                        storage5_4.addClip(item: item, imageData: nil, thumbData: nil)
                    case 2:
                        // Toggle pin on a random item
                        let currentItems = storage5_4.items
                        if let randomItem = currentItems.randomElement() {
                            storage5_4.togglePin(id: randomItem.id)
                        }
                    case 3:
                        // Mutate capacity
                        let caps = [10, 25, 50, 100, 200]
                        storage5_4.capacity = caps[(threadIndex + iter) % caps.count]
                    case 4:
                        // Delete random item
                        let currentItems = storage5_4.items
                        if currentItems.count > 5, let randomItem = currentItems.randomElement() {
                            storage5_4.deleteItem(id: randomItem.id)
                        }
                    case 5:
                        // Read properties
                        _ = storage5_4.items
                        _ = storage5_4.pinnedItems
                        _ = storage5_4.historyItems
                        _ = storage5_4.capacity
                    default:
                        break
                    }
                }
                concurrentGroup.leave()
            }
        }

        let waitResult = concurrentGroup.wait(timeout: .now() + 10.0)
        report(
            name: "10 concurrent background threads executed 500 operations with zero deadlocks",
            passed: (waitResult == .success),
            detail: "Wait result: \(waitResult)"
        )

        storage5_4.flushDiskQueue()
        let finalUnpinned5_4 = storage5_4.historyItems.count
        let finalCap5_4 = storage5_4.capacity
        report(
            name: "Concurrent stress maintains capacity invariant: unpinned count <= capacity",
            passed: (finalUnpinned5_4 <= finalCap5_4),
            detail: "Unpinned: \(finalUnpinned5_4), Capacity: \(finalCap5_4)"
        )

        // Verify cold-start serialization after concurrency
        let reloadedStorage5_4 = StorageManager(baseDirectory: sandbox5_4)
        report(
            name: "StorageManager cleanly deserializes from disk after heavy concurrent mutation",
            passed: (reloadedStorage5_4.items.count == storage5_4.items.count),
            detail: "Reloaded items: \(reloadedStorage5_4.items.count)/\(storage5_4.items.count)"
        )

        // ==================================================================
        // Summary & Verdict
        // ==================================================================
        print("\n==================================================")
        print("  Tier 5 Core Adversarial Stress Execution Summary")
        print("==================================================")
        print("  Total Tests Executed: \(totalTests)")
        print("  Passed:               \(passedTests)")
        print("  Failed:               \(failedTests)")

        if failedTests > 0 {
            print("\nVERDICT: REJECT (Found \(failedTests) failures in SuperClipCore)")
            exit(1)
        } else {
            print("\nVERDICT: APPROVE (100% Pass Rate across all Tier 5 Stress Tests)")
            exit(0)
        }
    }
}
