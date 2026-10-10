import Foundation
import AppKit
import SwiftUI
import SuperClipCore
import SuperClip

@main
public struct ChallengerClampingStressHarness {
    public static func main() {
        print("=================================================================")
        print("  SuperClip challenger_m2_r2_1 Empirical Clamping & Window Stress")
        print("=================================================================")

        var total = 0
        var passed = 0
        var failed = 0

        func test(_ name: String, condition: Bool, detail: String = "") {
            total += 1
            if condition {
                passed += 1
                print("  [PASS] \(name)")
            } else {
                failed += 1
                print("  [FAIL] \(name): \(detail)")
            }
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        // =====================================================================
        // SECTION 1: Monte Carlo Randomized Clamping Stress (100,000 Points)
        // =====================================================================
        print("\n--- Section 1: Monte Carlo Randomized Clamping Stress (100,000 points) ---")

        let screenConfigs: [NSRect] = [
            // Standard 1080p primary
            NSRect(x: 0, y: 0, width: 1920, height: 1080),
            // MacBook 16" with notch visibleFrame
            NSRect(x: 0, y: 0, width: 3456, height: 2190),
            // 4K secondary at negative X
            NSRect(x: -3840, y: 0, width: 3840, height: 2160),
            // Ultrawide secondary at positive X
            NSRect(x: 1920, y: 0, width: 5120, height: 1440),
            // Vertical portrait at negative Y
            NSRect(x: 0, y: -1920, width: 1080, height: 1920),
            // Staggered screen at negative X and negative Y
            NSRect(x: -2560, y: -1440, width: 2560, height: 1440),
            // Asymmetric screen with large left dock (120px) and top menu (32px)
            NSRect(x: 120, y: 0, width: 1800, height: 1048)
        ]

        let panelSizes: [NSSize] = [
            NSSize(width: 360, height: 480), // standard
            NSSize(width: 250, height: 350), // compact
            NSSize(width: 500, height: 700), // large
            NSSize(width: 4000, height: 3000), // oversized (both)
            NSSize(width: 4000, height: 400),  // oversized (width only)
            NSSize(width: 300, height: 3000),  // oversized (height only)
            NSSize(width: 1, height: 1)        // degenerate 1x1
        ]

        var monteCarloPassed = true
        var monteCarloFailureDetail = ""
        let randomSeed: UInt64 = 0xDEADBEEFCAFE
        var rngState = randomSeed

        func nextRandomDouble() -> Double {
            // Linear congruential generator
            rngState = rngState &* 6364136223846793005 &+ 1442695040888963407
            let val = Double(rngState >> 32) / Double(UInt32.max)
            return val
        }

        let iterations = 100_000
        for i in 0..<iterations {
            let screen = screenConfigs[i % screenConfigs.count]
            let pSize = panelSizes[(i / screenConfigs.count) % panelSizes.count]

            // Generate mouse coord spanning from far outside negative to far outside positive
            let rangeX = screen.width * 4.0
            let rangeY = screen.height * 4.0
            let mx = (screen.minX - screen.width * 1.5) + CGFloat(nextRandomDouble()) * rangeX
            let my = (screen.minY - screen.height * 1.5) + CGFloat(nextRandomDouble()) * rangeY
            let mouseLoc = NSPoint(x: mx, y: my)

            let result = PanelFrameCalculator.calculateClampedPanelFrame(
                mouseLoc: mouseLoc,
                panelSize: pSize,
                visibleFrame: screen
            )

            // Invariant checks:
            // 1. Dimensions must match pSize
            if abs(result.width - pSize.width) > 0.001 || abs(result.height - pSize.height) > 0.001 {
                monteCarloPassed = false
                monteCarloFailureDetail = "Dimension mismatch on iter \(i): expected \(pSize), got \(result.size)"
                break
            }

            // 2. Horizontal containment:
            if pSize.width <= screen.width {
                if result.minX < (screen.minX - 0.001) || result.maxX > (screen.maxX + 0.001) {
                    monteCarloPassed = false
                    monteCarloFailureDetail = "X containment violated on iter \(i): screen=\(screen), result=\(result)"
                    break
                }
            } else {
                // Oversized width: must pin to minX
                if abs(result.minX - screen.minX) > 0.001 {
                    monteCarloPassed = false
                    monteCarloFailureDetail = "Oversized X pinning violated on iter \(i): screen=\(screen), result=\(result)"
                    break
                }
            }

            // 3. Vertical containment:
            if pSize.height <= screen.height {
                if result.minY < (screen.minY - 0.001) || result.maxY > (screen.maxY + 0.001) {
                    monteCarloPassed = false
                    monteCarloFailureDetail = "Y containment violated on iter \(i): screen=\(screen), result=\(result)"
                    break
                }
            } else {
                // Oversized height: must pin to minY
                if abs(result.minY - screen.minY) > 0.001 {
                    monteCarloPassed = false
                    monteCarloFailureDetail = "Oversized Y pinning violated on iter \(i): screen=\(screen), result=\(result)"
                    break
                }
            }
        }

        test(
            "Monte Carlo: 100,000 randomized coordinate probes satisfy strict boundary invariants",
            condition: monteCarloPassed,
            detail: monteCarloFailureDetail
        )

        // =====================================================================
        // SECTION 2: Boundary Precision & Mathematical Symmetry
        // =====================================================================
        print("\n--- Section 2: Boundary Precision & Symmetry ---")

        let testScreen = NSRect(x: 100, y: 200, width: 1600, height: 900)
        let stdSize = NSSize(width: 360, height: 480)

        // Symmetry: Cursor equidistant from left/right edges
        let leftCursor = NSPoint(x: testScreen.minX + 50, y: testScreen.midY)
        let rightCursor = NSPoint(x: testScreen.maxX - 50, y: testScreen.midY)
        let leftFrame = PanelFrameCalculator.calculateClampedPanelFrame(mouseLoc: leftCursor, panelSize: stdSize, visibleFrame: testScreen)
        let rightFrame = PanelFrameCalculator.calculateClampedPanelFrame(mouseLoc: rightCursor, panelSize: stdSize, visibleFrame: testScreen)
        test("Symmetry: Left cursor clamps to minX", condition: leftFrame.minX == testScreen.minX)
        test("Symmetry: Right cursor clamps to maxX - width", condition: rightFrame.maxX == testScreen.maxX)

        // Exact 1-pixel steps across boundary
        let step1 = PanelFrameCalculator.calculateClampedPanelFrame(mouseLoc: NSPoint(x: testScreen.minX + (stdSize.width / 2.0) - 1.0, y: testScreen.midY), panelSize: stdSize, visibleFrame: testScreen)
        let step2 = PanelFrameCalculator.calculateClampedPanelFrame(mouseLoc: NSPoint(x: testScreen.minX + (stdSize.width / 2.0), y: testScreen.midY), panelSize: stdSize, visibleFrame: testScreen)
        let step3 = PanelFrameCalculator.calculateClampedPanelFrame(mouseLoc: NSPoint(x: testScreen.minX + (stdSize.width / 2.0) + 1.0, y: testScreen.midY), panelSize: stdSize, visibleFrame: testScreen)
        test("Step probe: 1px before clamp boundary pins to minX", condition: step1.minX == testScreen.minX)
        test("Step probe: exactly on clamp boundary matches minX", condition: step2.minX == testScreen.minX)
        test("Step probe: 1px after clamp boundary moves to minX + 1.0", condition: abs(step3.minX - (testScreen.minX + 1.0)) < 0.001)

        // Sub-pixel coordinates
        let subPixelFrame = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 500.12345, y: 600.98765),
            panelSize: stdSize,
            visibleFrame: testScreen
        )
        test("Sub-pixel coordinates center with float precision", condition: abs(subPixelFrame.midX - 500.12345) < 0.001 && abs(subPixelFrame.midY - 600.98765) < 0.001)

