import AppKit
import Carbon
import Combine
import SuperClipCore

/// Protocol defining the floating panel interface required for dual-presentation coordination.
public protocol FloatingPanelPresenting: AnyObject {
    var isVisible: Bool { get }
    var isKeyWindow: Bool { get }
    func show(near mouseLocation: NSPoint)
    func dismiss()
}

/// StatusItemManager manages the macOS menu bar status item, attached NSPopover,
/// secondary context menu, global hotkey registration, and dual-presentation coordination.
public final class StatusItemManager: NSObject, NSPopoverDelegate, NSMenuDelegate {
    // MARK: - Properties

    public private(set) var statusItem: NSStatusItem
    public private(set) var popover: NSPopover

    public weak var floatingPanel: (any FloatingPanelPresenting)?
    public var hotKeyManager: any HotKeyManaging
    public var previousAppTracker: any PreviousAppTracking

    /// Optional reference to the settings window controller
    public weak var settingsWindowController: SettingsWindowController?

    /// Optional reference to the storage manager for maintenance actions
    public weak var storageManager: (any StorageManaging)? {
        didSet {
            bindStorageManager()
        }
    }

    /// Action callbacks for testing and custom event interception
    public var onOpenSettingsRequested: (() -> Void)?
    public var onClearHistoryRequested: (() -> Void)?
    public var onCheckForUpdatesRequested: (() -> Void)?
    public var onDismissRequested: (() -> Void)?
    public var onPopoverVisibilityChanged: ((Bool) -> Void)?

    private var settingsObserver: AnyCancellable?
    private var escapeMonitor: Any?
    private var lastPopoverCloseTimestamp: TimeInterval = 0

    // MARK: - Context Menu

    public private(set) lazy var contextMenu: NSMenu = {
        let menu = NSMenu(title: "SuperClip")
        menu.delegate = self

        let showHistoryItem = NSMenuItem(
            title: "Show Clipboard History",
            action: #selector(openSuperClipMenuItemClicked(_:)),
            keyEquivalent: ""
        )
        showHistoryItem.target = self
        showHistoryItem.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)
        menu.addItem(showHistoryItem)

        let settingsItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(settingsMenuItemClicked(_:)),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let clearItem = NSMenuItem(
            title: "Clear Unpinned History",
            action: #selector(clearHistoryMenuItemClicked(_:)),
            keyEquivalent: ""
        )
        clearItem.target = self
        clearItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
        menu.addItem(clearItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit SuperClip",
            action: #selector(quitMenuItemClicked(_:)),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        menu.addItem(quitItem)

        return menu
    }()

    // MARK: - Initialization

    public init(
        contentViewController: NSViewController? = nil,
        floatingPanel: (any FloatingPanelPresenting)? = nil,
        hotKeyManager: any HotKeyManaging = HotKeyManager.shared,
        settingsWindowController: SettingsWindowController? = nil,
        storageManager: (any StorageManaging)? = nil,
        previousAppTracker: any PreviousAppTracking = PreviousAppTracker.shared
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        self.floatingPanel = floatingPanel
        self.hotKeyManager = hotKeyManager
        self.settingsWindowController = settingsWindowController
        self.storageManager = storageManager
        self.previousAppTracker = previousAppTracker
        if let panel = floatingPanel as? FloatingClipPanel {
            panel.previousAppTracker = previousAppTracker
        }

        super.init()

        setupStatusItem()
        setupPopover(contentViewController: contentViewController)

        let initialCode = (storageManager as? StorageManager)?.settings.hotKeyKeyCode ?? UInt32(kVK_ANSI_V)
        let initialMods = (storageManager as? StorageManager)?.settings.hotKeyModifiers ?? UInt32(optionKey)
        setupHotKey(keyCode: initialCode, modifiers: initialMods)
        bindStorageManager()
    }

    // MARK: - Status Item Setup

    private func setupStatusItem() {
        guard let button = statusItem.button else { return }

        let icon = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "SuperClip")
        icon?.isTemplate = true

        button.image = icon
        button.imagePosition = .imageOnly
        button.toolTip = "SuperClip - Clipboard History (Option+V)"
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    // MARK: - Popover Setup

    public func setupPopover(contentViewController: NSViewController?) {
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self

        if let vc = contentViewController {
            setContentViewController(vc)
        }
    }

    public func setContentViewController(_ vc: NSViewController) {
        popover.contentViewController = vc
        let prefSize = vc.preferredContentSize
        popover.contentSize = prefSize.width > 0 && prefSize.height > 0
            ? prefSize
            : NSSize(width: 360, height: 480)
    }

    // MARK: - HotKey Setup

