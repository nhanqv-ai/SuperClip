import Foundation
import SuperClipCore

/// Central action coordinator mediating UI actions, storage operations,
/// pasteboard writeback, and clean window dismissal.
public final class ClipboardActionCoordinator {
    public let storageManager: any StorageManaging
    public let pasteboardWriter: any PasteboardWriting
    public var onDismiss: (() -> Void)?

    public init(
        storageManager: any StorageManaging,
        pasteboardWriter: any PasteboardWriting,
        onDismiss: (() -> Void)? = nil
    ) {
        self.storageManager = storageManager
        self.pasteboardWriter = pasteboardWriter
        self.onDismiss = onDismiss
    }

    /// Selects an item, writes it to pasteboard, suppresses self-copy, and dismisses the UI.
    public func selectAndCopy(item: ClipItem) {
        let success = pasteboardWriter.writeClip(item, storageManager: storageManager)
        if success {
            onDismiss?()
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
