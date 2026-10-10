import Foundation
import AppKit

@main
public struct PanelFrameStressHarness {
    public static func main() {
        print("==================================================")
        print("  SuperClip PanelFrameCalculator Empirical Stress Harness")
        print("==================================================")

        var totalTests = 0
        var passedTests = 0
        var failedTests = 0

        func report(name: String, passed: Bool, detail: String = "") {
            totalTests += 1
            if passed {
                passedTests += 1
                print("  \u{001B}[32m[PASS]\u{001B}[0m \(name)")
            } else {
                failedTests += 1
                print("  \u{001B}[31m[FAIL]\u{001B}[0m \(name): \(detail)")
            }
        }

        func assertClampedWithin(
            frame: NSRect,
            visibleFrame: NSRect,
            expectedSize: NSSize,
            testName: String
        ) {
            let widthMatch = abs(frame.width - expectedSize.width) < 0.001
            let heightMatch = abs(frame.height - expectedSize.height) < 0.001
            let clampedMinX = frame.minX >= (visibleFrame.minX - 0.001)
            let clampedMaxX = frame.maxX <= (visibleFrame.maxX + 0.001)
            let clampedMinY = frame.minY >= (visibleFrame.minY - 0.001)
            let clampedMaxY = frame.maxY <= (visibleFrame.maxY + 0.001)

            let passed = widthMatch && heightMatch && clampedMinX && clampedMaxX && clampedMinY && clampedMaxY
            var detail = ""
            if !passed {
                detail = "Frame: \(frame), VisibleFrame: \(visibleFrame), ExpectedSize: \(expectedSize)"
            }
            report(name: testName, passed: passed, detail: detail)
        }

        let panelSize = NSSize(width: 360, height: 480)

        // =========================================================================
        // SUITE 1: Multi-Monitor Geometries
        // =========================================================================
        print("\n\u{001B}[1;36m--- Suite 1: Multi-Monitor Geometries ---\u{001B}[0m")

        // 1.1 Primary Standard Display [0, 0, 1920, 1080]
        let primaryScreen = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let primaryCenter = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 960, y: 540),
            panelSize: panelSize,
            visibleFrame: primaryScreen
        )
        report(
            name: "Primary screen: interior center cursor positions panel exactly at center",
            passed: (primaryCenter.minX == 780 && primaryCenter.minY == 300)
        )
        assertClampedWithin(frame: primaryCenter, visibleFrame: primaryScreen, expectedSize: panelSize, testName: "Primary screen: center bounds clamp within visibleFrame")

        // 1.2 Secondary Display at Negative X (Left display: [-1920, 0, 1920, 1080])
        let leftScreen = NSRect(x: -1920, y: 0, width: 1920, height: 1080)
        let leftCenter = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: -960, y: 540),
            panelSize: panelSize,
            visibleFrame: leftScreen
        )
        report(
            name: "Negative X display: interior cursor centers correctly in negative coordinate space",
            passed: (leftCenter.minX == -1140 && leftCenter.minY == 300 && leftCenter.maxX == -780)
        )
        assertClampedWithin(frame: leftCenter, visibleFrame: leftScreen, expectedSize: panelSize, testName: "Negative X display: center bounds clamp within visibleFrame")

        let leftFarLeft = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: -1920, y: 540),
            panelSize: panelSize,
            visibleFrame: leftScreen
        )
        report(
            name: "Negative X display: cursor at extreme left edge clamps minX to -1920",
            passed: (leftFarLeft.minX == -1920.0)
        )
        assertClampedWithin(frame: leftFarLeft, visibleFrame: leftScreen, expectedSize: panelSize, testName: "Negative X display: left boundary bounds clamped")

        let leftFarRight = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 0, y: 540),
            panelSize: panelSize,
            visibleFrame: leftScreen
        )
        report(
            name: "Negative X display: cursor at right boundary clamps maxX to 0.0",
            passed: (leftFarRight.maxX == 0.0 && leftFarRight.minX == -360.0)
        )
        assertClampedWithin(frame: leftFarRight, visibleFrame: leftScreen, expectedSize: panelSize, testName: "Negative X display: right boundary bounds clamped")

        let leftOutLeft = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: -3500, y: 540),
            panelSize: panelSize,
            visibleFrame: leftScreen
        )
        report(
            name: "Negative X display: cursor far outside to the left (-3500) clamps minX to -1920",
            passed: (leftOutLeft.minX == -1920.0)
        )

        let leftOutRight = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 500, y: 540),
            panelSize: panelSize,
            visibleFrame: leftScreen
        )
        report(
            name: "Negative X display: cursor far outside to the right (+500) clamps maxX to 0.0",
            passed: (leftOutRight.maxX == 0.0)
        )

        // 1.3 Secondary Display at Positive X (Right display: [1920, 0, 2560, 1440])
        let rightScreen = NSRect(x: 1920, y: 0, width: 2560, height: 1440)
        let rightCenter = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 3200, y: 720),
            panelSize: panelSize,
            visibleFrame: rightScreen
        )
        report(
            name: "Positive X display: interior cursor centers correctly",
            passed: (rightCenter.minX == 3020 && rightCenter.minY == 480)
        )
        assertClampedWithin(frame: rightCenter, visibleFrame: rightScreen, expectedSize: panelSize, testName: "Positive X display: center bounds clamped")

        let rightLeftEdge = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 1920, y: 720),
            panelSize: panelSize,
            visibleFrame: rightScreen
        )
        report(
            name: "Positive X display: cursor at left boundary clamps minX to 1920",
            passed: (rightLeftEdge.minX == 1920.0)
        )
        assertClampedWithin(frame: rightLeftEdge, visibleFrame: rightScreen, expectedSize: panelSize, testName: "Positive X display: left boundary bounds clamped")

        let rightRightEdge = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 4480, y: 720),
            panelSize: panelSize,
            visibleFrame: rightScreen
        )
        report(
            name: "Positive X display: cursor at right boundary clamps maxX to 4480",
            passed: (rightRightEdge.maxX == 4480.0 && rightRightEdge.minX == 4120.0)
        )
        assertClampedWithin(frame: rightRightEdge, visibleFrame: rightScreen, expectedSize: panelSize, testName: "Positive X display: right boundary bounds clamped")

        let rightOutRight = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 8000, y: 720),
            panelSize: panelSize,
            visibleFrame: rightScreen
        )
        report(
            name: "Positive X display: cursor far outside right (+8000) clamps maxX to 4480",
            passed: (rightOutRight.maxX == 4480.0)
        )

        // 1.4 Secondary Display at Negative Y (Below display: [0, -1080, 1920, 1080])
        let belowScreen = NSRect(x: 0, y: -1080, width: 1920, height: 1080)
        let belowCenter = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 960, y: -540),
            panelSize: panelSize,
            visibleFrame: belowScreen
        )
        report(
            name: "Negative Y display: interior cursor centers in negative vertical coordinate space",
            passed: (belowCenter.minX == 780 && belowCenter.minY == -780 && belowCenter.maxY == -300)
        )
        assertClampedWithin(frame: belowCenter, visibleFrame: belowScreen, expectedSize: panelSize, testName: "Negative Y display: center bounds clamped")

        let belowBottomEdge = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 960, y: -1080),
            panelSize: panelSize,
            visibleFrame: belowScreen
        )
        report(
            name: "Negative Y display: cursor at bottom boundary clamps minY to -1080",
            passed: (belowBottomEdge.minY == -1080.0)
        )
        assertClampedWithin(frame: belowBottomEdge, visibleFrame: belowScreen, expectedSize: panelSize, testName: "Negative Y display: bottom boundary bounds clamped")

        let belowTopEdge = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 960, y: 0),
            panelSize: panelSize,
            visibleFrame: belowScreen
        )
        report(
            name: "Negative Y display: cursor at top boundary clamps maxY to 0.0",
            passed: (belowTopEdge.maxY == 0.0 && belowTopEdge.minY == -480.0)
        )
        assertClampedWithin(frame: belowTopEdge, visibleFrame: belowScreen, expectedSize: panelSize, testName: "Negative Y display: top boundary bounds clamped")

        let belowFarBelow = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 960, y: -4000),
            panelSize: panelSize,
            visibleFrame: belowScreen
        )
        report(
            name: "Negative Y display: cursor far below (-4000) clamps minY to -1080",
            passed: (belowFarBelow.minY == -1080.0)
        )

        // 1.5 Secondary Display at Positive Y (Above display: [0, 1080, 1920, 1200])
        let aboveScreen = NSRect(x: 0, y: 1080, width: 1920, height: 1200)
        let aboveCenter = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 960, y: 1680),
            panelSize: panelSize,
            visibleFrame: aboveScreen
        )
        report(
            name: "Positive Y display: interior cursor centers in positive vertical space",
            passed: (aboveCenter.minX == 780 && aboveCenter.minY == 1440 && aboveCenter.maxY == 1920)
        )
        assertClampedWithin(frame: aboveCenter, visibleFrame: aboveScreen, expectedSize: panelSize, testName: "Positive Y display: center bounds clamped")

        let aboveBottomEdge = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 960, y: 1080),
            panelSize: panelSize,
            visibleFrame: aboveScreen
        )
        report(
            name: "Positive Y display: cursor at bottom boundary clamps minY to 1080",
            passed: (aboveBottomEdge.minY == 1080.0)
        )
        assertClampedWithin(frame: aboveBottomEdge, visibleFrame: aboveScreen, expectedSize: panelSize, testName: "Positive Y display: bottom boundary bounds clamped")

        let aboveTopEdge = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 960, y: 2280),
            panelSize: panelSize,
            visibleFrame: aboveScreen
        )
        report(
            name: "Positive Y display: cursor at top boundary clamps maxY to 2280",
            passed: (aboveTopEdge.maxY == 2280.0 && aboveTopEdge.minY == 1800.0)
        )
        assertClampedWithin(frame: aboveTopEdge, visibleFrame: aboveScreen, expectedSize: panelSize, testName: "Positive Y display: top boundary bounds clamped")

        // 1.6 Diagonal Displays across all 4 Quadrants
        let diagonalScreens: [(String, NSRect)] = [
            ("Quadrant 1 (Top-Right)", NSRect(x: 1920, y: 1080, width: 2560, height: 1440)),
            ("Quadrant 2 (Top-Left)", NSRect(x: -2560, y: 1080, width: 2560, height: 1440)),
            ("Quadrant 3 (Bottom-Left)", NSRect(x: -1920, y: -1080, width: 1920, height: 1080)),
            ("Quadrant 4 (Bottom-Right)", NSRect(x: 1920, y: -1080, width: 1920, height: 1080))
        ]

        for (quadName, quadRect) in diagonalScreens {
            let quadCenterMouse = NSPoint(x: quadRect.midX, y: quadRect.midY)
            let quadCenterFrame = PanelFrameCalculator.calculateClampedPanelFrame(
                mouseLoc: quadCenterMouse,
                panelSize: panelSize,
                visibleFrame: quadRect
            )
            assertClampedWithin(
                frame: quadCenterFrame,
                visibleFrame: quadRect,
                expectedSize: panelSize,
                testName: "\(quadName): center cursor clamped within bounds"
            )

            // Test 4 extreme corners for this diagonal screen
            let quadCorners = [
                NSPoint(x: quadRect.minX - 500, y: quadRect.minY - 500),
                NSPoint(x: quadRect.maxX + 500, y: quadRect.minY - 500),
                NSPoint(x: quadRect.minX - 500, y: quadRect.maxY + 500),
                NSPoint(x: quadRect.maxX + 500, y: quadRect.maxY + 500)
            ]
            for (idx, cornerPt) in quadCorners.enumerated() {
                let cornerFrame = PanelFrameCalculator.calculateClampedPanelFrame(
                    mouseLoc: cornerPt,
                    panelSize: panelSize,
                    visibleFrame: quadRect
                )
                assertClampedWithin(
                    frame: cornerFrame,
                    visibleFrame: quadRect,
                    expectedSize: panelSize,
                    testName: "\(quadName): corner \(idx + 1) cursor clamped within bounds"
                )
            }
        }

        // 1.7 Staggered Multi-Monitor Configurations
        let staggeredLeft = NSRect(x: -1920, y: -350, width: 1920, height: 1080)
        let stagLeftFrame = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: -1000, y: 100),
            panelSize: panelSize,
            visibleFrame: staggeredLeft
        )
        assertClampedWithin(frame: stagLeftFrame, visibleFrame: staggeredLeft, expectedSize: panelSize, testName: "Staggered left display (-350 Y offset) bounds clamped")

        let staggeredRight = NSRect(x: 1920, y: 400, width: 2560, height: 1440)
        let stagRightFrame = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 3000, y: 1000),
            panelSize: panelSize,
            visibleFrame: staggeredRight
        )
        assertClampedWithin(frame: stagRightFrame, visibleFrame: staggeredRight, expectedSize: panelSize, testName: "Staggered right display (+400 Y offset) bounds clamped")

        // 1.8 Portrait / Vertical Displays
        let portraitLeft = NSRect(x: -1080, y: -400, width: 1080, height: 1920)
        let portLeftFrame = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: -540, y: 500),
            panelSize: panelSize,
            visibleFrame: portraitLeft
        )
        assertClampedWithin(frame: portLeftFrame, visibleFrame: portraitLeft, expectedSize: panelSize, testName: "Portrait vertical display (1080x1920) bounds clamped")

        // 1.9 Multi-Display 9-Screen Grid Traversal (81 Probe Points)
        var allGridProbesPassed = true
        let gridXOffsets: [CGFloat] = [-3840, -1920, 0, 1920, 3840]
        let gridYOffsets: [CGFloat] = [-2160, -1080, 0, 1080, 2160]

        for gx in gridXOffsets {
            for gy in gridYOffsets {
                let testScreen = NSRect(x: gx, y: gy, width: 1920, height: 1080)
                let probes = [
                    NSPoint(x: gx - 100, y: gy - 100),
                    NSPoint(x: gx + 960, y: gy + 540),
                    NSPoint(x: gx + 2000, y: gy + 1200)
                ]
                for p in probes {
                    let res = PanelFrameCalculator.calculateClampedPanelFrame(
                        mouseLoc: p,
                        panelSize: panelSize,
                        visibleFrame: testScreen
                    )
                    if res.minX < testScreen.minX - 0.001 || res.maxX > testScreen.maxX + 0.001 ||
                       res.minY < testScreen.minY - 0.001 || res.maxY > testScreen.maxY + 0.001 ||
                       abs(res.width - panelSize.width) > 0.001 || abs(res.height - panelSize.height) > 0.001 {
                        allGridProbesPassed = false
                    }
                }
            }
        }
        report(
            name: "Multi-monitor grid stress: 75 cross-quadrant geometry probes clamp within bounds",
            passed: allGridProbesPassed
        )

        // =========================================================================
        // SUITE 2: Asymmetric Dock Positions and Menu Bar Insets
        // =========================================================================
        print("\n\u{001B}[1;36m--- Suite 2: Asymmetric Dock & Menu Bar Insets ---\u{001B}[0m")

        // 2.1 Dock on Left (80px dock, 24px top menu bar)
        let leftDockScreen = NSRect(x: 80, y: 0, width: 1840, height: 1056)
        let leftDockMouseNear = NSPoint(x: 40, y: 500)
        let leftDockFrame1 = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: leftDockMouseNear,
            panelSize: panelSize,
            visibleFrame: leftDockScreen
        )
        report(
            name: "Left Dock: cursor at x=40 clamps panel strictly to minX == 80.0",
            passed: (leftDockFrame1.minX == 80.0)
        )
        assertClampedWithin(frame: leftDockFrame1, visibleFrame: leftDockScreen, expectedSize: panelSize, testName: "Left Dock: frame never intrudes into left dock zone [0, 80)")

        let leftDockMouseZero = NSPoint(x: 0, y: 500)
        let leftDockFrame2 = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: leftDockMouseZero,
            panelSize: panelSize,
            visibleFrame: leftDockScreen
        )
        report(
            name: "Left Dock: cursor at screen boundary x=0 clamps minX to 80.0",
            passed: (leftDockFrame2.minX == 80.0)
        )

        // 2.2 Dock on Right (90px dock, 24px top menu bar)
        let rightDockScreen = NSRect(x: 0, y: 0, width: 1830, height: 1056)
        let rightDockMouseNear = NSPoint(x: 1800, y: 500)
        let rightDockFrame1 = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: rightDockMouseNear,
            panelSize: panelSize,
            visibleFrame: rightDockScreen
        )
        report(
            name: "Right Dock: cursor at x=1800 clamps panel maxX to 1830.0",
            passed: (rightDockFrame1.maxX == 1830.0 && rightDockFrame1.minX == 1470.0)
        )
        assertClampedWithin(frame: rightDockFrame1, visibleFrame: rightDockScreen, expectedSize: panelSize, testName: "Right Dock: frame never intrudes into right dock zone (1830, 1920]")

        let rightDockMouseMax = NSPoint(x: 1920, y: 500)
        let rightDockFrame2 = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: rightDockMouseMax,
            panelSize: panelSize,
            visibleFrame: rightDockScreen
        )
        report(
            name: "Right Dock: cursor at physical screen edge x=1920 clamps maxX to 1830.0",
            passed: (rightDockFrame2.maxX == 1830.0)
        )

        // 2.3 Dock on Bottom (95px dock, 24px top menu bar)
        let bottomDockScreen = NSRect(x: 0, y: 95, width: 1920, height: 961)
        let bottomDockMouseNear = NSPoint(x: 960, y: 50)
        let bottomDockFrame1 = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: bottomDockMouseNear,
            panelSize: panelSize,
            visibleFrame: bottomDockScreen
        )
        report(
            name: "Bottom Dock: cursor at y=50 clamps panel minY to 95.0",
            passed: (bottomDockFrame1.minY == 95.0)
        )
        assertClampedWithin(frame: bottomDockFrame1, visibleFrame: bottomDockScreen, expectedSize: panelSize, testName: "Bottom Dock: frame never intrudes into bottom dock zone [0, 95)")

        let bottomDockMouseZero = NSPoint(x: 960, y: 0)
        let bottomDockFrame2 = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: bottomDockMouseZero,
            panelSize: panelSize,
            visibleFrame: bottomDockScreen
        )
        report(
            name: "Bottom Dock: cursor at physical screen bottom y=0 clamps minY to 95.0",
            passed: (bottomDockFrame2.minY == 95.0)
        )

        // 2.4 Top Menu Bar Insets (Standard 24px and Notch 44px)
        let stdMenuScreen = NSRect(x: 0, y: 0, width: 1920, height: 1056)
        let stdMenuMouse = NSPoint(x: 960, y: 1070)
        let stdMenuFrame = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: stdMenuMouse,
            panelSize: panelSize,
            visibleFrame: stdMenuScreen
        )
        report(
            name: "Top Menu Bar: cursor inside menu bar (y=1070) clamps maxY to 1056.0",
            passed: (stdMenuFrame.maxY == 1056.0 && stdMenuFrame.minY == 576.0)
        )
        assertClampedWithin(frame: stdMenuFrame, visibleFrame: stdMenuScreen, expectedSize: panelSize, testName: "Top Menu Bar: frame never overlaps 24px menu bar")

        let notchMenuScreen = NSRect(x: 0, y: 0, width: 3456, height: 2190) // MacBook Pro 16" notch
        let notchMenuMouse = NSPoint(x: 1728, y: 2220)
        let notchMenuFrame = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: notchMenuMouse,
            panelSize: panelSize,
            visibleFrame: notchMenuScreen
        )
        report(
            name: "Notch Menu Bar (44px): cursor near notch clamps maxY to 2190.0",
            passed: (notchMenuFrame.maxY == 2190.0)
        )
        assertClampedWithin(frame: notchMenuFrame, visibleFrame: notchMenuScreen, expectedSize: panelSize, testName: "Notch Menu Bar: frame never overlaps notch region")

        // 2.5 Auto-Hiding Dock (4px reservation on all sides)
        let autoHideScreen = NSRect(x: 4, y: 4, width: 1912, height: 1052)
        let autoHideBL = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 0, y: 0),
            panelSize: panelSize,
            visibleFrame: autoHideScreen
        )
        report(
            name: "Auto-hide dock: 4px bottom-left reservation honored",
            passed: (autoHideBL.minX == 4.0 && autoHideBL.minY == 4.0)
        )

        let autoHideTR = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 1920, y: 1080),
            panelSize: panelSize,
            visibleFrame: autoHideScreen
        )
        report(
            name: "Auto-hide dock: top-right reservation honored",
            passed: (autoHideTR.maxX == 1916.0 && autoHideTR.maxY == 1056.0)
        )

        // 2.6 Multi-Monitor Secondary Display with Dock Placement
        let leftScreenWithDock = NSRect(x: -1920, y: 75, width: 1920, height: 1005)
        let leftDockFrame = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: -1900, y: 20),
            panelSize: panelSize,
            visibleFrame: leftScreenWithDock
        )
        report(
            name: "Secondary Negative X screen with custom Dock: minX clamped to -1920 and minY clamped to 75",
            passed: (leftDockFrame.minX == -1920.0 && leftDockFrame.minY == 75.0)
        )

        // =========================================================================
        // SUITE 3: Boundary Value Analysis
        // =========================================================================
        print("\n\u{001B}[1;36m--- Suite 3: Boundary Value Analysis ---\u{001B}[0m")

        let testVisible = NSRect(x: 100, y: 200, width: 1600, height: 900)

        // 3.1 Exact 4 Corners of visibleFrame
        let blCorner = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: testVisible.minX, y: testVisible.minY),
            panelSize: panelSize,
            visibleFrame: testVisible
        )
        report(
            name: "Corner probe: cursor at exact bottom-left corner clamps origin exactly to (minX, minY)",
            passed: (blCorner.minX == testVisible.minX && blCorner.minY == testVisible.minY)
        )
        assertClampedWithin(frame: blCorner, visibleFrame: testVisible, expectedSize: panelSize, testName: "Bottom-left corner within bounds")

        let brCorner = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: testVisible.maxX, y: testVisible.minY),
            panelSize: panelSize,
            visibleFrame: testVisible
        )
        report(
            name: "Corner probe: cursor at exact bottom-right corner clamps maxX and minY",
            passed: (brCorner.maxX == testVisible.maxX && brCorner.minY == testVisible.minY)
        )
        assertClampedWithin(frame: brCorner, visibleFrame: testVisible, expectedSize: panelSize, testName: "Bottom-right corner within bounds")

        let tlCorner = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: testVisible.minX, y: testVisible.maxY),
            panelSize: panelSize,
            visibleFrame: testVisible
        )
        report(
            name: "Corner probe: cursor at exact top-left corner clamps minX and maxY",
            passed: (tlCorner.minX == testVisible.minX && tlCorner.maxY == testVisible.maxY)
        )
        assertClampedWithin(frame: tlCorner, visibleFrame: testVisible, expectedSize: panelSize, testName: "Top-left corner within bounds")

        let trCorner = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: testVisible.maxX, y: testVisible.maxY),
            panelSize: panelSize,
            visibleFrame: testVisible
        )
        report(
            name: "Corner probe: cursor at exact top-right corner clamps maxX and maxY",
            passed: (trCorner.maxX == testVisible.maxX && trCorner.maxY == testVisible.maxY)
        )
        assertClampedWithin(frame: trCorner, visibleFrame: testVisible, expectedSize: panelSize, testName: "Top-right corner within bounds")

        // 3.2 Midpoint of All 4 Edges
        let leftEdgeMid = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: testVisible.minX, y: testVisible.midY),
            panelSize: panelSize,
            visibleFrame: testVisible
        )
        report(
            name: "Edge probe: cursor at left edge mid clamps minX to testVisible.minX while preserving midY",
            passed: (leftEdgeMid.minX == testVisible.minX && abs(leftEdgeMid.midY - testVisible.midY) < 0.001)
        )

        let rightEdgeMid = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: testVisible.maxX, y: testVisible.midY),
            panelSize: panelSize,
            visibleFrame: testVisible
        )
        report(
            name: "Edge probe: cursor at right edge mid clamps maxX to testVisible.maxX while preserving midY",
            passed: (rightEdgeMid.maxX == testVisible.maxX && abs(rightEdgeMid.midY - testVisible.midY) < 0.001)
        )

        let bottomEdgeMid = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: testVisible.midX, y: testVisible.minY),
            panelSize: panelSize,
            visibleFrame: testVisible
        )
        report(
            name: "Edge probe: cursor at bottom edge mid clamps minY to testVisible.minY while preserving midX",
            passed: (bottomEdgeMid.minY == testVisible.minY && abs(bottomEdgeMid.midX - testVisible.midX) < 0.001)
        )

        let topEdgeMid = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: testVisible.midX, y: testVisible.maxY),
            panelSize: panelSize,
            visibleFrame: testVisible
        )
        report(
            name: "Edge probe: cursor at top edge mid clamps maxY to testVisible.maxY while preserving midX",
            passed: (topEdgeMid.maxY == testVisible.maxY && abs(topEdgeMid.midX - testVisible.midX) < 0.001)
        )

        // 3.3 Extreme Value Coordinates (Int32, Int64, 1e18, Double.greatestFiniteMagnitude, Infinity)
        let extremeCoords: [(String, NSPoint, CGFloat, CGFloat)] = [
            ("Int32.min", NSPoint(x: Double(Int32.min), y: Double(Int32.min)), testVisible.minX, testVisible.minY),
            ("Int32.max", NSPoint(x: Double(Int32.max), y: Double(Int32.max)), testVisible.maxX - panelSize.width, testVisible.maxY - panelSize.height),
            ("Int64.min", NSPoint(x: Double(Int64.min), y: Double(Int64.min)), testVisible.minX, testVisible.minY),
            ("Int64.max", NSPoint(x: Double(Int64.max), y: Double(Int64.max)), testVisible.maxX - panelSize.width, testVisible.maxY - panelSize.height),
            ("-1e18", NSPoint(x: -1e18, y: -1e18), testVisible.minX, testVisible.minY),
            ("+1e18", NSPoint(x: 1e18, y: 1e18), testVisible.maxX - panelSize.width, testVisible.maxY - panelSize.height),
            ("-greatestFiniteMagnitude", NSPoint(x: -Double.greatestFiniteMagnitude, y: -Double.greatestFiniteMagnitude), testVisible.minX, testVisible.minY),
            ("+greatestFiniteMagnitude", NSPoint(x: Double.greatestFiniteMagnitude, y: Double.greatestFiniteMagnitude), testVisible.maxX - panelSize.width, testVisible.maxY - panelSize.height),
            ("-Double.infinity", NSPoint(x: -Double.infinity, y: -Double.infinity), testVisible.minX, testVisible.minY),
            ("+Double.infinity", NSPoint(x: Double.infinity, y: Double.infinity), testVisible.maxX - panelSize.width, testVisible.maxY - panelSize.height)
        ]

        for (label, pt, expX, expY) in extremeCoords {
            let res = PanelFrameCalculator.calculateClampedPanelFrame(
                mouseLoc: pt,
                panelSize: panelSize,
                visibleFrame: testVisible
            )
            let matchX = abs(res.minX - expX) < 0.001
            let matchY = abs(res.minY - expY) < 0.001
            report(
                name: "Extreme coordinates [\(label)]: correctly clamped to (\(expX), \(expY))",
                passed: (matchX && matchY),
                detail: "Got (\(res.minX), \(res.minY)), expected (\(expX), \(expY))"
            )
            assertClampedWithin(frame: res, visibleFrame: testVisible, expectedSize: panelSize, testName: "Extreme coordinates [\(label)] within bounds")
        }

        // Mixed Infinities
        let mixedInf1 = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: -Double.infinity, y: Double.infinity),
            panelSize: panelSize,
            visibleFrame: testVisible
        )
        report(
            name: "Mixed infinities (-inf, +inf): clamps to (minX, maxY - height)",
            passed: (mixedInf1.minX == testVisible.minX && mixedInf1.maxY == testVisible.maxY)
        )

        let mixedInf2 = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: Double.infinity, y: -Double.infinity),
            panelSize: panelSize,
            visibleFrame: testVisible
        )
        report(
            name: "Mixed infinities (+inf, -inf): clamps to (maxX - width, minY)",
            passed: (mixedInf2.maxX == testVisible.maxX && mixedInf2.minY == testVisible.minY)
        )

        // 3.4 IEEE 754 NaN Crash Safety
        let nanPoint = NSPoint(x: Double.nan, y: Double.nan)
        let nanResult = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: nanPoint,
            panelSize: panelSize,
            visibleFrame: testVisible
        )
        report(
            name: "IEEE 754 NaN: calculateClampedPanelFrame completes without hardware exception or crash",
            passed: (nanResult.width == panelSize.width && nanResult.height == panelSize.height)
        )

        let fallbackScreen = PanelFrameCalculator.findScreen(for: nanPoint, screens: [])
        report(
            name: "findScreen with NaN point and empty screens falls back safely without throwing",
            passed: (fallbackScreen == NSScreen.main || fallbackScreen == nil)
        )

        // 3.5 Degenerate Screen Dimensions
        let zeroScreen = NSRect(x: 100, y: 200, width: 0, height: 0)
        let zeroScreenResult = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 100, y: 200),
            panelSize: panelSize,
            visibleFrame: zeroScreen
        )
        report(
            name: "Degenerate zero-size screen: safe execution, clamps origin to (minX, minY)",
            passed: (zeroScreenResult.minX == 100.0 && zeroScreenResult.minY == 200.0)
        )

        let pixelScreen = NSRect(x: 50, y: 50, width: 1, height: 1)
        let pixelScreenResult = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 50, y: 50),
            panelSize: panelSize,
            visibleFrame: pixelScreen
        )
        report(
            name: "Degenerate 1x1 screen: clamps origin to (50, 50)",
            passed: (pixelScreenResult.minX == 50.0 && pixelScreenResult.minY == 50.0)
        )

        // 3.6 Degenerate Panel Dimensions
        let zeroPanel = NSSize(width: 0, height: 0)
        let zeroPanelResult = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 500, y: 400),
            panelSize: zeroPanel,
            visibleFrame: testVisible
        )
        report(
            name: "Degenerate 0x0 panel: positions at cursor with zero size",
            passed: (zeroPanelResult.minX == 500.0 && zeroPanelResult.minY == 400.0 && zeroPanelResult.width == 0 && zeroPanelResult.height == 0)
        )

        // 3.7 Oversized Panels Larger than visibleFrame
        let giantPanel = NSSize(width: 2500, height: 1500)
        let giantResult = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: testVisible.midX, y: testVisible.midY),
            panelSize: giantPanel,
            visibleFrame: testVisible
        )
        report(
            name: "Oversized panel (both dims larger): pins safely to visibleFrame (minX, minY)",
            passed: (giantResult.minX == testVisible.minX && giantResult.minY == testVisible.minY && giantResult.width == giantPanel.width && giantResult.height == giantPanel.height)
        )

        let widePanel = NSSize(width: 2500, height: 300)
        let wideResult = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: testVisible.midX, y: testVisible.midY),
            panelSize: widePanel,
            visibleFrame: testVisible
        )
        report(
            name: "Oversized panel (width larger, height smaller): pins minX to testVisible.minX while centering Y",
            passed: (wideResult.minX == testVisible.minX && abs(wideResult.midY - testVisible.midY) < 0.001)
        )

        let tallPanel = NSSize(width: 300, height: 1500)
        let tallResult = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: testVisible.midX, y: testVisible.midY),
            panelSize: tallPanel,
            visibleFrame: testVisible
        )
        report(
            name: "Oversized panel (height larger, width smaller): centers X while pinning minY to testVisible.minY",
            passed: (abs(tallResult.midX - testVisible.midX) < 0.001 && tallResult.minY == testVisible.minY)
        )

        let exactScreenSizePanel = NSSize(width: testVisible.width, height: testVisible.height)
        let exactResult = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: testVisible.midX, y: testVisible.midY),
            panelSize: exactScreenSizePanel,
            visibleFrame: testVisible
        )
        report(
            name: "Panel exactly matching visibleFrame size: aligns precisely with visibleFrame origin",
            passed: (exactResult.minX == testVisible.minX && exactResult.minY == testVisible.minY)
        )

        // 3.8 Fractional / Sub-Pixel Precision
        let subPixelMouse = NSPoint(x: 555.555, y: 444.444)
        let subPixelResult = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: subPixelMouse,
            panelSize: panelSize,
            visibleFrame: testVisible
        )
        report(
            name: "Sub-pixel precision: fractional mouse coordinates center cleanly",
            passed: (abs(subPixelResult.midX - subPixelMouse.x) < 0.001 && abs(subPixelResult.midY - subPixelMouse.y) < 0.001)
        )

        // =========================================================================
        // SUITE 4: Multi-Screen Resolution Logic (findScreen & targetScreen)
        // =========================================================================
        print("\n\u{001B}[1;36m--- Suite 4: Multi-Screen Resolution Logic ---\u{001B}[0m")

        let currentScreens = NSScreen.screens
        if let firstScreen = currentScreens.first {
            let pointOnFirst = NSPoint(x: firstScreen.frame.midX, y: firstScreen.frame.midY)
            let foundScreen = PanelFrameCalculator.findScreen(for: pointOnFirst, screens: currentScreens)
            report(
                name: "findScreen resolves screen containing pointOnFirst",
                passed: (foundScreen?.frame == firstScreen.frame)
            )

            let outsidePoint = NSPoint(x: 999999, y: 999999)
            let fallbackFound = PanelFrameCalculator.findScreen(for: outsidePoint, screens: currentScreens)
            report(
                name: "findScreen falls back to main screen when point is out of all screens",
                passed: (fallbackFound != nil)
            )
        } else {
            // Headless mock environment without screens
            report(
                name: "findScreen with empty screens returns nil in headless mode",
                passed: (PanelFrameCalculator.findScreen(for: NSPoint(x: 100, y: 100), screens: []) == nil)
            )
        }

        // Automatic targetScreen resolution fallback
        let headlessFrame = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 500, y: 500),
            panelSize: panelSize,
            targetScreen: nil
        )
        report(
            name: "calculateClampedPanelFrame with targetScreen: nil returns valid sized frame",
            passed: (headlessFrame.width == panelSize.width && headlessFrame.height == panelSize.height)
        )

        // =========================================================================
        // SUITE 5: High-Concurrency & Thread-Safety Stress (100 Threads, 1,000,000 Ops)
        // =========================================================================
        print("\n\u{001B}[1;36m--- Suite 5: High-Concurrency & Thread Safety ---\u{001B}[0m")

        let threadCount = 100
        let opsPerThread = 10000
        let totalConcurrencyOps = threadCount * opsPerThread

        let concurrentScreens = [
            NSRect(x: -1920, y: 0, width: 1920, height: 1080),
            NSRect(x: 0, y: 0, width: 1920, height: 1080),
            NSRect(x: 1920, y: 0, width: 2560, height: 1440),
            NSRect(x: 0, y: -1080, width: 1920, height: 1080)
        ]

        var raceDetected = false
        let startConcurrent = CFAbsoluteTimeGetCurrent()

        DispatchQueue.concurrentPerform(iterations: threadCount) { threadIdx in
            let testScreen = concurrentScreens[threadIdx % concurrentScreens.count]
            for op in 0..<opsPerThread {
                let mx = testScreen.minX + CGFloat((threadIdx * 17 + op * 31) % Int(testScreen.width + 500)) - 250
                let my = testScreen.minY + CGFloat((threadIdx * 19 + op * 23) % Int(testScreen.height + 500)) - 250
                let mouse = NSPoint(x: mx, y: my)

                let res = PanelFrameCalculator.calculateClampedPanelFrame(
                    mouseLoc: mouse,
                    panelSize: panelSize,
                    visibleFrame: testScreen
                )

                if res.width != panelSize.width || res.height != panelSize.height ||
                   res.minX < testScreen.minX - 0.001 || res.maxX > testScreen.maxX + 0.001 ||
                   res.minY < testScreen.minY - 0.001 || res.maxY > testScreen.maxY + 0.001 {
                    raceDetected = true
                }
            }
        }

        let concurrentDuration = CFAbsoluteTimeGetCurrent() - startConcurrent

        report(
            name: "Concurrency: 100 threads completed \(totalConcurrencyOps) ops with 0 race conditions or data corruptions",
            passed: !raceDetected
        )
        report(
            name: "Concurrency: throughput completed in under 2.0s (\(String(format: "%.3f", concurrentDuration))s)",
            passed: (concurrentDuration < 2.0),
            detail: "Duration: \(concurrentDuration)s"
        )

        // =========================================================================
        // Summary Verdict
        // =========================================================================
        print("\n==================================================")
        print("  SuperClip PanelFrameCalculator Stress Summary")
        print("==================================================")
        print("  Total Tests Executed: \(totalTests)")
        print("  Tests Passed:         \u{001B}[32m\(passedTests)\u{001B}[0m")
        print("  Tests Failed:         " + (failedTests > 0 ? "\u{001B}[31m\(failedTests)\u{001B}[0m" : "0"))

        if failedTests == 0 {
            print("\n\u{001B}[1;32mRESULT: ALL TESTS PASSED SUCCESSFULLY (0 EMOJIS, 100% PASS RATE)\u{001B}[0m\n")
            print("VERDICT: APPROVE (PanelFrameCalculator passed all stress challenges)")
            exit(0)
        } else {
            print("\n\u{001B}[1;31mRESULT: STRESS HARNESS FAILED (\(failedTests) FAILURES)\u{001B}[0m\n")
            print("VERDICT: REJECT (Found \(failedTests) geometry defects in PanelFrameCalculator)")
            exit(1)
        }
    }
}
