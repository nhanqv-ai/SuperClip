import Foundation
import AppKit
import SwiftUI
import SuperClipCore
import SuperClip

@main
struct ChallengerM3StressRunner {
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

    static func createTempDirectory() -> URL {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperClip_ChallengerM3_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        return temp
    }

    static func cleanupTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static func main() {
        print("==================================================")
        print("  SuperClip Challenger M3 Empirical Stress Runner ")
        print("  Target: Navigation, 1..9, Writeback Suppression ")
        print("==================================================")

        let sandbox = createTempDirectory()
        defer { cleanupTempDirectory(sandbox) }

        // ==========================================
        // Suite 1: Arrow Key Navigation & Boundary Conditions
        // ==========================================
        print("\n--- Suite 1: Arrow Key Navigation & Boundary Conditions ---")

        // 1.1: Up Arrow at top row (index 0) returns nil to restore search focus
        let upAtTop = ShortcutNavigator.stepUp(currentIndex: 0, visibleCount: 10)
        report(
            name: "Up Arrow at index 0 returns nil (restores search bar focus)",
            passed: upAtTop == nil,
            detail: "got \(String(describing: upAtTop))"
        )

        // 1.2: Up Arrow when unselected (nil) remains nil
        let upAtNil = ShortcutNavigator.stepUp(currentIndex: nil, visibleCount: 10)
        report(
            name: "Up Arrow when unselected remains nil",
            passed: upAtNil == nil,
            detail: "got \(String(describing: upAtNil))"
        )

        // 1.3: Up Arrow on empty list returns nil
        let upAtEmpty = ShortcutNavigator.stepUp(currentIndex: 0, visibleCount: 0)
        report(
            name: "Up Arrow on empty list returns nil",
            passed: upAtEmpty == nil,
            detail: "got \(String(describing: upAtEmpty))"
        )

        // 1.4: Down Arrow at bottom row clamps at visibleCount - 1
        let downAtBottom = ShortcutNavigator.stepDown(currentIndex: 9, visibleCount: 10)
        report(
            name: "Down Arrow at bottom row clamps at visibleCount - 1",
            passed: downAtBottom == 9,
            detail: "got \(String(describing: downAtBottom))"
        )

        // 1.5: Down Arrow when unselected (nil) selects top row (0)
        let downAtNil = ShortcutNavigator.stepDown(currentIndex: nil, visibleCount: 10)
        report(
            name: "Down Arrow when unselected selects index 0",
            passed: downAtNil == 0,
            detail: "got \(String(describing: downAtNil))"
        )

        // 1.6: Down Arrow on empty list returns nil
        let downAtEmpty = ShortcutNavigator.stepDown(currentIndex: nil, visibleCount: 0)
        report(
            name: "Down Arrow on empty list returns nil",
            passed: downAtEmpty == nil,
            detail: "got \(String(describing: downAtEmpty))"
        )

        // 1.7: 100 repeated Down Arrow steps strictly clamp at visibleCount - 1
        var curIdx: Int? = nil
        for _ in 1...100 {
            curIdx = ShortcutNavigator.stepDown(currentIndex: curIdx, visibleCount: 5)
        }
        report(
            name: "100 repeated Down Arrow steps strictly clamp at index 4 (visibleCount - 1)",
            passed: curIdx == 4,
            detail: "got \(String(describing: curIdx))"
        )

        // 1.8: 100 repeated Up Arrow steps strictly clamp at nil
        for _ in 1...100 {
            curIdx = ShortcutNavigator.stepUp(currentIndex: curIdx, visibleCount: 5)
        }
        report(
            name: "100 repeated Up Arrow steps strictly terminate at nil",
            passed: curIdx == nil,
            detail: "got \(String(describing: curIdx))"
        )

        // 1.9: Alternating boundary stepping across 10,000 rapid iterations
        var boundaryInvariantsMaintained = true
        var testIdx: Int? = nil
        let listCap = 7
        for i in 1...10000 {
            if i % 3 == 0 {
                testIdx = ShortcutNavigator.stepDown(currentIndex: testIdx, visibleCount: listCap)
            } else if i % 3 == 1 {
                testIdx = ShortcutNavigator.stepUp(currentIndex: testIdx, visibleCount: listCap)
            } else {
                // Return resolution invariant
                let testItems = (0..<listCap).map { ClipItem(contentType: .text, textContent: "Item \($0)", byteSize: 6) }
                let target = ShortcutNavigator.resolveReturnTarget(currentIndex: testIdx, visibleItems: testItems)
                if testIdx == nil && target?.textContent != "Item 0" {
                    boundaryInvariantsMaintained = false
                } else if let idx = testIdx, target?.textContent != "Item \(idx)" {
                    boundaryInvariantsMaintained = false
                }
            }

            if let idx = testIdx {
                if idx < 0 || idx >= listCap {
                    boundaryInvariantsMaintained = false
                    break
                }
            }
        }
        report(
            name: "10,000 alternating Up/Down arrow keystrokes maintain boundary invariants",
            passed: boundaryInvariantsMaintained
        )

        // 1.10: Dynamic list reduction handling (query narrows while index was high)
        let fullList = (0..<10).map { ClipItem(contentType: .text, textContent: "Full \($0)", byteSize: 6) }
        let narrowedList = [fullList[0], fullList[1]]
        // Suppose index was 8, but list narrowed to 2 items
        let returnFallback = ShortcutNavigator.resolveReturnTarget(currentIndex: 8, visibleItems: narrowedList)
        report(
            name: "resolveReturnTarget with out-of-bounds index safely defaults to first visible item",
            passed: returnFallback?.textContent == "Full 0",
            detail: "got \(String(describing: returnFallback?.textContent))"
        )

        // 1.11: Empty list Return target returns nil
        let returnEmpty = ShortcutNavigator.resolveReturnTarget(currentIndex: 0, visibleItems: [])
        report(
            name: "resolveReturnTarget on empty list returns nil safely",
            passed: returnEmpty == nil
        )

        // ==========================================
        // Suite 2: 1..9 Number Shortcuts & Event Parsing Stress
        // ==========================================
        print("\n--- Suite 2: 1..9 Number Shortcuts & Event Parsing Stress ---")

        let sampleItems = (1...20).map { i in
            ClipItem(
                id: UUID(),
                contentType: .text,
                textContent: "Sample Clip \(i)",
                byteSize: 15,
                isPinned: i <= 5
            )
        }

        // 2.1: Rapid sequential 1..9 shortcut index resolution
        var sequentialTargetsValid = true
        for num in 1...9 {
            let target = ShortcutNavigator.targetItem(forShortcut: num, in: sampleItems)
            if target?.textContent != "Sample Clip \(num)" {
                sequentialTargetsValid = false
            }
        }
        report(
            name: "Rapid sequential 1..9 shortcuts map 1:1 to visible items",
            passed: sequentialTargetsValid
        )

        // 2.2: Out of bounds shortcuts (10, 0, negative, 100) return nil
        let invalidShortcuts = [0, 10, 11, -1, 999]
        var invalidShortcutsAllNil = true
        for inv in invalidShortcuts {
            if ShortcutNavigator.targetItem(forShortcut: inv, in: sampleItems) != nil {
                invalidShortcutsAllNil = false
            }
        }
        report(
            name: "Shortcuts outside 1..9 range strictly return nil",
            passed: invalidShortcutsAllNil
        )

        // 2.3: Shortcut badge labels (0..8 -> 1..9, 9+ -> nil)
        var badgesValid = true
        for i in 0..<9 {
            if ShortcutNavigator.badgeLabel(forIndex: i) != "\(i + 1)" {
                badgesValid = false
            }
        }
        for i in 9...25 {
            if ShortcutNavigator.badgeLabel(forIndex: i) != nil {
                badgesValid = false
            }
        }
        if ShortcutNavigator.badgeLabel(forIndex: -1) != nil {
            badgesValid = false
        }
        report(
            name: "Shortcut badges strictly apply to rows 0..8 and return nil for 9+",
            passed: badgesValid
        )

        // 2.4: Focus-gated bare vs Command shortcuts
        func makeKeyEvent(char: String, keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> NSEvent {
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: modifiers,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: char,
                charactersIgnoringModifiers: char,
                isARepeat: false,
                keyCode: keyCode
            )!
        }

        var focusGatingPassed = true
        // Keycodes for digits 1..9 on ANSI keyboard: 18, 19, 20, 21, 23, 22, 26, 28, 25
        let keyCodes: [UInt16] = [18, 19, 20, 21, 23, 22, 26, 28, 25]
        for digit in 1...9 {
            let ch = "\(digit)"
            let kc = keyCodes[digit - 1]

            // Bare key with search field focused -> nil (enters text)
            let bareEvt = makeKeyEvent(char: ch, keyCode: kc, modifiers: [])
            let bareFocused = ShortcutNavigator.parseShortcut(from: bareEvt, searchFieldHasFocus: true)
            if bareFocused != nil { focusGatingPassed = false }

            // Bare key with search field blurred -> digit (shortcut)
            let bareBlurred = ShortcutNavigator.parseShortcut(from: bareEvt, searchFieldHasFocus: false)
            if bareBlurred != digit { focusGatingPassed = false }

            // Command key with search field focused -> digit (unconditional accelerator)
            let cmdEvt = makeKeyEvent(char: ch, keyCode: kc, modifiers: [.command])
            let cmdFocused = ShortcutNavigator.parseShortcut(from: cmdEvt, searchFieldHasFocus: true)
            if cmdFocused != digit { focusGatingPassed = false }

            // Command key with search field blurred -> digit
            let cmdBlurred = ShortcutNavigator.parseShortcut(from: cmdEvt, searchFieldHasFocus: false)
            if cmdBlurred != digit { focusGatingPassed = false }
        }
        report(
            name: "Focus-gated bare 1..9 and unconditional Command+1..9 parse accurately across all 9 digits",
            passed: focusGatingPassed
        )

        // 2.5: Modifier rejection (Control, Option, Shift)
        var modifierRejectionPassed = true
        let ctrlEvt = makeKeyEvent(char: "1", keyCode: 18, modifiers: [.control])
        if ShortcutNavigator.parseShortcut(from: ctrlEvt, searchFieldHasFocus: false) != nil {
            modifierRejectionPassed = false
        }
        let optEvt = makeKeyEvent(char: "\u{00A1}", keyCode: 18, modifiers: [.option])
        if ShortcutNavigator.parseShortcut(from: optEvt, searchFieldHasFocus: false) != nil {
            modifierRejectionPassed = false
        }
        let cmdCtrlEvt = makeKeyEvent(char: "1", keyCode: 18, modifiers: [.command, .control])
        if ShortcutNavigator.parseShortcut(from: cmdCtrlEvt, searchFieldHasFocus: false) != nil {
            modifierRejectionPassed = false
        }
        let cmdOptEvt = makeKeyEvent(char: "1", keyCode: 18, modifiers: [.command, .option])
        if ShortcutNavigator.parseShortcut(from: cmdOptEvt, searchFieldHasFocus: false) != nil {
            modifierRejectionPassed = false
        }
        report(
            name: "Control and Option modifier combinations are strictly rejected",
            passed: modifierRejectionPassed
        )

        // 2.6: Non-digit characters rejection
        let letterEvt = makeKeyEvent(char: "v", keyCode: 9, modifiers: [.command])
        let nonDigitRejected = ShortcutNavigator.parseShortcut(from: letterEvt, searchFieldHasFocus: false) == nil
        report(
            name: "Non-digit characters (e.g. Command+V) return nil from parseShortcut",
            passed: nonDigitRejected
        )

        // 2.7: Partitioned Continuity: Pinned items 1..3 and Recent items 4..9
        let partitionedItems = (1...15).map { i in
            ClipItem(
                contentType: .text,
                textContent: "Item \(i)",
                byteSize: 10,
                isPinned: i <= 3
            )
        }
        let resolvedVisible = ShortcutNavigator.resolveVisibleItems(items: partitionedItems, query: "")
        var partitionContinuityPassed = true
        for i in 1...9 {
            let target = ShortcutNavigator.targetItem(forShortcut: i, in: resolvedVisible)
            if target?.textContent != "Item \(i)" {
                partitionContinuityPassed = false
            }
        }
        report(
            name: "Shortcut 1..9 resolves continuously across partition boundary (3 pinned + 6 recent)",
            passed: partitionContinuityPassed
        )

        // ==========================================
        // Suite 3: Copy Writeback & Loop Suppression
        // ==========================================
        print("\n--- Suite 3: Copy Writeback & Loop Suppression ---")

        let pbName = NSPasteboard.Name("com.superclip.test.challenger_m3.\(UUID().uuidString)")
        let pb = NSPasteboard(name: pbName)
        let storageDir = sandbox.appendingPathComponent("StorageSuite3")
        let storage = StorageManager(baseDirectory: storageDir, initialCapacity: 20)
        let monitor = PasteboardMonitor(pasteboard: pb)
        let writer = PasteboardWriter(pasteboard: pb, monitor: monitor)

        // Hook up monitor's onNewClip to storage to simulate production app behavior
        monitor.onNewClip = { item, imgData, thData in
            storage.addClip(item: item, imageData: imgData, thumbData: thData)
        }

        // Add 5 initial items to storage
        let initialClips = (1...5).map { i in
            ClipItem(id: UUID(), contentType: .text, textContent: "Original Item \(i)", byteSize: 15, isPinned: false)
        }
        for clip in initialClips {
            storage.addClip(item: clip, imageData: nil, thumbData: nil)
        }
        let countBeforeCopy = storage.items.count

        // 3.1: Copy Item 1, 2, 3 sequentially: verify NO duplicate clips produced in StorageManager
        var writebackLoopSuppressionPassed = true
        for i in 0..<3 {
            let targetClip = initialClips[i]
            let success = writer.writeClip(targetClip, storageManager: storage)
            if !success {
                writebackLoopSuppressionPassed = false
            }

            // Immediately poll monitor as would occur on timer tick
            let polledChange = monitor.pollTick()
            if polledChange {
                // Poll tick returned true: self-copy was NOT suppressed!
                writebackLoopSuppressionPassed = false
            }

            // Also check checkNow directly
            monitor.checkNow()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

            // Storage count must NOT have increased
            if storage.items.count != countBeforeCopy {
                writebackLoopSuppressionPassed = false
            }
        }
        report(
            name: "Copying item 1, 2, 3 sequentially does NOT produce duplicate clips in StorageManager",
            passed: writebackLoopSuppressionPassed && storage.items.count == countBeforeCopy,
            detail: "storageCountBefore=\(countBeforeCopy), countAfter=\(storage.items.count)"
        )

        // 3.2: Rapid consecutive self-copies WITHOUT intervening poll ticks
        let itemA = initialClips[3]
        let itemB = initialClips[4]
        _ = writer.writeClip(itemA, storageManager: storage)
        _ = writer.writeClip(itemB, storageManager: storage)
        // Now single poll tick after 2 rapid writes
        let pollAfterBurst = monitor.pollTick()
        monitor.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        report(
            name: "Consecutive self-copies without intervening ticks are suppressed on single subsequent poll",
            passed: !pollAfterBurst && storage.items.count == countBeforeCopy,
            detail: "pollAfterBurst=\(pollAfterBurst), storageCount=\(storage.items.count)"
        )

        // 3.3: Legitimate external copy following suppressed self-copies is cleanly captured
        pb.clearContents()
        pb.setString("Legitimate External Input 123", forType: .string)
        monitor.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        let externalCaptured = storage.items.first?.textContent == "Legitimate External Input 123"
        let countAfterExternal = storage.items.count
        report(
            name: "External clipboard write following suppressed self-copies is accurately recorded",
            passed: externalCaptured && countAfterExternal == countBeforeCopy + 1,
            detail: "topItem='\(storage.items.first?.textContent ?? "")', count=\(countAfterExternal)"
        )

        // 3.4: Image payload copy writeback
        let fakePNG = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let imgID = UUID()
        let imgItem = ClipItem(
            id: imgID,
            contentType: .image,
            imageFileName: "\(imgID.uuidString).png",
            thumbnailFileName: "\(imgID.uuidString)_thumb.png",
            imageWidth: 100,
            imageHeight: 100,
            byteSize: fakePNG.count,
            isPinned: false
        )
        storage.addClip(item: imgItem, imageData: fakePNG, thumbData: nil)
        let countWithImage = storage.items.count

        let imgWriteSuccess = writer.writeClip(imgItem, storageManager: storage)
        let imgPBData = pb.data(forType: .png)
        let imgTickSuppressed = !monitor.pollTick()
        monitor.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        report(
            name: "Image clip writeback writes PNG to pasteboard and suppresses self-copy loop",
            passed: imgWriteSuccess && imgPBData == fakePNG && imgTickSuppressed && storage.items.count == countWithImage,
            detail: "imgWriteSuccess=\(imgWriteSuccess), imgTickSuppressed=\(imgTickSuppressed)"
        )

        // 3.5: Coordinator dismissal callback on selectAndCopy vs copyItem
        var dismissedCount = 0
        let coordinator = ClipboardActionCoordinator(
            storageManager: storage,
            pasteboardWriter: writer,
            onDismiss: { dismissedCount += 1 }
        )
        coordinator.selectAndCopy(item: initialClips[0])
        let selectDismissed = (dismissedCount == 1)

        coordinator.copyItem(item: initialClips[1], dismiss: false)
        let copyNoDismiss = (dismissedCount == 1)

        coordinator.copyItem(item: initialClips[1], dismiss: true)
        let copyWithDismiss = (dismissedCount == 2)

        report(
            name: "ClipboardActionCoordinator correctly triggers onDismiss on selectAndCopy and copyItem(dismiss: true)",
            passed: selectDismissed && copyNoDismiss && copyWithDismiss,
            detail: "dismissedCount=\(dismissedCount)"
        )

        // ==========================================
        // Suite 4: Concurrency & Burst Stress on Copy Writeback
        // ==========================================
        print("\n--- Suite 4: Concurrency & Burst Stress on Copy Writeback ---")

        let concPBName = NSPasteboard.Name("com.superclip.test.conc_pb.\(UUID().uuidString)")
        let concPB = NSPasteboard(name: concPBName)
        let concMonitor = PasteboardMonitor(pasteboard: concPB)
        let concWriter = PasteboardWriter(pasteboard: concPB, monitor: concMonitor)
        let concStorageDir = sandbox.appendingPathComponent("StorageConc")
        let concStorage = StorageManager(baseDirectory: concStorageDir, initialCapacity: 150)
        concMonitor.onNewClip = { item, imgData, thData in
            concStorage.addClip(item: item, imageData: imgData, thumbData: thData)
        }

        // Populate initial clips
        let initialConcClips = (1...10).map { i in
            ClipItem(contentType: .text, textContent: "Seed Clip \(i)", byteSize: 11)
        }
        for c in initialConcClips {
            concStorage.addClip(item: c, imageData: nil, thumbData: nil)
        }
        let concSeedCount = concStorage.items.count

        // 4.1: 100 rapid sequential writeClip operations under burst load
        var burstAllSucceeded = true
        for i in 1...100 {
            let targetClip = initialConcClips[i % initialConcClips.count]
            let ok = concWriter.writeClip(targetClip, storageManager: concStorage)
            if !ok { burstAllSucceeded = false }
            concMonitor.checkNow()
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        report(
            name: "100 rapid sequential writeClip operations succeed and generate 0 duplicates in StorageManager",
            passed: burstAllSucceeded && concStorage.items.count == concSeedCount,
            detail: "succeeded=\(burstAllSucceeded), count=\(concStorage.items.count)/\(concSeedCount)"
        )

        // 4.2: 100 concurrent workers dispatching writeClip through coordinator synchronization
        let syncLock = NSLock()
        let concGroup = DispatchGroup()
        let concQueue = DispatchQueue(label: "com.superclip.conc.test", attributes: .concurrent)
        var synchronizedErrors = 0

        for i in 1...100 {
            let item = initialConcClips[i % initialConcClips.count]
            concGroup.enter()
            concQueue.async {
                syncLock.lock()
                let ok = concWriter.writeClip(item, storageManager: concStorage)
                if !ok { synchronizedErrors += 1 }
                syncLock.unlock()
                concGroup.leave()
            }
        }
        _ = concGroup.wait(timeout: .now() + 5.0)
        concMonitor.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        report(
            name: "100 concurrent workers dispatching writeClip complete with 100% success and 0 duplicates",
            passed: synchronizedErrors == 0 && concStorage.items.count == concSeedCount,
            detail: "errors=\(synchronizedErrors), count=\(concStorage.items.count)/\(concSeedCount)"
        )

        // 4.3: Interleaved concurrent writeClip and checkNow across 200 operations
        let interGroup = DispatchGroup()
        for i in 1...200 {
            interGroup.enter()
            concQueue.async {
                if i % 2 == 0 {
                    let item = initialConcClips[i % initialConcClips.count]
                    syncLock.lock()
                    _ = concWriter.writeClip(item, storageManager: concStorage)
                    syncLock.unlock()
                } else {
                    concMonitor.checkNow()
                }
                interGroup.leave()
            }
        }
        let interWait = interGroup.wait(timeout: .now() + 5.0)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        report(
            name: "200 concurrent interleaved writeClip and checkNow operations complete safely",
            passed: (interWait == .success),
            detail: "waitResult=\(interWait)"
        )

        // 4.4: External copy capture immediately after concurrency burst
        concPB.clearContents()
        concPB.setString("Post Concurrency Clean Input", forType: .string)
        concMonitor.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        let postConcCaptured = concStorage.items.first?.textContent == "Post Concurrency Clean Input"
        report(
            name: "PasteboardMonitor captures external copy immediately after concurrency burst",
            passed: postConcCaptured && concStorage.items.count == concSeedCount + 1,
            detail: "captured=\(postConcCaptured), count=\(concStorage.items.count)"
        )

        // ==========================================
        // Summary Verdict
        // ==========================================
        print("\n==================================================")
        print("  Challenger M3 Execution Summary                 ")
        print("==================================================")
        print("  Total Tests: \(totalTests)")
        print("  Passed:      \(passedTests)")
        print("  Failed:      \(failedTests)")

        if failedTests > 0 {
            print("\nVERDICT: REJECT (Found \(failedTests) failures in adversarial challenge)")
            exit(1)
        } else {
            print("\nVERDICT: APPROVE (All \(passedTests) adversarial challenges passed)")
            exit(0)
        }
    }
}
