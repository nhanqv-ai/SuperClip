import Foundation
import CoreGraphics
import ImageIO
import AppKit
import SwiftUI
import SuperClipCore
import SuperClip

@main
public struct AdversarialChallengeRunner {
    public static func main() {
        print("==================================================")
        print("  SuperClip Adversarial Challenge Test Harness    ")
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
        // 1. PasteboardMonitor Adversarial Challenges
        // ==========================================
        print("\n--- Suite 1: PasteboardMonitor Adversarial Challenges ---")

        // Challenge 1.1: pollTick() self-copy suppression drops subsequent external copy
        let pb1 = NSPasteboard.withUniqueName()
        let monitor1 = PasteboardMonitor(pasteboard: pb1)
        pb1.clearContents()
        pb1.setString("Self Write 1", forType: .string)
        let sc1 = pb1.changeCount
        monitor1.markSelfCopy(newChangeCount: sc1)
        let tickSelf = monitor1.pollTick()
        report(
            name: "PasteboardMonitor suppresses self-copy on pollTick",
            passed: (tickSelf == false),
            detail: "Expected false, got \(tickSelf)"
        )

        pb1.clearContents()
        pb1.setString("Legitimate External Copy 1", forType: .string)
        let tickExt = monitor1.pollTick()
        report(
            name: "PasteboardMonitor captures external copy following self-copy in pollTick",
            passed: (tickExt == true),
            detail: "CRITICAL BUG: pollTick returned false because isSuppressed was not cleared on self count"
        )

        // Challenge 1.2: Rapid external copy immediately following markSelfCopy before checkPasteboard
        let pb2 = NSPasteboard.withUniqueName()
        let monitor2 = PasteboardMonitor(pasteboard: pb2)
        var capturedClips2: [ClipItem] = []
        monitor2.onNewClip = { item, _, _ in
            capturedClips2.append(item)
        }
        pb2.clearContents()
        pb2.setString("Self Write 2", forType: .string)
        let sc2 = pb2.changeCount
        monitor2.markSelfCopy(newChangeCount: sc2)
        // Rapid external write happens before checkPasteboard runs
        pb2.clearContents()
        pb2.setString("Rapid External Write 2", forType: .string)
        monitor2.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        report(
            name: "PasteboardMonitor does not drop rapid external copy after markSelfCopy in checkNow",
            passed: (capturedClips2.count == 1),
            detail: "BUG: checkNow dropped rapid external change (captured \(capturedClips2.count) clips)"
        )

        // Challenge 1.3: Image hash collision on middle-payload modifications
        let pb3 = NSPasteboard.withUniqueName()
        let monitor3 = PasteboardMonitor(pasteboard: pb3)
        var capturedClips3: [ClipItem] = []
        monitor3.onNewClip = { item, _, _ in
            capturedClips3.append(item)
        }

        let repImgA = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 64,
            pixelsHigh: 64,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 256,
            bitsPerPixel: 32
        )!
        var imgDataA = repImgA.representation(using: .png, properties: [:])!
        if imgDataA.count < 3000 {
            imgDataA.append(Data(repeating: 0x00, count: 3000 - imgDataA.count))
        }
        var imgDataB = imgDataA
        for i in 600..<800 {
            imgDataB[i] = 0xAA
        }

        pb3.clearContents()
        pb3.setData(imgDataA, forType: .png)
        monitor3.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        pb3.clearContents()
        pb3.setData(imgDataB, forType: .png)
        monitor3.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        report(
            name: "PasteboardMonitor detects distinct images sharing prefix/suffix",
            passed: (capturedClips3.count == 2),
            detail: "BUG: False duplicate suppression dropped distinct image due to 512-byte edge hashing"
        )