    public func setupHotKey(
        keyCode: UInt32 = UInt32(kVK_ANSI_V),
        modifiers: UInt32 = UInt32(optionKey)
    ) {
        hotKeyManager.onTrigger = { [weak self] in
            if Thread.isMainThread {
                self?.handleHotKeyTrigger()
            } else {
                DispatchQueue.main.async {
                    self?.handleHotKeyTrigger()
                }
            }
        }
        hotKeyManager.register(keyCode: keyCode, modifiers: modifiers)
        updateToolTip(keyCode: keyCode, modifiers: modifiers)
    }

    private func updateToolTip(keyCode: UInt32, modifiers: UInt32) {
        guard let button = statusItem.button else { return }
        if keyCode == UInt32(kVK_ANSI_V) && modifiers == UInt32(optionKey) {
            button.toolTip = "SuperClip - Clipboard History (Option+V)"
        } else {
            let shortcut = KeyCombinationHelper.formattedShortcut(keyCode: keyCode, modifiers: modifiers)
            button.toolTip = "SuperClip - Clipboard History (\(shortcut))"
        }
    }

    private func bindStorageManager() {
        settingsObserver?.cancel()
        settingsObserver = nil
        guard let sm = storageManager as? StorageManager else { return }
        updateToolTip(keyCode: sm.settings.hotKeyKeyCode, modifiers: sm.settings.hotKeyModifiers)
        settingsObserver = sm.objectWillChange.sink { [weak self, weak sm] _ in
            guard let self = self, let sm = sm else { return }
            if Thread.isMainThread {
                self.updateToolTip(keyCode: sm.settings.hotKeyKeyCode, modifiers: sm.settings.hotKeyModifiers)
            } else {
                DispatchQueue.main.async {
                    self.updateToolTip(keyCode: sm.settings.hotKeyKeyCode, modifiers: sm.settings.hotKeyModifiers)
                }
            }
        }
    }

    public func updateHotKey(keyCode: UInt32, modifiers: UInt32) {
        hotKeyManager.unregister()
        setupHotKey(keyCode: keyCode, modifiers: modifiers)
    }

    // MARK: - Status Item Action Handling

    @objc public func statusItemClicked(_ sender: Any?) {
        previousAppTracker.captureFrontmostApplication()

        let event = NSApp.currentEvent
        let isRightClick = (event?.type == .rightMouseUp) ||
            ((event?.type == .leftMouseUp) && (event?.modifierFlags.contains(.control) == true))

        if isRightClick {
            showContextMenu()
            return
        }

        let now = ProcessInfo.processInfo.systemUptime

        if popover.isShown {
            closePopover()
        } else {
            // Transient popover dismissal debounce (250ms)
            if now - lastPopoverCloseTimestamp < 0.25 {
                return
            }
            showPopover()
        }
    }

    // MARK: - Context Menu Presentation

