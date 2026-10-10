import AppKit
import SwiftUI
import SuperClipCore

/// A borderless, floating NSPanel subclass presenting clipboard history directly
/// near the mouse cursor or clamped to active screen boundaries.
///
/// Architectural Specifications:
/// - Borderless styleMask: [.nonactivatingPanel]
/// - Floating window level: .floating
/// - Non-opaque with clear background and native system drop shadow
/// - Key window capabilities for keyboard navigation and instant search
/// - Automatic dismissal on Escape key, outside click, and item selection
/// - Zero Accessibility permissions required
/// - Zero emojis across all UI strings and icons
public final class FloatingClipPanel: NSPanel, FloatingPanelPresenting {

    // MARK: - Constants

    /// Default panel dimensions matching SuperClip presentation standards.
    public static let defaultPanelSize = NSSize(width: 360, height: 480)

    // MARK: - Public Callbacks

    /// Callback invoked when the panel is dismissed.
    public var onDismiss: (() -> Void)?

    /// Callback invoked when a clip item is selected.
    public var onItemSelected: ((ClipItem) -> Void)?

    // MARK: - Private Lifecycle State

    /// Global event monitor observing mouse clicks outside application windows.
    private var globalMouseMonitor: Any?

    /// Local event monitor observing mouse clicks within the application.
    private var localMouseMonitor: Any?

    /// Guard flag preventing redundant or recursive dismiss executions.
    private var isDismissing: Bool = false

    // MARK: - Key Window Capabilities

    /// Overridden to allow the borderless floating panel to become the key window
    /// and receive keyboard events and text input focus without a title bar.
    public override var canBecomeKey: Bool {
        return true
    }

    /// Overridden to allow the panel to become the main window when presented.
    public override var canBecomeMain: Bool {
        return true
    }

    // MARK: - Initialization

