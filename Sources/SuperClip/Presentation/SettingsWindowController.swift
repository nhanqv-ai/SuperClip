import AppKit
import SwiftUI
import SuperClipCore

/// SettingsWindowController manages the presentation, lifecycle, and singleton
/// coordination of the SuperClip preferences and settings window.
///
/// Features:
/// - Standard macOS settings window (NSWindow with .titled, .closable, title "SuperClip Settings").
/// - Hosts SettingsView via NSHostingController.
/// - Single-instance management: brings existing window to front instead of duplicating.
/// - Centered on screen, ordered front, makes key window.
/// - App activation: NSApp.activate(ignoringOtherApps: true) ensures key window focus in accessory mode.
/// - Preserved across close operations (isReleasedWhenClosed = false).
/// - Window frame autosave support ("SuperClipSettingsWindow").
/// - Dismisses popover and floating panel upon presentation.
/// - Zero emojis invariant across all titles and identifiers.
public final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    // MARK: - Singleton & State

    public static var shared: SettingsWindowController?

    public let storageManager: StorageManager
    public let hotKeyManager: any HotKeyManaging

    /// Callback invoked when settings presentation begins to dismiss popover or floating panel
    public var onPresentationDismissalRequested: (() -> Void)?

    private var hasBeenCentered: Bool = false

    // MARK: - Initialization

    public init(
        storageManager: StorageManager,
        hotKeyManager: any HotKeyManaging = HotKeyManager.shared,
        onPresentationDismissalRequested: (() -> Void)? = nil
    ) {
        self.storageManager = storageManager
        self.hotKeyManager = hotKeyManager
        self.onPresentationDismissalRequested = onPresentationDismissalRequested

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "SuperClip Settings"
        window.isReleasedWhenClosed = false
        window.level = .normal
        window.setFrameAutosaveName("SuperClipSettingsWindow")

        super.init(window: window)
        window.delegate = self
        setupContentView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Content View Setup

    public func setupContentView() {
        guard let window = self.window else { return }

        let settingsView = SettingsView(
            storageManager: storageManager,
            hotKeyManager: hotKeyManager,
            onClose: { [weak self] in
                self?.close()
            }
        )
        let hostingController = NSHostingController(rootView: settingsView)
        hostingController.preferredContentSize = NSSize(width: 460, height: 440)
        window.contentViewController = hostingController
    }

    /// Convenience method for hosting custom views (e.g. for testing)
    public func setRootView<V: View>(_ view: V) {
        guard let window = self.window else { return }
        let hostingController = NSHostingController(rootView: view)
        hostingController.preferredContentSize = NSSize(width: 460, height: 440)
        window.contentViewController = hostingController
    }

    // MARK: - Presentation

    /// Presents the settings window, bringing it to front and making it key.
    /// If already visible, raises and focuses the existing window.
    public func showSettings() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.showSettings()
            }
            return
        }

        // Coordinate dismissal of transient presentations
        onPresentationDismissalRequested?()

        guard let window = self.window else { return }

        // Center on initial presentation if not restored by autosave
        if !hasBeenCentered && !window.isVisible {
            window.center()
            hasBeenCentered = true
        }

        // Activate application so window accepts key focus in accessory (LSUIElement) mode
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - NSWindowDelegate

    public func windowWillClose(_ notification: Notification) {
        // Window closed by user; preserved in memory for subsequent presentations
    }
}
