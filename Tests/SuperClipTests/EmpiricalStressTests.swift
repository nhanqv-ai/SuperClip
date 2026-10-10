import Foundation
import CoreGraphics
import ImageIO
import AppKit
import SuperClipCore

@main
public struct EmpiricalStressTestsRunner {
    public static func main() {
        print("==================================================")
        print("  SuperClip Empirical Stress & Challenger Harness ")
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

        let sandboxBase = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("SuperClip_Challenger_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: sandboxBase, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: sandboxBase)
        }

        // =========================================================================
        // SUITE 1: Self-Copy Suppression Under Rapid & Burst External Operations
        // =========================================================================
        print("\n--- Suite 1: Self-Copy Suppression Stress Suite ---")

        // 1.1 Standard self-copy followed by immediate external copy
        let pb1_1 = NSPasteboard.withUniqueName()
        let mon1_1 = PasteboardMonitor(pasteboard: pb1_1)
        pb1_1.clearContents()
        pb1_1.setString("Self Write 1.1", forType: .string)
        let sc1_1 = pb1_1.changeCount
        mon1_1.markSelfCopy(newChangeCount: sc1_1)

        let tickSelf1_1 = mon1_1.pollTick()
        report(
            name: "1.1: pollTick suppresses self copy count",
            passed: (tickSelf1_1 == false),
            detail: "Expected false, got \(tickSelf1_1)"
        )

        pb1_1.clearContents()
        pb1_1.setString("External Write 1.1", forType: .string)
        let tickExt1_1 = mon1_1.pollTick()
        report(
            name: "1.1: pollTick captures immediate external copy after self copy",
            passed: (tickExt1_1 == true),
            detail: "Expected true, got \(tickExt1_1)"
        )

        // 1.2 Rapid external copy immediately after markSelfCopy before checkPasteboard
        let pb1_2 = NSPasteboard.withUniqueName()
        let mon1_2 = PasteboardMonitor(pasteboard: pb1_2)
        var captured1_2: [ClipItem] = []
        mon1_2.onNewClip = { item, _, _ in
            captured1_2.append(item)
        }

        pb1_2.clearContents()
        pb1_2.setString("Internal App Copy 1.2", forType: .string)
        let sc1_2 = pb1_2.changeCount
        mon1_2.markSelfCopy(newChangeCount: sc1_2)

        // User immediately copies external text before poll/check executes
        pb1_2.clearContents()
        pb1_2.setString("Fast External Copy 1.2", forType: .string)

        mon1_2.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        report(
            name: "1.2: checkNow captures external copy that occurred before checkPasteboard",
            passed: (captured1_2.count == 1 && captured1_2.first?.textContent == "Fast External Copy 1.2"),
            detail: "Expected 1 clip 'Fast External Copy 1.2', got \(captured1_2.count) clips (\(captured1_2.first?.textContent ?? "none"))"
        )

        // 1.3 Multiple consecutive self-copies before external copy
        let pb1_3 = NSPasteboard.withUniqueName()
        let mon1_3 = PasteboardMonitor(pasteboard: pb1_3)
        var captured1_3: [ClipItem] = []
        mon1_3.onNewClip = { item, _, _ in
            captured1_3.append(item)
        }

        for i in 1...5 {
            pb1_3.clearContents()
            pb1_3.setString("Self Write Batch \(i)", forType: .string)
            mon1_3.markSelfCopy(newChangeCount: pb1_3.changeCount)
        }

        // Now external write
        pb1_3.clearContents()
        pb1_3.setString("External Write After Batch", forType: .string)

        mon1_3.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        report(
            name: "1.3: Multiple consecutive self-copies correctly suppressed without dropping subsequent external",
            passed: (captured1_3.count == 1 && captured1_3.first?.textContent == "External Write After Batch"),
            detail: "Expected 1 clip 'External Write After Batch', got \(captured1_3.count)"
        )

        // 1.4 Interleaved self and external copies in rapid succession
        let pb1_4 = NSPasteboard.withUniqueName()
        let mon1_4 = PasteboardMonitor(pasteboard: pb1_4)
        var captured1_4: [ClipItem] = []
        mon1_4.onNewClip = { item, _, _ in
            captured1_4.append(item)
        }

        for i in 1...10 {
            // Self write
            pb1_4.clearContents()
            pb1_4.setString("Interleaved Self \(i)", forType: .string)
            mon1_4.markSelfCopy(newChangeCount: pb1_4.changeCount)

            // External write
            pb1_4.clearContents()
            pb1_4.setString("Interleaved External \(i)", forType: .string)
            mon1_4.checkNow()
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))