    /// Initializes a new floating clip panel with the specified frame rectangle.
    /// - Parameter contentRect: Initial frame rectangle for the panel.
    public init(contentRect: NSRect = NSRect(origin: .zero, size: defaultPanelSize)) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        setupPanelAttributes()
        setupNotificationObservers()
    }

    /// Convenience initializer hosting a SwiftUI root view immediately.
    /// - Parameters:
    ///   - size: Panel dimensions (defaults to 360x480).
    ///   - rootView: The SwiftUI view to host.
    public convenience init<V: View>(size: NSSize = defaultPanelSize, rootView: V) {
        self.init(contentRect: NSRect(origin: .zero, size: size))
        setRootView(rootView)
    }

    // MARK: - Panel Configuration

    /// Configures panel attributes according to SuperClip presentation standards.
    private func setupPanelAttributes() {
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.hidesOnDeactivate = false
        self.isMovableByWindowBackground = true
        self.isReleasedWhenClosed = false
        self.animationBehavior = .none
    }

    /// Registers system notifications for window lifecycle events.
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowDidResignKey(_:)),
            name: NSWindow.didResignKeyNotification,
            object: self
        )
    }

    // MARK: - SwiftUI Hosting Integration

    /// Sets or replaces the root SwiftUI content view using an NSHostingController.
    /// - Parameter view: The SwiftUI view to be hosted within the panel.
    public func setRootView<V: View>(_ view: V) {
        let hostingController = NSHostingController(rootView: view)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        self.contentViewController = hostingController
        self.invalidateShadow()
    }

    // MARK: - Presentation

    /// Presents the panel at an explicit screen frame rectangle, activating key status.
    /// - Parameter frame: The target screen frame rectangle.
    public func present(at frame: NSRect) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.present(at: frame)
            }
            return
        }

        self.setFrame(frame, display: true)
        self.isDismissing = false
        installEventMonitors()
        self.orderFrontRegardless()
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.invalidateShadow()
    }

    /// Presents the panel centered and clamped near the current mouse cursor location.
    /// - Parameters:
    ///   - size: Optional custom panel size (defaults to current panel size).
    ///   - screen: Optional target screen override.
    public func presentNearCursor(size: NSSize? = nil, screen: NSScreen? = nil) {
        let mouseLoc = NSEvent.mouseLocation
        let panelSize = size ?? self.frame.size
        let targetFrame = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: mouseLoc,
            panelSize: panelSize,
            targetScreen: screen
        )
        present(at: targetFrame)
    }

    /// Presents the panel near a specified mouse location, conforming to FloatingPanelPresenting.
    /// - Parameter mouseLocation: The mouse anchor coordinates.
    public func show(near mouseLocation: NSPoint) {
        let panelSize = self.frame.size
        let targetFrame = PanelFrameCalculator.calculateClampedPanelFrame(
            mouseLoc: mouseLocation,
            panelSize: panelSize
        )
        present(at: targetFrame)
    }

    /// Toggles visibility of the panel near the current mouse cursor location.
    /// - Parameters:
    ///   - size: Optional custom panel size.
    ///   - screen: Optional target screen override.
    public func toggleNearCursor(size: NSSize? = nil, screen: NSScreen? = nil) {
        if isVisible {
            dismiss()
        } else {
            presentNearCursor(size: size, screen: screen)
        }
    }

    // MARK: - Dismissal

    /// Cleanly dismisses the panel, removing active monitors and ordering out the window.
    public func dismiss() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.dismiss()
            }
            return
        }

        guard !isDismissing, isVisible else { return }
        isDismissing = true
        removeEventMonitors()
        self.orderOut(nil)
        isDismissing = false
        onDismiss?()
    }

    /// Handles an item selection event by notifying subscribers and dismissing the panel.
    /// - Parameter item: The selected clip item.
    public func handleItemSelection(_ item: ClipItem) {
        onItemSelected?(item)
        dismiss()
    }

    // MARK: - Responder & Event Interception

    /// Intercepts window-level events prior to responder chain dispatch,
    /// ensuring the Escape key immediately dismisses the panel regardless of child focus.
    public override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown && event.keyCode == 53 {
            dismiss()
            return
        }
        super.sendEvent(event)
    }

    /// Standard AppKit cancellation selector invoked on Escape key press.
    public override func cancelOperation(_ sender: Any?) {
        dismiss()
    }

    /// Overridden orderOut to ensure event monitors are unconditionally dismantled.
    public override func orderOut(_ sender: Any?) {
        removeEventMonitors()
        super.orderOut(sender)
    }

    // MARK: - Notification Handling

    /// Invoked when the panel loses key window status.
    @objc private func handleWindowDidResignKey(_ notification: Notification) {
        guard !isDismissing, isVisible else { return }
        dismiss()
    }

    // MARK: - Event Monitors (Lifecycle Managed)

    /// Installs unprivileged global and local mouse monitors to detect outside clicks.
    private func installEventMonitors() {
        removeEventMonitors()

        // Global monitor: captures mouse clicks delivered to other applications.
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self = self, self.isVisible else { return }
            self.dismiss()
        }

        // Local monitor: captures mouse clicks delivered to this application.
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self = self, self.isVisible else { return event }
            if let targetWindow = event.window {
                if targetWindow != self {
                    self.dismiss()
                }
            } else {
                if !self.frame.contains(NSEvent.mouseLocation) {
                    self.dismiss()
                }
            }
            return event
        }
    }

    /// Tears down and unregisters all active NSEvent monitors to prevent memory leaks.
    private func removeEventMonitors() {
        if let gm = globalMouseMonitor {
            NSEvent.removeMonitor(gm)
            globalMouseMonitor = nil
        }
        if let lm = localMouseMonitor {
            NSEvent.removeMonitor(lm)
            localMouseMonitor = nil
        }
    }

    /// Inspection property indicating whether event monitors are currently active.
    public var hasActiveMonitors: Bool {
        return globalMouseMonitor != nil || localMouseMonitor != nil
    }

    // MARK: - Deinitialization

    deinit {
        removeEventMonitors()
        NotificationCenter.default.removeObserver(self)
    }
}

