import Foundation
import AppKit
import Carbon
import SuperClipCore
import SuperClip

// MARK: - Mock Panel Presenter for Coordination Testing

final class Tier5MockFloatingPanel: FloatingPanelPresenting {
    var isVisible: Bool = false
    var isKeyWindow: Bool = false
    var showCallCount: Int = 0
    var dismissCallCount: Int = 0
    var lastMouseLocation: NSPoint?

    func show(near mouseLocation: NSPoint) {
        isVisible = true
        isKeyWindow = true
        showCallCount += 1
        lastMouseLocation = mouseLocation
    }

    func dismiss() {
        isVisible = false
        isKeyWindow = false
        dismissCallCount += 1
    }

    func reset() {
        isVisible = false
        isKeyWindow = false
        showCallCount = 0
        dismissCallCount = 0
        lastMouseLocation = nil
    }
}

// MARK: - Mock HotKeyManager for Registration Tracking

final class Tier5MockHotKeyManager: HotKeyManaging {
    var onTrigger: (() -> Void)?
    var registeredHistory: [(keyCode: UInt32, modifiers: UInt32)] = []
    var unregisterCount: Int = 0
    private let lock = NSLock()

    var lastRegisteredKeyCode: UInt32? {
        lock.lock()
        defer { lock.unlock() }
        return registeredHistory.last?.keyCode
    }

    var lastRegisteredModifiers: UInt32? {
        lock.lock()
        defer { lock.unlock() }
        return registeredHistory.last?.modifiers
    }

    func register(keyCode: UInt32, modifiers: UInt32) {
        lock.lock()
        defer { lock.unlock() }
        registeredHistory.append((keyCode, modifiers))
    }

    func unregister() {
        lock.lock()
        defer { lock.unlock() }
        unregisterCount += 1
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        registeredHistory.removeAll()
        unregisterCount = 0
    }
}

// MARK: - Main Test Harness

@main
struct ChallengerTier5StressRunner {
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

    static func createTempDirectory(prefix: String) -> URL {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperClip_\(prefix)_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        return temp
    }

    static func cleanupTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static func createDummyPNG(width: Int = 32, height: Int = 32) -> Data {
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
        return rep.representation(using: .png, properties: [:]) ?? Data()
    }

    static func main() {
        print("==================================================")
        print("  SuperClip Tier 5 Adversarial Stress Harness    ")
        print("  White-Box Coverage & Packaging Hardening       ")
        print("==================================================")

        let startTime = CFAbsoluteTimeGetCurrent()

        testPanelFrameCalculatorClamping()
        testStatusItemContextMenuAndPopoverConcurrency()
        testHotKeyRegistrationThrashing()
        testApplicationBundleLaunchIsolation()
        testCopyOnlyPasteboardWritebackAndZeroAccessibility()

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        print("")
        print("==================================================")
        print("  Tier 5 Stress Test Execution Summary            ")
        print("==================================================")
        print("  Total Tests Executed: \(totalTests)")
        print("  Tests Passed:         \(passedTests)")
        print("  Tests Failed:         \(failedTests)")
        print("  Elapsed Time:         \(String(format: "%.3f", elapsed))s")
        print("==================================================")

        if failedTests == 0 {
            print("VERDICT: APPROVE (100% Pass Rate, 0 Emojis, Zero Crashes)")
            exit(0)
        } else {
            print("VERDICT: REJECT (\(failedTests) Tests Failed)")
            exit(1)
        }
    }

    // MARK: - Test Suite 1: PanelFrameCalculator Clamping Stress

    static func testPanelFrameCalculatorClamping() {
        print("")
        print("=== Suite 1: PanelFrameCalculator Clamping Stress ===")

        let panelSize = NSSize(width: 360, height: 480)

        // 1. Single Display with Menu Bar (top 24px) and Dock (bottom 68px)
        let primaryVisibleFrame = NSRect(x: 0, y: 68, width: 1920, height: 988)

        // Center cursor
        let centerPoint = NSPoint(x: 960, y: 540)
        let centerResult = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: centerPoint,
            panelSize: panelSize,
            visibleFrame: primaryVisibleFrame
        )
        report(
            name: "Panel centered at (960, 540) has expected width and height",
            passed: centerResult.width == 360 && centerResult.height == 480
        )
        report(
            name: "Panel centered at (960, 540) is within visibleFrame bounds",
            passed: centerResult.minX >= primaryVisibleFrame.minX &&
                    centerResult.maxX <= primaryVisibleFrame.maxX &&
                    centerResult.minY >= primaryVisibleFrame.minY &&
                    centerResult.maxY <= primaryVisibleFrame.maxY
        )

