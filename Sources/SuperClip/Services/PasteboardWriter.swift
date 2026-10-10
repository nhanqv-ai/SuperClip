import AppKit
import SuperClipCore

/// Protocol defining pasteboard writeback operations for dependency injection and testing.
public protocol PasteboardWriting: AnyObject {
    @discardableResult
    func writeClip(
        _ item: ClipItem,
        storageManager: (any StorageManaging)?
    ) -> Bool
}

/// Production pasteboard writer handling payload transfer, format declarations,
/// loop suppression coordination with PasteboardMonitor, and zero AX permissions.
public final class PasteboardWriter: PasteboardWriting, @unchecked Sendable {
    public let pasteboard: NSPasteboard
    public weak var monitor: (any PasteboardMonitoring)?
    private let writeLock = NSLock()

    public init(
        pasteboard: NSPasteboard = .general,
        monitor: (any PasteboardMonitoring)? = nil
    ) {
        self.pasteboard = pasteboard
        self.monitor = monitor
    }

    /// Writes the given clip payload back into NSPasteboard and immediately suppresses
    /// self-copy detection in PasteboardMonitor using the new changeCount.
    /// Thread-safe via writeLock mutex synchronization across concurrent callers.
    @discardableResult
    public func writeClip(
        _ item: ClipItem,
        storageManager: (any StorageManaging)? = nil
    ) -> Bool {
        writeLock.lock()
        defer { writeLock.unlock() }

        var writeSuccess = false

        switch item.contentType {
        case .text:
            guard let text = item.textContent else { return false }
            pasteboard.clearContents()
            pasteboard.declareTypes([.string], owner: nil)
            writeSuccess = pasteboard.setString(text, forType: .string)

        case .image:
            guard let storage = storageManager,
                  let rawData = storage.getImageData(for: item),
                  !rawData.isEmpty else {
                return false
            }

            pasteboard.clearContents()
            pasteboard.declareTypes([.png, .tiff], owner: nil)
            let pngSuccess = pasteboard.setData(rawData, forType: .png)

            var tiffSuccess = false
            if let nsImg = NSImage(data: rawData),
               let tiffData = nsImg.tiffRepresentation {
                tiffSuccess = pasteboard.setData(tiffData, forType: .tiff)
            }
            writeSuccess = pngSuccess || tiffSuccess
        }

        guard writeSuccess else { return false }

        // Capture new changeCount AFTER writeback and suppress self-copy loop
        let newCount = pasteboard.changeCount
        if let mon = monitor {
            mon.markSelfCopy(newChangeCount: newCount)
        } else {
            PasteboardMonitor.shared.markSelfCopy(newChangeCount: newCount)
        }

        return true
    }
}
