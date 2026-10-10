import Foundation
import AppKit
import SuperClipCore

public struct CopyWritebackTests {
    public static func run(sandboxDir: URL) {
        TestHarness.startSuite("Copy-Only Writeback & Concurrency Stress Tests")

        // 1. Baseline single-threaded copy writeback and loop suppression
        runBaselineWritebackTests(sandboxDir: sandboxDir.appendingPathComponent("Baseline"))

        // 2. 100 Concurrent threads performing selectAndCopy with dismissal callback counting
        testConcurrentSelectAndCopyStress(sandboxDir: sandboxDir.appendingPathComponent("ConcSelect"))

        // 3. 100 Concurrent threads performing direct writeClip across text & image payloads
        testConcurrentDirectWriteClipStress(sandboxDir: sandboxDir.appendingPathComponent("ConcWrite"))

        // 4. Concurrent dismissal gating and chaotic action verification
        testConcurrentDismissalGatingStress(sandboxDir: sandboxDir.appendingPathComponent("Gating"))
    }

    // MARK: - Baseline Suite
    private static func runBaselineWritebackTests(sandboxDir: URL) {
        let testPBName = NSPasteboard.Name("com.superclip.test.writeback.\(UUID().uuidString)")
        let testPB = NSPasteboard(name: testPBName)
        let monitor = PasteboardMonitor(pasteboard: testPB)
        let storage = StorageManager(baseDirectory: sandboxDir, initialCapacity: 10)
        let writer = PasteboardWriter(pasteboard: testPB, monitor: monitor)

        var dismissed = false
        let coordinator = ClipboardActionCoordinator(
            storageManager: storage,
            pasteboardWriter: writer,
            onDismiss: { dismissed = true }
        )

        // Text Clip Writeback
        let textItem = ClipItem(id: UUID(), contentType: .text, textContent: "SuperClip Text Writeback", byteSize: 24, isPinned: false)
        storage.addClip(item: textItem, imageData: nil, thumbData: nil)

        dismissed = false
        coordinator.selectAndCopy(item: textItem)
        TestHarness.assertEqual(testPB.string(forType: .string), "SuperClip Text Writeback", "Text payload written to pasteboard accurately")
        TestHarness.assertTrue(dismissed, "onDismiss invoked upon successful text copy")

        // Loop Suppression Verification
        let pollResult = monitor.pollTick()
        TestHarness.assertFalse(pollResult, "PasteboardMonitor suppressed self-copy writeback tick")

        // Followup External Copy Detected
        testPB.clearContents()
        testPB.setString("External Clipboard Input", forType: .string)
        let externalPollResult = monitor.pollTick()
        TestHarness.assertTrue(externalPollResult, "PasteboardMonitor detected external copy after suppression")

        // Image Clip Writeback
        let imgID = UUID()
        let fakePNG = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let imgItem = ClipItem(
            id: imgID,
            contentType: .image,
            imageFileName: "\(imgID.uuidString).png",
            thumbnailFileName: "\(imgID.uuidString)_thumb.png",
            imageWidth: 200,
            imageHeight: 150,
            byteSize: fakePNG.count,
            isPinned: false
        )
        storage.addClip(item: imgItem, imageData: fakePNG, thumbData: nil)

        dismissed = false
        coordinator.selectAndCopy(item: imgItem)
        TestHarness.assertNotNil(testPB.data(forType: .png), "Image payload written to pasteboard as PNG")
        TestHarness.assertTrue(dismissed, "onDismiss invoked upon successful image copy")
        TestHarness.assertFalse(monitor.pollTick(), "Image self-copy writeback suppressed in monitor")

        // Zero Accessibility Permissions Invariant
        TestHarness.assertTrue(testPB.changeCount > 0, "Pasteboard changeCount incremented cleanly without AX privileges")
    }

