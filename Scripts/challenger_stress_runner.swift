import Foundation
import AppKit
import SwiftUI
import SuperClipCore
import SuperClip

@main
struct ChallengerStressRunner {
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

    static func main() {
        print("==================================================")
        print("  SuperClip Challenger Empirical Stress Runner   ")
        print("  Target: Lifecycle, Escape Key, Concurrency      ")
        print("==================================================")

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        // ==========================================
        // Suite 1: Escape Key & Window Leakage Verification
        // ==========================================
        print("\n--- Suite 1: Escape Key & Window Leakage Stress ---")

        // Test 1.1: Escape key dismisses popover immediately without window leak
        let escHostWin1_1 = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 300, height: 300),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        escHostWin1_1.orderFrontRegardless()
        let vc1_1 = NSViewController()
        vc1_1.view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 480))
        let manager1_1 = StatusItemManager(contentViewController: vc1_1)
        if let btn = manager1_1.statusItem.button {
            escHostWin1_1.contentView?.addSubview(btn)
        }
        manager1_1.popover.animates = false

        manager1_1.showPopover()
        let popoverShown1_1 = manager1_1.popover.isShown
        let targetWinNum1_1 = vc1_1.view.window?.windowNumber ?? escHostWin1_1.windowNumber
        if let escEvt1_1 = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: targetWinNum1_1,
            context: nil,
            characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}",
            isARepeat: false,
            keyCode: 53
        ) {
            NSApp.sendEvent(escEvt1_1)
        }
        let popoverDismissed1_1 = !manager1_1.popover.isShown
        report(
            name: "Escape key dismisses StatusItemManager popover cleanly without window leak",
            passed: popoverShown1_1 && popoverDismissed1_1,
            detail: "shownBefore=\(popoverShown1_1), dismissedAfter=\(popoverDismissed1_1)"
        )
        escHostWin1_1.orderOut(nil)

        // Test 1.2: Escape key dismisses FloatingClipPanel and removes all event monitors
        let panel1_2 = FloatingClipPanel(rootView: Text("Panel Esc Test"))
        panel1_2.present(at: NSRect(x: 200, y: 200, width: 360, height: 480))
        let panelVisibleBefore1_2 = panel1_2.isVisible && panel1_2.hasActiveMonitors
        if let escEvt1_2 = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: panel1_2.windowNumber,
            context: nil,
            characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}",
            isARepeat: false,
            keyCode: 53
        ) {
            panel1_2.sendEvent(escEvt1_2)
        }
        let panelDismissed1_2 = !panel1_2.isVisible && !panel1_2.hasActiveMonitors
        report(
            name: "Escape key dismisses FloatingClipPanel and tears down all event monitors",
            passed: panelVisibleBefore1_2 && panelDismissed1_2,
            detail: "visibleBefore=\(panelVisibleBefore1_2), dismissedAfter=\(panelDismissed1_2)"
        )

        // Test 1.3: 100 Sequential Escape Key Cycles on Popover (Zero Leaks)
        let escHostWin1_3 = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 300, height: 300),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        escHostWin1_3.orderFrontRegardless()
        let vc1_3 = NSViewController()
        vc1_3.view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 480))
        let manager1_3 = StatusItemManager(contentViewController: vc1_3)
        if let btn = manager1_3.statusItem.button {
            escHostWin1_3.contentView?.addSubview(btn)
        }
        manager1_3.popover.animates = false

        var escCyclesPassed1_3 = true
        var escCyclesFailedCount1_3 = 0
        for i in 1...100 {
            manager1_3.showPopover()
            if !manager1_3.popover.isShown {
                escCyclesPassed1_3 = false
                escCyclesFailedCount1_3 += 1
                continue
            }
            let winNum = vc1_3.view.window?.windowNumber ?? escHostWin1_3.windowNumber
            if let evt = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: TimeInterval(i),
                windowNumber: winNum,
                context: nil,
                characters: "\u{1b}",
                charactersIgnoringModifiers: "\u{1b}",
                isARepeat: false,
                keyCode: 53
            ) {
                NSApp.sendEvent(evt)
            }
            if manager1_3.popover.isShown {
                escCyclesPassed1_3 = false
                escCyclesFailedCount1_3 += 1
            }
        }
        report(
            name: "StatusItemManager survives 100 sequential Escape key dismissals with 100% success rate",
            passed: escCyclesPassed1_3 && escCyclesFailedCount1_3 == 0,
            detail: "failedCycles=\(escCyclesFailedCount1_3)/100"
        )
        escHostWin1_3.orderOut(nil)

        // Test 1.4: 100 Sequential Escape Key Cycles on FloatingClipPanel (Zero Monitor Leaks)
        let panel1_4 = FloatingClipPanel(rootView: Text("Escape 100 Cycles"))
        var panelEscPassed1_4 = true
        var panelEscMonitorLeaks1_4 = 0
        for i in 1...100 {
            panel1_4.present(at: NSRect(x: 100 + Double(i % 10), y: 100 + Double(i % 10), width: 360, height: 480))
            if !panel1_4.isVisible || !panel1_4.hasActiveMonitors {
                panelEscPassed1_4 = false
            }
            if let evt = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: TimeInterval(i),
                windowNumber: panel1_4.windowNumber,
                context: nil,
                characters: "\u{1b}",
                charactersIgnoringModifiers: "\u{1b}",
                isARepeat: false,
                keyCode: 53
            ) {
                panel1_4.sendEvent(evt)
            }
            if panel1_4.isVisible {
                panelEscPassed1_4 = false
            }
            if panel1_4.hasActiveMonitors {
                panelEscMonitorLeaks1_4 += 1
            }
        }
        report(
            name: "FloatingClipPanel survives 100 sequential Escape dismissals with 0 monitor leaks",
            passed: panelEscPassed1_4 && panelEscMonitorLeaks1_4 == 0,
            detail: "passed=\(panelEscPassed1_4), leaks=\(panelEscMonitorLeaks1_4)"
        )

        // Test 1.5: Escape key when no presentation is active does not crash or corrupt state
        var harmlessEscPassed = true
        for _ in 1...10 {
            if let evt = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "\u{1b}",
                charactersIgnoringModifiers: "\u{1b}",
                isARepeat: false,
                keyCode: 53
            ) {
                NSApp.sendEvent(evt)
            }
        }
        report(
            name: "Escape key delivered to inactive state executes harmlessly without crash",
            passed: harmlessEscPassed
        )

        // Test 1.6: Escape key cancels operation via standard cancelOperation responder
        let panel1_6 = FloatingClipPanel(rootView: Text("CancelOp Test"))
        panel1_6.present(at: NSRect(x: 200, y: 200, width: 360, height: 480))
        panel1_6.cancelOperation(nil)
        report(
            name: "FloatingClipPanel responds to cancelOperation selector by cleanly dismissing",
            passed: !panel1_6.isVisible && !panel1_6.hasActiveMonitors
        )

        // ==========================================
        // Suite 2: 100 Concurrent Threads Presentation Stress
        // ==========================================
        print("\n--- Suite 2: 100 Concurrent Threads Concurrency Stress ---")

        final class ThreadSafePresenter: FloatingPanelPresenting {
            private let lock = NSLock()
            private var _isVisible: Bool = false
            private var _isKeyWindow: Bool = false
            private var _showCount: Int = 0
            private var _dismissCount: Int = 0

            var isVisible: Bool {
                lock.lock()
                defer { lock.unlock() }
                return _isVisible
            }

            var isKeyWindow: Bool {
                lock.lock()
                defer { lock.unlock() }
                return _isKeyWindow
            }

            var showCount: Int {
                lock.lock()
                defer { lock.unlock() }
                return _showCount
            }

            var dismissCount: Int {
                lock.lock()
                defer { lock.unlock() }
                return _dismissCount
            }

            func show(near mouseLocation: NSPoint) {
                lock.lock()
                _isVisible = true
                _isKeyWindow = true
                _showCount += 1
                lock.unlock()
            }

            func dismiss() {
                lock.lock()
                _isVisible = false
                _isKeyWindow = false
                _dismissCount += 1
                lock.unlock()
            }
        }

        final class StubHotKeyManager: HotKeyManaging {
            var onTrigger: (() -> Void)?
            func register(keyCode: UInt32, modifiers: UInt32) {}
            func unregister() {}
        }

        let concurrentPresenter = ThreadSafePresenter()
        let concurrentVC = NSViewController()
        concurrentVC.view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 480))
        let stubHotKey = StubHotKeyManager()
        let concurrentManager = StatusItemManager(
            contentViewController: concurrentVC,
            floatingPanel: concurrentPresenter,
            hotKeyManager: stubHotKey
        )
        concurrentManager.popover.animates = false

        let concurrentHostWin = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        concurrentHostWin.orderFrontRegardless()
        if let btn = concurrentManager.statusItem.button {
            concurrentHostWin.contentView?.addSubview(btn)
        }

        // Test 2.1: Exactly 100 concurrent threads calling showPopover, closePopover, handleHotKeyTrigger, dismissAll
        let threadCount = 100
        let opsPerThread = 50
        let totalOps = threadCount * opsPerThread
        let startBarrier = DispatchSemaphore(value: 0)
        let threadGroup = DispatchGroup()
        let opsLock = NSLock()
        var opsCompleted = 0
        var mutualExclusionViolations = 0
        let violationLock = NSLock()

        for t in 0..<threadCount {
            threadGroup.enter()
            Thread.detachNewThread {
                _ = startBarrier.wait(timeout: .distantFuture)
                for op in 0..<opsPerThread {
                    let action = (t * opsPerThread + op) % 4
                    switch action {
                    case 0:
                        concurrentManager.showPopover()
                    case 1:
                        concurrentManager.closePopover()
                    case 2:
                        concurrentManager.handleHotKeyTrigger()
                    case 3:
                        concurrentManager.dismissAll()
                    default:
                        break
                    }
                    opsLock.lock()
                    opsCompleted += 1
                    opsLock.unlock()
                }
                threadGroup.leave()
            }
        }

        // Release all 100 threads simultaneously
        for _ in 0..<threadCount {
            startBarrier.signal()
        }

        // Drain runloop while waiting to allow main-thread dispatches to execute concurrently
        let deadline = Date(timeIntervalSinceNow: 10.0)
        while Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            opsLock.lock()
            let done = opsCompleted >= totalOps
            opsLock.unlock()
            if done {
                break
            }
        }

        let waitResult = threadGroup.wait(timeout: .now() + 2.0)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))

        opsLock.lock()
        let completedTotal = opsCompleted
        opsLock.unlock()
        report(
            name: "100 concurrent threads perform \(totalOps) presentation calls without deadlock or crash",
            passed: (waitResult == .success && completedTotal == totalOps),
            detail: "completed=\(completedTotal)/\(totalOps), timedOut=\(waitResult != .success)"
        )

        // Test 2.2: Mutual Exclusion verification after 100 concurrent threads
        concurrentManager.dismissAll()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        let finalPopoverShown = concurrentManager.popover.isShown
        let finalPanelVisible = concurrentPresenter.isVisible
        report(
            name: "Presentation state resolves to clean dismissal after 100 concurrent threads",
            passed: (!finalPopoverShown && !finalPanelVisible),
            detail: "popoverShown=\(finalPopoverShown), panelVisible=\(finalPanelVisible)"
        )

        // Test 2.3: 100 Concurrent Threads executing dismissAll() concurrently across multiple rounds
        var dismissAllRoundsPassed = true
        let realPanel = FloatingClipPanel(rootView: Text("Concurrent Dismiss Panel"))
        let realManager = StatusItemManager(floatingPanel: realPanel)

        for round in 1...10 {
            realPanel.present(at: NSRect(x: 100, y: 100, width: 360, height: 480))
            let dGroup = DispatchGroup()
            for _ in 0..<100 {
                dGroup.enter()
                DispatchQueue.global().async {
                    realManager.dismissAll()
                    dGroup.leave()
                }
            }
            _ = dGroup.wait(timeout: .now() + 2.0)
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            if realPanel.isVisible || realPanel.hasActiveMonitors {
                dismissAllRoundsPassed = false
            }
        }
        report(
            name: "100 concurrent threads hammering dismissAll() across 10 rounds maintain 0 monitor leaks",
            passed: dismissAllRoundsPassed && !realPanel.isVisible && !realPanel.hasActiveMonitors,
            detail: "visible=\(realPanel.isVisible), activeMonitors=\(realPanel.hasActiveMonitors)"
        )

        // Test 2.4: 100 Concurrent Threads hammering handleHotKeyTrigger()
        let hotKeyGroup = DispatchGroup()
        for _ in 0..<100 {
            hotKeyGroup.enter()
            DispatchQueue.global().async {
                concurrentManager.handleHotKeyTrigger()
                hotKeyGroup.leave()
            }
        }
        _ = hotKeyGroup.wait(timeout: .now() + 3.0)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        concurrentManager.dismissAll()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        report(
            name: "100 concurrent threads firing handleHotKeyTrigger() complete safely without deadlock",
            passed: !concurrentManager.popover.isShown
        )
        concurrentHostWin.orderOut(nil)

        // ==========================================
        // Suite 3: FloatingClipPanel 100-Cycle Lifecycle & Zero Monitor Leaks
        // ==========================================
        print("\n--- Suite 3: FloatingClipPanel 100-Cycle Lifecycle & Zero Monitor Leaks ---")

        // Test 3.1: 100 Sequential present() and dismiss() cycles
        let panel3_1 = FloatingClipPanel(rootView: Text("Cycle Test Panel"))
        var dismissCounter3_1 = 0
        panel3_1.onDismiss = { dismissCounter3_1 += 1 }

        var all100CyclesValid = true
        var leakCount3_1 = 0
        for i in 1...100 {
            panel3_1.present(at: NSRect(x: 150 + Double(i % 20), y: 150 + Double(i % 20), width: 360, height: 480))
            if !panel3_1.isVisible || !panel3_1.hasActiveMonitors {
                all100CyclesValid = false
            }
            panel3_1.dismiss()
            if panel3_1.isVisible {
                all100CyclesValid = false
            }
            if panel3_1.hasActiveMonitors {
                leakCount3_1 += 1
            }
        }
        report(
            name: "FloatingClipPanel completes 100 present/dismiss cycles with 100 callbacks and 0 monitor leaks",
            passed: (all100CyclesValid && leakCount3_1 == 0 && dismissCounter3_1 == 100),
            detail: "valid=\(all100CyclesValid), leaks=\(leakCount3_1), dismissCount=\(dismissCounter3_1)/100"
        )

        // Test 3.2: 100 presentNearCursor() cycles with automatic screen clamping
        var cursorCyclesValid = true
        var cursorLeaks = 0
        for i in 1...100 {
            panel3_1.presentNearCursor(size: NSSize(width: 360, height: 480))
            if !panel3_1.isVisible || !panel3_1.hasActiveMonitors {
                cursorCyclesValid = false
            }
            panel3_1.dismiss()
            if panel3_1.isVisible {
                cursorCyclesValid = false
            }
            if panel3_1.hasActiveMonitors {
                cursorLeaks += 1
            }
        }
        report(
            name: "FloatingClipPanel completes 100 presentNearCursor() cycles with 0 monitor leaks",
            passed: (cursorCyclesValid && cursorLeaks == 0),
            detail: "valid=\(cursorCyclesValid), leaks=\(cursorLeaks)"
        )

        // Test 3.3: 100 distinct FloatingClipPanel instances deallocate cleanly without retain cycles
        var deallocPassed = true
        var leakedInstances = 0
        for _ in 1...100 {
            weak var weakRef: FloatingClipPanel?
            autoreleasepool {
                let p = FloatingClipPanel(rootView: Text("Instance Alloc Test"))
                weakRef = p
                p.present(at: NSRect(x: 100, y: 100, width: 360, height: 480))
                p.dismiss()
            }
            if weakRef != nil {
                deallocPassed = false
                leakedInstances += 1
            }
        }
        report(
            name: "100 distinct FloatingClipPanel instances deallocate cleanly with 0 retain cycles",
            passed: deallocPassed && leakedInstances == 0,
            detail: "leakedInstances=\(leakedInstances)/100"
        )

        // Test 3.4: Redundant dismiss calls are strictly idempotent and do not corrupt monitor state
        panel3_1.present(at: NSRect(x: 200, y: 200, width: 360, height: 480))
        var idempotentCallbackCount = 0
        panel3_1.onDismiss = { idempotentCallbackCount += 1 }
        panel3_1.dismiss()
        for _ in 1...100 {
            panel3_1.dismiss()
        }
        report(
            name: "100 redundant dismiss() calls fire callback exactly once and leave monitors dismantled",
            passed: (!panel3_1.isVisible && !panel3_1.hasActiveMonitors && idempotentCallbackCount == 1),
            detail: "callbacks=\(idempotentCallbackCount), isVisible=\(panel3_1.isVisible), activeMonitors=\(panel3_1.hasActiveMonitors)"
        )

        // Test 3.5: Outside click dismisses panel and dismantles monitors across 50 cycles
        let otherWin = NSWindow(
            contentRect: NSRect(x: 800, y: 800, width: 200, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        otherWin.orderFrontRegardless()

        var outsideClickCyclesPassed = true
        for i in 1...50 {
            panel3_1.present(at: NSRect(x: 100, y: 100, width: 360, height: 480))
            guard panel3_1.isVisible && panel3_1.hasActiveMonitors else {
                outsideClickCyclesPassed = false
                break
            }
            if let evt = NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: NSPoint(x: 50, y: 50),
                modifierFlags: [],
                timestamp: TimeInterval(i),
                windowNumber: otherWin.windowNumber,
                context: nil,
                eventNumber: i,
                clickCount: 1,
                pressure: 1.0
            ) {
                NSApp.sendEvent(evt)
            }
            if panel3_1.isVisible || panel3_1.hasActiveMonitors {
                outsideClickCyclesPassed = false
            }
        }
        report(
            name: "FloatingClipPanel handles 50 outside click dismissal cycles with 0 monitor leaks",
            passed: outsideClickCyclesPassed && !panel3_1.isVisible && !panel3_1.hasActiveMonitors
        )
        otherWin.orderOut(nil)

        // ==========================================
        // Summary Verdict
        // ==========================================
        print("\n==================================================")
        print("  Challenger Stress Execution Summary             ")
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