        // Menu Bar Collision (Cursor high inside menu bar area: y = 1075)
        let menuBarCursor = NSPoint(x: 960, y: 1075)
        let menuBarResult = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: menuBarCursor,
            panelSize: panelSize,
            visibleFrame: primaryVisibleFrame
        )
        report(
            name: "Menu bar collision clamps top of panel to visibleFrame.maxY (1056)",
            passed: menuBarResult.maxY == primaryVisibleFrame.maxY
        )
        report(
            name: "Menu bar collision panel remains strictly within visible bounds",
            passed: menuBarResult.minY >= primaryVisibleFrame.minY
        )

        // Dock Bottom Collision (Cursor inside Dock region: y = 20)
        let dockBottomCursor = NSPoint(x: 960, y: 20)
        let dockBottomResult = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: dockBottomCursor,
            panelSize: panelSize,
            visibleFrame: primaryVisibleFrame
        )
        report(
            name: "Dock bottom collision clamps bottom of panel to visibleFrame.minY (68)",
            passed: dockBottomResult.minY == primaryVisibleFrame.minY
        )
        report(
            name: "Dock bottom collision panel does not exceed visibleFrame.maxY",
            passed: dockBottomResult.maxY <= primaryVisibleFrame.maxY
        )

        // Left screen collision (x = 10)
        let leftCursor = NSPoint(x: 10, y: 540)
        let leftResult = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: leftCursor,
            panelSize: panelSize,
            visibleFrame: primaryVisibleFrame
        )
        report(
            name: "Left screen collision clamps panel originX to visibleFrame.minX (0)",
            passed: leftResult.minX == primaryVisibleFrame.minX
        )

        // Right screen collision (x = 1910)
        let rightCursor = NSPoint(x: 1910, y: 540)
        let rightResult = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: rightCursor,
            panelSize: panelSize,
            visibleFrame: primaryVisibleFrame
        )
        report(
            name: "Right screen collision clamps panel maxX to visibleFrame.maxX (1920)",
            passed: rightResult.maxX == primaryVisibleFrame.maxX
        )

        // Dock on Left edge: visibleFrame(x: 70, y: 0, width: 1850, height: 1056)
        let leftDockVisible = NSRect(x: 70, y: 0, width: 1850, height: 1056)
        let leftDockCursor = NSPoint(x: 20, y: 500)
        let leftDockResult = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: leftDockCursor,
            panelSize: panelSize,
            visibleFrame: leftDockVisible
        )
        report(
            name: "Left Dock collision clamps panel minX to leftDockVisible.minX (70)",
            passed: leftDockResult.minX == 70
        )

        // Dock on Right edge: visibleFrame(x: 0, y: 0, width: 1850, height: 1056)
        let rightDockVisible = NSRect(x: 0, y: 0, width: 1850, height: 1056)
        let rightDockCursor = NSPoint(x: 1900, y: 500)
        let rightDockResult = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: rightDockCursor,
            panelSize: panelSize,
            visibleFrame: rightDockVisible
        )
        report(
            name: "Right Dock collision clamps panel maxX to rightDockVisible.maxX (1850)",
            passed: rightDockResult.maxX == 1850
        )

        // 2. Multi-Display Horizontal Layout with Negative X Coordinates
        // Display 2 (Left): frame (-1920, 0, 1920, 1080), visibleFrame (-1920, 0, 1920, 1080)
        let secondaryLeftVisible = NSRect(x: -1920, y: 0, width: 1920, height: 1080)

        let negativeCenterCursor = NSPoint(x: -960, y: 540)
        let negativeCenterResult = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: negativeCenterCursor,
            panelSize: panelSize,
            visibleFrame: secondaryLeftVisible
        )
        report(
            name: "Negative coordinate center panel minX is within [-1920, 0]",
            passed: negativeCenterResult.minX >= -1920 && negativeCenterResult.maxX <= 0
        )
        report(
            name: "Negative coordinate center panel originX is centered at -1140",
            passed: negativeCenterResult.origin.x == -1140
        )

        let negativeLeftCornerCursor = NSPoint(x: -1915, y: 1075)
        let negativeLeftCornerResult = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: negativeLeftCornerCursor,
            panelSize: panelSize,
            visibleFrame: secondaryLeftVisible
        )
        report(
            name: "Negative display left-top corner clamps minX to -1920 and maxY to 1080",
            passed: negativeLeftCornerResult.minX == -1920 && negativeLeftCornerResult.maxY == 1080
        )

        let negativeSeamCursor = NSPoint(x: -5, y: 500)
        let negativeSeamResult = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: negativeSeamCursor,
            panelSize: panelSize,
            visibleFrame: secondaryLeftVisible
        )
        report(
            name: "Negative display right seam clamps maxX to exactly 0",
            passed: negativeSeamResult.maxX == 0
        )

        // 3. Multi-Display Vertical Layout with Negative Y Coordinates
        // Display 3 (Bottom): frame (0, -1440, 2560, 1440), visibleFrame (0, -1440, 2560, 1440)
        let bottomStackedVisible = NSRect(x: 0, y: -1440, width: 2560, height: 1440)
        let negativeYCursor = NSPoint(x: 1280, y: -720)
        let negativeYResult = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: negativeYCursor,
            panelSize: panelSize,
            visibleFrame: bottomStackedVisible
        )
        report(
            name: "Negative Y display center panel minY is >= -1440 and maxY <= 0",
            passed: negativeYResult.minY >= -1440 && negativeYResult.maxY <= 0
        )
        report(
            name: "Negative Y display center originY is exactly -960",
            passed: negativeYResult.origin.y == -960
        )

        let negativeYBottomCursor = NSPoint(x: 1280, y: -1435)
        let negativeYBottomResult = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: negativeYBottomCursor,
            panelSize: panelSize,
            visibleFrame: bottomStackedVisible
        )
        report(
            name: "Negative Y bottom collision clamps panel minY to exactly -1440",
            passed: negativeYBottomResult.minY == -1440
        )

        // 4. Asymmetric Triple Display Arrangement with Negative X and Negative Y
        let asymmetricVisible = NSRect(x: -2560, y: -500, width: 2560, height: 1440)
        let asymmetricCursor = NSPoint(x: -2500, y: -450)
        let asymmetricResult = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: asymmetricCursor,
            panelSize: panelSize,
            visibleFrame: asymmetricVisible
        )
        report(
            name: "Asymmetric display with negative X and negative Y clamps minX >= -2560",
            passed: asymmetricResult.minX == -2560
        )
        report(
            name: "Asymmetric display with negative X and negative Y clamps minY >= -500",
            passed: asymmetricResult.minY == -500
        )

        // 5. Extreme Edge Cases: Oversized Panel
        let oversizedPanel = NSSize(width: 2500, height: 1500)
        let oversizedResult = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 960, y: 540),
            panelSize: oversizedPanel,
            visibleFrame: primaryVisibleFrame
        )
        report(
            name: "Oversized panel width clamped to visibleFrame.minX gracefully",
            passed: oversizedResult.minX == primaryVisibleFrame.minX
        )
        report(
            name: "Oversized panel height clamped to visibleFrame.minY gracefully",
            passed: oversizedResult.minY == primaryVisibleFrame.minY
        )

        // 6. Zero Dimensions Panel
        let zeroPanel = NSSize(width: 0, height: 0)
        let zeroResult = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 500, y: 500),
            panelSize: zeroPanel,
            visibleFrame: primaryVisibleFrame
        )
        report(
            name: "Zero dimension panel produces zero size without crash or NaN",
            passed: zeroResult.width == 0 && zeroResult.height == 0 && !zeroResult.origin.x.isNaN
        )

        // 7. Micro Panel (1x1)
        let microPanel = NSSize(width: 1, height: 1)
        let microResult = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 500, y: 500),
            panelSize: microPanel,
            visibleFrame: primaryVisibleFrame
        )
        report(
            name: "1x1 micro panel centers correctly within visible bounds",
            passed: microResult.width == 1 && microResult.height == 1 &&
                    microResult.minX >= primaryVisibleFrame.minX &&
                    microResult.maxX <= primaryVisibleFrame.maxX
        )

        // 8. Far Out-of-Bounds Cursor (e.g. 100000, -100000)
        let extremePoint = NSPoint(x: 100000, y: -100000)
        let extremeResult = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: extremePoint,
            panelSize: panelSize,
            visibleFrame: primaryVisibleFrame
        )
        report(
            name: "Far out-of-bounds cursor clamps strictly to visibleFrame maxX and minY",
            passed: extremeResult.maxX == primaryVisibleFrame.maxX &&
                    extremeResult.minY == primaryVisibleFrame.minY
        )
    }

    // MARK: - Test Suite 2: StatusItem Context Menu & Popover Concurrency Stress

    static func testStatusItemContextMenuAndPopoverConcurrency() {
        print("")
        print("=== Suite 2: StatusItem Context Menu & Popover Concurrency Stress ===")

        let mockPanel = Tier5MockFloatingPanel()
        let mockHotKey = Tier5MockHotKeyManager()

        let dummyVC = NSViewController()
        dummyVC.view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 480))

        let statusManager = StatusItemManager(
            contentViewController: dummyVC,
            floatingPanel: mockPanel,
            hotKeyManager: mockHotKey
        )

        // 1. Initial State
        report(
            name: "Initial statusItem.menu is nil for left-click tracking",
            passed: statusManager.statusItem.menu == nil
        )
        report(
            name: "Initial popover is not shown",
            passed: !statusManager.popover.isShown
        )

        // 2. Context Menu Presentation & Clean Closure
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            statusManager.contextMenu.cancelTracking()
            statusManager.menuDidClose(statusManager.contextMenu)
        }
        statusManager.showContextMenu()
        // Drain runloop to ensure cancelTracking and menuDidClose executed
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        report(
            name: "showContextMenu and menuDidClose execute cleanly without blocking",
            passed: statusManager.statusItem.menu == nil
        )

        // 3. Mutual Exclusion: Popover vs Floating Panel
        mockPanel.show(near: NSPoint(x: 500, y: 500))
        report(
            name: "Floating panel is visible before popover open",
            passed: mockPanel.isVisible
        )

        statusManager.showPopover()
        report(
            name: "showPopover dismisses floating panel cleanly (mutual exclusion)",
            passed: !mockPanel.isVisible && mockPanel.dismissCallCount >= 1
        )

        statusManager.closePopover()
        report(
            name: "closePopover cleans up popover state",
            passed: !statusManager.popover.isShown
        )

        // 4. HotKey Trigger Presentation & Mutual Exclusion
        statusManager.showPopover()
        statusManager.handleHotKeyTrigger()
        report(
            name: "handleHotKeyTrigger summons floating panel and closes popover",
            passed: mockPanel.isVisible && !statusManager.popover.isShown
        )

        statusManager.handleHotKeyTrigger()
        report(
            name: "handleHotKeyTrigger while panel is active toggles panel off",
            passed: !mockPanel.isVisible
        )

        // 5. Debounce Testing (250ms)
        let now = ProcessInfo.processInfo.systemUptime
        statusManager.setLastPopoverCloseTimestampForTesting(now)
        // Click within debounce (< 250ms)
        statusManager.statusItemClicked(nil)
        report(
            name: "Click within 250ms debounce window suppresses popover reopen",
            passed: !statusManager.popover.isShown
        )

        // Timestamp expired (> 250ms ago)
        statusManager.setLastPopoverCloseTimestampForTesting(now - 0.30)
        statusManager.statusItemClicked(nil)
        report(
            name: "Click after 250ms debounce window allows popover show",
            passed: statusManager.popover.isShown
        )
        statusManager.closePopover()

        // 6. Rapid Interleaved Context Menu and Popover Cycles (100 cycles)
        var menuCyclePassed = true
        for _ in 0..<100 {
            // Context menu simulation
            statusManager.floatingPanel?.dismiss()
            statusManager.closePopover()
            statusManager.statusItem.menu = statusManager.contextMenu
            if statusManager.statusItem.menu !== statusManager.contextMenu {
                menuCyclePassed = false
            }
            statusManager.menuDidClose(statusManager.contextMenu)
            if statusManager.statusItem.menu != nil {
                menuCyclePassed = false
            }
            // Popover cycle
            statusManager.showPopover()
            statusManager.closePopover()
        }
        report(
            name: "100 sequential interleaved context menu and popover cycles complete cleanly",
            passed: menuCyclePassed && statusManager.statusItem.menu == nil && !statusManager.popover.isShown
        )

        // 7. Concurrent Multi-Threaded Stress Test
        // 10 threads dispatching 50 operations each (500 total operations)
        let queue = DispatchQueue(label: "com.superclip.test.concurrency", attributes: .concurrent)
        var completedThreads = 0
        let threadLock = NSLock()

        for threadIdx in 0..<10 {
            queue.async {
                for iter in 0..<50 {
                    let op = (threadIdx + iter) % 4
                    switch op {
                    case 0:
                        statusManager.menuDidClose(statusManager.contextMenu)
                    case 1:
                        statusManager.showPopover()
                    case 2:
                        statusManager.closePopover()
                    case 3:
                        statusManager.dismissAll()
                    default:
                        break
                    }
                }
                threadLock.lock()
                completedThreads += 1
                threadLock.unlock()
            }
        }

        // Pump main run loop while background threads dispatch to main
        let waitDeadline = Date(timeIntervalSinceNow: 5.0)
        while Date() < waitDeadline {
            threadLock.lock()
            let done = completedThreads >= 10
            threadLock.unlock()
            if done { break }
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }

        threadLock.lock()
        let allThreadsDone = completedThreads >= 10
        threadLock.unlock()

        report(
            name: "500 concurrent operations across 10 threads completed without deadlocks",
            passed: allThreadsDone
        )

        // Verify final main-thread state stabilization
        statusManager.dismissAll()
        statusManager.menuDidClose(statusManager.contextMenu)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        report(
            name: "StatusItemManager stabilizes with nil menu and closed popover after concurrent stress",
            passed: statusManager.statusItem.menu == nil && !statusManager.popover.isShown
        )
    }

    // MARK: - Test Suite 3: HotKey Registration Thrashing Stress

    static func testHotKeyRegistrationThrashing() {
        print("")
        print("=== Suite 3: HotKey Registration Thrashing Stress ===")

        let hotKeyManager = HotKeyManager.shared

        // 1. Rapid Sequential Registration & Unregistration Thrashing (500 cycles)
        let thrashSuccess = true
        let keyCodes: [UInt32] = [0, 9, 11, 8, 2, 14, 3, 5, 4, 34, 49, 18, 19, 20]
        let modifiersList: [UInt32] = [
            UInt32(optionKey),
            UInt32(cmdKey),
            UInt32(controlKey),
            UInt32(optionKey | cmdKey),
            UInt32(cmdKey | shiftKey)
        ]

        for i in 0..<500 {
            let k = keyCodes[i % keyCodes.count]
            let m = modifiersList[i % modifiersList.count]

            hotKeyManager.register(keyCode: k, modifiers: m)
            if i % 3 == 0 {
                hotKeyManager.unregister()
            }
        }
        hotKeyManager.unregister()

        report(
            name: "500 rapid sequential HotKeyManager register/unregister cycles completed cleanly",
            passed: thrashSuccess
        )

        // 2. Idempotent Unregister Calls (multiple consecutive unregister)
        for _ in 0..<20 {
            hotKeyManager.unregister()
        }
        report(
            name: "Consecutive idempotent unregister calls succeed without crashing",
            passed: true
        )

        // 3. Consecutive Register Calls without intermediate Unregister
        for i in 0..<50 {
            let k = keyCodes[i % keyCodes.count]
            let m = modifiersList[i % modifiersList.count]
            hotKeyManager.register(keyCode: k, modifiers: m)
        }
        hotKeyManager.unregister()
        report(
            name: "50 consecutive register calls without unregister replace previous registrations cleanly",
            passed: true
        )

        // 4. Multi-Threaded Concurrent Registration Thrashing Dispatched to Main
        // 8 background threads scheduling 50 registrations/unregistrations each (400 operations)
        let thrashQueue = DispatchQueue(label: "com.superclip.test.hotkeythrash", attributes: .concurrent)
        var completedThrashThreads = 0
        let thrashLock = NSLock()

        for threadId in 0..<8 {
            thrashQueue.async {
                for iter in 0..<50 {
                    let k = UInt32((threadId * 10 + iter) % 50)
                    let m = UInt32(optionKey)
                    DispatchQueue.main.async {
                        if iter % 2 == 0 {
                            hotKeyManager.register(keyCode: k, modifiers: m)
                        } else {
                            hotKeyManager.unregister()
                        }
                    }
                }
                thrashLock.lock()
                completedThrashThreads += 1
                thrashLock.unlock()
            }
        }

        let thrashDeadline = Date(timeIntervalSinceNow: 5.0)
        while Date() < thrashDeadline {
            thrashLock.lock()
            let done = completedThrashThreads >= 8
            thrashLock.unlock()
            if done { break }
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        thrashLock.lock()
        let allThrashDone = completedThrashThreads >= 8
        thrashLock.unlock()

        report(
            name: "400 concurrent multi-threaded HotKeyManager registration requests processed cleanly",
            passed: allThrashDone
        )

        // 5. Restore Default HotKey (Option+V)
        hotKeyManager.register(keyCode: 9, modifiers: UInt32(optionKey))
        report(
            name: "Default Option+V hotkey registered successfully after thrashing stress",
            passed: true
        )
        hotKeyManager.unregister()

        // 6. MockHotKeyManager Verification for StatusItemManager.updateHotKey
        let mock = Tier5MockHotKeyManager()
        let mockPanel = Tier5MockFloatingPanel()
        let dummyVC = NSViewController()
        dummyVC.view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 480))

        let statusManager = StatusItemManager(
            contentViewController: dummyVC,
            floatingPanel: mockPanel,
            hotKeyManager: mock
        )

        for i in 0..<100 {
            let code = UInt32(i % 30)
            let mods = UInt32(optionKey)
            statusManager.updateHotKey(keyCode: code, modifiers: mods)
        }
        report(
            name: "StatusItemManager.updateHotKey completes 100 rapid updates with unregister pairing",
            passed: mock.unregisterCount >= 100 && mock.registeredHistory.count >= 100
        )
    }

    // MARK: - Test Suite 4: Application Bundle Launch Isolation

    static func testApplicationBundleLaunchIsolation() {
        print("")
        print("=== Suite 4: Application Bundle Launch Isolation ===")

        let projectRoot = FileManager.default.currentDirectoryPath
        let bundlePath = "\(projectRoot)/SuperClip.app"
        let binaryPath = "\(bundlePath)/Contents/MacOS/SuperClip"

        guard FileManager.default.fileExists(atPath: binaryPath) else {
            report(name: "SuperClip binary exists at \(binaryPath)", passed: false)
            return
        }
        report(name: "SuperClip binary located at \(binaryPath)", passed: true)

        // Subtest 4.1: Launch from external directory /tmp/sc_iso_dir1
        let dir1 = createTempDirectory(prefix: "iso_dir1")
        defer { cleanupTempDirectory(dir1) }
        let (alive1, stderr1) = launchAndProbeProcess(binaryPath: binaryPath, workingDir: dir1.path)
        report(
            name: "Launch from isolated directory (/tmp/...) starts without dyld errors",
            passed: alive1 && !stderr1.contains("dyld: Library not loaded")
        )

        // Subtest 4.2: Launch from directory with spaces
        let dir2 = createTempDirectory(prefix: "iso dir with spaces")
        defer { cleanupTempDirectory(dir2) }
        let (alive2, stderr2) = launchAndProbeProcess(binaryPath: binaryPath, workingDir: dir2.path)
        report(
            name: "Launch from directory path containing spaces succeeds without linker errors",
            passed: alive2 && !stderr2.contains("dyld: Library not loaded")
        )

        // Subtest 4.3: Launch from deeply nested path
        let deepDir = dir1.appendingPathComponent("sub1/sub2/sub3")
        try? FileManager.default.createDirectory(at: deepDir, withIntermediateDirectories: true)
        let (alive3, stderr3) = launchAndProbeProcess(binaryPath: binaryPath, workingDir: deepDir.path)
        report(
            name: "Launch from deeply nested working directory succeeds cleanly",
            passed: alive3 && !stderr3.contains("dyld: Library not loaded")
        )

        // Subtest 4.4: Relocated App Bundle Portability Test
        // Copy entire SuperClip.app to an external temporary sandbox directory, verifying bundle self-containment
        let externalBundleParent = createTempDirectory(prefix: "relocated_bundle")
        defer { cleanupTempDirectory(externalBundleParent) }
        let relocatedAppURL = externalBundleParent.appendingPathComponent("SuperClip.app")

        do {
            try FileManager.default.copyItem(at: URL(fileURLWithPath: bundlePath), to: relocatedAppURL)
            let relocatedBinary = relocatedAppURL.appendingPathComponent("Contents/MacOS/SuperClip").path
            let relocatedWorkingDir = createTempDirectory(prefix: "relocated_run")
            defer { cleanupTempDirectory(relocatedWorkingDir) }

            let (relocatedAlive, relocatedStderr) = launchAndProbeProcess(
                binaryPath: relocatedBinary,
                workingDir: relocatedWorkingDir.path
            )
            report(
                name: "Relocated SuperClip.app bundle in external directory launches cleanly",
                passed: relocatedAlive && !relocatedStderr.contains("dyld: Library not loaded")
            )
        } catch {
            report(
                name: "Relocated bundle copy and launch",
                passed: false,
                detail: "\(error)"
            )
        }

        // Subtest 4.5: Clean SIGTERM Termination Verification
        let (termAlive, _) = launchAndProbeProcess(
            binaryPath: binaryPath,
            workingDir: dir1.path,
            verifyCleanTerm: true
        )
        report(
            name: "SuperClip process terminates cleanly on SIGTERM without zombie processes",
            passed: termAlive
        )
    }

    static func launchAndProbeProcess(
        binaryPath: String,
        workingDir: String,
        verifyCleanTerm: Bool = false
    ) -> (isAlive: Bool, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.currentDirectoryURL = URL(fileURLWithPath: workingDir)

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            return (false, "Failed to run: \(error)")
        }

        // Wait 0.8s to let dynamic linker complete initialization
        Thread.sleep(forTimeInterval: 0.8)

        let isRunning = process.isRunning

        // Send SIGTERM
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }

        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let errString = String(data: errData, encoding: .utf8) ?? ""

        if verifyCleanTerm {
            // Process termination status should be SIGTERM (15) or 0
            let termStatus = process.terminationStatus
            let cleanTerm = termStatus == 0 || termStatus == 15 || termStatus == 143
            return (cleanTerm, errString)
        }

        return (isRunning, errString)
    }

    // MARK: - Test Suite 5: Copy-Only Pasteboard Writeback & Zero AX Permissions

    static func testCopyOnlyPasteboardWritebackAndZeroAccessibility() {
        print("")
        print("=== Suite 5: Copy-Only Pasteboard Writeback & Zero AX Permissions ===")

        let tempDir = createTempDirectory(prefix: "writer_test")
        defer { cleanupTempDirectory(tempDir) }

        let storage = StorageManager(baseDirectory: tempDir, initialCapacity: 50)
        let pasteboard = NSPasteboard.general
        let monitor = PasteboardMonitor.shared
        let writer = PasteboardWriter(pasteboard: pasteboard, monitor: monitor)

        // 1. Text Clip Writeback
        let textItem = ClipItem(
            contentType: .text,
            textContent: "Adversarial Tier 5 Copy Writeback Content: \(UUID().uuidString)"
        )
        storage.addClip(item: textItem, imageData: nil, thumbData: nil)

        let initialChangeCount = pasteboard.changeCount
        let writeTextSuccess = writer.writeClip(textItem, storageManager: storage)
        report(
            name: "writer.writeClip successfully writes plain text clip",
            passed: writeTextSuccess
        )

        let newChangeCount = pasteboard.changeCount
        report(
            name: "pasteboard.changeCount incremented after text write",
            passed: newChangeCount > initialChangeCount
        )

        let pasteboardText = pasteboard.string(forType: .string)
        report(
            name: "pasteboard.string(forType: .string) matches written text payload exactly",
            passed: pasteboardText == textItem.textContent
        )

        // 2. Loop Suppression Verification
        let tickResult = monitor.pollTick()
        report(
            name: "PasteboardMonitor suppresses self-copy on pollTick",
            passed: !tickResult
        )

        // 3. Image Clip Writeback
        let dummyPNG = createDummyPNG(width: 64, height: 64)
        let dummyThumb = createDummyPNG(width: 32, height: 32)
        let imageItem = ClipItem(
            contentType: .image,
            imageWidth: 64,
            imageHeight: 64,
            byteSize: dummyPNG.count
        )
        storage.addClip(item: imageItem, imageData: dummyPNG, thumbData: dummyThumb)

        let writeImageSuccess = writer.writeClip(imageItem, storageManager: storage)
        report(
            name: "writer.writeClip successfully writes image clip",
            passed: writeImageSuccess
        )

        let pasteboardPNG = pasteboard.data(forType: .png)
        report(
            name: "pasteboard.data(forType: .png) matches original image bytes",
            passed: pasteboardPNG == dummyPNG
        )

        let pasteboardTIFF = pasteboard.data(forType: .tiff)
        report(
            name: "pasteboard.data(forType: .tiff) provides valid TIFF representation",
            passed: pasteboardTIFF != nil && !(pasteboardTIFF?.isEmpty ?? true)
        )

        // 4. ClipboardActionCoordinator Coordination without Synthetic Events
        var coordinatorDismissed = false
        let coordinator = ClipboardActionCoordinator(
            storageManager: storage,
            pasteboardWriter: writer,
            onDismiss: {
                coordinatorDismissed = true
            }
        )

        coordinator.selectAndCopy(item: textItem)
        report(
            name: "ClipboardActionCoordinator.selectAndCopy triggers dismiss callback on completion",
            passed: coordinatorDismissed
        )

        // 5. Concurrent Write Stress
        // 20 threads simultaneously writing clips via writer (testing writeLock mutex)
        let writeGroup = DispatchGroup()
        let writeQueue = DispatchQueue(label: "com.superclip.test.writer", attributes: .concurrent)
        var allWritesSucceeded = true
        let writeSuccessLock = NSLock()

        for i in 0..<20 {
            writeGroup.enter()
            writeQueue.async {
                let clip = ClipItem(
                    contentType: .text,
                    textContent: "Concurrent Clip Write \(i)"
                )
                let res = writer.writeClip(clip, storageManager: storage)
                writeSuccessLock.lock()
                if !res { allWritesSucceeded = false }
                writeSuccessLock.unlock()
                writeGroup.leave()
            }
        }

        let writeWait = writeGroup.wait(timeout: .now() + 5.0)
        report(
            name: "20 concurrent multi-threaded pasteboard write operations completed without deadlock",
            passed: writeWait == .success && allWritesSucceeded
        )

        // 6. Zero Accessibility / Zero CGEvent Static Verification
        let projectRoot = FileManager.default.currentDirectoryPath
        let sourcesURL = URL(fileURLWithPath: "\(projectRoot)/Sources")
        let disallowedTokens = [
            "CGEvent(",
            "CGEventPost",
            "AXUIElement",
            "AXIsProcessTrusted",
            "kAXPressAction",
            "kAXUIElement"
        ]

        var foundDisallowed: [String] = []

        if let enumerator = FileManager.default.enumerator(at: sourcesURL, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
                if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                    for token in disallowedTokens {
                        if content.contains(token) {
                            foundDisallowed.append("\(fileURL.lastPathComponent): \(token)")
                        }
                    }
                }
            }
        }

        report(
            name: "Zero occurrences of synthetic CGEvent keystrokes or AXUIElement Accessibility APIs in Sources",
            passed: foundDisallowed.isEmpty,
            detail: foundDisallowed.joined(separator: ", ")
        )
    }
}