        let allExternal1_4 = captured1_4.allSatisfy { $0.textContent?.hasPrefix("Interleaved External") == true }
        report(
            name: "1.4: 10 interleaved self/external cycles capture exactly 10 external clips and 0 self clips",
            passed: (captured1_4.count == 10 && allExternal1_4),
            detail: "Captured count: \(captured1_4.count) of 10. All external: \(allExternal1_4)"
        )

        // 1.5 Active polling timer captures external copies following self-copy suppression without swallowing
        let pb1_5 = NSPasteboard.withUniqueName()
        let mon1_5 = PasteboardMonitor(pasteboard: pb1_5)
        var captured1_5: [ClipItem] = []
        let capLock1_5 = NSLock()
        mon1_5.onNewClip = { item, _, _ in
            capLock1_5.lock()
            captured1_5.append(item)
            capLock1_5.unlock()
        }

        mon1_5.startPolling(intervalMs: 50)
        // Allow initial tick to settle
        Thread.sleep(forTimeInterval: 0.05)

        for i in 1...10 {
            // Self write + mark suppression
            pb1_5.clearContents()
            pb1_5.setString("Timer Self \(i)", forType: .string)
            mon1_5.markSelfCopy(newChangeCount: pb1_5.changeCount)

            // Wait for monitor cycle while suppressed
            Thread.sleep(forTimeInterval: 0.06)

            // External write immediately following self copy
            pb1_5.clearContents()
            pb1_5.setString("Timer External \(i)", forType: .string)

            // Wait for monitor to pick up external write
            Thread.sleep(forTimeInterval: 0.08)
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }

        mon1_5.stopPolling()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        capLock1_5.lock()
        let count1_5 = captured1_5.count
        let zeroSelf1_5 = captured1_5.allSatisfy { $0.textContent?.hasPrefix("Timer Self") == false }
        let allExternalPresent = (1...10).allSatisfy { idx in
            captured1_5.contains { $0.textContent == "Timer External \(idx)" }
        }
        let capturedNames1_5 = captured1_5.compactMap { $0.textContent }
        capLock1_5.unlock()

        report(
            name: "1.5: Active polling timer captures all 10 external writes without swallowing after self-copy",
            passed: (count1_5 == 10 && zeroSelf1_5 && allExternalPresent),
            detail: "Captured: \(count1_5)/10, zero self: \(zeroSelf1_5), all external: \(allExternalPresent), items: \(capturedNames1_5)"
        )

        // 1.6 Stale markSelfCopy call does not suppress future copies
        let pb1_6 = NSPasteboard.withUniqueName()
        let mon1_6 = PasteboardMonitor(pasteboard: pb1_6)
        pb1_6.clearContents()
        pb1_6.setString("Init 1.6", forType: .string)
        let currentCount1_6 = pb1_6.changeCount

        // Stale mark with smaller change count
        mon1_6.markSelfCopy(newChangeCount: currentCount1_6 - 1)

        pb1_6.clearContents()
        pb1_6.setString("External After Stale Mark", forType: .string)
        let tickStale = mon1_6.pollTick()
        report(
            name: "1.6: Stale markSelfCopy with smaller count does not suppress valid external copy",
            passed: (tickStale == true),
            detail: "Expected true, got \(tickStale)"
        )