    // MARK: - Concurrency Stress: selectAndCopy & Dismissal Callbacks
    private static func testConcurrentSelectAndCopyStress(sandboxDir: URL) {
        let testPBName = NSPasteboard.Name("com.superclip.test.conc.select.\(UUID().uuidString)")
        let testPB = NSPasteboard(name: testPBName)
        let monitor = PasteboardMonitor(pasteboard: testPB)
        let writer = PasteboardWriter(pasteboard: testPB, monitor: monitor)
        let storage = StorageManager(baseDirectory: sandboxDir, initialCapacity: 100)

        // Seed storage with 25 distinct items
        var items: [ClipItem] = []
        for i in 1...25 {
            let item = ClipItem(
                id: UUID(),
                contentType: .text,
                textContent: "Concurrent Stress Clip Line \(i)",
                byteSize: 30,
                isPinned: false
            )
            storage.addClip(item: item, imageData: nil, thumbData: nil)
            items.append(item)
        }

        var dismissCallbackCount = 0
        let callbackLock = NSLock()
        let coordinator = ClipboardActionCoordinator(
            storageManager: storage,
            pasteboardWriter: writer,
            onDismiss: {
                callbackLock.lock()
                dismissCallbackCount += 1
                callbackLock.unlock()
            }
        )

        let group = DispatchGroup()
        let queue = DispatchQueue(label: "com.superclip.test.conc.select.queue", attributes: .concurrent)

        for i in 0..<100 {
            let item = items[i % items.count]
            group.enter()
            queue.async {
                coordinator.selectAndCopy(item: item)
                group.leave()
            }
        }

        let waitResult = group.wait(timeout: .now() + 5.0)
        TestHarness.assertEqual(waitResult, .success, "100 concurrent selectAndCopy operations complete within 5s without deadlocks")

        callbackLock.lock()
        let finalCallbacks = dismissCallbackCount
        callbackLock.unlock()

        TestHarness.assertEqual(
            finalCallbacks,
            100,
            "100 concurrent selectAndCopy operations invoke onDismiss exactly 100 times without dropped callbacks"
        )
        TestHarness.assertNotNil(testPB.string(forType: .string), "Pasteboard contains valid text content after concurrent stress")
    }

    // MARK: - Concurrency Stress: Direct writeClip Across Mixed Text & Image Payloads
    private static func testConcurrentDirectWriteClipStress(sandboxDir: URL) {
        let testPBName = NSPasteboard.Name("com.superclip.test.conc.write.\(UUID().uuidString)")
        let testPB = NSPasteboard(name: testPBName)
        let monitor = PasteboardMonitor(pasteboard: testPB)
        let writer = PasteboardWriter(pasteboard: testPB, monitor: monitor)
        let storage = StorageManager(baseDirectory: sandboxDir, initialCapacity: 150)

        let samplePNG = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        var mixedItems: [ClipItem] = []

        // 50 text items and 50 image items
        for i in 1...50 {
            let textItem = ClipItem(id: UUID(), contentType: .text, textContent: "Direct Write Text \(i)", byteSize: 20)
            storage.addClip(item: textItem, imageData: nil, thumbData: nil)
            mixedItems.append(textItem)

            let imgId = UUID()
            let imgItem = ClipItem(
                id: imgId,
                contentType: .image,
                textContent: "Direct Write Image \(i)",
                imageFileName: "\(imgId.uuidString).png",
                thumbnailFileName: "\(imgId.uuidString)_thumb.png",
                imageWidth: 64,
                imageHeight: 64,
                byteSize: samplePNG.count,
                isPinned: false
            )
            storage.addClip(item: imgItem, imageData: samplePNG, thumbData: samplePNG)
            mixedItems.append(imgItem)
        }
        storage.flushDiskQueue()

        var writeErrors = 0
        var writeSuccesses = 0
        let statsLock = NSLock()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "com.superclip.test.conc.write.queue", attributes: .concurrent)

        for i in 0..<100 {
            let item = mixedItems[i]
            group.enter()
            queue.async {
                let success = writer.writeClip(item, storageManager: storage)
                statsLock.lock()
                if success {
                    writeSuccesses += 1
                } else {
                    writeErrors += 1
                }
                statsLock.unlock()
                group.leave()
            }
        }

