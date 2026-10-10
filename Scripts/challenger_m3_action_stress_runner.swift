import Foundation
import AppKit
import SwiftUI
import SuperClipCore
import SuperClip

@main
struct ChallengerM3ActionStressRunner {
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
            .appendingPathComponent("SuperClip_ChallengerM3_Action_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        return temp
    }

    static func cleanupTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static func main() {
        print("==================================================")
        print("  SuperClip Challenger M3-2 Action & Writeback   ")
        print("  Target: Writeback, Row Actions, Disk Cleanup    ")
        print("==================================================")

        let sandbox = createTempDirectory()
        defer { cleanupTempDirectory(sandbox) }

        // ==========================================
        // Suite 1: Deep PasteboardWriter Stress
        // ==========================================
        print("\n--- Suite 1: Deep PasteboardWriter Stress ---")

        let pb1Name = NSPasteboard.Name("com.superclip.test.writer1.\(UUID().uuidString)")
        let pb1 = NSPasteboard(name: pb1Name)
        let monitor1 = PasteboardMonitor(pasteboard: pb1)
        let writer1 = PasteboardWriter(pasteboard: pb1, monitor: monitor1)
        let storageDir1 = sandbox.appendingPathComponent("StorageSuite1")
        let storage1 = StorageManager(baseDirectory: storageDir1, initialCapacity: 200)

        // 1.1: Plain text writeback with large payload (1MB)
        let largeText = String(repeating: "SuperClip Pasteboard Writeback Payload Line.\n", count: 25000)
        let largeTextItem = ClipItem(
            id: UUID(),
            contentType: .text,
            textContent: largeText,
            byteSize: largeText.utf8.count,
            isPinned: false
        )
        let writeLargeOk = writer1.writeClip(largeTextItem, storageManager: storage1)
        let readLargeBack = pb1.string(forType: .string)
        report(
            name: "Plain text writeback with 1MB payload writes accurately to NSPasteboard",
            passed: writeLargeOk && readLargeBack == largeText,
            detail: "writeOk=\(writeLargeOk), readMatches=\(readLargeBack == largeText)"
        )

        // 1.2: Plain text writeback suppresses self-copy on pollTick
        let poll1_2 = monitor1.pollTick()
        report(
            name: "Self-copy loop suppression: pollTick returns false after large text writeback",
            passed: !poll1_2,
            detail: "pollResult=\(poll1_2)"
        )

        // 1.3: Multiline Unicode and control characters writeback
        let unicodeText = "Line 1\tTab\u{0000}Null\nLine 2\r\nLine 3 with accents: Cafe resume and symbols."
        let unicodeItem = ClipItem(
            id: UUID(),
            contentType: .text,
            textContent: unicodeText,
            byteSize: unicodeText.utf8.count,
            isPinned: false
        )
        let writeUnicodeOk = writer1.writeClip(unicodeItem, storageManager: storage1)
        let readUnicodeBack = pb1.string(forType: .string)
        report(
            name: "Unicode and control characters written accurately to NSPasteboard",
            passed: writeUnicodeOk && readUnicodeBack == unicodeText
        )

        // 1.4: Item with nil textContent safely returns false without crashing
        let nilTextItem = ClipItem(
            id: UUID(),
            contentType: .text,
            textContent: nil,
            byteSize: 0,
            isPinned: false
        )
        let writeNilTextOk = writer1.writeClip(nilTextItem, storageManager: storage1)
        report(
            name: "Writing text item with nil textContent returns false safely",
            passed: !writeNilTextOk
        )

        // 1.5: Image copy writeback with valid PNG and TIFF data
        let samplePNG = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52])
        let imgID = UUID()
        let imgItem = ClipItem(
            id: imgID,
            contentType: .image,
            textContent: "Image 100x100",
            imageFileName: "\(imgID.uuidString).png",
            thumbnailFileName: "\(imgID.uuidString)_thumb.png",
            imageWidth: 100,
            imageHeight: 100,
            byteSize: samplePNG.count,
            isPinned: false
        )
        storage1.addClip(item: imgItem, imageData: samplePNG, thumbData: nil)
        let writeImgOk = writer1.writeClip(imgItem, storageManager: storage1)
        let readPNGBack = pb1.data(forType: .png)
        let pollImgSuppressed = !monitor1.pollTick()
        report(
            name: "Image writeback populates NSPasteboard PNG data and suppresses pollTick",
            passed: writeImgOk && readPNGBack == samplePNG && pollImgSuppressed,
            detail: "writeOk=\(writeImgOk), pngMatches=\(readPNGBack == samplePNG), suppressed=\(pollImgSuppressed)"
        )

        // 1.6: Image writeback with nil storageManager returns false
        let writeImgNilStorage = writer1.writeClip(imgItem, storageManager: nil)
        report(
            name: "Image writeback with nil storageManager returns false safely",
            passed: !writeImgNilStorage
        )

        // 1.7: Image writeback with missing disk asset returns false
        let missingImgID = UUID()
        let missingImgItem = ClipItem(
            id: missingImgID,
            contentType: .image,
            textContent: "Missing",
            imageFileName: "nonexistent_\(missingImgID.uuidString).png",
            thumbnailFileName: nil,
            imageWidth: 50,
            imageHeight: 50,
            byteSize: 100,
            isPinned: false
        )
        let writeMissingImgOk = writer1.writeClip(missingImgItem, storageManager: storage1)
        report(
            name: "Image writeback with nonexistent asset in storage returns false safely",
            passed: !writeMissingImgOk
        )

        // 1.8: 100 alternating cycles of self-copy followed immediately by external copy
        var alternatingCyclesPassed = true
        var selfSuppressedCount = 0
        var extCapturedCount = 0
        for i in 1...100 {
            let cycleItem = ClipItem(
                id: UUID(),
                contentType: .text,
                textContent: "Self Copy Cycle \(i)",
                byteSize: 20,
                isPinned: false
            )
            let writeOk = writer1.writeClip(cycleItem, storageManager: storage1)
            let selfTick = monitor1.pollTick()
            if writeOk && !selfTick {
                selfSuppressedCount += 1
            } else {
                alternatingCyclesPassed = false
            }

            // Immediately simulate external write
            pb1.clearContents()
            pb1.setString("External Input Cycle \(i)", forType: .string)
            let extTick = monitor1.pollTick()
            if extTick {
                extCapturedCount += 1
            } else {
                alternatingCyclesPassed = false
            }
        }
        report(
            name: "100 alternating cycles: 100% self-copy suppressed, 100% external copy captured",
            passed: alternatingCyclesPassed && selfSuppressedCount == 100 && extCapturedCount == 100,
            detail: "selfSuppressed=\(selfSuppressedCount)/100, extCaptured=\(extCapturedCount)/100"
        )

        // 1.9: Burst of 20 rapid self-copies followed by 20 rapid external copies
        var burstSelfSuppressed = true
        for i in 1...20 {
            let burstItem = ClipItem(contentType: .text, textContent: "Burst Self \(i)", byteSize: 15)
            _ = writer1.writeClip(burstItem, storageManager: storage1)
        }
        // Single poll tick after burst of 20 self-copies must be suppressed
        let burstSelfTick = monitor1.pollTick()
        if burstSelfTick { burstSelfSuppressed = false }

        var burstExtCaptured = 0
        for i in 1...20 {
            pb1.clearContents()
            pb1.setString("Burst External \(i)", forType: .string)
            if monitor1.pollTick() {
                burstExtCaptured += 1
            }
        }
        report(
            name: "Burst of 20 self-copies suppressed and 20 subsequent external copies all captured",
            passed: burstSelfSuppressed && burstExtCaptured == 20,
            detail: "burstSelfSuppressed=\(burstSelfSuppressed), burstExtCaptured=\(burstExtCaptured)/20"
        )

        // 1.10: Zero Accessibility Permissions Invariant
        // Verify pasteboard operations do not check or require AX privileges
        let changeCountBefore = pb1.changeCount
        pb1.clearContents()
        pb1.setString("AX Independence Check", forType: .string)
        let changeCountAfter = pb1.changeCount
        report(
            name: "NSPasteboard operations increment changeCount cleanly without macOS Accessibility privileges",
            passed: changeCountAfter > changeCountBefore
        )

        // ==========================================
        // Suite 2: Rapid Pin Toggling across 100 Items
        // ==========================================
        print("\n--- Suite 2: Rapid Pin Toggling across 100 Items ---")

        let storageDir2 = sandbox.appendingPathComponent("StorageSuite2")
        let storage2 = StorageManager(baseDirectory: storageDir2, initialCapacity: 10)
        let coordinator2 = ClipboardActionCoordinator(
            storageManager: storage2,
            pasteboardWriter: writer1
        )

        // 2.1: Populate storage with 100 distinct items (50 text, 50 images)
        var createdItems: [ClipItem] = []
        for i in 1...100 {
            if i % 2 == 0 {
                let item = ClipItem(
                    id: UUID(),
                    contentType: .text,
                    textContent: "Clip Item \(i)",
                    byteSize: 15,
                    isPinned: false
                )
                storage2.addClip(item: item, imageData: nil, thumbData: nil)
                createdItems.append(item)
            } else {
                let imgId = UUID()
                let item = ClipItem(
                    id: imgId,
                    contentType: .image,
                    textContent: "Image Item \(i)",
                    imageFileName: "\(imgId.uuidString).png",
                    thumbnailFileName: "\(imgId.uuidString)_thumb.png",
                    imageWidth: 80,
                    imageHeight: 80,
                    byteSize: 100,
                    isPinned: false
                )
                let dummyData = Data([0x89, 0x50, 0x4E, 0x47])
                storage2.addClip(item: item, imageData: dummyData, thumbData: dummyData)
                createdItems.append(item)
            }
        }

        // Because initialCapacity is 10 and all were unpinned, only the 10 most recent survive
        let initialSurvivingCount = storage2.items.count
        report(
            name: "Initial population respects unpinned FIFO capacity of 10 items",
            passed: initialSurvivingCount == 10,
            detail: "survivingCount=\(initialSurvivingCount)"
        )

        // 2.2: Re-populate with 100 items by pinning each immediately upon addition
        let storageDir2b = sandbox.appendingPathComponent("StorageSuite2b")
        let storage2b = StorageManager(baseDirectory: storageDir2b, initialCapacity: 10)
        let coordinator2b = ClipboardActionCoordinator(
            storageManager: storage2b,
            pasteboardWriter: writer1
        )

        var pinned100Items: [ClipItem] = []
        for i in 1...100 {
            let item = ClipItem(
                id: UUID(),
                contentType: .text,
                textContent: "Pinned Item \(i)",
                byteSize: 15,
                isPinned: false
            )
            storage2b.addClip(item: item, imageData: nil, thumbData: nil)
            coordinator2b.togglePin(item: item)
            pinned100Items.append(item)
        }

        let all100PinnedSurvive = storage2b.items.count == 100 && storage2b.pinnedItems.count == 100
        report(
            name: "All 100 items pinned upon creation survive despite capacity of 10",
            passed: all100PinnedSurvive,
            detail: "itemsCount=\(storage2b.items.count), pinnedCount=\(storage2b.pinnedItems.count)"
        )

        // 2.3: Rapid pin toggling across all 100 items sequentially
        var pinTogglingSucceeded = true
        // Toggle all 100 from pinned to unpinned
        for item in pinned100Items {
            coordinator2b.togglePin(item: item)
        }
        // Since capacity is 10, unpinning them triggers FIFO eviction down to 10 items
        let countAfterAllUnpinned = storage2b.items.count
        let pinnedAfterAllUnpinned = storage2b.pinnedItems.count
        report(
            name: "Unpinning all 100 items enforces FIFO capacity of 10 unpinned items",
            passed: countAfterAllUnpinned == 10 && pinnedAfterAllUnpinned == 0,
            detail: "totalCount=\(countAfterAllUnpinned), pinnedCount=\(pinnedAfterAllUnpinned)"
        )

        // 2.4: Rapid 500 pin/unpin toggles on the surviving 10 items
        let survivingItems = storage2b.items
        var rapid500Passed = true
        for cycle in 1...500 {
            let target = survivingItems[cycle % survivingItems.count]
            coordinator2b.togglePin(item: target)
        }
        // Verify storage is consistent and contains all 10 items
        let final10Count = storage2b.items.count
        report(
            name: "500 rapid pin/unpin toggles execute without crash or corruption",
            passed: final10Count == 10,
            detail: "finalCount=\(final10Count)"
        )

        // ==========================================
        // Suite 3: Item Deletions & clearUnpinnedHistory Disk Asset Cleanup
        // ==========================================
        print("\n--- Suite 3: Item Deletions & clearUnpinnedHistory Disk Asset Cleanup ---")

        let storageDir3 = sandbox.appendingPathComponent("StorageSuite3")
        let storage3 = StorageManager(baseDirectory: storageDir3, initialCapacity: 100)
        let coordinator3 = ClipboardActionCoordinator(
            storageManager: storage3,
            pasteboardWriter: writer1
        )

        // Create 50 pinned image items and 50 unpinned image items with real disk files
        var pinnedImageItems: [ClipItem] = []
        var unpinnedImageItems: [ClipItem] = []

        let dummyPNG = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let dummyThumb = Data([0x89, 0x50, 0x4E, 0x47])

        for i in 1...50 {
            let id = UUID()
            let item = ClipItem(
                id: id,
                contentType: .image,
                textContent: "Pinned Image \(i)",
                imageFileName: "pinned_\(id.uuidString).png",
                thumbnailFileName: "pinned_\(id.uuidString)_thumb.png",
                imageWidth: 100,
                imageHeight: 100,
                byteSize: dummyPNG.count,
                isPinned: true
            )
            storage3.addClip(item: item, imageData: dummyPNG, thumbData: dummyThumb)
            pinnedImageItems.append(item)
        }

        for i in 1...50 {
            let id = UUID()
            let item = ClipItem(
                id: id,
                contentType: .image,
                textContent: "Unpinned Image \(i)",
                imageFileName: "unpinned_\(id.uuidString).png",
                thumbnailFileName: "unpinned_\(id.uuidString)_thumb.png",
                imageWidth: 100,
                imageHeight: 100,
                byteSize: dummyPNG.count,
                isPinned: false
            )
            storage3.addClip(item: item, imageData: dummyPNG, thumbData: dummyThumb)
            unpinnedImageItems.append(item)
        }

        // Flush disk queue to ensure all 100 writes completed
        storage3.flushDiskQueue()

        // Verify disk files exist before clearing
        let fm = FileManager.default
        var preCheckOk = true
        for item in unpinnedImageItems {
            let imgURL = storage3.imagesDirectory.appendingPathComponent(item.imageFileName!)
            let thURL = storage3.thumbnailsDirectory.appendingPathComponent(item.thumbnailFileName!)
            if !fm.fileExists(atPath: imgURL.path) || !fm.fileExists(atPath: thURL.path) {
                preCheckOk = false
            }
        }
        for item in pinnedImageItems {
            let imgURL = storage3.imagesDirectory.appendingPathComponent(item.imageFileName!)
            let thURL = storage3.thumbnailsDirectory.appendingPathComponent(item.thumbnailFileName!)
            if !fm.fileExists(atPath: imgURL.path) || !fm.fileExists(atPath: thURL.path) {
                preCheckOk = false
            }
        }
        report(
            name: "Pre-clear: All 100 image blobs and thumbnails exist on disk",
            passed: preCheckOk && storage3.items.count == 100
        )

        // 3.1: Execute clearUnpinnedHistory()
        coordinator3.clearUnpinned()
        storage3.flushDiskQueue()

        // 3.2: Verify memory state
        let memoryCleanedOk = (storage3.items.count == 50) && (storage3.historyItems.count == 0) && (storage3.pinnedItems.count == 50)
        report(
            name: "clearUnpinnedHistory removes all 50 unpinned items from memory, retaining all 50 pinned items",
            passed: memoryCleanedOk,
            detail: "total=\(storage3.items.count), pinned=\(storage3.pinnedItems.count), history=\(storage3.historyItems.count)"
        )

        // 3.3: Verify disk cleanup: All unpinned assets removed
        var unpinnedFilesCleaned = true
        var unpinnedFilesRemaining = 0
        for item in unpinnedImageItems {
            let imgURL = storage3.imagesDirectory.appendingPathComponent(item.imageFileName!)
            let thURL = storage3.thumbnailsDirectory.appendingPathComponent(item.thumbnailFileName!)
            if fm.fileExists(atPath: imgURL.path) || fm.fileExists(atPath: thURL.path) {
                unpinnedFilesCleaned = false
                unpinnedFilesRemaining += 1
            }
        }
        report(
            name: "clearUnpinnedHistory deletes all 50 unpinned image blobs and thumbnails from disk",
            passed: unpinnedFilesCleaned,
            detail: "unpinnedRemainingCount=\(unpinnedFilesRemaining)"
        )

        // 3.4: Verify pinned disk assets remain completely intact
        var pinnedFilesIntact = true
        var pinnedFilesMissing = 0
        for item in pinnedImageItems {
            let imgURL = storage3.imagesDirectory.appendingPathComponent(item.imageFileName!)
            let thURL = storage3.thumbnailsDirectory.appendingPathComponent(item.thumbnailFileName!)
            if !fm.fileExists(atPath: imgURL.path) || !fm.fileExists(atPath: thURL.path) {
                pinnedFilesIntact = false
                pinnedFilesMissing += 1
            }
        }
        report(
            name: "clearUnpinnedHistory strictly preserves all 50 pinned image blobs and thumbnails on disk",
            passed: pinnedFilesIntact,
            detail: "pinnedMissingCount=\(pinnedFilesMissing)"
        )

        // 3.5: Rapid item deletions: delete 25 pinned items individually
        for i in 0..<25 {
            let item = pinnedImageItems[i]
            coordinator3.deleteItem(item: item)
        }
        storage3.flushDiskQueue()

        var deletedFilesCleaned = true
        for i in 0..<25 {
            let item = pinnedImageItems[i]
            let imgURL = storage3.imagesDirectory.appendingPathComponent(item.imageFileName!)
            let thURL = storage3.thumbnailsDirectory.appendingPathComponent(item.thumbnailFileName!)
            if fm.fileExists(atPath: imgURL.path) || fm.fileExists(atPath: thURL.path) {
                deletedFilesCleaned = false
            }
        }
        var remaining25Intact = true
        for i in 25..<50 {
            let item = pinnedImageItems[i]
            let imgURL = storage3.imagesDirectory.appendingPathComponent(item.imageFileName!)
            let thURL = storage3.thumbnailsDirectory.appendingPathComponent(item.thumbnailFileName!)
            if !fm.fileExists(atPath: imgURL.path) || !fm.fileExists(atPath: thURL.path) {
                remaining25Intact = false
            }
        }
        report(
            name: "25 individual item deletions remove disk assets cleanly while leaving other 25 intact",
            passed: storage3.items.count == 25 && deletedFilesCleaned && remaining25Intact,
            detail: "storageCount=\(storage3.items.count), deletedCleaned=\(deletedFilesCleaned), remainingIntact=\(remaining25Intact)"
        )

        // 3.6: Deleting non-existent UUID executes harmlessly
        let fakeItem = ClipItem(id: UUID(), contentType: .text, textContent: "Ghost", byteSize: 5)
        coordinator3.deleteItem(item: fakeItem)
        report(
            name: "Deleting nonexistent item executes harmlessly without altering storage count",
            passed: storage3.items.count == 25
        )

        // ==========================================
        // Suite 4: Concurrent Selection/Copy & Window Dismissal Callbacks
        // ==========================================
        print("\n--- Suite 4: Concurrent Selection/Copy & Window Dismissal Callbacks ---")

        let concPB4Name = NSPasteboard.Name("com.superclip.test.conc4.\(UUID().uuidString)")
        let concPB4 = NSPasteboard(name: concPB4Name)
        let concMonitor4 = PasteboardMonitor(pasteboard: concPB4)
        let concWriter4 = PasteboardWriter(pasteboard: concPB4, monitor: concMonitor4)
        let storageDir4 = sandbox.appendingPathComponent("StorageSuite4")
        let storage4 = StorageManager(baseDirectory: storageDir4, initialCapacity: 100)

        // Add 50 items to storage
        var items4: [ClipItem] = []
        for i in 1...50 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Concurrency Clip \(i)", byteSize: 20)
            storage4.addClip(item: item, imageData: nil, thumbData: nil)
            items4.append(item)
        }

        // 4.1: 100 Concurrent threads performing selectAndCopy with dismissal callback counting
        var dismissCallbackCount4_1 = 0
        let callbackLock4_1 = NSLock()
        let coordinator4_1 = ClipboardActionCoordinator(
            storageManager: storage4,
            pasteboardWriter: concWriter4,
            onDismiss: {
                callbackLock4_1.lock()
                dismissCallbackCount4_1 += 1
                callbackLock4_1.unlock()
            }
        )

        let group4_1 = DispatchGroup()
        let queue4_1 = DispatchQueue(label: "com.superclip.select.copy.stress", attributes: .concurrent)

        for i in 0..<100 {
            let item = items4[i % items4.count]
            group4_1.enter()
            queue4_1.async {
                coordinator4_1.selectAndCopy(item: item)
                group4_1.leave()
            }
        }
        _ = group4_1.wait(timeout: .now() + 5.0)

        callbackLock4_1.lock()
        let finalCallbacks4_1 = dismissCallbackCount4_1
        callbackLock4_1.unlock()

        report(
            name: "100 concurrent selectAndCopy operations invoke onDismiss exactly 100 times without data race",
            passed: finalCallbacks4_1 == 100,
            detail: "callbacks=\(finalCallbacks4_1)/100"
        )

        // 4.2: copyItem(item, dismiss: false) fires ZERO dismissal callbacks
        var dismissCallbackCount4_2 = 0
        let coordinator4_2 = ClipboardActionCoordinator(
            storageManager: storage4,
            pasteboardWriter: concWriter4,
            onDismiss: { dismissCallbackCount4_2 += 1 }
        )
        for i in 0..<50 {
            coordinator4_2.copyItem(item: items4[i], dismiss: false)
        }
        report(
            name: "50 copyItem calls with dismiss=false trigger 0 dismiss callbacks",
            passed: dismissCallbackCount4_2 == 0,
            detail: "dismissCallbacks=\(dismissCallbackCount4_2)"
        )

        // 4.3: Failed copy (corrupt image or missing asset) does NOT invoke onDismiss
        var dismissCallbackCount4_3 = 0
        let coordinator4_3 = ClipboardActionCoordinator(
            storageManager: storage4,
            pasteboardWriter: concWriter4,
            onDismiss: { dismissCallbackCount4_3 += 1 }
        )
        let corruptImageItem = ClipItem(
            id: UUID(),
            contentType: .image,
            textContent: "Corrupt",
            imageFileName: "nonexistent.png",
            thumbnailFileName: nil,
            imageWidth: 10,
            imageHeight: 10,
            byteSize: 0,
            isPinned: false
        )
        coordinator4_3.selectAndCopy(item: corruptImageItem)
        report(
            name: "Failed copy of nonexistent asset does NOT invoke onDismiss callback",
            passed: dismissCallbackCount4_3 == 0,
            detail: "dismissCallbacks=\(dismissCallbackCount4_3)"
        )

        // 4.4: 200 Interleaved chaotic concurrent operations: selectAndCopy, copyItem, togglePin, deleteItem
        let chaosGroup = DispatchGroup()
        let chaosQueue = DispatchQueue(label: "com.superclip.chaos.actions", attributes: .concurrent)
        var chaosDismissCount = 0
        let chaosLock = NSLock()

        let chaosCoordinator = ClipboardActionCoordinator(
            storageManager: storage4,
            pasteboardWriter: concWriter4,
            onDismiss: {
                chaosLock.lock()
                chaosDismissCount += 1
                chaosLock.unlock()
            }
        )

        for i in 0..<200 {
            let item = items4[i % items4.count]
            chaosGroup.enter()
            chaosQueue.async {
                switch i % 4 {
                case 0:
                    chaosCoordinator.selectAndCopy(item: item)
                case 1:
                    chaosCoordinator.copyItem(item: item, dismiss: false)
                case 2:
                    chaosCoordinator.togglePin(item: item)
                default:
                    // Rapid delete and re-add to maintain item pool
                    chaosCoordinator.deleteItem(item: item)
                    storage4.addClip(item: item, imageData: nil, thumbData: nil)
                }
                chaosGroup.leave()
            }
        }
        let chaosWait = chaosGroup.wait(timeout: .now() + 5.0)
        report(
            name: "200 chaotic concurrent interleaved actions complete safely without deadlocks or crashes",
            passed: chaosWait == .success,
            detail: "waitResult=\(chaosWait)"
        )

        // ==========================================
        // Summary Verdict
        // ==========================================
        print("\n==================================================")
        print("  Challenger M3-2 Execution Summary               ")
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
