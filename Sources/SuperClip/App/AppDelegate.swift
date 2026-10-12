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

        // Synchronize launch at login with system
        LaunchAtLoginManager.shared.setEnabled(storageManager.settings.launchAtLogin)

        // Configure ignored apps provider and check for pasteboard monitor
        pasteboardMonitor.ignoredAppsProvider = { [weak self] in
            self?.storageManager.settings.ignoredApps ?? []
        }
        pasteboardMonitor.isIgnoredAppCheck = { [weak self] bundleId, name in
            self?.storageManager.isAppIgnored(bundleIdentifier: bundleId, name: name) ?? false
        }

        // Register pasteboard polling callback
        pasteboardMonitor.onNewClip = { [weak self] item, rawData, thumbData in
            guard let self = self, self.storageManager.settings.recordClipboardHistory else { return }

            // Active filtering check for frontmost application
            let (rawBid, rawName) = self.pasteboardMonitor.frontmostAppProvider?() ?? (
                NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                NSWorkspace.shared.frontmostApplication?.localizedName
            )
            let bundleId = rawBid?.trimmingCharacters(in: .whitespacesAndNewlines)
            let appName = rawName?.trimmingCharacters(in: .whitespacesAndNewlines)
            if self.storageManager.isAppIgnored(bundleIdentifier: bundleId, name: appName) {
                return
            }

            self.storageManager.addClip(item: item, imageData: rawData, thumbData: thumbData)
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

        floatingPanel.onDismiss = { [weak self] in
            self?.statusItemManager.dismissAll()
        }

        statusItemManager.onOpenSettingsRequested = { [weak self] in
            self?.openSettings()
        }

        statusItemManager.onClearHistoryRequested = { [weak self] in
            self?.storageManager.clearUnpinnedHistory()
        }

        statusItemManager.onCheckForUpdatesRequested = { [weak self] in
            UpdateManager.shared.checkForUpdates(userInitiated: true) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let release):
                        if release != nil {
                            self?.statusItemManager.showPopover()
                        }
                    case .failure:
                        break
                    }
                }
            }
        }

        // Configure update manager and schedule background update checking
        UpdateManager.shared.storageManager = storageManager
        UpdateManager.shared.checkOnStartupIfNeeded(storageManager: storageManager)
        UpdateManager.shared.startPeriodicCheck(interval: 86400, storageManager: storageManager)
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

        // 4. Invalidate periodic update timer
        UpdateManager.shared.stopPeriodicCheck()

        // 5. Synchronously flush disk queue to guarantee persistence of metadata, settings, and blobs
        storageManager?.flushDiskQueue()
    }
}