        // =====================================================================
        // SECTION 3: Outside Click Dismissal Deep Verification
        // =====================================================================
        print("\n--- Section 3: Outside Click Dismissal Deep Verification ---")

        let panel = FloatingClipPanel(rootView: Text("Challenger Test"))
        let panelFrame = NSRect(x: 300, y: 300, width: 360, height: 480)

        // Test 3.1: Outside left click on another window
        let targetOtherWindow = NSWindow(contentRect: NSRect(x: 800, y: 800, width: 200, height: 200), styleMask: [.borderless], backing: .buffered, defer: false)
        targetOtherWindow.orderFrontRegardless()

        panel.present(at: panelFrame)
        test("3.1 Panel is visible before outside click", condition: panel.isVisible && panel.hasActiveMonitors)

        let outsideLeftEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: 100, y: 100),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: targetOtherWindow.windowNumber,
            context: nil,
            eventNumber: 101,
            clickCount: 1,
            pressure: 1.0
        )!
        NSApp.sendEvent(outsideLeftEvent)
        test("3.1 Outside left click on another window dismisses panel", condition: !panel.isVisible && !panel.hasActiveMonitors)

        // Test 3.2: Outside right click on another window
        panel.present(at: panelFrame)
        let outsideRightEvent = NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: NSPoint(x: 100, y: 100),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: targetOtherWindow.windowNumber,
            context: nil,
            eventNumber: 102,
            clickCount: 1,
            pressure: 1.0
        )!
        NSApp.sendEvent(outsideRightEvent)
        test("3.2 Outside right click on another window dismisses panel", condition: !panel.isVisible && !panel.hasActiveMonitors)

        // Test 3.3: Inside left click does NOT dismiss panel
        panel.present(at: panelFrame)
        let insideLeftEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: 50, y: 50),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: panel.windowNumber,
            context: nil,
            eventNumber: 103,
            clickCount: 1,
            pressure: 1.0
        )!
        NSApp.sendEvent(insideLeftEvent)
        test("3.3 Inside left click keeps panel visible", condition: panel.isVisible && panel.hasActiveMonitors)

        // Test 3.4: Inside right click does NOT dismiss panel
        let insideRightEvent = NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: NSPoint(x: 50, y: 50),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: panel.windowNumber,
            context: nil,
            eventNumber: 104,
            clickCount: 1,
            pressure: 1.0
        )!
        NSApp.sendEvent(insideRightEvent)
        test("3.4 Inside right click keeps panel visible", condition: panel.isVisible && panel.hasActiveMonitors)
        panel.dismiss()

        // Test 3.5: Click on nil window outside frame dismisses panel
        panel.present(at: panelFrame)
        let nilWindowOutsideEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: 9999, y: 9999),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0, // not a valid window
            context: nil,
            eventNumber: 105,
            clickCount: 1,
            pressure: 1.0
        )!
        NSApp.sendEvent(nilWindowOutsideEvent)
        test("3.5 Click on nil window number outside frame dismisses panel", condition: !panel.isVisible && !panel.hasActiveMonitors)

        // =====================================================================
        // SECTION 4: Escape Key Interception Deep Verification
        // =====================================================================
        print("\n--- Section 4: Escape Key Interception Deep Verification ---")

        let modifierCases: [(String, NSEvent.ModifierFlags)] = [
            ("Standard Escape", []),
            ("Shift + Escape", [.shift]),
            ("Control + Escape", [.control]),
            ("Option + Escape", [.option]),
            ("Command + Escape", [.command]),
            ("Shift + Option + Escape", [.shift, .option]),
            ("Command + Shift + Escape", [.command, .shift]),
            ("Caps Lock + Escape", [.capsLock]),
            ("Function + Escape", [.function])
        ]

        var allEscModifiersDismissed = true
        for (desc, mods) in modifierCases {
            panel.present(at: panelFrame)
            if let escEvt = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: mods,
                timestamp: 0,
                windowNumber: panel.windowNumber,
                context: nil,
                characters: "\u{1b}",
                charactersIgnoringModifiers: "\u{1b}",
                isARepeat: false,
                keyCode: 53
            ) {
                panel.sendEvent(escEvt)
            }
            if panel.isVisible || panel.hasActiveMonitors {
                allEscModifiersDismissed = false
                print("    Failed on modifier: \(desc)")
            }
        }
        test("4.1 All 9 Escape key modifier combinations dismiss panel immediately", condition: allEscModifiersDismissed)

        // Test 4.2: Repeated Escape key (key repeat = true)
        panel.present(at: panelFrame)
        if let repeatEscEvt = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: panel.windowNumber,
            context: nil,
            characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}",
            isARepeat: true,
            keyCode: 53
        ) {
            panel.sendEvent(repeatEscEvt)
        }
        test("4.2 Repeated Escape key (isARepeat: true) dismisses panel cleanly", condition: !panel.isVisible && !panel.hasActiveMonitors)

        // Test 4.3: Non-Escape keys do NOT dismiss panel
        let nonEscKeys: [(String, UInt16, String)] = [
            ("Space", 49, " "),
            ("Return", 36, "\r"),
            ("Tab", 48, "\t"),
            ("A key", 0, "a"),
            ("1 key", 18, "1"),
            ("Left Arrow", 123, "\u{f702}"),
            ("Right Arrow", 124, "\u{f703}"),
            ("Down Arrow", 125, "\u{f701}"),
            ("Up Arrow", 126, "\u{f700}")
        ]

        panel.present(at: panelFrame)
        var nonEscStayedVisible = true
        for (name, kCode, chars) in nonEscKeys {
            if let keyEvt = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: panel.windowNumber,
                context: nil,
                characters: chars,
                charactersIgnoringModifiers: chars,
                isARepeat: false,
                keyCode: kCode
            ) {
                panel.sendEvent(keyEvt)
            }
            if !panel.isVisible {
                nonEscStayedVisible = false
                print("    Premature dismissal on non-escape key: \(name)")
                break
            }
        }
        test("4.3 None of 9 non-escape keys (Space, Return, Tab, A, 1, Arrows) dismiss panel", condition: nonEscStayedVisible)
        panel.dismiss()

        // =====================================================================
        // SECTION 5: High-Frequency Lifecycle Stress & Monitor Teardown
        // =====================================================================
        print("\n--- Section 5: High-Frequency Lifecycle Stress (500 cycles) ---")

        var lifecycleStressPassed = true
        var leakCount = 0
        for i in 1...500 {
            let rect = NSRect(x: 100 + Double(i % 100), y: 100 + Double(i % 100), width: 360, height: 480)
            panel.present(at: rect)
            if !panel.isVisible || !panel.hasActiveMonitors {
                lifecycleStressPassed = false
            }
            // Alternate between dismiss(), cancelOperation, and Escape key
            switch i % 3 {
            case 0:
                panel.dismiss()
            case 1:
                panel.cancelOperation(nil)
            default:
                if let escEvt = NSEvent.keyEvent(
                    with: .keyDown,
                    location: .zero,
                    modifierFlags: [],
                    timestamp: 0,
                    windowNumber: panel.windowNumber,
                    context: nil,
                    characters: "\u{1b}",
                    charactersIgnoringModifiers: "\u{1b}",
                    isARepeat: false,
                    keyCode: 53
                ) {
                    panel.sendEvent(escEvt)
                }
            }
            if panel.isVisible {
                lifecycleStressPassed = false
            }
            if panel.hasActiveMonitors {
                leakCount += 1
            }
        }
        test(
            "5.1 500 rapid present/dismiss cycles with alternating dismissal triggers complete with 0 leaks",
            condition: lifecycleStressPassed && leakCount == 0,
            detail: "leakCount: \(leakCount)"
        )

        // =====================================================================
        // Summary & Verdict
        // =====================================================================
        print("\n=================================================================")
        print("  SuperClip challenger_m2_r2_1 Empirical Stress Summary")
        print("=================================================================")
        print("  Total Tests:  \(total)")
        print("  Passed:       \(passed)")
        print("  Failed:       \(failed)")

        if failed == 0 {
            print("\nVERDICT: APPROVE (PanelFrameCalculator & FloatingClipPanel passed all empirical stress tests)")
            exit(0)
        } else {
            print("\nVERDICT: REJECT (\(failed) defects found in PanelFrameCalculator / FloatingClipPanel)")
            exit(1)
        }
    }
}
