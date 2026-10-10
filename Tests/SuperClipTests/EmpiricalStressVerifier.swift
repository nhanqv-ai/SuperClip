import AppKit
import SwiftUI
import SuperClipCore
import SuperClip

@main
struct EmpiricalStressVerifier {
    static var totalTests = 0
    static var passedTests = 0
    static var failedTests = 0

    static func record(name: String, passed: Bool, detail: String = "") {
        totalTests += 1
        if passed {
            passedTests += 1
            print("  [PASS] \(name)")
        } else {
            failedTests += 1
            print("  [FAIL] \(name): \(detail)")
        }
    }

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        print("==================================================")
        print("  Empirical Adversarial Stress Verification Suite ")
        print("==================================================")

        // ---------------------------------------------------------
        // Test 1: Challenge 4.4 Re-verification with Real Components
        // ---------------------------------------------------------
        print("\n--- Phase 1: Challenge 4.4 Real-Object Mutual Exclusion ---")
        let hostWindow1 = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 400, height: 400),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let hostView1 = NSView(frame: NSRect(x: 50, y: 50, width: 100, height: 100))
        hostWindow1.contentView?.addSubview(hostView1)
        hostWindow1.orderFrontRegardless()

        let realPanel1 = FloatingClipPanel(rootView: Text("Real Panel 1"))
        let popoverVC1 = NSViewController()
        popoverVC1.view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 480))
        let manager1 = StatusItemManager(contentViewController: popoverVC1, floatingPanel: realPanel1)

        // Show popover attached to real view
        manager1.popover.show(relativeTo: hostView1.bounds, of: hostView1, preferredEdge: .minY)
        let initialPopoverShown = manager1.popover.isShown
        let initialPanelVisible = realPanel1.isVisible

        // Trigger hotkey
        manager1.handleHotKeyTrigger()

        let popoverAfterHotkey = manager1.popover.isShown
        let panelAfterHotkey = realPanel1.isVisible

        record(
            name: "Phase 1: Real Popover closed synchronously before FloatingClipPanel presents",
            passed: initialPopoverShown && !initialPanelVisible && !popoverAfterHotkey && panelAfterHotkey,
            detail: "initialPopover=\(initialPopoverShown), initialPanel=\(initialPanelVisible), popoverAfter=\(popoverAfterHotkey), panelAfter=\(panelAfterHotkey)"
        )

        realPanel1.dismiss()
        hostWindow1.orderOut(nil)

        // ---------------------------------------------------------
        // Test 2: Rapid Alternating Invocations (100 Cycles)
        // ---------------------------------------------------------
        print("\n--- Phase 2: Rapid Alternating Invocations (100 Cycles) ---")
        let hostWindow2 = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 300, height: 300),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        hostWindow2.orderFrontRegardless()
        let hostButton2 = NSButton(frame: NSRect(x: 10, y: 10, width: 80, height: 30))
        hostWindow2.contentView?.addSubview(hostButton2)

        let realPanel2 = FloatingClipPanel(rootView: Text("Real Panel 2"))
        let popoverVC2 = NSViewController()
        popoverVC2.view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 480))
        let manager2 = StatusItemManager(contentViewController: popoverVC2, floatingPanel: realPanel2)
        if let btn = manager2.statusItem.button {
            hostWindow2.contentView?.addSubview(btn)
        }

        var alternatingViolations = 0
        var popoverFailedToShow = 0
        var panelFailedToShow = 0

        for _ in 1...100 {
            // Step A: Show popover
            manager2.showPopover()
            if !manager2.popover.isShown {
                popoverFailedToShow += 1
            }
            if realPanel2.isVisible {
                alternatingViolations += 1
            }
            if manager2.popover.isShown && realPanel2.isVisible {
                alternatingViolations += 1
            }

            // Step B: Trigger hotkey (should close popover and open panel)
            manager2.handleHotKeyTrigger()
            if manager2.popover.isShown {
                alternatingViolations += 1
            }
            if !realPanel2.isVisible {
                panelFailedToShow += 1
            }
            if manager2.popover.isShown && realPanel2.isVisible {
                alternatingViolations += 1
            }
        }

        record(
            name: "Phase 2: 100 alternating cycles maintain zero simultaneous presentations",
            passed: alternatingViolations == 0 && popoverFailedToShow == 0 && panelFailedToShow == 0,
            detail: "Violations: \(alternatingViolations), popoverFailed: \(popoverFailedToShow), panelFailed: \(panelFailedToShow)"
        )

        realPanel2.dismiss()
        manager2.closePopover()
        hostWindow2.orderOut(nil)

        // ---------------------------------------------------------
        // Test 3: Rapid HotKey Invocations with Real FloatingClipPanel (50 Cycles)
        // Focus: Ensure popover.isShown and panel.isVisible never both equal true
        // ---------------------------------------------------------
        print("\n--- Phase 3: Rapid HotKey Invocations & Mutual Exclusion (50 Cycles) ---")
        let hostWindow3 = NSWindow(
            contentRect: NSRect(x: 250, y: 250, width: 300, height: 300),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        hostWindow3.orderFrontRegardless()
        let realPanel3 = FloatingClipPanel(rootView: Text("Real Panel 3"))
        let popoverVC3 = NSViewController()
        popoverVC3.view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 480))
        let manager3 = StatusItemManager(contentViewController: popoverVC3, floatingPanel: realPanel3)
        if let btn = manager3.statusItem.button {
            hostWindow3.contentView?.addSubview(btn)
        }

        var rapidHotkeyViolations = 0
        for _ in 1...50 {
            // Randomly or sequentially open popover then burst hotkey
            manager3.showPopover()
            if manager3.popover.isShown && realPanel3.isVisible {
                rapidHotkeyViolations += 1
            }

            // Burst hotkey invocation
            manager3.handleHotKeyTrigger()
            if manager3.popover.isShown && realPanel3.isVisible {
                rapidHotkeyViolations += 1
            }

            // Second immediate hotkey invocation
            manager3.handleHotKeyTrigger()
            if manager3.popover.isShown && realPanel3.isVisible {
                rapidHotkeyViolations += 1
            }
        }

        record(
            name: "Phase 3: 50 rapid hotkey burst cycles with real FloatingClipPanel maintain 100% mutual exclusion",
            passed: rapidHotkeyViolations == 0,
            detail: "Violations: \(rapidHotkeyViolations)"
        )

        realPanel3.dismiss()
        manager3.closePopover()
        hostWindow3.orderOut(nil)

        // Phase 3b: Key-window toggle behavior verification with mock presenter
        final class KeyTogglePresenter: FloatingPanelPresenting {
            var isVisible: Bool = false
            var isKeyWindow: Bool = false
            func show(near mouseLocation: NSPoint) {
                isVisible = true
                isKeyWindow = true
            }
            func dismiss() {
                isVisible = false
                isKeyWindow = false
            }
        }
        let togglePresenter = KeyTogglePresenter()
        let toggleManager = StatusItemManager(floatingPanel: togglePresenter)
        var toggleMismatches = 0
        for i in 1...50 {
            toggleManager.handleHotKeyTrigger()
            let expected = (i % 2 == 1)
            if togglePresenter.isVisible != expected {
                toggleMismatches += 1
            }
        }
        record(
            name: "Phase 3b: 50 sequential hotkey toggle invocations cleanly alternate visibility when key",
            passed: toggleMismatches == 0 && !togglePresenter.isVisible,
            detail: "Toggle mismatches: \(toggleMismatches)"
        )

        // ---------------------------------------------------------
        // Test 4: Debounce Boundary Stress Verification
        // ---------------------------------------------------------
        print("\n--- Phase 4: Debounce Boundary Stress Verification ---")
        let hostWindow4 = NSWindow(
            contentRect: NSRect(x: 300, y: 300, width: 300, height: 300),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        hostWindow4.orderFrontRegardless()
        let realPanel4 = FloatingClipPanel(rootView: Text("Real Panel 4"))
        let popoverVC4 = NSViewController()
        popoverVC4.view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 480))
        let manager4 = StatusItemManager(contentViewController: popoverVC4, floatingPanel: realPanel4)
        if let btn = manager4.statusItem.button {
            hostWindow4.contentView?.addSubview(btn)
        }

        // Test boundary intervals
        let testBoundaries: [(interval: Double, shouldOpen: Bool, label: String)] = [
            (0.000, false, "0ms"),
            (0.050, false, "50ms"),
            (0.100, false, "100ms"),
            (0.150, false, "150ms"),
            (0.200, false, "200ms"),
            (0.240, false, "240ms"),
            (0.249, false, "249ms"),
            (0.251, true,  "251ms"),
            (0.260, true,  "260ms"),
            (0.300, true,  "300ms"),
            (0.500, true,  "500ms"),
            (1.000, true,  "1000ms")
        ]

        var boundaryErrors = 0
        var boundaryErrorDetails = ""

        for item in testBoundaries {
            var visibilityChangedToTrue = false
            manager4.onPopoverVisibilityChanged = { visible in
                if visible { visibilityChangedToTrue = true }
            }

            let fakeCloseTime = ProcessInfo.processInfo.systemUptime - item.interval
            manager4.setLastPopoverCloseTimestampForTesting(fakeCloseTime)

            // Simulate statusItemClicked
            manager4.statusItemClicked(nil)

            if visibilityChangedToTrue != item.shouldOpen {
                boundaryErrors += 1
                boundaryErrorDetails += "[\(item.label): got \(visibilityChangedToTrue), expected \(item.shouldOpen)] "
            }

            // Cleanup popover
            manager4.closePopover()
        }

        record(
            name: "Phase 4: Debounce boundary strictly enforces 250ms cut-off across all sub/super-millisecond boundaries",
            passed: boundaryErrors == 0,
            detail: boundaryErrorDetails
        )

        // ---------------------------------------------------------
        // Test 5: Rapid Double-Click Simulation on Status Item
        // ---------------------------------------------------------
        print("\n--- Phase 5: Rapid Status Item Double-Click Simulation ---")
        // Step 1: Initial click opens popover
        manager4.setLastPopoverCloseTimestampForTesting(0)
        manager4.statusItemClicked(nil)
        let open1 = manager4.popover.isShown

        // Step 2: Immediate second click closes popover
        manager4.statusItemClicked(nil)
        let closed2 = !manager4.popover.isShown

        // Step 3: Immediate third click (simulating rapid bounce at 50ms)
        // Since popover was closed in step 2, lastPopoverCloseTimestamp is now ~= uptime.
        manager4.statusItemClicked(nil)
        let stayedClosed3 = !manager4.popover.isShown

        record(
            name: "Phase 5: Rapid consecutive clicks on status item do not re-open popover within debounce window",
            passed: open1 && closed2 && stayedClosed3,
            detail: "open1=\(open1), closed2=\(closed2), stayedClosed3=\(stayedClosed3)"
        )

        manager4.closePopover()
        realPanel4.dismiss()
        hostWindow4.orderOut(nil)

        // ---------------------------------------------------------
        // Test 6: Cross-Presentation Interleaving with Debounce
        // ---------------------------------------------------------
        print("\n--- Phase 6: Cross-Presentation Interleaving with Debounce ---")
        let hostWindow6 = NSWindow(
            contentRect: NSRect(x: 400, y: 400, width: 300, height: 300),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        hostWindow6.orderFrontRegardless()
        let realPanel6 = FloatingClipPanel(rootView: Text("Real Panel 6"))
        let popoverVC6 = NSViewController()
        popoverVC6.view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 480))
        let manager6 = StatusItemManager(contentViewController: popoverVC6, floatingPanel: realPanel6)
        if let btn = manager6.statusItem.button {
            hostWindow6.contentView?.addSubview(btn)
        }

        // Open popover
        manager6.setLastPopoverCloseTimestampForTesting(0)
        manager6.showPopover()
        let stepA_popover = manager6.popover.isShown
        let stepA_panel = realPanel6.isVisible

        // Trigger hotkey -> popover closes, panel opens
        manager6.handleHotKeyTrigger()
        let stepB_popover = manager6.popover.isShown
        let stepB_panel = realPanel6.isVisible

        // Click status button immediately (<250ms from popover close): should be debounced
        manager6.statusItemClicked(nil)
        let stepC_popover = manager6.popover.isShown
        let stepC_panel = realPanel6.isVisible

        // Wait past 250ms (simulated), click status button: should dismiss panel and show popover
        manager6.setLastPopoverCloseTimestampForTesting(ProcessInfo.processInfo.systemUptime - 0.3)
        manager6.statusItemClicked(nil)
        let stepD_popover = manager6.popover.isShown
        let stepD_panel = realPanel6.isVisible

        let crossExclusionPreserved =
            (stepA_popover && !stepA_panel) &&
            (!stepB_popover && stepB_panel) &&
            (!stepC_popover && stepC_panel) &&
            (stepD_popover && !stepD_panel)

        record(
            name: "Phase 6: Cross-presentation interleaving maintains mutual exclusion across debounced status clicks",
            passed: crossExclusionPreserved,
            detail: "stepA=(\(stepA_popover),\(stepA_panel)), stepB=(\(stepB_popover),\(stepB_panel)), stepC=(\(stepC_popover),\(stepC_panel)), stepD=(\(stepD_popover),\(stepD_panel))"
        )

        manager6.dismissAll()
        hostWindow6.orderOut(nil)

        // ---------------------------------------------------------
        // Test 7: Multi-Threaded Stress Test on Mutual Exclusion
        // ---------------------------------------------------------
        print("\n--- Phase 7: Multi-Threaded Concurrent Stress Test ---")
        let hostWindow7 = NSWindow(
            contentRect: NSRect(x: 500, y: 500, width: 300, height: 300),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        hostWindow7.orderFrontRegardless()
        let realPanel7 = FloatingClipPanel(rootView: Text("Real Panel 7"))
        let popoverVC7 = NSViewController()
        popoverVC7.view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 480))
        let manager7 = StatusItemManager(contentViewController: popoverVC7, floatingPanel: realPanel7)
        if let btn = manager7.statusItem.button {
            hostWindow7.contentView?.addSubview(btn)
        }

        let concurrentQueue = DispatchQueue(label: "stress.concurrent", attributes: .concurrent)
        let dispatchGroup = DispatchGroup()
        var concurrentMutualViolations = 0

        for i in 1...200 {
            dispatchGroup.enter()
            concurrentQueue.async {
                DispatchQueue.main.async {
                    switch i % 4 {
                    case 0:
                        manager7.showPopover()
                    case 1:
                        manager7.handleHotKeyTrigger()
                    case 2:
                        manager7.statusItemClicked(nil)
                    default:
                        manager7.dismissAll()
                    }

                    if manager7.popover.isShown && realPanel7.isVisible {
                        concurrentMutualViolations += 1
                    }
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.wait()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))

        // Check final mutual exclusion
        let finalBothShown = manager7.popover.isShown && realPanel7.isVisible

        record(
            name: "Phase 7: 200 concurrent interleaved operations maintain zero mutual exclusion violations",
            passed: concurrentMutualViolations == 0 && !finalBothShown,
            detail: "Concurrent violations: \(concurrentMutualViolations), finalBothShown: \(finalBothShown)"
        )

        manager7.dismissAll()
        hostWindow7.orderOut(nil)

        // ---------------------------------------------------------
        // Final Summary
        // ---------------------------------------------------------
        print("\n==================================================")
        print("  Empirical Adversarial Stress Summary            ")
        print("==================================================")
        print("  Total Tests: \(totalTests)")
        print("  Passed:      \(passedTests)")
        print("  Failed:      \(failedTests)")

        if failedTests > 0 {
            print("\nEMPIRICAL VERDICT: REJECT")
            exit(1)
        } else {
            print("\nEMPIRICAL VERDICT: APPROVE")
            exit(0)
        }
    }
}
