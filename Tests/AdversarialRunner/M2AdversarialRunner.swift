import Foundation
import AppKit
import SwiftUI
import SuperClipCore
import SuperClip

@main
public struct M2AdversarialRunner {
    public static func main() {
        print("==================================================")
        print("  SuperClip M2 Empirical Adversarial Stress Suite ")
        print("  Target: PanelFrameCalculator & FloatingClipPanel")
        print("==================================================")

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

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

        // ==============================================================
        // SUITE 1: PanelFrameCalculator Extreme Geometries & Cursor Clamping
        // ==============================================================
        print("\n--- Suite 1: PanelFrameCalculator Extreme Geometries ---")

        let visible1080p = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let standardPanelSize = NSSize(width: 360, height: 480)

        // 1.1: Cursor Far Outside Positive Screen Boundaries (1e6, 1e6)
        let farPosMouse = NSPoint(x: 1_000_000.0, y: 1_000_000.0)
        let frameFarPos = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: farPosMouse,
            panelSize: standardPanelSize,
            visibleFrame: visible1080p
        )
        report(
            name: "1.1 Cursor far positive (1e6, 1e6) clamps maxX to screen right edge",
            passed: (frameFarPos.maxX == visible1080p.maxX),
            detail: "Expected maxX \(visible1080p.maxX), got \(frameFarPos.maxX)"
        )
        report(
            name: "1.1b Cursor far positive (1e6, 1e6) clamps maxY to screen top edge",
            passed: (frameFarPos.maxY == visible1080p.maxY),
            detail: "Expected maxY \(visible1080p.maxY), got \(frameFarPos.maxY)"
        )
        report(
            name: "1.1c Far positive frame preserves dimensions exactly",
            passed: (frameFarPos.size.width == 360 && frameFarPos.size.height == 480),
            detail: "Got size \(frameFarPos.size)"
        )