        // Challenge 1.4: Rapid 50 distinct text copies under burst load
        let pb4 = NSPasteboard.withUniqueName()
        let monitor4 = PasteboardMonitor(pasteboard: pb4)
        var capturedClips4: [ClipItem] = []
        monitor4.onNewClip = { item, _, _ in
            capturedClips4.append(item)
        }
        for i in 1...50 {
            pb4.clearContents()
            pb4.setString("Burst Item \(i)", forType: .string)
            monitor4.checkNow()
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.4))
        report(
            name: "PasteboardMonitor captures all 50 sequential burst text clips",
            passed: (capturedClips4.count == 50),
            detail: "Captured \(capturedClips4.count) of 50"
        )

        // ==========================================
        // 2. ThumbnailGenerator Adversarial Challenges
        // ==========================================
        print("\n--- Suite 2: ThumbnailGenerator Adversarial Challenges ---")

        // Challenge 2.1: Malformed and truncated inputs
        let corruptData = Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0x00, 0xFF])
        let malformedThumb = ThumbnailGenerator.generateThumbnail(from: corruptData, maxPixelSize: 180)
        report(
            name: "ThumbnailGenerator safely returns nil on corrupt PNG header",
            passed: (malformedThumb == nil)
        )

        let htmlBytes = "<!DOCTYPE html><html><body><h1>Fake Image</h1></body></html>".data(using: .utf8)!
        let htmlThumb = ThumbnailGenerator.generateThumbnail(from: htmlBytes, maxPixelSize: 180)
        report(
            name: "ThumbnailGenerator safely returns nil on HTML payload",
            passed: (htmlThumb == nil)
        )

        let zeroBytes = Data()
        let zeroThumb = ThumbnailGenerator.generateThumbnail(from: zeroBytes, maxPixelSize: 180)
        report(
            name: "ThumbnailGenerator safely returns nil on 0-byte input",
            passed: (zeroThumb == nil)
        )

        // Challenge 2.2: Extreme aspect ratio images
        let tallRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 1,
            pixelsHigh: 4000,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 4,
            bitsPerPixel: 32
        )!
        let tallData = tallRep.representation(using: .png, properties: [:])!
        let tallThumb = ThumbnailGenerator.generateThumbnail(from: tallData, maxPixelSize: 180)
        let tallDims = tallThumb.flatMap { ThumbnailGenerator.extractDimensions(from: $0) }
        report(
            name: "ThumbnailGenerator handles 1x4000 ribbon without crash or division by zero",
            passed: (tallDims?.width == 1 && tallDims?.height == 180),
            detail: "Got dims: \(String(describing: tallDims))"
        )

        let wideRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 4000,
            pixelsHigh: 1,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 4000 * 4,
            bitsPerPixel: 32
        )!
        let wideData = wideRep.representation(using: .png, properties: [:])!
        let wideThumb = ThumbnailGenerator.generateThumbnail(from: wideData, maxPixelSize: 180)
        let wideDims = wideThumb.flatMap { ThumbnailGenerator.extractDimensions(from: $0) }
        report(
            name: "ThumbnailGenerator handles 4000x1 ribbon without crash or distortion",
            passed: (wideDims?.width == 180 && wideDims?.height == 1),
            detail: "Got dims: \(String(describing: wideDims))"
        )

        // Challenge 2.3: Micro image (1x1)
        let microRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 1,
            pixelsHigh: 1,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 4,
            bitsPerPixel: 32
        )!
        let microData = microRep.representation(using: .png, properties: [:])!
        let microThumb = ThumbnailGenerator.generateThumbnail(from: microData, maxPixelSize: 180)
        let microDims = microThumb.flatMap { ThumbnailGenerator.extractDimensions(from: $0) }
        report(
            name: "ThumbnailGenerator handles 1x1 micro image",
            passed: (microDims?.width == 1 && microDims?.height == 1),
            detail: "Got dims: \(String(describing: microDims))"
        )

        // Challenge 2.4: Huge image payload (4000x4000 pixels = 16 Megapixels)
        let hugeRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 4000,
            pixelsHigh: 4000,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 4000 * 4,
            bitsPerPixel: 32
        )!
        let hugeData = hugeRep.representation(using: .png, properties: [:])!
        let startHuge = CFAbsoluteTimeGetCurrent()
        let hugeThumb = ThumbnailGenerator.generateThumbnail(from: hugeData, maxPixelSize: 180)
        let durHuge = CFAbsoluteTimeGetCurrent() - startHuge
        let hugeDims = hugeThumb.flatMap { ThumbnailGenerator.extractDimensions(from: $0) }
        report(
            name: "ThumbnailGenerator downscales 16MP image rapidly (< 1.0s)",
            passed: (hugeDims?.width == 180 && hugeDims?.height == 180 && durHuge < 1.0),
            detail: "Time: \(durHuge)s, dims: \(String(describing: hugeDims))"
        )

        // Challenge 2.5: Zero and negative maxPixelSize bounds
        let normalRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 200,
            pixelsHigh: 200,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 800,
            bitsPerPixel: 32
        )!
        let normalData = normalRep.representation(using: .png, properties: [:])!
        let zeroBoundThumb = ThumbnailGenerator.generateThumbnail(from: normalData, maxPixelSize: 0)
        let zeroDims = zeroBoundThumb.flatMap { ThumbnailGenerator.extractDimensions(from: $0) }
        // CoreGraphics behavior on 0 maxPixelSize is unscaled full size
        report(
            name: "ThumbnailGenerator does not crash on maxPixelSize = 0",
            passed: (zeroBoundThumb != nil),
            detail: "Result dims: \(String(describing: zeroDims))"
        )

        // ==========================================
        // 3. SearchEngine Adversarial Challenges
        // ==========================================
        print("\n--- Suite 3: SearchEngine Adversarial Challenges ---")

        // Challenge 3.1: Regex metacharacters treated literally without crashes
        let regexItem = ClipItem(
            contentType: .text,
            textContent: "Special characters: .* and [a-z]+ and \\d+ and (foo) and ^start$ and $end and \\",
            byteSize: 85
        )
        report(
            name: "SearchEngine matches literal '.*' substring",
            passed: SearchEngine.matches(item: regexItem, query: ".*")
        )
        report(
            name: "SearchEngine matches literal '[a-z]+' substring",
            passed: SearchEngine.matches(item: regexItem, query: "[a-z]+")
        )
        report(
            name: "SearchEngine matches literal '\\d+' substring",
            passed: SearchEngine.matches(item: regexItem, query: "\\d+")
        )
        report(
            name: "SearchEngine matches literal '\\' single backslash",
            passed: SearchEngine.matches(item: regexItem, query: "\\")
        )

        let plainItem = ClipItem(contentType: .text, textContent: "Simple text payload without regex symbols", byteSize: 42)
        report(
            name: "SearchEngine does not falsely match plain text with '.*' regex query",
            passed: !SearchEngine.matches(item: plainItem, query: ".*")
        )
        report(
            name: "SearchEngine does not falsely match plain text with '[a-z]+' regex query",
            passed: !SearchEngine.matches(item: plainItem, query: "[a-z]+")
        )

        // Challenge 3.2: Unicode normalization & diacritic folding
        let precomposedItem = ClipItem(contentType: .text, textContent: "Visit Café SuperClip today", byteSize: 28)
        report(
            name: "SearchEngine matches accented café with unaccented query 'cafe'",
            passed: SearchEngine.matches(item: precomposedItem, query: "cafe")
        )
        let decomposedQuery = "cafe\u{0301}"
        report(
            name: "SearchEngine matches precomposed text with decomposed query",
            passed: SearchEngine.matches(item: precomposedItem, query: decomposedQuery)
        )

        // Challenge 3.3: CJK and Right-to-Left Arabic
        let cjkItem = ClipItem(contentType: .text, textContent: "日本語 クリップボード 中文 测试 한국어 클립", byteSize: 55)
        report(
            name: "SearchEngine matches Japanese Kanji query",
            passed: SearchEngine.matches(item: cjkItem, query: "日本語")
        )
        report(
            name: "SearchEngine matches Korean Hangul query",
            passed: SearchEngine.matches(item: cjkItem, query: "한국어")
        )
        let arabicItem = ClipItem(contentType: .text, textContent: "حافظة النصوص سوبر كليب للمستخدم", byteSize: 45)
        report(
            name: "SearchEngine matches Arabic RTL query",
            passed: SearchEngine.matches(item: arabicItem, query: "سوبر")
        )

        // Challenge 3.4: Control characters and null bytes
        let ctrlItem = ClipItem(contentType: .text, textContent: "Line one\nLine two\tTabbed\0Null", byteSize: 30)
        report(
            name: "SearchEngine matches substring containing newline",
            passed: SearchEngine.matches(item: ctrlItem, query: "one\nLine")
        )
        report(
            name: "SearchEngine matches null byte literally",
            passed: SearchEngine.matches(item: ctrlItem, query: "\0")
        )

        // Challenge 3.5: Large dataset throughput (50,000 items)
        var dataset: [ClipItem] = []
        dataset.reserveCapacity(50000)
        for i in 0..<50000 {
            dataset.append(ClipItem(
                contentType: .text,
                textContent: "Record \(i): system event log audit for module alpha",
                byteSize: 60,
                isPinned: (i % 200 == 0)
            ))
        }

        let startFilter = CFAbsoluteTimeGetCurrent()
        let filterResults = SearchEngine.filter(items: dataset, query: "Record 49999")
        let filterDuration = CFAbsoluteTimeGetCurrent() - startFilter
        report(
            name: "SearchEngine filters 50,000 items in under 1.5 seconds",
            passed: (filterResults.count == 1 && filterDuration < 1.5),
            detail: "Matches: \(filterResults.count), Duration: \(filterDuration)s"
        )

        let startPart = CFAbsoluteTimeGetCurrent()
        let partResults = SearchEngine.partition(items: dataset, query: "audit")
        let partDuration = CFAbsoluteTimeGetCurrent() - startPart
        report(
            name: "SearchEngine partitions 50,000 items in under 1.5 seconds",
            passed: (partResults.pinned.count == 250 && partResults.recent.count == 49750 && partDuration < 1.5),
            detail: "Pinned: \(partResults.pinned.count), Recent: \(partResults.recent.count), Duration: \(partDuration)s"
        )

        // ==========================================
        // 4. Presentation & Concurrency Adversarial Challenges
        // ==========================================
        print("\n--- Suite 4: Presentation & Concurrency Adversarial Challenges ---")

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        // Challenge 4.1: Rapid 100-cycle present() and dismiss() lifecycle
        let panel4_1 = FloatingClipPanel(rootView: Text("Cycle Test"))
        var dismissCount4_1 = 0
        panel4_1.onDismiss = { dismissCount4_1 += 1 }

        var cyclePassed4_1 = true
        var monitorLeak4_1 = false
        for i in 1...100 {
            panel4_1.present(at: NSRect(x: 100 + Double(i), y: 100 + Double(i), width: 360, height: 480))
            if !panel4_1.isVisible || !panel4_1.hasActiveMonitors {
                cyclePassed4_1 = false
            }
            panel4_1.dismiss()
            if panel4_1.isVisible {
                cyclePassed4_1 = false
            }
            if panel4_1.hasActiveMonitors {
                monitorLeak4_1 = true
            }
        }
        // Extra dismiss calls should be idempotent
        panel4_1.dismiss()
        panel4_1.dismiss()

        report(
            name: "FloatingClipPanel completes 100 sequential present/dismiss cycles with clean monitor teardown",
            passed: (cyclePassed4_1 && !monitorLeak4_1 && dismissCount4_1 == 100),
            detail: "cyclePassed: \(cyclePassed4_1), monitorLeak: \(monitorLeak4_1), dismissCount: \(dismissCount4_1)/100"
        )

        // Challenge 4.2: Retain cycle and memory deallocation under ARC
        weak var weakPanel4_2: FloatingClipPanel?
        autoreleasepool {
            let panel = FloatingClipPanel(rootView: Text("Retain Test"))
            weakPanel4_2 = panel
            panel.present(at: NSRect(x: 150, y: 150, width: 360, height: 480))
            panel.dismiss()
        }
        report(
            name: "FloatingClipPanel has zero retain cycles and deallocates cleanly after dismissal",
            passed: (weakPanel4_2 == nil),
            detail: "weakPanel was not nil after autoreleasepool drain: \(String(describing: weakPanel4_2))"
        )

        // Challenge 4.3: StatusItemManager debounce thresholds (100ms, 200ms, 240ms, 260ms, 300ms)
        let vc4_3 = NSViewController()
        vc4_3.view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 480))
        let manager4_3 = StatusItemManager(contentViewController: vc4_3)

        let debounceIntervals: [(Double, Bool)] = [
            (0.100, false), // 100ms: debounced
            (0.200, false), // 200ms: debounced
            (0.240, false), // 240ms: debounced
            (0.260, true),  // 260ms: allowed
            (0.300, true)   // 300ms: allowed
        ]

        var debouncePassed = true
        var debounceDetail = ""
        for (interval, shouldShow) in debounceIntervals {
            var showFired = false
            manager4_3.onPopoverVisibilityChanged = { visible in
                if visible { showFired = true }
            }
            let fakeCloseTime = ProcessInfo.processInfo.systemUptime - interval
            manager4_3.setLastPopoverCloseTimestampForTesting(fakeCloseTime)
            manager4_3.statusItemClicked(nil)

            if showFired != shouldShow {
                debouncePassed = false
                debounceDetail += "[\(Int(interval * 1000))ms: got \(showFired), expected \(shouldShow)] "
            }
            manager4_3.closePopover()
        }
        report(
            name: "StatusItemManager strictly enforces 250ms debounce boundary across 100ms, 200ms, 240ms, 260ms, 300ms",
            passed: debouncePassed,
            detail: debounceDetail
        )

        // Challenge 4.4: Dual Presentation Mutual Exclusion Invariant
        // When NSPopover is active, triggering HotKey must dismiss popover BEFORE floating panel is visible.
        let hostWindow4_4 = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 400, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        let hostView4_4 = NSView(frame: NSRect(x: 50, y: 50, width: 100, height: 100))
        hostWindow4_4.contentView?.addSubview(hostView4_4)
        hostWindow4_4.orderFront(nil)

        let panel4_4 = FloatingClipPanel(rootView: Text("Mutual Exclusion"))
        let vc4_4 = NSViewController()
        vc4_4.view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 480))
        let manager4_4 = StatusItemManager(contentViewController: vc4_4, floatingPanel: panel4_4)

        // Display popover using host view so isShown is genuinely true
        manager4_4.popover.show(relativeTo: hostView4_4.bounds, of: hostView4_4, preferredEdge: .minY)
        let popoverInitiallyShown = manager4_4.popover.isShown

        // Trigger HotKey
        manager4_4.handleHotKeyTrigger()

        let popoverStillShown = manager4_4.popover.isShown
        let panelNowVisible = panel4_4.isVisible
        let mutualExclusionViolated = popoverStillShown && panelNowVisible

        report(
            name: "StatusItemManager guarantees mutual exclusion: Popover is not visible when FloatingClipPanel opens",
            passed: (popoverInitiallyShown && !mutualExclusionViolated),
            detail: "CRITICAL BUG: popoverInitiallyShown=\(popoverInitiallyShown), popoverStillShown=\(popoverStillShown), panelNowVisible=\(panelNowVisible). Both Popover and Panel are simultaneously visible due to asynchronous popover animation."
        )

        panel4_4.dismiss()
        hostWindow4_4.orderOut(nil)

        // Challenge 4.5: Escape Key window-level dismissal
        let panel4_5 = FloatingClipPanel(rootView: Text("Escape Test"))
        panel4_5.present(at: NSRect(x: 200, y: 200, width: 360, height: 480))
        let visibleBeforeEsc = panel4_5.isVisible
        if let escEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: panel4_5.windowNumber,
            context: nil,
            characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}",
            isARepeat: false,
            keyCode: 53
        ) {
            panel4_5.sendEvent(escEvent)
        }
        report(
            name: "FloatingClipPanel intercepts Escape key and dismisses immediately",
            passed: (visibleBeforeEsc && !panel4_5.isVisible && !panel4_5.hasActiveMonitors)
        )

        // Challenge 4.6: Concurrent multi-threaded presentation stress
        let panel4_6 = FloatingClipPanel(rootView: Text("Concurrency Test"))
        let group4_6 = DispatchGroup()
        for i in 1...100 {
            group4_6.enter()
            DispatchQueue.global().async {
                if i % 2 == 0 {
                    panel4_6.present(at: NSRect(x: 100, y: 100, width: 360, height: 480))
                } else {
                    panel4_6.dismiss()
                }
                group4_6.leave()
            }
        }
        group4_6.wait()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        panel4_6.dismiss()
        report(
            name: "FloatingClipPanel survives 100 concurrent multi-threaded present/dismiss calls without crash or deadlock",
            passed: (!panel4_6.isVisible && !panel4_6.hasActiveMonitors)
        )

        // Challenge 4.7: High-frequency rapid hotkey bursts (50 toggle triggers)
        final class BurstPresenter: FloatingPanelPresenting {
            var isVisible: Bool = false
            var isKeyWindow: Bool = false
            var showCount: Int = 0
            var dismissCount: Int = 0
            func show(near mouseLocation: NSPoint) {
                isVisible = true
                isKeyWindow = true
                showCount += 1
            }
            func dismiss() {
                isVisible = false
                isKeyWindow = false
                dismissCount += 1
            }
        }
        let burstPresenter = BurstPresenter()
        final class MockHotKeySource: HotKeyManaging {
            var onTrigger: (() -> Void)?
            func register(keyCode: UInt32, modifiers: UInt32) {}
            func unregister() {}
        }
        let mockHotKeySource = MockHotKeySource()
        let burstManager = StatusItemManager(floatingPanel: burstPresenter, hotKeyManager: mockHotKeySource)

        var toggleMismatchCount = 0
        for i in 1...50 {
            burstManager.handleHotKeyTrigger()
            let expectedVisible = (i % 2 == 1)
            if burstPresenter.isVisible != expectedVisible {
                toggleMismatchCount += 1
            }
        }
        report(
            name: "StatusItemManager handles 50 rapid sequential hotkey toggle triggers with clean alternating states",
            passed: (toggleMismatchCount == 0 && burstPresenter.showCount == 25 && burstPresenter.dismissCount == 25 && !burstPresenter.isVisible),
            detail: "Mismatches: \(toggleMismatchCount), shows: \(burstPresenter.showCount), dismisses: \(burstPresenter.dismissCount)"
        )

        // Challenge 4.8: 50 high-frequency concurrent hotkey bursts from background threads
        let bgGroup = DispatchGroup()
        let bgQueue = DispatchQueue(label: "burst.concurrent", attributes: .concurrent)
        for _ in 1...50 {
            bgGroup.enter()
            bgQueue.async {
                mockHotKeySource.onTrigger?()
                bgGroup.leave()
            }
        }
        bgGroup.wait()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        report(
            name: "StatusItemManager processes 50 concurrent hotkey bursts from background threads without deadlocks",
            passed: (burstPresenter.showCount == 50 && burstPresenter.dismissCount == 50 && !burstPresenter.isVisible),
            detail: "Final shows: \(burstPresenter.showCount), dismisses: \(burstPresenter.dismissCount), isVisible: \(burstPresenter.isVisible)"
        )

        // Challenge 4.9: 100 alternating presentation cycles (Mutual Exclusion Invariant)
        let mutualPresenter = BurstPresenter()
        let mutualVC = NSViewController()
        mutualVC.view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 480))
        let mutualManager = StatusItemManager(contentViewController: mutualVC, floatingPanel: mutualPresenter)
        mutualManager.popover.animates = false

        let mutualWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200), styleMask: [.borderless], backing: .buffered, defer: false)
        mutualWindow.orderFrontRegardless()
        if let btn = mutualManager.statusItem.button {
            mutualWindow.contentView?.addSubview(btn)
        }

        var mutualViolations = 0
        for _ in 1...100 {
            mutualManager.showPopover()
            if mutualPresenter.isVisible && mutualManager.popover.isShown {
                mutualViolations += 1
            }
            mutualManager.handleHotKeyTrigger()
            if mutualPresenter.isVisible && mutualManager.popover.isShown {
                mutualViolations += 1
            }
        }
        report(
            name: "StatusItemManager enforces mutual exclusion across 100 alternating Popover and HotKey cycles",
            passed: (mutualViolations == 0 && mutualPresenter.isVisible && !mutualManager.popover.isShown),
            detail: "Mutual exclusion violations: \(mutualViolations)"
        )

        // Challenge 4.10: Concurrent interleaved presentation triggers (Chaos Test)
        let chaosQueue = DispatchQueue(label: "chaos.concurrent", attributes: .concurrent)
        let chaosGroup = DispatchGroup()
        var chaosViolations = 0
        for i in 1...150 {
            chaosGroup.enter()
            chaosQueue.async {
                DispatchQueue.main.async {
                    switch i % 3 {
                    case 0:
                        mutualManager.showPopover()
                    case 1:
                        mutualManager.handleHotKeyTrigger()
                    default:
                        mutualManager.dismissAll()
                    }
                    if mutualPresenter.isVisible && mutualManager.popover.isShown {
                        chaosViolations += 1
                    }
                }
                chaosGroup.leave()
            }
        }
        chaosGroup.wait()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.4))
        mutualManager.dismissAll()
        report(
            name: "StatusItemManager maintains mutual exclusion under 150 concurrent chaotic interleaved calls",
            passed: (chaosViolations == 0 && !mutualPresenter.isVisible && !mutualManager.popover.isShown),
            detail: "Chaos violations: \(chaosViolations)"
        )
        mutualWindow.orderOut(nil)

        // Challenge 4.11: High-concurrency dismissAll() stress
        let stressPanel = FloatingClipPanel(rootView: Text("Dismiss Stress"))
        let stressManager = StatusItemManager(floatingPanel: stressPanel)
        var dismissAllPassed = true
        for _ in 1...20 {
            stressPanel.present(at: NSRect(x: 100, y: 100, width: 360, height: 480))
            let dGroup = DispatchGroup()
            let dQueue = DispatchQueue(label: "dismiss.stress", attributes: .concurrent)
            for _ in 1...30 {
                dGroup.enter()
                dQueue.async {
                    stressManager.dismissAll()
                    dGroup.leave()
                }
            }
            dGroup.wait()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            if stressPanel.isVisible || stressPanel.hasActiveMonitors {
                dismissAllPassed = false
            }
        }
        report(
            name: "dismissAll() safely executes under 600 concurrent background calls across 20 iterations",
            passed: dismissAllPassed,
            detail: "Final panel visible: \(stressPanel.isVisible), active monitors: \(stressPanel.hasActiveMonitors)"
        )

        // Challenge 4.12: Outside mouse click dismissal via synthetic NSEvent
        let outsideClickPanel = FloatingClipPanel(rootView: Text("Outside Click Test"))
        let otherWin = NSWindow(contentRect: NSRect(x: 500, y: 500, width: 200, height: 200), styleMask: [.borderless], backing: .buffered, defer: false)
        otherWin.orderFrontRegardless()
        outsideClickPanel.present(at: NSRect(x: 100, y: 100, width: 360, height: 480))
        let wasVisibleBeforeClick = outsideClickPanel.isVisible && outsideClickPanel.hasActiveMonitors
        if let outsideEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: 50, y: 50),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: otherWin.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1.0
        ) {
            NSApp.sendEvent(outsideEvent)
        }
        report(
            name: "FloatingClipPanel detects outside mouse click and dismantles monitors immediately",
            passed: (wasVisibleBeforeClick && !outsideClickPanel.isVisible && !outsideClickPanel.hasActiveMonitors)
        )
        otherWin.orderOut(nil)

        // Challenge 4.13: Inside mouse click retention
        outsideClickPanel.present(at: NSRect(x: 100, y: 100, width: 360, height: 480))
        if let insideEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: 50, y: 50),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: outsideClickPanel.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1.0
        ) {
            NSApp.sendEvent(insideEvent)
        }
        let stayedVisibleOnInsideClick = outsideClickPanel.isVisible && outsideClickPanel.hasActiveMonitors
        outsideClickPanel.dismiss()
        report(
            name: "FloatingClipPanel ignores clicks inside panel boundaries without premature dismissal",
            passed: stayedVisibleOnInsideClick
        )

        // Challenge 4.14: Popover Escape key monitor dismissal
        let escWin = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200), styleMask: [.borderless], backing: .buffered, defer: false)
        escWin.orderFrontRegardless()
        let escPopoverVC = NSViewController()
        escPopoverVC.view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 480))
        let escPopoverManager = StatusItemManager(contentViewController: escPopoverVC)
        if let btn = escPopoverManager.statusItem.button {
            escWin.contentView?.addSubview(btn)
        }
        escPopoverManager.popover.animates = false
        escPopoverManager.showPopover()
        escPopoverVC.view.window?.makeKeyAndOrderFront(nil)
        let popoverShownBeforeEsc = escPopoverManager.popover.isShown
        let targetWinNum = escPopoverVC.view.window?.windowNumber ?? escWin.windowNumber
        if let escKeyEvt = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: targetWinNum,
            context: nil,
            characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}",
            isARepeat: false,
            keyCode: 53
        ) {
            NSApp.sendEvent(escKeyEvt)
        }
        report(
            name: "StatusItemManager escape monitor closes popover immediately on Escape key press",
            passed: (popoverShownBeforeEsc && !escPopoverManager.popover.isShown),
            detail: "shownBefore=\(popoverShownBeforeEsc), shownAfter=\(escPopoverManager.popover.isShown), targetWinNum=\(targetWinNum)"
        )
        escPopoverManager.closePopover()
        escWin.orderOut(nil)

        // ==========================================
        // Helper Functions for Tier 5 Suites
        // ==========================================
        func t5_createSandbox() -> URL {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("SuperClip_T5_AdvSandbox_\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }

        func t5_cleanupSandbox(_ url: URL) {
            try? FileManager.default.removeItem(at: url)
        }

        func t5_makeTestPNG(width: Int, height: Int) -> Data {
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
        // 5. Tier 5: High-Throughput Burst Clipboard Writes (>100 ops)
        // ==================================================================
        print("\n--- Suite 5: High-Throughput Burst Clipboard Writes (>100 ops) ---")

        // Challenge 5.1: 150 sequential rapid text writes
        let t5_pb1 = NSPasteboard.withUniqueName()
        let t5_monitor1 = PasteboardMonitor(pasteboard: t5_pb1)
        var t5_capturedItems1: [ClipItem] = []
        let t5_lock1 = NSLock()
        t5_monitor1.onNewClip = { item, _, _ in
            t5_lock1.lock()
            t5_capturedItems1.append(item)
            t5_lock1.unlock()
        }

        let t5_burstStart1 = CFAbsoluteTimeGetCurrent()
        for i in 1...150 {
            t5_pb1.clearContents()
            t5_pb1.setString("Burst Payload Alpha #\(i)", forType: .string)
            t5_monitor1.checkNow()
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        let t5_burstDuration1 = CFAbsoluteTimeGetCurrent() - t5_burstStart1

        t5_lock1.lock()
        let t5_count1 = t5_capturedItems1.count
        t5_lock1.unlock()

        report(
            name: "High-throughput 150 sequential text writes captured without drop",
            passed: (t5_count1 == 150 && t5_burstDuration1 < 2.0),
            detail: "Captured: \(t5_count1)/150 in \(t5_burstDuration1)s"
        )

        // Challenge 5.2: 120 interleaved alternating text and PNG image writes
        let t5_pb2 = NSPasteboard.withUniqueName()
        let t5_monitor2 = PasteboardMonitor(pasteboard: t5_pb2)
        var t5_textClips2 = 0
        var t5_imageClips2 = 0
        let t5_lock2 = NSLock()
        t5_monitor2.onNewClip = { item, _, _ in
            t5_lock2.lock()
            if item.contentType == .text {
                t5_textClips2 += 1
            } else if item.contentType == .image {
                t5_imageClips2 += 1
            }
            t5_lock2.unlock()
        }

        let t5_png2_A = t5_makeTestPNG(width: 40, height: 40)
        let t5_png2_B = t5_makeTestPNG(width: 60, height: 60)

        for i in 1...60 {
            t5_pb2.clearContents()
            t5_pb2.setString("Interleaved Text #\(i)", forType: .string)
            t5_monitor2.checkNow()

            t5_pb2.clearContents()
            let imgData = (i % 2 == 0) ? t5_png2_A : t5_png2_B
            t5_pb2.setData(imgData, forType: .png)
            t5_monitor2.checkNow()
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))

        t5_lock2.lock()
        let t5_totalCaptured2 = t5_textClips2 + t5_imageClips2
        t5_lock2.unlock()

        report(
            name: "Interleaved 120 rapid alternating text and image writes processed cleanly",
            passed: (t5_totalCaptured2 == 120 && t5_textClips2 == 60 && t5_imageClips2 == 60),
            detail: "Total: \(t5_totalCaptured2)/120 (Text: \(t5_textClips2), Images: \(t5_imageClips2))"
        )

        // Challenge 5.3: Burst self-copy loop suppression: 100 consecutive markSelfCopy calls
        let t5_pb3 = NSPasteboard.withUniqueName()
        let t5_monitor3 = PasteboardMonitor(pasteboard: t5_pb3)
        var t5_capturedClips3: [ClipItem] = []
        let t5_lock3 = NSLock()
        t5_monitor3.onNewClip = { item, _, _ in
            t5_lock3.lock()
            t5_capturedClips3.append(item)
            t5_lock3.unlock()
        }

        var t5_allSelfSuppressed3 = true
        for i in 1...100 {
            t5_pb3.clearContents()
            t5_pb3.setString("Self Write Burst #\(i)", forType: .string)
            let sc = t5_pb3.changeCount
            t5_monitor3.markSelfCopy(newChangeCount: sc)
            let ticked = t5_monitor3.pollTick()
            if ticked {
                t5_allSelfSuppressed3 = false
            }
        }
        report(
            name: "100 consecutive markSelfCopy burst events strictly suppressed",
            passed: t5_allSelfSuppressed3,
            detail: "Self copy suppression failed in burst"
        )

        t5_pb3.clearContents()
        t5_pb3.setString("Legitimate External Write After 100 Self Copies", forType: .string)
        t5_monitor3.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        t5_lock3.lock()
        let t5_countAfterSelf3 = t5_capturedClips3.count
        t5_lock3.unlock()

        report(
            name: "Legitimate external copy captured immediately after 100 self-copy events",
            passed: (t5_countAfterSelf3 == 1),
            detail: "Captured clips: \(t5_countAfterSelf3)"
        )

        // Challenge 5.4: 150 consecutive identical text writes deduplicated without store bloat
        let t5_sandbox4 = t5_createSandbox()
        defer { t5_cleanupSandbox(t5_sandbox4) }
        let t5_storage4 = StorageManager(baseDirectory: t5_sandbox4, initialCapacity: 100)
        let t5_identicalItem = ClipItem(contentType: .text, textContent: "Identical Redundant Clip", byteSize: 24)

        let t5_startIdentical = CFAbsoluteTimeGetCurrent()
        for _ in 1...150 {
            t5_storage4.addClip(item: t5_identicalItem, imageData: nil, thumbData: nil)
        }
        let t5_durIdentical = CFAbsoluteTimeGetCurrent() - t5_startIdentical

        report(
            name: "150 consecutive identical text writes deduplicated without store bloat",
            passed: (t5_storage4.items.count == 1 && t5_durIdentical < 0.5),
            detail: "Items count: \(t5_storage4.items.count), Duration: \(t5_durIdentical)s"
        )

        // ==================================================================
        // 6. Tier 5: Deep ImageIO & Corrupt Image Payload Fuzzing
        // ==================================================================
        print("\n--- Suite 6: Deep ImageIO & Corrupt Image Payload Fuzzing ---")

        // Challenge 6.1: Sub-4-byte buffers
        let t5_sub4Bytes = [
            Data([0x00]),
            Data([0x89, 0x50]),
            Data([0xFF, 0xD8, 0xFF])
        ]
        var t5_sub4Passed = true
        for d in t5_sub4Bytes {
            if ThumbnailGenerator.generateThumbnail(from: d) != nil ||
               ThumbnailGenerator.extractDimensions(from: d) != nil ||
               ThumbnailGenerator.isImagePayload(d) {
                t5_sub4Passed = false
            }
        }
        report(
            name: "Buffers smaller than 4 bytes rejected safely across all entry points",
            passed: t5_sub4Passed
        )

        // Challenge 6.2: Truncated PNG chunks
        let t5_png8 = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let t5_pngTruncIHDR = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52])
        report(
            name: "Truncated 8-byte PNG header without chunks returns nil safely",
            passed: (ThumbnailGenerator.generateThumbnail(from: t5_png8) == nil)
        )
        report(
            name: "Truncated IHDR chunk returns nil safely",
            passed: (ThumbnailGenerator.generateThumbnail(from: t5_pngTruncIHDR) == nil)
        )

        // Challenge 6.3: Fuzz stress with 110 randomized byte buffers
        var t5_fuzzPassed = true
        let t5_fuzzSizes = [5, 17, 33, 64, 128, 256, 512, 1024, 4096, 16384, 65536]
        for (idx, sz) in t5_fuzzSizes.enumerated() {
            for round in 0..<10 {
                var randomBytes = [UInt8](repeating: 0, count: sz)
                for b in 0..<sz {
                    randomBytes[b] = UInt8((idx * 37 + round * 19 + b * 7) & 0xFF)
                }
                let fuzzData = Data(randomBytes)
                let th = ThumbnailGenerator.generateThumbnail(from: fuzzData, maxPixelSize: 180)
                let dims = ThumbnailGenerator.extractDimensions(from: fuzzData)
                let isImg = ThumbnailGenerator.isImagePayload(fuzzData)
                if isImg && (dims == nil || th == nil) {
                    t5_fuzzPassed = false
                }
            }
        }
        report(
            name: "Fuzz stress: 110 randomized byte buffers processed with zero crashes",
            passed: t5_fuzzPassed
        )

        // Challenge 6.4: Non-image binary formats
        let t5_nonImagePayloads: [(String, Data)] = [
            ("HTML", "<!DOCTYPE html><html><body>Test</body></html>".data(using: .utf8)!),
            ("JSON", "{\"status\":\"ok\",\"clips\":[1,2,3]}".data(using: .utf8)!),
            ("XML", "<?xml version=\"1.0\"?><dict><key>k</key></dict>".data(using: .utf8)!),
            ("SQLite", "SQLite format 3\0".data(using: .utf8)!),
            ("PDF", "%PDF-1.7\n%truncated".data(using: .utf8)!),
            ("ZIP", Data([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00, 0x00, 0x00]))
        ]
        var t5_nonImagePassed = true
        for (_, data) in t5_nonImagePayloads {
            if ThumbnailGenerator.isImagePayload(data) || ThumbnailGenerator.generateThumbnail(from: data) != nil {
                t5_nonImagePassed = false
            }
        }
        report(
            name: "Non-image binary formats (HTML, JSON, XML, SQLite, PDF, ZIP) rejected safely",
            passed: t5_nonImagePassed
        )

        // Challenge 6.5: Extreme aspect ratios
        let t5_tallData = t5_makeTestPNG(width: 1, height: 10000)
        let t5_tallThumb = ThumbnailGenerator.generateThumbnail(from: t5_tallData, maxPixelSize: 180)
        let t5_tallDims = t5_tallThumb.flatMap { ThumbnailGenerator.extractDimensions(from: $0) }
        report(
            name: "Extreme 1x10000 vertical aspect ratio downscales to 1x180",
            passed: (t5_tallDims?.width == 1 && t5_tallDims?.height == 180),
            detail: "Got dims: \(String(describing: t5_tallDims))"
        )

        let t5_wideData = t5_makeTestPNG(width: 10000, height: 1)
        let t5_wideThumb = ThumbnailGenerator.generateThumbnail(from: t5_wideData, maxPixelSize: 180)
        let t5_wideDims = t5_wideThumb.flatMap { ThumbnailGenerator.extractDimensions(from: $0) }
        report(
            name: "Extreme 10000x1 horizontal aspect ratio downscales to 180x1",
            passed: (t5_wideDims?.width == 180 && t5_wideDims?.height == 1),
            detail: "Got dims: \(String(describing: t5_wideDims))"
        )

        // Challenge 6.6: PasteboardMonitor corrupt image recovery
        let t5_pb_rec = NSPasteboard.withUniqueName()
        let t5_monitor_rec = PasteboardMonitor(pasteboard: t5_pb_rec)
        var t5_captured_rec: [ClipItem] = []
        t5_monitor_rec.onNewClip = { item, _, _ in
            t5_captured_rec.append(item)
        }
        t5_pb_rec.clearContents()
        t5_pb_rec.setData(Data([0x89, 0x50, 0x4E, 0x47, 0xAA, 0xBB, 0xCC, 0xDD]), forType: .png)
        t5_monitor_rec.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        let t5_validPNG = t5_makeTestPNG(width: 50, height: 50)
        t5_pb_rec.clearContents()
        t5_pb_rec.setData(t5_validPNG, forType: .png)
        t5_monitor_rec.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        report(
            name: "PasteboardMonitor gracefully recovers from corrupt image and captures subsequent valid image",
            passed: (t5_captured_rec.count == 1 && t5_captured_rec.first?.contentType == .image),
            detail: "Captured clips: \(t5_captured_rec.count)"
        )

        // ==================================================================
        // 7. Tier 5: Exotic Unicode, Combining Marks, RTL & Emoji Surrogates
        // ==================================================================
        print("\n--- Suite 7: Exotic Unicode Strings, Combining Marks, RTL & Emoji Surrogates ---")

        // Challenge 7.1: Zalgo stacked combining diacritical marks
        var t5_zalgoStr = "Z"
        for code in 0x0300...0x0364 {
            if let scalar = UnicodeScalar(code) {
                t5_zalgoStr.append(Character(scalar))
            }
        }
        let t5_zalgoItem = ClipItem(contentType: .text, textContent: t5_zalgoStr, byteSize: t5_zalgoStr.utf8.count)
        let t5_zalgoTitle = t5_zalgoItem.displayTitle
        report(
            name: "Zalgo stacked combining diacritical marks compute displayTitle safely",
            passed: (!t5_zalgoTitle.isEmpty && t5_zalgoTitle.count <= 60),
            detail: "Title count: \(t5_zalgoTitle.count)"
        )

        // Challenge 7.2: Bidirectional RTL/LTR mixed text
        let t5_rtlArabic = "\u{0645}\u{0631}\u{062D}\u{0628}\u{0627} \u{0628}\u{0627}\u{0644}\u{0639}\u{0627}\u{0644}\u{0645}"
        let t5_rtlHebrew = "\u{05E9}\u{05DC}\u{05D5}\u{05DD} \u{05E2}\u{05D5}\u{05DC}\u{05DD}"
        let t5_bidiText = "\(t5_rtlArabic) - Order #98765 - \(t5_rtlHebrew)"
        let t5_bidiItem = ClipItem(contentType: .text, textContent: t5_bidiText, byteSize: t5_bidiText.utf8.count)
        report(
            name: "Bidirectional RTL/LTR mixed text formats displayTitle cleanly",
            passed: (!t5_bidiItem.displayTitle.isEmpty)
        )
        report(
            name: "SearchEngine matches embedded ASCII number token in bidi text",
            passed: SearchEngine.matches(item: t5_bidiItem, query: "98765")
        )

        // Challenge 7.3: High Unicode codepoints & Emoji surrogate sequences
        var t5_highUnicodeStr = "Prefix "
        let t5_scalarGrinning = UnicodeScalar(0x1F600)!
        let t5_scalarRocket   = UnicodeScalar(0x1F680)!
        let t5_scalarLaptop   = UnicodeScalar(0x1F4BB)!
        t5_highUnicodeStr.append(Character(t5_scalarGrinning))
        t5_highUnicodeStr.append(Character(t5_scalarRocket))
        t5_highUnicodeStr.append(Character(t5_scalarLaptop))
        t5_highUnicodeStr.append(" Suffix Content with Long Tail Padding Characters 1234567890")

        let t5_highUniItem = ClipItem(contentType: .text, textContent: t5_highUnicodeStr, byteSize: t5_highUnicodeStr.utf8.count)
        let t5_highUniTitle = t5_highUniItem.displayTitle
        report(
            name: "High Unicode codepoints and surrogate pairs truncated safely without index crash",
            passed: (t5_highUniTitle.hasSuffix("...") && t5_highUniTitle.count <= 60),
            detail: "Title: length \(t5_highUniTitle.count)"
        )
        let t5_queryRocket = String(Character(t5_scalarRocket))
        report(
            name: "SearchEngine matches runtime high-codepoint surrogate substring accurately",
            passed: SearchEngine.matches(item: t5_highUniItem, query: t5_queryRocket)
        )

        // Challenge 7.4: Zero-width format characters
        let t5_zwspString = "\u{200B}\u{200C}\u{200D}\u{FEFF}"
        let t5_zwspItem = ClipItem(contentType: .text, textContent: t5_zwspString, byteSize: t5_zwspString.utf8.count)
        report(
            name: "Zero-width characters handled safely without exceptions in displayTitle",
            passed: (!t5_zwspItem.displayTitle.isEmpty)
        )

        // Challenge 7.5: 100,000-character single-line text
        let t5_hugeLine = String(repeating: "X", count: 100000)
        let t5_hugeLineItem = ClipItem(contentType: .text, textContent: t5_hugeLine, byteSize: t5_hugeLine.utf8.count)
        let t5_startPrefix = CFAbsoluteTimeGetCurrent()
        let t5_hugeTitle = t5_hugeLineItem.displayTitle
        let t5_durPrefix = CFAbsoluteTimeGetCurrent() - t5_startPrefix
        report(
            name: "100,000-character single-line text truncated to 60 chars in O(1) time (< 5ms)",
            passed: (t5_hugeTitle.count == 60 && t5_hugeTitle.hasSuffix("...") && t5_durPrefix < 0.05),
            detail: "Title count: \(t5_hugeTitle.count), Duration: \(t5_durPrefix)s"
        )

        // Challenge 7.6: CRLF and CR newline encodings
        let t5_crlfItem = ClipItem(contentType: .text, textContent: "First CRLF Line\r\nSecond CRLF Line", byteSize: 34)
        report(
            name: "displayTitle extracts first line cleanly with CRLF delimiter",
            passed: (t5_crlfItem.displayTitle == "First CRLF Line"),
            detail: "Got: \(t5_crlfItem.displayTitle)"
        )

        // ==================================================================
        // 8. Tier 5: Extreme Capacity Mutation Edge Cases (1, 500, rapid)
        // ==================================================================
        print("\n--- Suite 8: Extreme Capacity Mutation Edge Cases (1, 500, rapid) ---")

        // Challenge 8.1: Capacity = 1 minimum boundary
        let t5_sandboxCap = t5_createSandbox()
        defer { t5_cleanupSandbox(t5_sandboxCap) }
        let t5_storageCap = StorageManager(baseDirectory: t5_sandboxCap, initialCapacity: 1)

        var t5_cap1Passed = true
        for i in 1...60 {
            let item = ClipItem(contentType: .text, textContent: "Cap1 Item #\(i)", byteSize: 20)
            t5_storageCap.addClip(item: item, imageData: nil, thumbData: nil)
            if t5_storageCap.historyItems.count != 1 {
                t5_cap1Passed = false
            }
        }
        let t5_lastItemCap = t5_storageCap.historyItems.first
        report(
            name: "Capacity = 1 strictly bounds unpinned items to exactly 1 at all times",
            passed: (t5_cap1Passed && t5_lastItemCap?.textContent == "Cap1 Item #60"),
            detail: "History count: \(t5_storageCap.historyItems.count), Latest: \(t5_lastItemCap?.textContent ?? "nil")"
        )

        // Challenge 8.2: Capacity expansion to 500
        t5_storageCap.capacity = 500
        for i in 61...260 {
            let item = ClipItem(contentType: .text, textContent: "Cap500 Item #\(i)", byteSize: 20)
            t5_storageCap.addClip(item: item, imageData: nil, thumbData: nil)
        }
        report(
            name: "Capacity expansion to 500 retains all 201 unpinned items without eviction",
            passed: (t5_storageCap.historyItems.count == 201),
            detail: "History count: \(t5_storageCap.historyItems.count)/201"
        )

        // Challenge 8.3: Dynamic downscale from 500 to 1
        t5_storageCap.capacity = 1
        let t5_retainedItemDown = t5_storageCap.historyItems.first
        report(
            name: "Dynamic downscale from 500 to 1 immediately evicts 200 items, keeping newest",
            passed: (t5_storageCap.historyItems.count == 1 && t5_retainedItemDown?.textContent == "Cap500 Item #260"),
            detail: "History count: \(t5_storageCap.historyItems.count), Retained: \(t5_retainedItemDown?.textContent ?? "nil")"
        )

        // Challenge 8.4: 40 rapid alternating capacity mutations (1 <-> 500)
        var t5_altPassed = true
        for cycle in 1...40 {
            t5_storageCap.capacity = 1
            if t5_storageCap.historyItems.count > 1 {
                t5_altPassed = false
            }
            t5_storageCap.capacity = 500
            for k in 1...5 {
                let item = ClipItem(contentType: .text, textContent: "Alt Cycle \(cycle) Item \(k)", byteSize: 25)
                t5_storageCap.addClip(item: item, imageData: nil, thumbData: nil)
            }
            if t5_storageCap.historyItems.count > 500 {
                t5_altPassed = false
            }
        }
        report(
            name: "40 rapid alternating capacity mutations (1 <-> 500) maintain strict invariants",
            passed: t5_altPassed,
            detail: "Final count: \(t5_storageCap.historyItems.count)"
        )

        // Challenge 8.5: Zero and negative capacity clamping
        t5_storageCap.capacity = 0
        report(
            name: "Capacity = 0 clamped to minimum safe bound >= 1",
            passed: (t5_storageCap.capacity >= 1),
            detail: "Clamped capacity: \(t5_storageCap.capacity)"
        )
        t5_storageCap.capacity = -100
        report(
            name: "Negative capacity clamped to minimum safe bound >= 1",
            passed: (t5_storageCap.capacity >= 1),
            detail: "Clamped capacity: \(t5_storageCap.capacity)"
        )

        // Challenge 8.6: Cold-start persistence with capacity = 1
        t5_storageCap.capacity = 1
        t5_storageCap.flushDiskQueue()
        let t5_reloadedCap = StorageManager(baseDirectory: t5_sandboxCap)
        report(
            name: "Cold-start StorageManager reloads persisted capacity = 1 correctly",
            passed: (t5_reloadedCap.capacity == 1 && t5_reloadedCap.historyItems.count <= 1),
            detail: "Reloaded capacity: \(t5_reloadedCap.capacity), items: \(t5_reloadedCap.historyItems.count)"
        )

        // ==================================================================
        // 9. Tier 5: Pin Protection Immunity & Mass Purge under Concurrency
        // ==================================================================
        print("\n--- Suite 9: Pin Protection Immunity & Mass Purge under Concurrency ---")

        // Challenge 9.1: clearUnpinnedHistory preserves 100% of pinned items
        let t5_sandboxPin = t5_createSandbox()
        defer { t5_cleanupSandbox(t5_sandboxPin) }
        let t5_storagePin = StorageManager(baseDirectory: t5_sandboxPin, initialCapacity: 100)

        var t5_pinnedUUIDs: Set<UUID> = []
        for i in 1...25 {
            let id = UUID()
            t5_pinnedUUIDs.insert(id)
            let item = ClipItem(id: id, contentType: .text, textContent: "Pinned Alpha #\(i)", byteSize: 22, isPinned: true)
            t5_storagePin.addClip(item: item, imageData: nil, thumbData: nil)
        }
        for i in 1...80 {
            let item = ClipItem(contentType: .text, textContent: "Unpinned Alpha #\(i)", byteSize: 24, isPinned: false)
            t5_storagePin.addClip(item: item, imageData: nil, thumbData: nil)
        }
        t5_storagePin.clearUnpinnedHistory()
        let t5_remainingUUIDs = Set(t5_storagePin.items.map { $0.id })
        report(
            name: "clearUnpinnedHistory removes 100% of unpinned items (0 unpinned remaining)",
            passed: (t5_storagePin.historyItems.isEmpty)
        )
        report(
            name: "clearUnpinnedHistory preserves 100% of pinned items with identical UUIDs",
            passed: (t5_storagePin.pinnedItems.count == 25 && t5_remainingUUIDs == t5_pinnedUUIDs),
            detail: "Pinned remaining: \(t5_storagePin.pinnedItems.count)/25"
        )

        // Challenge 9.2: Pin immunity under mass capacity overflow (capacity = 1 with 40 pinned items)
        let t5_sandboxImm = t5_createSandbox()
        defer { t5_cleanupSandbox(t5_sandboxImm) }
        let t5_storageImm = StorageManager(baseDirectory: t5_sandboxImm, initialCapacity: 1)
        for i in 1...40 {
            let item = ClipItem(contentType: .text, textContent: "Immune Pin #\(i)", byteSize: 20, isPinned: true)
            t5_storageImm.addClip(item: item, imageData: nil, thumbData: nil)
        }
        for i in 1...100 {
            let item = ClipItem(contentType: .text, textContent: "Overflow Unpinned #\(i)", byteSize: 25, isPinned: false)
            t5_storageImm.addClip(item: item, imageData: nil, thumbData: nil)
        }
        report(
            name: "Pinned items are 100% immune from capacity overflow when capacity = 1",
            passed: (t5_storageImm.pinnedItems.count == 40 && t5_storageImm.historyItems.count == 1 && t5_storageImm.items.count == 41),
            detail: "Pinned: \(t5_storageImm.pinnedItems.count)/40, Unpinned: \(t5_storageImm.historyItems.count)/1, Total: \(t5_storageImm.items.count)"
        )

        // Challenge 9.3: Pin toggling dynamics
        let t5_oldestUnpinnedBefore = t5_storageImm.historyItems.first?.id
        if let toPinID = t5_oldestUnpinnedBefore {
            t5_storageImm.togglePin(id: toPinID)
        }
        report(
            name: "Toggling unpinned item to pinned increases pinned count to 41, leaves 0 unpinned",
            passed: (t5_storageImm.pinnedItems.count == 41 && t5_storageImm.historyItems.isEmpty)
        )
        let t5_freshUnpinned = ClipItem(contentType: .text, textContent: "Fresh Unpinned", byteSize: 20, isPinned: false)
        t5_storageImm.addClip(item: t5_freshUnpinned, imageData: nil, thumbData: nil)
        report(
            name: "Adding unpinned item at capacity = 1 sets unpinned count to exactly 1",
            passed: (t5_storageImm.historyItems.count == 1 && t5_storageImm.pinnedItems.count == 41)
        )

        // Challenge 9.4: Multi-threaded concurrent storage access stress (10 threads, 500 operations)
        let t5_sandboxConc = t5_createSandbox()
        defer { t5_cleanupSandbox(t5_sandboxConc) }
        let t5_storageConc = StorageManager(baseDirectory: t5_sandboxConc, initialCapacity: 50)
        for i in 1...20 {
            let item = ClipItem(contentType: .text, textContent: "Concurrent Seed #\(i)", byteSize: 25, isPinned: (i % 3 == 0))
            t5_storageConc.addClip(item: item, imageData: nil, thumbData: nil)
        }
        let t5_concGroup = DispatchGroup()
        let t5_concQueue = DispatchQueue(label: "com.superclip.test.advconcurrent", attributes: .concurrent)

        for threadIndex in 1...10 {
            t5_concGroup.enter()
            t5_concQueue.async {
                for iter in 1...50 {
                    switch (threadIndex + iter) % 6 {
                    case 0, 1:
                        let item = ClipItem(
                            contentType: .text,
                            textContent: "Thread \(threadIndex) Clip \(iter)",
                            byteSize: 30,
                            isPinned: (iter % 10 == 0)
                        )
                        t5_storageConc.addClip(item: item, imageData: nil, thumbData: nil)
                    case 2:
                        let currentItems = t5_storageConc.items
                        if let randomItem = currentItems.randomElement() {
                            t5_storageConc.togglePin(id: randomItem.id)
                        }
                    case 3:
                        let caps = [10, 25, 50, 100, 200]
                        t5_storageConc.capacity = caps[(threadIndex + iter) % caps.count]
                    case 4:
                        let currentItems = t5_storageConc.items
                        if currentItems.count > 5, let randomItem = currentItems.randomElement() {
                            t5_storageConc.deleteItem(id: randomItem.id)
                        }
                    case 5:
                        _ = t5_storageConc.items
                        _ = t5_storageConc.pinnedItems
                        _ = t5_storageConc.historyItems
                        _ = t5_storageConc.capacity
                    default:
                        break
                    }
                }
                t5_concGroup.leave()
            }
        }

        let t5_waitResult = t5_concGroup.wait(timeout: .now() + 10.0)
        report(
            name: "10 concurrent background threads executed 500 operations with zero deadlocks",
            passed: (t5_waitResult == .success),
            detail: "Wait result: \(t5_waitResult)"
        )
        t5_storageConc.flushDiskQueue()
        let t5_finalUnpinned = t5_storageConc.historyItems.count
        let t5_finalCap = t5_storageConc.capacity
        report(
            name: "Concurrent stress maintains capacity invariant: unpinned count <= capacity",
            passed: (t5_finalUnpinned <= t5_finalCap),
            detail: "Unpinned: \(t5_finalUnpinned), Capacity: \(t5_finalCap)"
        )
        let t5_reloadedConc = StorageManager(baseDirectory: t5_sandboxConc)
        report(
            name: "StorageManager cleanly deserializes from disk after heavy concurrent mutation",
            passed: (t5_reloadedConc.items.count == t5_storageConc.items.count),
            detail: "Reloaded items: \(t5_reloadedConc.items.count)/\(t5_storageConc.items.count)"
        )

        // ==========================================
        // Summary Verdict
        // ==========================================
        print("\n==================================================")
        print("  Adversarial Challenge Execution Summary         ")
        print("==================================================")
        print("  Total Challenges: \(totalTests)")
        print("  Passed:           \(passedTests)")
        print("  Failed:           \(failedTests)")

        if failedTests > 0 {
            print("\nVERDICT: REJECT (Found \(failedTests) critical/high defects in SuperClip)")
            exit(1)
        } else {
            print("\nVERDICT: APPROVE (All adversarial challenges passed)")
            exit(0)
        }
    }
}

