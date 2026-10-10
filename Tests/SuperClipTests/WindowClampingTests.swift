import Foundation
import AppKit
import SuperClipCore

public struct WindowClampingTests {
    public static func run() {
        TestHarness.startSuite("Window Clamping & Coordinate Calculation")

        let dummyScreen = NSScreen.main ?? NSScreen.screens.first!
        let visibleFrame = dummyScreen.visibleFrame
        let panelSize = NSSize(width: 360, height: 480)

        // Test 1: Screen Center Placement
        let centerPoint = NSPoint(x: visibleFrame.midX, y: visibleFrame.midY)
        let centerFrame = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: centerPoint,
            panelSize: panelSize,
            targetScreen: dummyScreen
        )
        TestHarness.assertEqual(centerFrame.width, panelSize.width, "Center frame width matches panel size")
        TestHarness.assertEqual(centerFrame.height, panelSize.height, "Center frame height matches panel size")
        TestHarness.assertTrue(centerFrame.minX >= visibleFrame.minX && centerFrame.maxX <= visibleFrame.maxX, "Center frame horizontally within visible frame")
        TestHarness.assertTrue(centerFrame.minY >= visibleFrame.minY && centerFrame.maxY <= visibleFrame.maxY, "Center frame vertically within visible frame")

        // Test 2: Bottom-Left Extreme Clamping
        let bottomLeftMouse = NSPoint(x: 5, y: 5)
        let bottomLeftFrame = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: bottomLeftMouse,
            panelSize: panelSize,
            targetScreen: dummyScreen
        )
        TestHarness.assertTrue(bottomLeftFrame.minX >= visibleFrame.minX, "Bottom-left panel origin X clamped >= visibleFrame.minX")
        TestHarness.assertTrue(bottomLeftFrame.minY >= visibleFrame.minY, "Bottom-left panel origin Y clamped >= visibleFrame.minY")

        // Test 3: Top-Right Extreme Clamping
        let topRightMouse = NSPoint(x: 99999, y: 99999)
        let topRightFrame = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: topRightMouse,
            panelSize: panelSize,
            targetScreen: dummyScreen
        )
        TestHarness.assertTrue(topRightFrame.maxX <= visibleFrame.maxX, "Top-right panel max X clamped <= visibleFrame.maxX")
        TestHarness.assertTrue(topRightFrame.maxY <= visibleFrame.maxY, "Top-right panel max Y clamped <= visibleFrame.maxY")

        // Test 4: Negative Coordinate Clamping
        let negativeMouse = NSPoint(x: -500, y: -500)
        let negativeFrame = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: negativeMouse,
            panelSize: panelSize,
            targetScreen: dummyScreen
        )
        TestHarness.assertEqual(negativeFrame.minX, visibleFrame.minX, "Negative coordinate clamped exactly to visibleFrame.minX")
        TestHarness.assertEqual(negativeFrame.minY, visibleFrame.minY, "Negative coordinate clamped exactly to visibleFrame.minY")

        // Test 5: Automatic Target Screen Resolution (targetScreen == nil)
        let screenMidPoint = NSPoint(x: dummyScreen.frame.midX, y: dummyScreen.frame.midY)
        let autoResolvedFrame = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: screenMidPoint,
            panelSize: panelSize,
            targetScreen: nil
        )
        TestHarness.assertEqual(autoResolvedFrame.width, panelSize.width, "Auto-resolved frame width matches panel size")
        TestHarness.assertEqual(autoResolvedFrame.height, panelSize.height, "Auto-resolved frame height matches panel size")
        TestHarness.assertTrue(autoResolvedFrame.minX >= visibleFrame.minX && autoResolvedFrame.maxX <= visibleFrame.maxX, "Auto-resolved frame fits horizontally")
        TestHarness.assertTrue(autoResolvedFrame.minY >= visibleFrame.minY && autoResolvedFrame.maxY <= visibleFrame.maxY, "Auto-resolved frame fits vertically")

        // Test 6: Multi-Monitor Synthetic Secondary Display (Left with Negative X Coordinates)
        let leftScreenVisibleFrame = NSRect(x: -1920, y: 0, width: 1920, height: 1080)
        let leftScreenMouse = NSPoint(x: -1000, y: 500)
        let leftScreenFrame = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: leftScreenMouse,
            panelSize: panelSize,
            visibleFrame: leftScreenVisibleFrame
        )
        TestHarness.assertEqual(leftScreenFrame.minX, -1000 - (panelSize.width / 2.0), "Left screen X centers on cursor")
        TestHarness.assertEqual(leftScreenFrame.minY, 500 - (panelSize.height / 2.0), "Left screen Y centers on cursor")
        TestHarness.assertTrue(leftScreenFrame.minX >= leftScreenVisibleFrame.minX, "Left screen origin >= visibleFrame.minX (-1920)")
        TestHarness.assertTrue(leftScreenFrame.maxX <= leftScreenVisibleFrame.maxX, "Left screen maxX <= visibleFrame.maxX (0)")

        // Test 7: Multi-Monitor Synthetic Secondary Display (Below with Negative Y Coordinates)
        let bottomScreenVisibleFrame = NSRect(x: 0, y: -1080, width: 1920, height: 1080)
        let bottomScreenMouse = NSPoint(x: 960, y: -500)
        let bottomScreenFrame = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: bottomScreenMouse,
            panelSize: panelSize,
            visibleFrame: bottomScreenVisibleFrame
        )
        TestHarness.assertEqual(bottomScreenFrame.minX, 960 - (panelSize.width / 2.0), "Bottom screen X centers on cursor")
        TestHarness.assertEqual(bottomScreenFrame.minY, -500 - (panelSize.height / 2.0), "Bottom screen Y centers on cursor")
        TestHarness.assertTrue(bottomScreenFrame.minY >= bottomScreenVisibleFrame.minY, "Bottom screen origin >= visibleFrame.minY (-1080)")
        TestHarness.assertTrue(bottomScreenFrame.maxY <= bottomScreenVisibleFrame.maxY, "Bottom screen maxY <= visibleFrame.maxY (0)")

        // Test 8: Asymmetric Left Dock Inset Clamping
        let leftDockVisibleFrame = NSRect(x: 80, y: 0, width: 1840, height: 1080)
        let nearDockMouse = NSPoint(x: 10, y: 500)
        let leftDockClampedFrame = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: nearDockMouse,
            panelSize: panelSize,
            visibleFrame: leftDockVisibleFrame
        )
        TestHarness.assertEqual(leftDockClampedFrame.minX, 80.0, "Panel clamped strictly to right of left-side Dock (minX == 80.0)")

        // Test 9: Asymmetric Top Menu Bar Inset Clamping
        let topMenuVisibleFrame = NSRect(x: 0, y: 0, width: 1920, height: 1056)
        let nearMenuMouse = NSPoint(x: 960, y: 1070)
        let topMenuClampedFrame = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: nearMenuMouse,
            panelSize: panelSize,
            visibleFrame: topMenuVisibleFrame
        )
        TestHarness.assertEqual(topMenuClampedFrame.maxY, 1056.0, "Panel clamped strictly below Menu Bar (maxY == 1056.0)")

        // Test 10: Oversized Panel Geometry Handling
        let smallScreenVisibleFrame = NSRect(x: 100, y: 100, width: 300, height: 400)
        let giantPanelSize = NSSize(width: 500, height: 600)
        let oversizedFrame = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: NSPoint(x: 200, y: 200),
            panelSize: giantPanelSize,
            visibleFrame: smallScreenVisibleFrame
        )
        TestHarness.assertEqual(oversizedFrame.minX, 100.0, "Oversized panel pinned safely to visibleFrame.minX")
        TestHarness.assertEqual(oversizedFrame.minY, 100.0, "Oversized panel pinned safely to visibleFrame.minY")
    }
}
