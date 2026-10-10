import Foundation
import AppKit

/// Protocol defining window panel positioning and screen boundary clamping.
public protocol PanelPositioning {
    static func calculateClampedPanelFrame(
        mouseLoc: NSPoint,
        panelSize: NSSize,
        targetScreen: NSScreen?
    ) -> NSRect
}

/// Pure mathematical calculation engine for positioning and clamping floating panels
/// within active screen boundaries, respecting menu bar and Dock insets.
public enum PanelFrameCalculator: PanelPositioning {
    /// Calculates the clamped panel frame centered on the mouse location,
    /// constrained strictly within the visible frame of the appropriate screen.
    ///
    /// - Parameters:
    ///   - mouseLoc: The current cursor coordinates in global screen space (e.g. `NSEvent.mouseLocation`).
    ///   - panelSize: The desired width and height of the floating panel.
    ///   - targetScreen: The specific screen to place the panel on, or `nil` to automatically detect the screen containing `mouseLoc`.
    /// - Returns: An `NSRect` with size `panelSize` positioned within the target screen's visible bounds.
    public static func calculateClampedPanelFrame(
        mouseLoc: NSPoint,
        panelSize: NSSize,
        targetScreen: NSScreen? = nil
    ) -> NSRect {
        let screen = targetScreen ?? findScreen(for: mouseLoc)
        guard let screen = screen else {
            // Safe fallback if no screen is available (e.g. headless environment)
            return NSRect(
                x: mouseLoc.x - (panelSize.width / 2.0),
                y: mouseLoc.y - (panelSize.height / 2.0),
                width: panelSize.width,
                height: panelSize.height
            )
        }
        return calculateClampedPanelFrame(
            mouseLoc: mouseLoc,
            panelSize: panelSize,
            visibleFrame: screen.visibleFrame
        )
    }

    /// Pure mathematical clamping calculation against an explicit visible frame rectangle.
    /// Centers the panel on `mouseLoc` and clamps the resulting frame so that it remains
    /// strictly within `visibleFrame`.
    ///
    /// - Parameters:
    ///   - mouseLoc: The anchor point (cursor coordinates) to center upon.
    ///   - panelSize: The dimensions of the panel.
    ///   - visibleFrame: The bounding rectangle (e.g. `NSScreen.visibleFrame`) to clamp within.
    /// - Returns: The clamped `NSRect`.
    public static func calculateClampedPanelFrame(
        mouseLoc: NSPoint,
        panelSize: NSSize,
        visibleFrame: NSRect
    ) -> NSRect {
        var originX = mouseLoc.x - (panelSize.width / 2.0)
        var originY = mouseLoc.y - (panelSize.height / 2.0)

        // Clamp X axis
        if panelSize.width >= visibleFrame.width {
            originX = visibleFrame.minX
        } else if originX < visibleFrame.minX {
            originX = visibleFrame.minX
        } else if originX + panelSize.width > visibleFrame.maxX {
            originX = visibleFrame.maxX - panelSize.width
        }

        // Clamp Y axis
        if panelSize.height >= visibleFrame.height {
            originY = visibleFrame.minY
        } else if originY < visibleFrame.minY {
            originY = visibleFrame.minY
        } else if originY + panelSize.height > visibleFrame.maxY {
            originY = visibleFrame.maxY - panelSize.height
        }

        return NSRect(
            x: originX,
            y: originY,
            width: panelSize.width,
            height: panelSize.height
        )
    }

    /// Resolves the screen containing the specified global point, falling back to
    /// `NSScreen.main` or `NSScreen.screens.first`.
    ///
    /// - Parameters:
    ///   - point: The point in global display coordinates.
    ///   - screens: The list of candidate screens (defaults to `NSScreen.screens`).
    /// - Returns: The resolved `NSScreen`, or `nil` if no displays are available.
    public static func findScreen(
        for point: NSPoint,
        screens: [NSScreen] = NSScreen.screens
    ) -> NSScreen? {
        let containingScreen = screens.first { screen in
            point.x >= screen.frame.minX && point.x <= screen.frame.maxX &&
            point.y >= screen.frame.minY && point.y <= screen.frame.maxY
        }
        return containingScreen ?? NSScreen.main ?? screens.first
    }
}
