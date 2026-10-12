import AppKit
import ApplicationServices

/// Protocol defining low-level synthetic paste key event and application activation operations.
public protocol PasteSimulating: AnyObject {
    func activate(app: NSRunningApplication) -> Bool
    func postPasteKeyEvent() -> Bool
    func postPasteKeyEvent(tap: CGEventTapLocation) -> Bool
    func pasteToActiveApp(targetApp: NSRunningApplication?, delay: TimeInterval, completion: (() -> Void)?)
}

extension PasteSimulating {
    public func postPasteKeyEvent() -> Bool {
        return postPasteKeyEvent(tap: .cghidEventTap)
    }

    public func pasteToActiveApp(targetApp: NSRunningApplication?) {
        pasteToActiveApp(targetApp: targetApp, delay: 0.035, completion: nil)
    }
}

/// Production implementation of synthetic Command + V event simulation and target app reactivation.
public final class PasteSimulator: PasteSimulating, @unchecked Sendable {
    public static let shared = PasteSimulator()

    public var defaultEventTap: CGEventTapLocation = .cghidEventTap

    public init() {}

    /// Reactivates the target application ignoring other apps to return focus to its text input.
    @discardableResult
    public func activate(app: NSRunningApplication) -> Bool {
        guard !app.isTerminated else { return false }
        return app.activate(options: [.activateIgnoringOtherApps])
    }

    /// Posts a synthetic Command + V key down and key up event pair to the specified system event tap.
    @discardableResult
    public func postPasteKeyEvent(tap: CGEventTapLocation) -> Bool {
        // Virtual key 0x09 corresponds to kVK_ANSI_V
        let vKeyCode: CGKeyCode = 0x09

        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: true) else {
            return false
        }
        keyDown.flags = .maskCommand

        guard let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: false) else {
            return false
        }
        keyUp.flags = .maskCommand

        keyDown.post(tap: tap)
        keyUp.post(tap: tap)
        return true
    }

    /// Posts a synthetic Command + V key down and key up event pair using the default event tap location.
    @discardableResult
    public func postPasteKeyEvent() -> Bool {
        return postPasteKeyEvent(tap: defaultEventTap)
    }

    /// Reactivates the target application and dispatches a synthetic Command + V after a minimal delay.
    public func pasteToActiveApp(
        targetApp: NSRunningApplication?,
        delay: TimeInterval = 0.035,
        completion: (() -> Void)? = nil
    ) {
        if let app = targetApp {
            _ = activate(app: app)
        }

        let delaySeconds = max(0, delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds) { [weak self] in
            guard let self = self else {
                completion?()
                return
            }
            _ = self.postPasteKeyEvent()
            completion?()
        }
    }
}

/// Protocol defining high-level auto-paste coordination, accessibility verification, and fallback handling.
public protocol AutoPasteServicing: AnyObject {
    var isAccessibilityTrusted: Bool { get }
    func checkAccessibilityPermission() -> Bool
    func requestAccessibilityPermission() -> Bool
    func openAccessibilitySettings()
    @discardableResult
    func pasteToActiveApp(
        targetApp: NSRunningApplication?,
        delay: TimeInterval,
        promptIfUntrusted: Bool,
        completion: (() -> Void)?
    ) -> Bool
}

extension AutoPasteServicing {
    @discardableResult
    public func pasteToActiveApp(targetApp: NSRunningApplication?) -> Bool {
        return pasteToActiveApp(targetApp: targetApp, delay: 0.035, promptIfUntrusted: false, completion: nil)
    }

    @discardableResult
    public func pasteToActiveApp(
        targetApp: NSRunningApplication?,
        delay: TimeInterval = 0.035,
        completion: (() -> Void)? = nil
    ) -> Bool {
        return pasteToActiveApp(targetApp: targetApp, delay: delay, promptIfUntrusted: false, completion: completion)
    }
}

/// High-level direct auto-paste service managing accessibility checks, application reactivation,
/// delay debouncing, synthetic key events, and graceful degradation.
public final class AutoPasteService: AutoPasteServicing, @unchecked Sendable {
    public static let shared = AutoPasteService()

    public var pasteSimulator: any PasteSimulating
    public var accessibilityChecker: () -> Bool
    public var accessibilityPrompter: () -> Bool
    public var settingsOpener: () -> Void
    public var dispatchQueue: DispatchQueue

    public init(
        pasteSimulator: any PasteSimulating = PasteSimulator.shared,
        accessibilityChecker: @escaping () -> Bool = { AXIsProcessTrusted() },
        accessibilityPrompter: @escaping () -> Bool = {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        },
        settingsOpener: @escaping () -> Void = {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"),
               NSWorkspace.shared.open(url) {
                return
            }
            if let fallbackURL = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
                NSWorkspace.shared.open(fallbackURL)
            }
        },
        dispatchQueue: DispatchQueue = .main
    ) {
        self.pasteSimulator = pasteSimulator
        self.accessibilityChecker = accessibilityChecker
        self.accessibilityPrompter = accessibilityPrompter
        self.settingsOpener = settingsOpener
        self.dispatchQueue = dispatchQueue
    }

    /// Current accessibility status via AXIsProcessTrusted.
    public var isAccessibilityTrusted: Bool {
        return accessibilityChecker()
    }

    /// Evaluates whether the process has macOS Accessibility permission.
    public func checkAccessibilityPermission() -> Bool {
        return accessibilityChecker()
    }

    /// Triggers the system accessibility permission prompt dialog.
    public func requestAccessibilityPermission() -> Bool {
        return accessibilityPrompter()
    }

    /// Opens macOS System Settings directly to Privacy & Security -> Accessibility.
    public func openAccessibilitySettings() {
        settingsOpener()
    }

    /// Executes the direct auto-paste sequence:
    /// 1. Reactivates targetApp.
    /// 2. Verifies AXIsProcessTrusted(); if untrusted, falls back gracefully to clipboard-only write.
    /// 3. Delays non-blockingly (25-40ms, default 35ms) for window focus restoration.
    /// 4. Generates and posts synthetic Command + V keypress events.
    @discardableResult
    public func pasteToActiveApp(
        targetApp: NSRunningApplication?,
        delay: TimeInterval = 0.035,
        promptIfUntrusted: Bool = false,
        completion: (() -> Void)? = nil
    ) -> Bool {
        // Step 1: Reactivate target application if present
        if let app = targetApp, !app.isTerminated {
            _ = pasteSimulator.activate(app: app)
        }

        // Accessibility check: fallback gracefully if permissions not granted
        guard isAccessibilityTrusted else {
            if promptIfUntrusted {
                _ = requestAccessibilityPermission()
            }
            completion?()
            return false
        }

        // Step 2: Minimal non-blocking dispatch delay for window server focus transfer
        let delaySeconds = max(0, delay)
        dispatchQueue.asyncAfter(deadline: .now() + delaySeconds) { [weak self] in
            guard let self = self else {
                completion?()
                return
            }
            // Step 3: Synthetic Command + V event simulation
            _ = self.pasteSimulator.postPasteKeyEvent()
            completion?()
        }

        return true
    }
}
