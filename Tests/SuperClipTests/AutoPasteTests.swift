import Foundation
import AppKit
import ApplicationServices
import SwiftUI
import SuperClipCore
import SuperClip

/// Mock implementation of PasteSimulating for deterministic unit testing.
public final class MockPasteSimulator: PasteSimulating, @unchecked Sendable {
    public var activatedApps: [NSRunningApplication] = []
    public var postKeyEventCount: Int = 0
    public var shouldActivateSucceed: Bool = true
    public var shouldPostSucceed: Bool = true

    public init() {}

    public func activate(app: NSRunningApplication) -> Bool {
        activatedApps.append(app)
        return shouldActivateSucceed
    }

    public func postPasteKeyEvent(tap: CGEventTapLocation) -> Bool {
        postKeyEventCount += 1
        return shouldPostSucceed
    }

    public func postPasteKeyEvent() -> Bool {
        return postPasteKeyEvent(tap: .cghidEventTap)
    }

    public func pasteToActiveApp(
        targetApp: NSRunningApplication?,
        delay: TimeInterval,
        completion: (() -> Void)?
    ) {
        if let app = targetApp {
            _ = activate(app: app)
        }
        _ = postPasteKeyEvent()
        completion?()
    }
}

/// Mock implementation of AutoPasteServicing for coordinator testing.
public final class MockAutoPasteService: AutoPasteServicing, @unchecked Sendable {
    public var isAccessibilityTrusted: Bool = true
    public var checkPermissionCallCount: Int = 0
    public var requestPermissionCallCount: Int = 0
    public var resetPermissionCallCount: Int = 0
    public var resetAndRequestCallCount: Int = 0
    public var openSettingsCallCount: Int = 0
    public var pasteToActiveAppCalls: [(targetApp: NSRunningApplication?, delay: TimeInterval)] = []

    public init(isAccessibilityTrusted: Bool = true) {
        self.isAccessibilityTrusted = isAccessibilityTrusted
    }

    public func checkAccessibilityPermission() -> Bool {
        checkPermissionCallCount += 1
        return isAccessibilityTrusted
    }

    public func requestAccessibilityPermission() -> Bool {
        requestPermissionCallCount += 1
        return isAccessibilityTrusted
    }

    public func resetAccessibilityPermission() -> Bool {
        resetPermissionCallCount += 1
        return true
    }

    public func resetAndRequestAccessibilityPermission() -> Bool {
        resetAndRequestCallCount += 1
        _ = resetAccessibilityPermission()
        openAccessibilitySettings()
        return requestAccessibilityPermission()
    }

    public func openAccessibilitySettings() {
        openSettingsCallCount += 1
    }

    public func pasteToActiveApp(
        targetApp: NSRunningApplication?,
        delay: TimeInterval,
        promptIfUntrusted: Bool,
        completion: (() -> Void)?
    ) -> Bool {
        pasteToActiveAppCalls.append((targetApp: targetApp, delay: delay))
        guard isAccessibilityTrusted else {
            if promptIfUntrusted {
                _ = requestAccessibilityPermission()
            }
            completion?()
            return false
        }
        completion?()
        return true
    }
}

/// Mock implementation of PreviousAppTracking for deterministic coordinator tests.
public final class MockPreviousAppTracker: PreviousAppTracking, @unchecked Sendable {
    public var previousApp: NSRunningApplication?
    public var captureCallCount: Int = 0
    public var clearCallCount: Int = 0

    public init(app: NSRunningApplication? = nil) {
        self.previousApp = app
    }

    public func captureFrontmostApplication() {
        captureCallCount += 1
    }

    public func setPreviousApp(_ app: NSRunningApplication?) {
        self.previousApp = app
    }

    public func clear() {
        clearCallCount += 1
        self.previousApp = nil
    }
}

/// Comprehensive test suite verifying Direct Auto-Paste (Automatic Paste on Selection).
public struct AutoPasteTests {