    /// Presents the status bar context menu cleanly without breaking subsequent left-clicks
    public func showContextMenu() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.showContextMenu()
            }
            return
        }

        // Mutual exclusion: dismiss floating panel and popover
        floatingPanel?.dismiss()
        closePopover()

        addCheckForUpdatesMenuItem()

        guard let button = statusItem.button else { return }

        // Temporarily set menu to invoke native status item popup tracking
        statusItem.menu = contextMenu
        button.performClick(nil)
    }

    /// Dynamically injects the 'Check for Updates...' menu item into contextMenu
    public func addCheckForUpdatesMenuItem() {
        guard !contextMenu.items.contains(where: { $0.action == #selector(checkUpdatesMenuItemClicked(_:)) }) else {
            return
        }

        let updateItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(checkUpdatesMenuItemClicked(_:)),
            keyEquivalent: ""
        )
        updateItem.target = self
        updateItem.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)

        // Insert before the last separator and Quit SuperClip
        if let quitIndex = contextMenu.items.firstIndex(where: { $0.action == #selector(quitMenuItemClicked(_:)) }) {
            contextMenu.insertItem(updateItem, at: quitIndex)
        } else {
            contextMenu.addItem(updateItem)
        }
    }

    // MARK: - NSMenuDelegate

    public func menuDidClose(_ menu: NSMenu) {
        if menu == contextMenu {
            // Immediately restore nil menu so subsequent left-clicks invoke button.action
            statusItem.menu = nil
        }
    }

    // MARK: - Legacy Context Menu Support

    /// Builds a 6-item context menu for legacy compatibility
    public func buildContextMenu() -> NSMenu {
        return contextMenu
    }

    @objc public func handleShowHistoryMenuItem(_ sender: Any?) {
        openSuperClipMenuItemClicked(sender)
    }

    @objc public func handlePreferencesMenuItem(_ sender: Any?) {
        settingsMenuItemClicked(sender)
    }

    @objc public func handleClearHistoryMenuItem(_ sender: Any?) {
        clearHistoryMenuItemClicked(sender)
    }

    @objc public func handleCheckUpdatesMenuItem(_ sender: Any?) {
        checkUpdatesMenuItemClicked(sender)
    }

    @objc public func handleQuitMenuItem(_ sender: Any?) {
        quitMenuItemClicked(sender)
    }

    // MARK: - Context Menu Actions

    @objc public func openSuperClipMenuItemClicked(_ sender: Any?) {
        showPopover()
    }

    @objc public func settingsMenuItemClicked(_ sender: Any?) {
        closePopover()
        floatingPanel?.dismiss()

        if let onOpen = onOpenSettingsRequested {
            onOpen()
        } else if let controller = settingsWindowController {
            controller.showSettings()
        } else if let sharedController = SettingsWindowController.shared {
            sharedController.showSettings()
        }
    }

    @objc public func checkUpdatesMenuItemClicked(_ sender: Any?) {
        closePopover()
        floatingPanel?.dismiss()

        if let onCheck = onCheckForUpdatesRequested {
            onCheck()
        } else {
            UpdateManager.shared.checkForUpdates(userInitiated: true)
        }
    }

    @objc public func clearHistoryMenuItemClicked(_ sender: Any?) {
        executeClearHistory()
    }

    public func executeClearHistory() {
        storageManager?.clearUnpinnedHistory()
        onClearHistoryRequested?()
    }

    @objc public func aboutMenuItemClicked(_ sender: Any?) {
        closePopover()
        floatingPanel?.dismiss()

        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(
            options: [
                NSApplication.AboutPanelOptionKey.applicationName: "SuperClip",
                NSApplication.AboutPanelOptionKey.version: (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.2")
            ]
        )
    }

    @objc public func quitMenuItemClicked(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    // MARK: - Dual Presentation Coordination

    /// Mode 1: Show Popover beneath status bar button (closing floating panel)
    public func showPopover() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.showPopover()
            }
            return
        }

        // Mutual exclusion: Close floating panel if open
        floatingPanel?.dismiss()

        guard let button = statusItem.button else { return }
        guard popover.contentViewController != nil else { return }

        // Capture previous frontmost app before SuperClip popover activates
        previousAppTracker.captureFrontmostApplication()

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        installEscapeMonitor()

        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
        onPopoverVisibilityChanged?(true)
    }

    /// Close popover cleanly
    public func closePopover() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.closePopover()
            }
            return
        }

        removeEscapeMonitor()
        ThumbnailHoverPreviewPanel.shared.hide()
        guard popover.isShown else { return }
        let wasAnimated = popover.animates
        popover.animates = false
        popover.close()
        popover.animates = wasAnimated
        previousAppTracker.clear()
        onPopoverVisibilityChanged?(false)
    }

    /// Toggle popover visibility
    public func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    /// Mode 2: Handle Global HotKey (Option+V) trigger
    public func handleHotKeyTrigger() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.handleHotKeyTrigger()
            }
            return
        }

        // Mutual exclusion: Close popover if open
        if popover.isShown {
            closePopover()
        }

        // Toggle behavior: If floating panel is already visible and key, dismiss it
        if let panel = floatingPanel, panel.isVisible && panel.isKeyWindow {
            panel.dismiss()
            previousAppTracker.clear()
            return
        }

        // Capture previous frontmost app before floating panel is presented
        previousAppTracker.captureFrontmostApplication()

        // Summon floating panel near current mouse position
        let mouseLoc = NSEvent.mouseLocation
        floatingPanel?.show(near: mouseLoc)
    }

    /// Dismiss all presentations upon item selection or cancel
    public func dismissAll() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.dismissAll()
            }
            return
        }

        closePopover()
        floatingPanel?.dismiss()
        previousAppTracker.clear()
        onDismissRequested?()
    }

    // MARK: - Escape Key Monitoring

    private func installEscapeMonitor() {
        removeEscapeMonitor()
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // kVK_Escape
                guard let self = self, self.popover.isShown else { return event }
                self.closePopover()
                return nil
            }
            return event
        }
    }

    private func removeEscapeMonitor() {
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }
    }

    // MARK: - NSPopoverDelegate

    public func popoverDidShow(_ notification: Notification) {
        installEscapeMonitor()
        onPopoverVisibilityChanged?(true)
    }

    public func popoverDidClose(_ notification: Notification) {
        lastPopoverCloseTimestamp = ProcessInfo.processInfo.systemUptime
        removeEscapeMonitor()
        previousAppTracker.clear()
        onPopoverVisibilityChanged?(false)
    }

    // MARK: - Test Support

    public func setLastPopoverCloseTimestampForTesting(_ timestamp: TimeInterval) {
        self.lastPopoverCloseTimestamp = timestamp
    }

    // MARK: - Lifecycle Teardown

    deinit {
        settingsObserver?.cancel()
        removeEscapeMonitor()
        hotKeyManager.unregister()
        NSStatusBar.system.removeStatusItem(statusItem)
    }
}