        // 1.7 isSuppressed property reflection
        let pb1_7 = NSPasteboard.withUniqueName()
        let mon1_7 = PasteboardMonitor(pasteboard: pb1_7)
        report(
            name: "1.7: isSuppressed is false initially",
            passed: (mon1_7.isSuppressed == false)
        )
        mon1_7.markSelfCopy(newChangeCount: 9999)
        report(
            name: "1.7: isSuppressed is true after markSelfCopy",
            passed: (mon1_7.isSuppressed == true)
        )

        // =========================================================================
        // SUITE 2: Image Deduplication with Prefix/Suffix Sharing Stress Suite
        // =========================================================================
        print("\n--- Suite 2: Image Deduplication Stress Suite ---")

        // 2.1 Identical size images sharing 1024-byte prefix and suffix, differing in middle
        let pb2_1 = NSPasteboard.withUniqueName()
        let mon2_1 = PasteboardMonitor(pasteboard: pb2_1)
        var captured2_1: [ClipItem] = []
        mon2_1.onNewClip = { item, _, _ in
            captured2_1.append(item)
        }

        let baseImgRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 128,
            pixelsHigh: 128,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 512,
            bitsPerPixel: 32
        )!
        var imgDataA = baseImgRep.representation(using: .png, properties: [:])!
        if imgDataA.count < 8192 {
            imgDataA.append(Data(repeating: 0x55, count: 8192 - imgDataA.count))
        }
        var imgDataB = imgDataA
        // Modify bytes in the exact middle (e.g. index 4000 to 4200)
        for i in 4000..<4200 {
            imgDataB[i] = 0xAA
        }

        report(
            name: "2.1: Image A and B have identical total byte count",
            passed: (imgDataA.count == imgDataB.count && imgDataA.count >= 8192),
            detail: "Count A: \(imgDataA.count), Count B: \(imgDataB.count)"
        )
        report(
            name: "2.1: Image A and B share identical 1024-byte prefix and suffix",
            passed: (imgDataA.prefix(1024) == imgDataB.prefix(1024) && imgDataA.suffix(1024) == imgDataB.suffix(1024))
        )

        pb2_1.clearContents()
        pb2_1.setData(imgDataA, forType: .png)
        mon2_1.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        pb2_1.clearContents()
        pb2_1.setData(imgDataB, forType: .png)
        mon2_1.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        report(
            name: "2.1: Both images captured as distinct clips (no middle-byte collision)",
            passed: (captured2_1.count == 2),
            detail: "Captured \(captured2_1.count) clips (expected 2)"
        )

        // 2.2 1-Bit Difference at the Exact Center Byte of a 16KB payload
        let pb2_2 = NSPasteboard.withUniqueName()
        let mon2_2 = PasteboardMonitor(pasteboard: pb2_2)
        var captured2_2: [ClipItem] = []
        mon2_2.onNewClip = { item, _, _ in
            captured2_2.append(item)
        }

        var imgDataCenterA = baseImgRep.representation(using: .png, properties: [:])!
        if imgDataCenterA.count < 16384 {
            imgDataCenterA.append(Data(repeating: 0x33, count: 16384 - imgDataCenterA.count))
        }
        var imgDataCenterB = imgDataCenterA
        let centerIdx = imgDataCenterA.count / 2
        imgDataCenterB[centerIdx] ^= 0x01 // flip single bit at exact center

        pb2_2.clearContents()
        pb2_2.setData(imgDataCenterA, forType: .png)
        mon2_2.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        pb2_2.clearContents()
        pb2_2.setData(imgDataCenterB, forType: .png)
        mon2_2.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        report(
            name: "2.2: 1-bit center difference in 16KB payload detected as distinct image",
            passed: (captured2_2.count == 2),
            detail: "Captured \(captured2_2.count) clips (expected 2)"
        )

        // 2.3 Genuine duplicate image suppression when changeCount increments
        let pb2_3 = NSPasteboard.withUniqueName()
        let mon2_3 = PasteboardMonitor(pasteboard: pb2_3)
        var captured2_3: [ClipItem] = []
        mon2_3.onNewClip = { item, _, _ in
            captured2_3.append(item)
        }

        pb2_3.clearContents()
        pb2_3.setData(imgDataA, forType: .png)
        mon2_3.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        // Copy exact same image bytes again (clearing pasteboard increments changeCount)
        pb2_3.clearContents()
        pb2_3.setData(imgDataA, forType: .png)
        mon2_3.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        report(
            name: "2.3: Re-copying identical image bytes with incremented changeCount is deduplicated",
            passed: (captured2_3.count == 1),
            detail: "Captured \(captured2_3.count) clips (expected 1)"
        )

        // 2.4 Alternating Image A -> Image B -> Image A
        let pb2_4 = NSPasteboard.withUniqueName()
        let mon2_4 = PasteboardMonitor(pasteboard: pb2_4)
        var captured2_4: [ClipItem] = []
        mon2_4.onNewClip = { item, _, _ in
            captured2_4.append(item)
        }

        pb2_4.clearContents()
        pb2_4.setData(imgDataA, forType: .png)
        mon2_4.checkNow()

        pb2_4.clearContents()
        pb2_4.setData(imgDataB, forType: .png)
        mon2_4.checkNow()

        pb2_4.clearContents()
        pb2_4.setData(imgDataA, forType: .png)
        mon2_4.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))

        report(
            name: "2.4: Alternating Image A -> B -> A captures all 3 occurrences",
            passed: (captured2_4.count == 3),
            detail: "Captured \(captured2_4.count) of 3"
        )

        // 2.5 Image A -> Text -> Image A (text resets image hash state)
        let pb2_5 = NSPasteboard.withUniqueName()
        let mon2_5 = PasteboardMonitor(pasteboard: pb2_5)
        var captured2_5: [ClipItem] = []
        mon2_5.onNewClip = { item, _, _ in
            captured2_5.append(item)
        }

        pb2_5.clearContents()
        pb2_5.setData(imgDataA, forType: .png)
        mon2_5.checkNow()

        pb2_5.clearContents()
        pb2_5.setString("Interleaved Text", forType: .string)
        mon2_5.checkNow()

        pb2_5.clearContents()
        pb2_5.setData(imgDataA, forType: .png)
        mon2_5.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))

        report(
            name: "2.5: Image A -> Text -> Image A re-captures Image A",
            passed: (captured2_5.count == 3 && captured2_5[0].contentType == .image && captured2_5[1].contentType == .text && captured2_5[2].contentType == .image),
            detail: "Captured types: \(captured2_5.map { $0.contentType.rawValue })"
        )

        // 2.6 Corrupt image payload does not poison hash state for subsequent valid payload
        let pb2_6 = NSPasteboard.withUniqueName()
        let mon2_6 = PasteboardMonitor(pasteboard: pb2_6)
        var captured2_6: [ClipItem] = []
        mon2_6.onNewClip = { item, _, _ in
            captured2_6.append(item)
        }

        let corruptBytes = Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0x00, 0x00, 0x00])
        pb2_6.clearContents()
        pb2_6.setData(corruptBytes, forType: .png)
        mon2_6.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        report(
            name: "2.6: Corrupt PNG payload safely ignored without creating clip",
            passed: (captured2_6.count == 0)
        )

        pb2_6.clearContents()
        pb2_6.setData(imgDataA, forType: .png)
        mon2_6.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        report(
            name: "2.6: Valid PNG captured after corrupt payload (hash state unpoisoned)",
            passed: (captured2_6.count == 1 && captured2_6.first?.contentType == .image)
        )

        // =========================================================================
        // SUITE 3: Duplicate Promotion When ChangeCount Increments
        // =========================================================================
        print("\n--- Suite 3: Duplicate Promotion Stress Suite ---")

        // 3.1 Full pipeline: PasteboardMonitor feeding StorageManager with duplicate promotion
        let storageDir3_1 = sandboxBase.appendingPathComponent("Storage3_1")
        let storage3_1 = StorageManager(baseDirectory: storageDir3_1, initialCapacity: 10)
        let pb3_1 = NSPasteboard.withUniqueName()
        let mon3_1 = PasteboardMonitor(pasteboard: pb3_1)
        mon3_1.onNewClip = { item, imgData, thumbData in
            storage3_1.addClip(item: item, imageData: imgData, thumbData: thumbData)
        }

        // Copy Alpha -> Beta -> Gamma
        pb3_1.clearContents()
        pb3_1.setString("Alpha Item", forType: .string)
        mon3_1.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))

        let alphaOriginalUUID = storage3_1.items.first?.id

        pb3_1.clearContents()
        pb3_1.setString("Beta Item", forType: .string)
        mon3_1.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))

        pb3_1.clearContents()
        pb3_1.setString("Gamma Item", forType: .string)
        mon3_1.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))

        report(
            name: "3.1: Storage contains 3 items before duplicate promotion",
            passed: (storage3_1.items.count == 3),
            detail: "Got \(storage3_1.items.count) items"
        )
        report(
            name: "3.1: Alpha Item is at index 2 before promotion",
            passed: (storage3_1.items[2].textContent == "Alpha Item")
        )

        // Copy Alpha Item again (changeCount increments on pasteboard)
        pb3_1.clearContents()
        pb3_1.setString("Alpha Item", forType: .string)
        mon3_1.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        report(
            name: "3.1: Storage items count remains 3 after duplicate promotion",
            passed: (storage3_1.items.count == 3),
            detail: "Count: \(storage3_1.items.count)"
        )
        report(
            name: "3.1: Alpha Item promoted to index 0 (top of history)",
            passed: (storage3_1.items[0].textContent == "Alpha Item"),
            detail: "Index 0 is \(storage3_1.items[0].textContent ?? "nil")"
        )
        report(
            name: "3.1: Promoted Alpha Item preserves original UUID",
            passed: (storage3_1.items[0].id == alphaOriginalUUID),
            detail: "Original: \(String(describing: alphaOriginalUUID)), Current: \(storage3_1.items[0].id)"
        )
        report(
            name: "3.1: Order of remaining items is preserved (Gamma at 1, Beta at 2)",
            passed: (storage3_1.items[1].textContent == "Gamma Item" && storage3_1.items[2].textContent == "Beta Item")
        )

        // 3.2 Immediate duplicate copy (same text copied twice in a row)
        let countBeforeImmediate = storage3_1.items.count
        pb3_1.clearContents()
        pb3_1.setString("Alpha Item", forType: .string)
        mon3_1.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        report(
            name: "3.2: Immediate consecutive duplicate does not duplicate or re-insert",
            passed: (storage3_1.items.count == countBeforeImmediate && storage3_1.items[0].textContent == "Alpha Item")
        )

        // 3.3 Duplicate promotion of a PINNED clip
        // Pin "Beta Item" at index 2
        let betaItem = storage3_1.items.first(where: { $0.textContent == "Beta Item" })!
        storage3_1.togglePin(id: betaItem.id)

        report(
            name: "3.3: Beta Item marked as pinned",
            passed: (storage3_1.pinnedItems.count == 1 && storage3_1.pinnedItems.first?.textContent == "Beta Item")
        )

        // Re-copy "Beta Item" to pasteboard
        pb3_1.clearContents()
        pb3_1.setString("Beta Item", forType: .string)
        mon3_1.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        report(
            name: "3.3: Pinned Beta Item promoted to index 0",
            passed: (storage3_1.items[0].textContent == "Beta Item"),
            detail: "Index 0 is \(storage3_1.items[0].textContent ?? "nil")"
        )
        report(
            name: "3.3: Promoted Beta Item retains isPinned == true",
            passed: (storage3_1.items[0].isPinned == true),
            detail: "isPinned: \(storage3_1.items[0].isPinned)"
        )
        report(
            name: "3.3: Total store count remains 3 after pinned duplicate promotion",
            passed: (storage3_1.items.count == 3)
        )

        // 3.4 Duplicate promotion of tail item under maximum capacity
        let storageDir3_4 = sandboxBase.appendingPathComponent("Storage3_4")
        let storage3_4 = StorageManager(baseDirectory: storageDir3_4, initialCapacity: 3)
        let pb3_4 = NSPasteboard.withUniqueName()
        let mon3_4 = PasteboardMonitor(pasteboard: pb3_4)
        mon3_4.onNewClip = { item, img, th in
            storage3_4.addClip(item: item, imageData: img, thumbData: th)
        }

        // Fill exactly 3 unpinned items: C (index 0), B (index 1), A (index 2)
        for letter in ["A", "B", "C"] {
            pb3_4.clearContents()
            pb3_4.setString("Clip \(letter)", forType: .string)
            mon3_4.checkNow()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
        }

        report(
            name: "3.4: Store filled to capacity 3: [Clip C, Clip B, Clip A]",
            passed: (storage3_4.items.map { $0.textContent ?? "" } == ["Clip C", "Clip B", "Clip A"])
        )

        // Re-copy Clip A (the oldest item at index 2)
        pb3_4.clearContents()
        pb3_4.setString("Clip A", forType: .string)
        mon3_4.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        report(
            name: "3.4: Promoting tail item Clip A retains capacity 3 with zero evictions",
            passed: (storage3_4.items.count == 3),
            detail: "Count: \(storage3_4.items.count)"
        )
        report(
            name: "3.4: Promoted Clip A is at index 0, new order is [Clip A, Clip C, Clip B]",
            passed: (storage3_4.items.map { $0.textContent ?? "" } == ["Clip A", "Clip C", "Clip B"]),
            detail: "Actual order: \(storage3_4.items.map { $0.textContent ?? "" })"
        )

        // 3.5 Casing and whitespace distinctness
        pb3_4.clearContents()
        pb3_4.setString("clip a", forType: .string) // lowercase
        mon3_4.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        report(
            name: "3.5: Lowercase 'clip a' is treated as distinct from 'Clip A' (evicts oldest 'Clip B')",
            passed: (storage3_4.items.first?.textContent == "clip a" && storage3_4.items.contains(where: { $0.textContent == "Clip A" })),
            detail: "Current items: \(storage3_4.items.map { $0.textContent ?? "" })"
        )

        // =========================================================================
        // SUITE 4: Burst Concurrency & Heavy Stress Harness
        // =========================================================================
        print("\n--- Suite 4: Heavy Burst & Concurrency Stress Suite ---")

        let pb4 = NSPasteboard.withUniqueName()
        let mon4 = PasteboardMonitor(pasteboard: pb4)
        var captured4: [ClipItem] = []
        let lock4 = NSLock()
        mon4.onNewClip = { item, _, _ in
            lock4.lock()
            captured4.append(item)
            lock4.unlock()
        }

        // Burst of 100 external copies
        for i in 1...100 {
            pb4.clearContents()
            pb4.setString("Stress Burst Item \(i)", forType: .string)
            mon4.checkNow()
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))

        lock4.lock()
        let count4 = captured4.count
        lock4.unlock()

        report(
            name: "4.1: Burst capture of 100 sequential pasteboard changes",
            passed: (count4 == 100),
            detail: "Captured \(count4)/100"
        )

        // =========================================================================
        // FINAL SUMMARY
        // =========================================================================
        print("\n==================================================")
        print("  Empirical Challenger Stress Test Summary        ")
        print("==================================================")
        print("  Total Tests:  \(totalTests)")
        print("  Passed:       \(passedTests)")
        print("  Failed:       \(failedTests)")

        if failedTests > 0 {
            print("\nVERDICT: REJECT (\(failedTests) tests failed)")
            exit(1)
        } else {
            print("\nVERDICT: APPROVE (100% empirical stress tests passed)")
            exit(0)
        }
    }
}