    public static func run(sandboxDir: URL) {
        TestHarness.startSuite("Direct Auto-Paste & Simulation Tests")

        testAppSettingsAutoPasteSerialization()
        testAppSettingsBackwardCompatibility()
        testPreviousAppTrackerBehavior()
        testPasteSimulatorSyntheticKeyEvents()
        testAutoPasteServiceExecutionSequence()
        testAutoPasteServicePermissionDeniedFallback()
        testClipboardActionCoordinatorEnabledAutoPaste(sandboxDir: sandboxDir)
        testClipboardActionCoordinatorDisabledAutoPaste(sandboxDir: sandboxDir)
        testClipboardActionCoordinatorCopyItemSuppression(sandboxDir: sandboxDir)
        testAutoPasteSettingsViewIntegration(sandboxDir: sandboxDir)
        testPasteSimulatorMultipleEventTaps()
        testPreviousAppTrackerThreadSafety()
        testFloatingClipPanelPreviousAppTrackerInjection()
        testStatusItemManagerDismissAllClearsTracker()
        testFloatingClipPanelEscapeDismissClearsTracker()
        testStatusItemManagerPopoverDidCloseClearsTracker()
        testAutoPasteServiceNilAndTerminatedTargetApp()
        testClipboardActionCoordinatorImageAutoPasteSuccess(sandboxDir: sandboxDir)
        testClipboardActionCoordinatorImageAutoPasteFailureOnMissingData(sandboxDir: sandboxDir)
        testPasteSimulatingProtocolExtensionNonCircular()
        testAutoPasteServiceResetAccessibilityPermission()
        testAutoPasteServiceResetAndRequestSequence()
    }

    // MARK: - 1. AppSettings Serialization

    private static func testAppSettingsAutoPasteSerialization() {
        let defaultSettings = AppSettings()
        TestHarness.assertTrue(
            defaultSettings.autoPasteOnSelection,
            "AppSettings defaults autoPasteOnSelection to true"
        )

        var modifiedSettings = AppSettings()
        modifiedSettings.autoPasteOnSelection = false

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(modifiedSettings) else {
            TestHarness.assertTrue(false, "Failed to encode AppSettings with autoPasteOnSelection false")
            return
        }

        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(AppSettings.self, from: data) else {
            TestHarness.assertTrue(false, "Failed to decode AppSettings")
            return
        }

        TestHarness.assertFalse(
            decoded.autoPasteOnSelection,
            "AppSettings accurately preserves autoPasteOnSelection false across JSON round-trip"
        )
    }

    // MARK: - 2. Backward Compatibility