        let waitResult = group.wait(timeout: .now() + 5.0)
        TestHarness.assertEqual(waitResult, .success, "100 concurrent direct writeClip calls complete without deadlock")

        statsLock.lock()
        let finalSuccess = writeSuccesses
        let finalErrors = writeErrors
        statsLock.unlock()

        TestHarness.assertEqual(finalErrors, 0, "100 concurrent direct writeClip operations execute with zero errors")
        TestHarness.assertEqual(finalSuccess, 100, "100 concurrent direct writeClip operations achieve 100% success rate")

        // Self-copy loop suppression validation after concurrent burst
        let selfCopySuppressed = !monitor.pollTick()
        TestHarness.assertTrue(selfCopySuppressed, "PasteboardMonitor self-copy loop suppression maintained after concurrent write burst")

        // External copy cleanly detected following concurrency burst
        testPB.clearContents()
        testPB.setString("Post-burst external input", forType: .string)
        let externalDetected = monitor.pollTick()
        TestHarness.assertTrue(externalDetected, "PasteboardMonitor captures external clipboard write after concurrent stress")
    }

    // MARK: - Dismissal Gating & Chaotic Interleaved Actions
    private static func testConcurrentDismissalGatingStress(sandboxDir: URL) {
        let testPBName = NSPasteboard.Name("com.superclip.test.conc.gating.\(UUID().uuidString)")
        let testPB = NSPasteboard(name: testPBName)
        let monitor = PasteboardMonitor(pasteboard: testPB)
        let writer = PasteboardWriter(pasteboard: testPB, monitor: monitor)
        let storage = StorageManager(baseDirectory: sandboxDir, initialCapacity: 50)

        let item = ClipItem(id: UUID(), contentType: .text, textContent: "Gating Item", byteSize: 11)
        storage.addClip(item: item, imageData: nil, thumbData: nil)

        // 1. copyItem with dismiss=false fires 0 callbacks across 50 calls
        var dismissCount1 = 0
        let coordinator1 = ClipboardActionCoordinator(
            storageManager: storage,
            pasteboardWriter: writer,
            onDismiss: { dismissCount1 += 1 }
        )
        for _ in 0..<50 {
            coordinator1.copyItem(item: item, dismiss: false)
        }
        TestHarness.assertEqual(dismissCount1, 0, "50 copyItem calls with dismiss=false trigger 0 dismiss callbacks")

        // 2. Failed copy of nonexistent asset does NOT fire onDismiss callback
        var dismissCount2 = 0
        let coordinator2 = ClipboardActionCoordinator(
            storageManager: storage,
            pasteboardWriter: writer,
            onDismiss: { dismissCount2 += 1 }
        )
        let ghostItem = ClipItem(
            id: UUID(),
            contentType: .image,
            textContent: "Ghost Image",
            imageFileName: "missing_\(UUID().uuidString).png",
            thumbnailFileName: nil,
            imageWidth: 50,
            imageHeight: 50,
            byteSize: 0,
            isPinned: false
        )
        coordinator2.selectAndCopy(item: ghostItem)
        TestHarness.assertEqual(dismissCount2, 0, "Failed copy of nonexistent asset does NOT invoke onDismiss callback")

        // 3. 100 Chaotic concurrent interleaved operations
        let chaosGroup = DispatchGroup()
        let chaosQueue = DispatchQueue(label: "com.superclip.test.conc.chaos", attributes: .concurrent)

        for i in 0..<100 {
            chaosGroup.enter()
            chaosQueue.async {
                switch i % 3 {
                case 0:
                    coordinator1.selectAndCopy(item: item)
                case 1:
                    coordinator1.copyItem(item: item, dismiss: false)
                default:
                    coordinator1.togglePin(item: item)
                }
                chaosGroup.leave()
            }
        }
        let chaosWait = chaosGroup.wait(timeout: .now() + 5.0)
        TestHarness.assertEqual(chaosWait, .success, "100 chaotic interleaved operations complete safely without deadlocks")
    }
}