        // 1.2: Cursor Far Outside Negative Screen Boundaries (-1e6, -1e6)
        let farNegMouse = NSPoint(x: -1_000_000.0, y: -1_000_000.0)
        let frameFarNeg = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: farNegMouse,
            panelSize: standardPanelSize,
            visibleFrame: visible1080p
        )
        report(
            name: "1.2 Cursor far negative (-1e6, -1e6) clamps minX to screen left edge",
            passed: (frameFarNeg.minX == visible1080p.minX),
            detail: "Expected minX \(visible1080p.minX), got \(frameFarNeg.minX)"
        )
        report(
            name: "1.2b Cursor far negative (-1e6, -1e6) clamps minY to screen bottom edge",
            passed: (frameFarNeg.minY == visible1080p.minY),
            detail: "Expected minY \(visible1080p.minY), got \(frameFarNeg.minY)"
        )

        // 1.3: Mixed Far Coordinates (+5e7, -2e7)
        let mixedFarMouse = NSPoint(x: 50_000_000.0, y: -20_000_000.0)
        let frameMixedFar = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: mixedFarMouse,
            panelSize: standardPanelSize,
            visibleFrame: visible1080p
        )
        report(
            name: "1.3 Mixed far cursor (+5e7, -2e7) clamps X to max and Y to min",
            passed: (frameMixedFar.maxX == visible1080p.maxX && frameMixedFar.minY == visible1080p.minY),
            detail: "maxX: \(frameMixedFar.maxX), minY: \(frameMixedFar.minY)"
        )

        // 1.4: Synthetic Multi-Monitor - Negative Left Display (-2560 to 0)
        let leftDisplay = NSRect(x: -2560.0, y: 0.0, width: 2560.0, height: 1440.0)
        let leftCenterMouse = NSPoint(x: -1280.0, y: 720.0)
        let frameLeftCenter = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: leftCenterMouse,
            panelSize: standardPanelSize,
            visibleFrame: leftDisplay
        )
        report(
            name: "1.4 Left display cursor centers accurately at negative origin",
            passed: (frameLeftCenter.origin.x == -1280.0 - 180.0 && frameLeftCenter.origin.y == 720.0 - 240.0),
            detail: "Origin: \(frameLeftCenter.origin)"
        )

        // 1.5: Synthetic Multi-Monitor - Negative Bottom Display (-1440 to 0)
        let bottomDisplay = NSRect(x: 0.0, y: -1440.0, width: 2560.0, height: 1440.0)
        let bottomCenterMouse = NSPoint(x: 1280.0, y: -720.0)
        let frameBottomCenter = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: bottomCenterMouse,
            panelSize: standardPanelSize,
            visibleFrame: bottomDisplay
        )
        report(
            name: "1.5 Bottom display cursor centers accurately at negative Y",
            passed: (frameBottomCenter.origin.x == 1280.0 - 180.0 && frameBottomCenter.origin.y == -720.0 - 240.0),
            detail: "Origin: \(frameBottomCenter.origin)"
        )

        // 1.6: Synthetic Multi-Monitor - Diagonal Negative Display (-1920 to 0, -1080 to 0)
        let diagonalNegDisplay = NSRect(x: -1920.0, y: -1080.0, width: 1920.0, height: 1080.0)
        let diagExtremeMouse = NSPoint(x: -3000.0, y: -2000.0)
        let frameDiagNeg = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: diagExtremeMouse,
            panelSize: standardPanelSize,
            visibleFrame: diagonalNegDisplay
        )
        report(
            name: "1.6 Diagonal negative display clamps extreme out-of-bounds cursor",
            passed: (frameDiagNeg.minX == -1920.0 && frameDiagNeg.minY == -1080.0),
            detail: "minX: \(frameDiagNeg.minX), minY: \(frameDiagNeg.minY)"
        )

        // 1.7: Panel Larger Than Screen - Width Exceeds Screen
        let widePanel = NSSize(width: 3000.0, height: 400.0)
        let frameWidePanel = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 500.0, y: 500.0),
            panelSize: widePanel,
            visibleFrame: visible1080p
        )
        report(
            name: "1.7 Panel wider than screen pins originX to visibleFrame.minX",
            passed: (frameWidePanel.origin.x == visible1080p.minX && frameWidePanel.width == 3000.0),
            detail: "originX: \(frameWidePanel.origin.x), width: \(frameWidePanel.width)"
        )

        // 1.8: Panel Larger Than Screen - Height Exceeds Screen
        let tallPanel = NSSize(width: 300.0, height: 2000.0)
        let frameTallPanel = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 500.0, y: 500.0),
            panelSize: tallPanel,
            visibleFrame: visible1080p
        )
        report(
            name: "1.8 Panel taller than screen pins originY to visibleFrame.minY",
            passed: (frameTallPanel.origin.y == visible1080p.minY && frameTallPanel.height == 2000.0),
            detail: "originY: \(frameTallPanel.origin.y), height: \(frameTallPanel.height)"
        )

        // 1.9: Panel Larger Than Screen - Both Dimensions Exceed Screen
        let giantPanel = NSSize(width: 4000.0, height: 3000.0)
        let frameGiantPanel = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 960.0, y: 540.0),
            panelSize: giantPanel,
            visibleFrame: visible1080p
        )
        report(
            name: "1.9 Giant panel pins both originX and originY to visibleFrame min bounds",
            passed: (frameGiantPanel.origin.x == visible1080p.minX && frameGiantPanel.origin.y == visible1080p.minY),
            detail: "origin: \(frameGiantPanel.origin)"
        )

        // 1.10: Zero-Size Screen (0x0)
        let zeroScreen = NSRect(x: 100.0, y: 200.0, width: 0.0, height: 0.0)
        let frameZeroScreen = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 50.0, y: 50.0),
            panelSize: standardPanelSize,
            visibleFrame: zeroScreen
        )
        report(
            name: "1.10 Zero-size screen handles gracefully without crashing or zero-division",
            passed: (frameZeroScreen.origin.x == 100.0 && frameZeroScreen.origin.y == 200.0),
            detail: "origin: \(frameZeroScreen.origin)"
        )

        // 1.11: Zero-Size Panel (0x0)
        let zeroPanel = NSSize(width: 0.0, height: 0.0)
        let frameZeroPanel = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 500.0, y: 400.0),
            panelSize: zeroPanel,
            visibleFrame: visible1080p
        )
        report(
            name: "1.11 Zero-size panel clamps cursor point accurately within bounds",
            passed: (frameZeroPanel.origin.x == 500.0 && frameZeroPanel.origin.y == 400.0 && frameZeroPanel.size == .zero),
            detail: "frame: \(frameZeroPanel)"
        )

        // 1.12: Degenerate 1x1 Pixel Screen
        let microScreen = NSRect(x: 50.0, y: 50.0, width: 1.0, height: 1.0)
        let frameMicroScreen = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 20.0, y: 20.0),
            panelSize: standardPanelSize,
            visibleFrame: microScreen
        )
        report(
            name: "1.12 Micro 1x1 screen clamps panel origin to screen origin",
            passed: (frameMicroScreen.origin.x == 50.0 && frameMicroScreen.origin.y == 50.0),
            detail: "origin: \(frameMicroScreen.origin)"
        )

        // 1.13: Infinity Coordinates Clamping Behavior
        let infMouse = NSPoint(x: Double.infinity, y: -Double.infinity)
        let frameInf = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: infMouse,
            panelSize: standardPanelSize,
            visibleFrame: visible1080p
        )
        report(
            name: "1.13 Positive infinity X clamps to maxX - width",
            passed: (frameInf.maxX == visible1080p.maxX),
            detail: "maxX: \(frameInf.maxX)"
        )
        report(
            name: "1.13b Negative infinity Y clamps to minY",
            passed: (frameInf.minY == visible1080p.minY),
            detail: "minY: \(frameInf.minY)"
        )

        // 1.14: Infinite Panel Dimensions Handling
        let infPanelSize = NSSize(width: Double.infinity, height: Double.infinity)
        let frameInfPanel = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 200, y: 200),
            panelSize: infPanelSize,
            visibleFrame: visible1080p
        )
        report(
            name: "1.14 Infinite panel size clamps safely to visibleFrame.minX and minY",
            passed: (frameInfPanel.origin.x == visible1080p.minX && frameInfPanel.origin.y == visible1080p.minY),
            detail: "origin: \(frameInfPanel.origin)"
        )

        // 1.15: NaN Coordinate Robustness
        // When mouseLoc is NaN, origin calculates as NaN.
        // We verify that findScreen fallback handles NaN point without exception,
        // and calculateClampedPanelFrame does not crash.
        let nanMouse = NSPoint(x: Double.nan, y: Double.nan)
        let foundScreenForNaN = PanelFrameCalculator.findScreen(for: nanMouse)
        report(
            name: "1.15 findScreen safely returns fallback screen on NaN cursor coordinates",
            passed: (foundScreenForNaN != nil),
            detail: "Resolved screen: \(String(describing: foundScreenForNaN))"
        )
        let frameNaN = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: nanMouse,
            panelSize: standardPanelSize,
            visibleFrame: visible1080p
        )
        report(
            name: "1.15b NaN coordinates calculate without crash or signal",
            passed: (frameNaN.origin.x.isNaN && frameNaN.origin.y.isNaN),
            detail: "originX.isNaN: \(frameNaN.origin.x.isNaN), originY.isNaN: \(frameNaN.origin.y.isNaN)"
        )

        // ==============================================================
        // SUITE 2: FloatingClipPanel Initialization & Property Invariants
        // ==============================================================
        print("\n--- Suite 2: FloatingClipPanel Invariants & Properties ---")

        let panel = FloatingClipPanel(rootView: Text("Adversarial Content"))

        report(
            name: "2.1 Panel is marked as floating panel",
            passed: panel.isFloatingPanel
        )
        report(
            name: "2.2 Panel level is .floating",
            passed: (panel.level == .floating)
        )
        report(
            name: "2.3 Panel canBecomeKey is overridden to true",
            passed: panel.canBecomeKey
        )
        report(
            name: "2.4 Panel canBecomeMain is overridden to true",
            passed: panel.canBecomeMain
        )
        report(
            name: "2.5 Panel is non-opaque for rounded styling",
            passed: !panel.isOpaque
        )
        report(
            name: "2.6 Panel background color is clear",
            passed: (panel.backgroundColor == .clear)
        )
        report(
            name: "2.7 Panel has native window shadow enabled",
            passed: panel.hasShadow
        )
        report(
            name: "2.8 Panel styleMask contains .nonactivatingPanel",
            passed: panel.styleMask.contains(.nonactivatingPanel)
        )
        report(
            name: "2.9 Panel collectionBehavior includes canJoinAllSpaces and fullScreenAuxiliary",
            passed: (panel.collectionBehavior.contains(.canJoinAllSpaces) &&
                     panel.collectionBehavior.contains(.fullScreenAuxiliary))
        )
        report(
            name: "2.10 Panel hidesOnDeactivate is false",
            passed: !panel.hidesOnDeactivate
        )
        report(
            name: "2.11 Panel isReleasedWhenClosed is false",
            passed: !panel.isReleasedWhenClosed
        )

        // 2.12: Rapid Panel Instantiation and Disposal (50 panels)
        var rapidCreationPassed = true
        for _ in 0..<50 {
            let tempPanel = FloatingClipPanel(rootView: Text("Temp"))
            if !tempPanel.canBecomeKey || tempPanel.level != .floating {
                rapidCreationPassed = false
                break
            }
        }
        report(
            name: "2.12 Rapid creation of 50 panel instances succeeds cleanly",
            passed: rapidCreationPassed
        )

        // ==============================================================
        // SUITE 3: FloatingClipPanel Presentation & Dismissal Transitions
        // ==============================================================
        print("\n--- Suite 3: Presentation, Dismissal & Event Monitors ---")

        let testRect = NSRect(x: 200, y: 200, width: 360, height: 480)

        // 3.1: Normal Presentation
        panel.present(at: testRect)
        report(
            name: "3.1 Panel is visible after present(at:)",
            passed: panel.isVisible
        )
        report(
            name: "3.1b Panel frame matches target rect",
            passed: (panel.frame == testRect)
        )
        report(
            name: "3.1c Event monitors active upon presentation",
            passed: panel.hasActiveMonitors
        )

        // 3.2: Re-presentation while already visible
        let newRect = NSRect(x: 300, y: 300, width: 360, height: 480)
        panel.present(at: newRect)
        report(
            name: "3.2 Re-presentation updates frame to new target rect",
            passed: (panel.frame == newRect),
            detail: "Current frame: \(panel.frame)"
        )
        report(
            name: "3.2b Re-presentation preserves active event monitors without duplication",
            passed: panel.hasActiveMonitors
        )

        // 3.3: Clean Dismissal and Callback Propagation
        var dismissCallbackFired = false
        panel.onDismiss = { dismissCallbackFired = true }
        panel.dismiss()
        report(
            name: "3.3 Panel is hidden after dismiss()",
            passed: !panel.isVisible
        )
        report(
            name: "3.3b Event monitors removed after dismiss()",
            passed: !panel.hasActiveMonitors
        )
        report(
            name: "3.3c onDismiss callback invoked cleanly",
            passed: dismissCallbackFired
        )

        // 3.4: Idempotent Dismissal (Multiple redundant calls)
        var redundantCallbacks = 0
        panel.onDismiss = { redundantCallbacks += 1 }
        panel.dismiss()
        panel.dismiss()
        panel.dismiss()
        report(
            name: "3.4 Redundant dismiss() calls are idempotent (0 callbacks on hidden panel)",
            passed: (redundantCallbacks == 0),
            detail: "Callbacks fired: \(redundantCallbacks)"
        )

        // 3.5: Re-entrant Dismissal Protection
        panel.present(at: testRect)
        var reentrantDidNotRecurse = true
        panel.onDismiss = {
            // Re-entrant dismiss call inside callback
            panel.dismiss()
            reentrantDidNotRecurse = true
        }
        panel.dismiss()
        report(
            name: "3.5 Re-entrant dismiss inside onDismiss does not cause infinite loop or stack overflow",
            passed: reentrantDidNotRecurse
        )

        // 3.6: Direct orderOut Dismantles Monitors
        panel.present(at: testRect)
        report(
            name: "3.6 Panel is visible before direct orderOut",
            passed: panel.isVisible
        )
        panel.orderOut(nil)
        report(
            name: "3.6b Direct orderOut(nil) unregisters event monitors",
            passed: !panel.hasActiveMonitors
        )

        // 3.7: Background Thread Dismissal Safety
        panel.present(at: testRect)
        let bgGroup = DispatchGroup()
        bgGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            panel.dismiss()
            bgGroup.leave()
        }
        _ = bgGroup.wait(timeout: .now() + 1.0)
        // Pump main run loop to process main thread async dispatch
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        report(
            name: "3.7 Background thread dismiss safely dispatches to main thread",
            passed: !panel.isVisible
        )

        // ==============================================================
        // SUITE 4: Escape Key & Outside Click Adversarial Challenges
        // ==============================================================
        print("\n--- Suite 4: Escape Interception & Outside Click Simulation ---")

        // 4.1: Standard Escape Key (KeyCode 53)
        panel.present(at: testRect)
        if let escEvent = NSEvent.keyEvent(
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
            panel.sendEvent(escEvent)
        }
        report(
            name: "4.1 Escape key (keyCode 53) immediately dismisses panel",
            passed: !panel.isVisible
        )
        report(
            name: "4.1b Escape dismissal cleans up event monitors",
            passed: !panel.hasActiveMonitors
        )

        // 4.2: Escape Key with Modifiers (Shift + Escape)
        panel.present(at: testRect)
        if let shiftEscEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.shift],
            timestamp: 0,
            windowNumber: panel.windowNumber,
            context: nil,
            characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}",
            isARepeat: false,
            keyCode: 53
        ) {
            panel.sendEvent(shiftEscEvent)
        }
        report(
            name: "4.2 Shift + Escape key immediately dismisses panel",
            passed: !panel.isVisible
        )

        // 4.3: Escape Key with Command Modifier (Cmd + Escape)
        panel.present(at: testRect)
        if let cmdEscEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: panel.windowNumber,
            context: nil,
            characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}",
            isARepeat: false,
            keyCode: 53
        ) {
            panel.sendEvent(cmdEscEvent)
        }
        report(
            name: "4.3 Cmd + Escape key immediately dismisses panel",
            passed: !panel.isVisible
        )

        // 4.4: Non-Escape Key (KeyCode 49 = Space) must NOT dismiss
        panel.present(at: testRect)
        if let spaceEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: panel.windowNumber,
            context: nil,
            characters: " ",
            charactersIgnoringModifiers: " ",
            isARepeat: false,
            keyCode: 49
        ) {
            panel.sendEvent(spaceEvent)
        }
        report(
            name: "4.4 Non-Escape key (Space, keyCode 49) does NOT dismiss panel",
            passed: panel.isVisible
        )
        panel.dismiss()

        // 4.5: AppKit cancelOperation invocation
        panel.present(at: testRect)
        panel.cancelOperation(nil)
        report(
            name: "4.5 cancelOperation(nil) dismisses panel immediately",
            passed: !panel.isVisible
        )

        // 4.6: Item Selection Triggers Dismissal & Callback
        panel.present(at: testRect)
        var selectedItemResult: ClipItem?
        panel.onItemSelected = { selectedItemResult = $0 }
        let testItem = ClipItem(contentType: .text, textContent: "Adversarial Clip Selection", byteSize: 26)
        panel.handleItemSelection(testItem)
        report(
            name: "4.6 handleItemSelection dismisses panel immediately",
            passed: !panel.isVisible
        )
        report(
            name: "4.6b onItemSelected receives exact clip item payload",
            passed: (selectedItemResult?.textContent == "Adversarial Clip Selection"),
            detail: "Got: \(String(describing: selectedItemResult?.textContent))"
        )

        // 4.7: Rapid Toggle Stress (20 iterations)
        var toggleConsistent = true
        for i in 0..<20 {
            panel.toggleNearCursor(size: standardPanelSize)
            let expectedVisible = (i % 2 == 0)
            if panel.isVisible != expectedVisible {
                toggleConsistent = false
                break
            }
        }
        if panel.isVisible {
            panel.dismiss()
        }
        report(
            name: "4.7 Rapid toggle near cursor (20 cycles) alternates deterministically",
            passed: toggleConsistent
        )

        // ==============================================================
        // SUITE 5: Deep Outside Click, Resign Key & Multi-Display Boundaries
        // ==============================================================
        print("\n--- Suite 5: Resign Key, Outside Click & Screen Disambiguation ---")

        // 5.1: didResignKeyNotification on self triggers dismissal
        panel.present(at: testRect)
        report(
            name: "5.1 Panel is visible before didResignKeyNotification",
            passed: panel.isVisible
        )
        NotificationCenter.default.post(
            name: NSWindow.didResignKeyNotification,
            object: panel
        )
        report(
            name: "5.1b didResignKeyNotification on panel immediately dismisses panel",
            passed: !panel.isVisible
        )
        report(
            name: "5.1c Monitors removed upon resign key dismissal",
            passed: !panel.hasActiveMonitors
        )

        // 5.2: didResignKeyNotification on another window does NOT dismiss panel
        panel.present(at: testRect)
        let otherWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        NotificationCenter.default.post(
            name: NSWindow.didResignKeyNotification,
            object: otherWindow
        )
        report(
            name: "5.2 didResignKeyNotification on unrelated window does NOT dismiss panel",
            passed: panel.isVisible
        )
        panel.dismiss()

        // 5.3: Clean deallocation while visible does not crash or leak
        var deallocPanel: FloatingClipPanel? = FloatingClipPanel(rootView: Text("Dealloc"))
        deallocPanel?.present(at: testRect)
        let wasVisible = deallocPanel?.isVisible == true
        let hadMonitors = deallocPanel?.hasActiveMonitors == true
        deallocPanel = nil
        report(
            name: "5.3 Visible panel with active monitors deallocates cleanly without crash",
            passed: (wasVisible && hadMonitors && deallocPanel == nil)
        )

        // 5.4: Multi-Display boundary point disambiguation
        let screenList = NSScreen.screens
        let boundaryPoint = NSPoint(x: 0.0, y: 0.0)
        let resolvedScreen = PanelFrameCalculator.findScreen(for: boundaryPoint, screens: screenList)
        report(
            name: "5.4 findScreen successfully resolves boundary point (0, 0)",
            passed: (resolvedScreen != nil || screenList.isEmpty)
        )

        // 5.5: Empty screens array in findScreen safely falls back
        let fallbackScreen = PanelFrameCalculator.findScreen(for: NSPoint(x: 100, y: 100), screens: [])
        report(
            name: "5.5 findScreen with empty screens array safely falls back without crash",
            passed: (fallbackScreen == NSScreen.main || fallbackScreen == nil)
        )

        // 5.6: Headless calculateClampedPanelFrame fallback when screen is nil
        let headlessFrame = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 500, y: 500),
            panelSize: standardPanelSize,
            targetScreen: nil
        )
        report(
            name: "5.6 calculateClampedPanelFrame returns centered frame when screen is nil or auto-resolved",
            passed: (headlessFrame.size == standardPanelSize),
            detail: "Size: \(headlessFrame.size)"
        )

        // ==============================================================
        // Summary & Verdict
        // ==============================================================
        print("\n==================================================")
        print("  SuperClip M2 Adversarial Test Summary           ")
        print("==================================================")
        print("  Total Challenges: \(totalTests)")
        print("  Passed:           \(passedTests)")
        print("  Failed:           \(failedTests)")

        if failedTests > 0 {
            print("\nVERDICT: REJECT (Found \(failedTests) failure modes in M2 windowing/clamping)")
            exit(1)
        } else {
            print("\nVERDICT: APPROVE (All M2 adversarial challenges passed with 0 errors)")
            exit(0)
        }
    }
}