    private static func testAppSettingsBackwardCompatibility() {
        // Legacy JSON omitting autoPasteOnSelection key
        let legacyJSON = """
        {
            "capacity": 150,
            "hotKeyKeyCode": 9,
            "hotKeyModifiers": 2048,
            "pollIntervalMs": 250,
            "maxThumbnailPixelSize": 180,
            "launchAtLogin": false,
            "recordClipboardHistory": true,
            "displayCapacity": 20,
            "language": "system",
            "ignoredApps": [],
            "automaticallyCheckForUpdates": true
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(AppSettings.self, from: legacyJSON) else {
            TestHarness.assertTrue(false, "Failed to decode legacy AppSettings JSON")
            return
        }

        TestHarness.assertTrue(
            decoded.autoPasteOnSelection,
            "Legacy AppSettings JSON without autoPasteOnSelection decodes safely to true"
        )
        TestHarness.assertEqual(decoded.capacity, 150, "Preserved legacy capacity")
    }

    // MARK: - 3. PreviousAppTracker Behavior

    private static func testPreviousAppTrackerBehavior() {
        let tracker = PreviousAppTracker()
        tracker.clear()
        TestHarness.assertNil(tracker.previousApp, "PreviousAppTracker starts empty after clear")

        let currentApp = NSRunningApplication.current
        tracker.setPreviousApp(currentApp)
        TestHarness.assertNil(
            tracker.previousApp,
            "PreviousAppTracker ignores SuperClip itself when set"
        )

        // Capture frontmost application when SuperClip is frontmost does not set SuperClip
        tracker.captureFrontmostApplication()
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            TestHarness.assertNil(
                tracker.previousApp,
                "captureFrontmostApplication ignores current process"
            )
        }

        tracker.clear()
        TestHarness.assertNil(tracker.previousApp, "clear() clears target app")
    }

    // MARK: - 4. PasteSimulator Keystroke Generation

    private static func testPasteSimulatorSyntheticKeyEvents() {
        let simulator = PasteSimulator()
        // Verify postPasteKeyEvent executes without crashing or throwing
        let posted = simulator.postPasteKeyEvent()
        TestHarness.assertTrue(
            posted,
            "PasteSimulator successfully constructs and posts synthetic Command+V CGEvent pair"
        )

        // Verify activate on running application executes safely without throwing or hanging
        let currentApp = NSRunningApplication.current
        _ = simulator.activate(app: currentApp)
        TestHarness.assertTrue(
            !currentApp.isTerminated,
            "Current application is active and not terminated"
        )

        // Verify activate on terminated application returns false safely
        let proc = Process()
        proc.launchPath = "/bin/echo"
        proc.arguments = ["terminated"]
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()
        try? proc.run()
        proc.waitUntilExit()
        if let deadApp = NSRunningApplication(processIdentifier: proc.processIdentifier) {
            TestHarness.assertFalse(
                simulator.activate(app: deadApp),
                "activate returns false on terminated app"
            )
        }
    }

    // MARK: - 5. AutoPasteService Execution Sequence

    private static func testAutoPasteServiceExecutionSequence() {
        let mockSimulator = MockPasteSimulator()
        var accessibilityChecked = false
        let testQueue = DispatchQueue(label: "com.superclip.test.autopaste")

        let service = AutoPasteService(
            pasteSimulator: mockSimulator,
            accessibilityChecker: {
                accessibilityChecked = true
                return true
            },
            dispatchQueue: testQueue
        )

        let exp = DispatchSemaphore(value: 0)
        let success = service.pasteToActiveApp(
            targetApp: NSRunningApplication.current,
            delay: 0.001,
            completion: {
                exp.signal()
            }
        )

        TestHarness.assertTrue(success, "pasteToActiveApp returns true when permission granted")
        TestHarness.assertTrue(accessibilityChecked, "Accessibility permission checked prior to simulation")

        let waitRes = exp.wait(timeout: .now() + 2.0)
        TestHarness.assertEqual(waitRes, .success, "Async paste completion callback fired within timeout")
        TestHarness.assertEqual(mockSimulator.activatedApps.count, 1, "Target application reactivated once")
        TestHarness.assertEqual(mockSimulator.postKeyEventCount, 1, "Synthetic Cmd+V key event posted once")
    }

    // MARK: - 6. AutoPasteService Permission Denied Fallback

    private static func testAutoPasteServicePermissionDeniedFallback() {
        let mockSimulator = MockPasteSimulator()
        var promptInvoked = false
        var settingsOpened = false

        let service = AutoPasteService(
            pasteSimulator: mockSimulator,
            accessibilityChecker: { false },
            accessibilityPrompter: {
                promptInvoked = true
                return false
            },
            settingsOpener: {
                settingsOpened = true
            }
        )

        TestHarness.assertFalse(service.isAccessibilityTrusted, "isAccessibilityTrusted is false")
        TestHarness.assertFalse(service.checkAccessibilityPermission(), "checkAccessibilityPermission is false")

        var completionCalled = false
        let success = service.pasteToActiveApp(
            targetApp: NSRunningApplication.current,
            delay: 0.001,
            promptIfUntrusted: true,
            completion: {
                completionCalled = true
            }
        )

        TestHarness.assertFalse(success, "pasteToActiveApp returns false when untrusted")
        TestHarness.assertTrue(completionCalled, "Completion handler called on fallback")
        TestHarness.assertTrue(promptInvoked, "requestAccessibilityPermission invoked on promptIfUntrusted")
        TestHarness.assertEqual(mockSimulator.postKeyEventCount, 0, "No synthetic keystrokes posted when untrusted")

        service.openAccessibilitySettings()
        TestHarness.assertTrue(settingsOpened, "openAccessibilitySettings invoked successfully")
    }

    // MARK: - 7. Coordinator Enabled Auto-Paste

    private static func testClipboardActionCoordinatorEnabledAutoPaste(sandboxDir: URL) {
        let subDir = sandboxDir.appendingPathComponent("CoordEnabled_\(UUID().uuidString)")
        let storage = StorageManager(baseDirectory: subDir, initialCapacity: 10)
        var s = storage.settings
        s.autoPasteOnSelection = true
        storage.settings = s

        let testPB = NSPasteboard(name: .init("com.superclip.test.coord.enabled.\(UUID().uuidString)"))
        let monitor = PasteboardMonitor(pasteboard: testPB)
        let writer = PasteboardWriter(pasteboard: testPB, monitor: monitor)
        let mockAutoPaste = MockAutoPasteService(isAccessibilityTrusted: true)
        let mockTracker = MockPreviousAppTracker(app: NSRunningApplication.current)

        var dismissed = false
        let coordinator = ClipboardActionCoordinator(
            storageManager: storage,
            pasteboardWriter: writer,
            autoPasteService: mockAutoPaste,
            previousAppTracker: mockTracker,
            onDismiss: { dismissed = true }
        )

        let item = ClipItem(id: UUID(), contentType: .text, textContent: "Auto Paste Item", byteSize: 14, isPinned: false)
        storage.addClip(item: item, imageData: nil, thumbData: nil)

        coordinator.selectAndCopy(item: item)

        TestHarness.assertTrue(dismissed, "onDismiss fired on selection")
        TestHarness.assertEqual(testPB.string(forType: .string), "Auto Paste Item", "Payload written to pasteboard")
        TestHarness.assertEqual(mockAutoPaste.pasteToActiveAppCalls.count, 1, "AutoPasteService invoked when enabled")
        TestHarness.assertEqual(
            mockAutoPaste.pasteToActiveAppCalls.first?.targetApp?.processIdentifier,
            NSRunningApplication.current.processIdentifier,
            "AutoPasteService passed correct previous application"
        )
    }

    // MARK: - 8. Coordinator Disabled Auto-Paste

    private static func testClipboardActionCoordinatorDisabledAutoPaste(sandboxDir: URL) {
        let subDir = sandboxDir.appendingPathComponent("CoordDisabled_\(UUID().uuidString)")
        let storage = StorageManager(baseDirectory: subDir, initialCapacity: 10)
        var s = storage.settings
        s.autoPasteOnSelection = false
        storage.settings = s

        let testPB = NSPasteboard(name: .init("com.superclip.test.coord.disabled.\(UUID().uuidString)"))
        let monitor = PasteboardMonitor(pasteboard: testPB)
        let writer = PasteboardWriter(pasteboard: testPB, monitor: monitor)
        let mockAutoPaste = MockAutoPasteService(isAccessibilityTrusted: true)
        let mockTracker = MockPreviousAppTracker(app: NSRunningApplication.current)

        var dismissed = false
        let coordinator = ClipboardActionCoordinator(
            storageManager: storage,
            pasteboardWriter: writer,
            autoPasteService: mockAutoPaste,
            previousAppTracker: mockTracker,
            onDismiss: { dismissed = true }
        )

        let item = ClipItem(id: UUID(), contentType: .text, textContent: "Copy Only Item", byteSize: 14, isPinned: false)
        storage.addClip(item: item, imageData: nil, thumbData: nil)

        coordinator.selectAndCopy(item: item)

        TestHarness.assertTrue(dismissed, "onDismiss fired on selection")
        TestHarness.assertEqual(testPB.string(forType: .string), "Copy Only Item", "Payload written to pasteboard")
        TestHarness.assertEqual(
            mockAutoPaste.pasteToActiveAppCalls.count,
            0,
            "AutoPasteService suppressed when autoPasteOnSelection is false"
        )
    }

    // MARK: - 9. Coordinator Copy Item Suppression

    private static func testClipboardActionCoordinatorCopyItemSuppression(sandboxDir: URL) {
        let subDir = sandboxDir.appendingPathComponent("CoordCopyItem_\(UUID().uuidString)")
        let storage = StorageManager(baseDirectory: subDir, initialCapacity: 10)
        var s = storage.settings
        s.autoPasteOnSelection = true
        storage.settings = s

        let testPB = NSPasteboard(name: .init("com.superclip.test.coord.copy.\(UUID().uuidString)"))
        let monitor = PasteboardMonitor(pasteboard: testPB)
        let writer = PasteboardWriter(pasteboard: testPB, monitor: monitor)
        let mockAutoPaste = MockAutoPasteService(isAccessibilityTrusted: true)
        let mockTracker = MockPreviousAppTracker(app: NSRunningApplication.current)

        var dismissed = false
        let coordinator = ClipboardActionCoordinator(
            storageManager: storage,
            pasteboardWriter: writer,
            autoPasteService: mockAutoPaste,
            previousAppTracker: mockTracker,
            onDismiss: { dismissed = true }
        )

        let item = ClipItem(id: UUID(), contentType: .text, textContent: "Context Copy Item", byteSize: 17, isPinned: false)
        storage.addClip(item: item, imageData: nil, thumbData: nil)

        coordinator.copyItem(item: item, dismiss: true)

        TestHarness.assertTrue(dismissed, "onDismiss fired on copyItem")
        TestHarness.assertEqual(testPB.string(forType: .string), "Context Copy Item", "Payload written to pasteboard")
        TestHarness.assertEqual(
            mockAutoPaste.pasteToActiveAppCalls.count,
            0,
            "copyItem remains strictly copy-only without auto-paste"
        )
    }

    // MARK: - 10. SettingsView Integration

    private static func testAutoPasteSettingsViewIntegration(sandboxDir: URL) {
        let subDir = sandboxDir.appendingPathComponent("SettingsIntegration_\(UUID().uuidString)")
        let storage = StorageManager(baseDirectory: subDir, initialCapacity: 10)
        let mockAutoPaste = MockAutoPasteService(isAccessibilityTrusted: false)

        let settingsView = SettingsView(
            storageManager: storage,
            autoPasteService: mockAutoPaste
        )

        TestHarness.assertNotNil(settingsView, "SettingsView instantiates with autoPasteService")
        TestHarness.assertTrue(storage.settings.autoPasteOnSelection, "Initial autoPasteOnSelection is true")

        var newSettings = storage.settings
        newSettings.autoPasteOnSelection = false
        storage.settings = newSettings
        TestHarness.assertFalse(storage.settings.autoPasteOnSelection, "autoPasteOnSelection toggled off")

        newSettings.autoPasteOnSelection = true
        storage.settings = newSettings
        TestHarness.assertTrue(storage.settings.autoPasteOnSelection, "autoPasteOnSelection toggled back on")
    }

    // MARK: - 11. Multiple Event Tap Locations

    private static func testPasteSimulatorMultipleEventTaps() {
        let simulator = PasteSimulator()
        let hidPosted = simulator.postPasteKeyEvent(tap: .cghidEventTap)
        TestHarness.assertTrue(hidPosted, "PasteSimulator successfully posts to cghidEventTap")

        let sessionPosted = simulator.postPasteKeyEvent(tap: .cgAnnotatedSessionEventTap)
        TestHarness.assertTrue(sessionPosted, "PasteSimulator successfully posts to cgAnnotatedSessionEventTap")
    }

    // MARK: - 12. PreviousAppTracker Concurrency & Thread-Safety

    private static func testPreviousAppTrackerThreadSafety() {
        let tracker = PreviousAppTracker()
        let group = DispatchGroup()
        let iterations = 20
        let queue = DispatchQueue(label: "com.superclip.test.tracker.concurrent", attributes: .concurrent)

        for _ in 0..<iterations {
            group.enter()
            queue.async {
                tracker.captureFrontmostApplication()
                _ = tracker.previousApp
                tracker.clear()
                group.leave()
            }
        }

        let result = group.wait(timeout: .now() + 3.0)
        TestHarness.assertEqual(result, .success, "PreviousAppTracker handles concurrent access cleanly without deadlock")
    }

    // MARK: - 13. FloatingClipPanel PreviousAppTracker Injection

    private static func testFloatingClipPanelPreviousAppTrackerInjection() {
        let mockTracker = MockPreviousAppTracker()
        let panel = FloatingClipPanel(rootView: Text("Panel Test"))
        panel.previousAppTracker = mockTracker

        let testRect = NSRect(x: 100, y: 100, width: 300, height: 400)
        panel.present(at: testRect)

        TestHarness.assertEqual(mockTracker.captureCallCount, 1, "FloatingClipPanel invokes injected previousAppTracker on present")
        panel.dismiss()
        TestHarness.assertEqual(mockTracker.clearCallCount, 1, "FloatingClipPanel invokes injected previousAppTracker.clear on dismiss")
    }

    // MARK: - 14. StatusItemManager DismissAll Clears Tracker

    private static func testStatusItemManagerDismissAllClearsTracker() {
        let mockTracker = MockPreviousAppTracker(app: NSRunningApplication.current)
        let sim = StatusItemManager(previousAppTracker: mockTracker)

        sim.dismissAll()
        TestHarness.assertEqual(mockTracker.clearCallCount, 1, "StatusItemManager.dismissAll cleans up target application reference")
    }

    // MARK: - 15. FloatingClipPanel Escape Dismiss Clears Tracker

    private static func testFloatingClipPanelEscapeDismissClearsTracker() {
        let mockTracker = MockPreviousAppTracker()
        let panel = FloatingClipPanel(rootView: Text("Escape Test"))
        panel.previousAppTracker = mockTracker

        let testRect = NSRect(x: 100, y: 100, width: 300, height: 400)
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

        TestHarness.assertEqual(mockTracker.clearCallCount, 1, "FloatingClipPanel Escape dismissal cleans up target application reference")
    }

    // MARK: - 16. StatusItemManager Transient PopoverDidClose Clears Tracker

    private static func testStatusItemManagerPopoverDidCloseClearsTracker() {
        let mockTracker = MockPreviousAppTracker(app: NSRunningApplication.current)
        let sim = StatusItemManager(previousAppTracker: mockTracker)

        let notification = Notification(name: NSPopover.didCloseNotification, object: sim.popover)
        sim.popoverDidClose(notification)
        TestHarness.assertEqual(mockTracker.clearCallCount, 1, "StatusItemManager.popoverDidClose cleans up target application reference")
    }

    // MARK: - 17. AutoPasteService Nil and Terminated Target App Handling

    private static func testAutoPasteServiceNilAndTerminatedTargetApp() {
        let mockSimulator = MockPasteSimulator()
        let testQueue = DispatchQueue(label: "com.superclip.test.autopaste.edge")
        let service = AutoPasteService(
            pasteSimulator: mockSimulator,
            accessibilityChecker: { true },
            dispatchQueue: testQueue
        )

        // Nil target app executes safely
        let expNil = DispatchSemaphore(value: 0)
        let nilSuccess = service.pasteToActiveApp(targetApp: nil, delay: 0.001) {
            expNil.signal()
        }
        TestHarness.assertTrue(nilSuccess, "pasteToActiveApp succeeds with nil targetApp")
        _ = expNil.wait(timeout: .now() + 2.0)
        TestHarness.assertEqual(mockSimulator.postKeyEventCount, 1, "Keystroke simulated even when targetApp is nil")
        TestHarness.assertEqual(mockSimulator.activatedApps.count, 0, "No activation attempted for nil targetApp")

        // Terminated process is rejected by activation
        let proc = Process()
        proc.launchPath = "/bin/echo"
        proc.arguments = ["done"]
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()
        try? proc.run()
        proc.waitUntilExit()

        if let terminatedApp = NSRunningApplication(processIdentifier: proc.processIdentifier) {
            let expTerm = DispatchSemaphore(value: 0)
            let termSuccess = service.pasteToActiveApp(targetApp: terminatedApp, delay: 0.001) {
                expTerm.signal()
            }
            TestHarness.assertTrue(termSuccess, "pasteToActiveApp succeeds safely for terminated process")
            _ = expTerm.wait(timeout: .now() + 2.0)
        }
    }

    // MARK: - 18. Coordinator Image Auto-Paste Success

    private static func testClipboardActionCoordinatorImageAutoPasteSuccess(sandboxDir: URL) {
        let subDir = sandboxDir.appendingPathComponent("CoordImageSuccess_\(UUID().uuidString)")
        let storage = StorageManager(baseDirectory: subDir, initialCapacity: 10)
        var s = storage.settings
        s.autoPasteOnSelection = true
        storage.settings = s

        let testPB = NSPasteboard(name: .init("com.superclip.test.coord.image.success.\(UUID().uuidString)"))
        let monitor = PasteboardMonitor(pasteboard: testPB)
        let writer = PasteboardWriter(pasteboard: testPB, monitor: monitor)
        let mockAutoPaste = MockAutoPasteService(isAccessibilityTrusted: true)
        let mockTracker = MockPreviousAppTracker(app: NSRunningApplication.current)

        var dismissed = false
        let coordinator = ClipboardActionCoordinator(
            storageManager: storage,
            pasteboardWriter: writer,
            autoPasteService: mockAutoPaste,
            previousAppTracker: mockTracker,
            onDismiss: { dismissed = true }
        )

        let rawPNG = Data([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
            0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
            0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
            0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
            0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
            0x42, 0x60, 0x82
        ])
        let imageItem = ClipItem(id: UUID(), contentType: .image, imageWidth: 1, imageHeight: 1, byteSize: rawPNG.count)
        storage.addClip(item: imageItem, imageData: rawPNG, thumbData: rawPNG)

        coordinator.selectAndCopy(item: imageItem)

        TestHarness.assertTrue(dismissed, "onDismiss fired on image selection")
        TestHarness.assertNotNil(testPB.data(forType: .png), "Image payload written to pasteboard as PNG")
        TestHarness.assertEqual(mockAutoPaste.pasteToActiveAppCalls.count, 1, "AutoPasteService invoked for image selection")
    }

    // MARK: - 19. Coordinator Image Auto-Paste Failure On Missing Data

    private static func testClipboardActionCoordinatorImageAutoPasteFailureOnMissingData(sandboxDir: URL) {
        let subDir = sandboxDir.appendingPathComponent("CoordImageFail_\(UUID().uuidString)")
        let storage = StorageManager(baseDirectory: subDir, initialCapacity: 10)
        var s = storage.settings
        s.autoPasteOnSelection = true
        storage.settings = s

        let testPB = NSPasteboard(name: .init("com.superclip.test.coord.image.fail.\(UUID().uuidString)"))
        let monitor = PasteboardMonitor(pasteboard: testPB)
        let writer = PasteboardWriter(pasteboard: testPB, monitor: monitor)
        let mockAutoPaste = MockAutoPasteService(isAccessibilityTrusted: true)
        let mockTracker = MockPreviousAppTracker(app: NSRunningApplication.current)

        var dismissed = false
        let coordinator = ClipboardActionCoordinator(
            storageManager: storage,
            pasteboardWriter: writer,
            autoPasteService: mockAutoPaste,
            previousAppTracker: mockTracker,
            onDismiss: { dismissed = true }
        )

        // Item has .image type but was never added with imageData to storage
        let missingImageItem = ClipItem(id: UUID(), contentType: .image, imageWidth: 10, imageHeight: 10, byteSize: 50)

        coordinator.selectAndCopy(item: missingImageItem)

        TestHarness.assertFalse(dismissed, "onDismiss suppressed when image write fails")
        TestHarness.assertEqual(mockAutoPaste.pasteToActiveAppCalls.count, 0, "AutoPasteService suppressed when image write fails")
    }

    // MARK: - 20. PasteSimulating Protocol Extension Non-Circular Invocation

    private static func testPasteSimulatingProtocolExtensionNonCircular() {
        final class CustomTapOnlySimulator: PasteSimulating {
            var postTapCallCount = 0
            func activate(app: NSRunningApplication) -> Bool { true }
            func postPasteKeyEvent(tap: CGEventTapLocation) -> Bool {
                postTapCallCount += 1
                return true
            }
            func pasteToActiveApp(targetApp: NSRunningApplication?, delay: TimeInterval, completion: (() -> Void)?) {
                completion?()
            }
        }

        let customSim = CustomTapOnlySimulator()
        // Calling postPasteKeyEvent() uses protocol extension to dispatch to postPasteKeyEvent(tap: .cghidEventTap)
        let success = customSim.postPasteKeyEvent()
        TestHarness.assertTrue(success, "Protocol extension postPasteKeyEvent succeeds without recursion")
        TestHarness.assertEqual(customSim.postTapCallCount, 1, "Dispatched directly to postPasteKeyEvent(tap:)")
    }

    // MARK: - 21. AutoPasteService Reset Accessibility Permission

    private static func testAutoPasteServiceResetAccessibilityPermission() {
        var resetCalled = false
        let service = AutoPasteService(
            accessibilityResetter: {
                resetCalled = true
                return true
            }
        )

        let success = service.resetAccessibilityPermission()
        TestHarness.assertTrue(success, "resetAccessibilityPermission returns true on success")
        TestHarness.assertTrue(resetCalled, "accessibilityResetter invoked by resetAccessibilityPermission")
    }

    // MARK: - 22. AutoPasteService Reset And Request Sequence

    private static func testAutoPasteServiceResetAndRequestSequence() {
        var resetCalled = false
        var settingsOpened = false
        var promptCalled = false

        let service = AutoPasteService(
            accessibilityChecker: { false },
            accessibilityPrompter: {
                promptCalled = true
                return false
            },
            accessibilityResetter: {
                resetCalled = true
                return true
            },
            settingsOpener: {
                settingsOpened = true
            }
        )

        let promptRes = service.resetAndRequestAccessibilityPermission()
        TestHarness.assertFalse(promptRes, "resetAndRequestAccessibilityPermission returns prompter result")
        TestHarness.assertTrue(resetCalled, "TCC reset invoked in resetAndRequest sequence")
        TestHarness.assertTrue(settingsOpened, "System Settings opened in resetAndRequest sequence")
        TestHarness.assertTrue(promptCalled, "System prompt requested in resetAndRequest sequence")

        // Also test MockAutoPasteService
        let mockService = MockAutoPasteService()
        _ = mockService.resetAndRequestAccessibilityPermission()
        TestHarness.assertEqual(mockService.resetPermissionCallCount, 1, "Mock resetPermissionCallCount incremented")
        TestHarness.assertEqual(mockService.openSettingsCallCount, 1, "Mock openSettingsCallCount incremented")
        TestHarness.assertEqual(mockService.requestPermissionCallCount, 1, "Mock requestPermissionCallCount incremented")
    }
}
