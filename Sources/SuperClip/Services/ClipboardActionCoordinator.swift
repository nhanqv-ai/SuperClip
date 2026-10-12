import Foundation
import SuperClipCore

/// Central action coordinator mediating UI actions, storage operations,
/// pasteboard writeback, and clean window dismissal.
public final class ClipboardActionCoordinator {
    public let storageManager: any StorageManaging
    public let pasteboardWriter: any PasteboardWriting
    public let autoPasteService: any AutoPasteServicing
    public let previousAppTracker: any PreviousAppTracking
    public var onDismiss: (() -> Void)?

    public init(
        storageManager: any StorageManaging,
        pasteboardWriter: any PasteboardWriting,
        autoPasteService: any AutoPasteServicing = AutoPasteService.shared,
        previousAppTracker: any PreviousAppTracking = PreviousAppTracker.shared,
        onDismiss: (() -> Void)? = nil
    ) {
        self.storageManager = storageManager
        self.pasteboardWriter = pasteboardWriter
        self.autoPasteService = autoPasteService
        self.previousAppTracker = previousAppTracker
        self.onDismiss = onDismiss
    }

    /// Selects an item, writes it to pasteboard, suppresses self-copy, dismisses the UI,
    /// and triggers direct auto-paste to the previous active application if enabled.
    public func selectAndCopy(item: ClipItem) {
        let success = pasteboardWriter.writeClip(item, storageManager: storageManager)
        guard success else { return }

        let targetApp = previousAppTracker.previousApp
        onDismiss?()

        if storageManager.settings.autoPasteOnSelection {
            autoPasteService.pasteToActiveApp(targetApp: targetApp)
        }
    }

    /// Dedicated per-row copy button action.
    public func copyItem(item: ClipItem, dismiss: Bool = true) {
        let success = pasteboardWriter.writeClip(item, storageManager: storageManager)
        if success && dismiss {
            onDismiss?()
        }
    }

    /// Toggles the pin state for an item.
    public func togglePin(item: ClipItem) {
        storageManager.togglePin(id: item.id)
    }

    /// Toggles the masked state for an item.
    public func toggleMask(item: ClipItem) {
        storageManager.toggleMaskItem(id: item.id)
    }

    /// Deletes an item permanently from memory and disk.
    public func deleteItem(item: ClipItem) {
        storageManager.deleteItem(id: item.id)
    }

    /// Clears all unpinned history items and their disk assets.
    public func clearUnpinned() {
        storageManager.clearUnpinnedHistory()
    }
}
