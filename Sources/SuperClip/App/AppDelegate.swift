import AppKit
import SwiftUI
import SuperClipCore

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public var storageManager: StorageManager!
    public var pasteboardMonitor: PasteboardMonitor!
    public var statusItemManager: StatusItemManager!
    public var floatingPanel: FloatingClipPanel!
    public var settingsWindowController: SettingsWindowController!

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Enforce runtime menu bar accessory mode (LSUIElement safeguard)
        NSApplication.shared.setActivationPolicy(.accessory)

        storageManager = StorageManager()
        pasteboardMonitor = PasteboardMonitor.shared

        // Register pasteboard polling callback
        pasteboardMonitor.onNewClip = { [weak self] item, rawData, thumbData in
            self?.storageManager.addClip(item: item, imageData: rawData, thumbData: thumbData)
        }
        pasteboardMonitor.startPolling(intervalMs: storageManager.settings.pollIntervalMs)

        // Initialize SettingsWindowController singleton
        settingsWindowController = SettingsWindowController(
            storageManager: storageManager,
            hotKeyManager: HotKeyManager.shared,
            onPresentationDismissalRequested: { [weak self] in
                self?.statusItemManager?.dismissAll()
            }
        )
        SettingsWindowController.shared = settingsWindowController

        let pasteboardWriter = PasteboardWriter(
            pasteboard: .general,
            monitor: pasteboardMonitor
        )

        let mainClipView = MainClipView(
            storageManager: storageManager,
            pasteboardWriter: pasteboardWriter,
            pasteboardMonitor: pasteboardMonitor,
            onDismiss: { [weak self] in
                self?.statusItemManager.dismissAll()
            },
            onOpenSettings: { [weak self] in
                self?.openSettings()
            }
        )

        floatingPanel = FloatingClipPanel(size: NSSize(width: 380, height: 600), rootView: mainClipView)

        let popoverVC = NSHostingController(rootView: mainClipView)
        popoverVC.preferredContentSize = NSSize(width: 380, height: 600)

        statusItemManager = StatusItemManager(
            contentViewController: popoverVC,
            floatingPanel: floatingPanel,
            hotKeyManager: HotKeyManager.shared,
            settingsWindowController: settingsWindowController,
            storageManager: storageManager
        )

        statusItemManager.onOpenSettingsRequested = { [weak self] in
            self?.openSettings()
        }

        statusItemManager.onClearHistoryRequested = { [weak self] in
            self?.storageManager.clearUnpinnedHistory()
        }
    }

    public func openSettings() {
        statusItemManager?.dismissAll()
        settingsWindowController?.showSettings()
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Prevent application shutdown when settings window or floating panel closes
        return false
    }

    // MARK: - Application Termination Lifecycle

    public func applicationWillTerminate(_ notification: Notification) {
        // 1. Halt pasteboard polling timer
        pasteboardMonitor?.stopPolling()

        // 2. Unregister Carbon global event hotkey
        statusItemManager?.hotKeyManager.unregister()

        // 3. Dismantle presentation monitors and windows
        statusItemManager?.dismissAll()

        // 4. Synchronously flush disk queue to guarantee persistence of metadata, settings, and blobs
        storageManager?.flushDiskQueue()
    }
}
