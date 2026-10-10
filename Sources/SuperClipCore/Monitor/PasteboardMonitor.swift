import AppKit
import CoreGraphics
import ImageIO

public protocol PasteboardMonitoring: AnyObject {
    var onNewClip: ((ClipItem, Data?, Data?) -> Void)? { get set }
    func startPolling(intervalMs: Int)
    func stopPolling()
    func markSelfCopy(newChangeCount: Int)
}

public final class PasteboardMonitor: PasteboardMonitoring, @unchecked Sendable {
    /// Shared singleton instance for application-wide pasteboard monitoring.
    public static let shared = PasteboardMonitor()

    public let pasteboard: NSPasteboard
    private let monitorQueue = DispatchQueue(label: "com.superclip.pasteboard.monitor", qos: .userInitiated)
    private var timer: DispatchSourceTimer?
    private var isPolling = false
    private let stateLock = NSLock()

    public var lastChangeCount: Int
    private var suppressedChangeCounts: Set<Int> = []
    public var pollCount: Int = 0

    public var isSuppressed: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return !suppressedChangeCounts.isEmpty
    }

    private var lastExtractedImageHash: Int?

    public var onNewClip: ((ClipItem, Data?, Data?) -> Void)?

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
    }

    public func startPolling(intervalMs: Int = 250) {
        stateLock.lock()
        defer { stateLock.unlock() }

        if isPolling {
            timer?.cancel()
            timer = nil
        }

        let t = DispatchSource.makeTimerSource(queue: monitorQueue)
        t.schedule(
            deadline: .now(),
            repeating: .milliseconds(intervalMs),
            leeway: .milliseconds(50)
        )
        t.setEventHandler { [weak self] in
            self?.checkPasteboard()
        }
        timer = t
        isPolling = true
        t.resume()
    }

    public func stopPolling() {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard isPolling else { return }
        timer?.cancel()
        timer = nil
        isPolling = false
    }

    public func markSelfCopy(newChangeCount: Int) {
        stateLock.lock()
        defer { stateLock.unlock() }
        self.suppressedChangeCounts.insert(newChangeCount)
        self.lastChangeCount = newChangeCount
    }

    public func pollTick() -> Bool {
        pollCount += 1
        let current = pasteboard.changeCount
        stateLock.lock()
        defer { stateLock.unlock() }

        if suppressedChangeCounts.contains(current) {
            suppressedChangeCounts = suppressedChangeCounts.filter { $0 > current }
            lastChangeCount = current
            return false
        }

        suppressedChangeCounts = suppressedChangeCounts.filter { $0 > current }

        if current != lastChangeCount {
            lastChangeCount = current
            return true
        }

        return false
    }

    public func checkNow() {
        monitorQueue.sync {
            self.checkPasteboard()
        }
    }

    private func checkPasteboard() {
        autoreleasepool {
            let currentCount = pasteboard.changeCount

            stateLock.lock()
            let shouldProcess: Bool
            if suppressedChangeCounts.contains(currentCount) {
                suppressedChangeCounts = suppressedChangeCounts.filter { $0 > currentCount }
                lastChangeCount = currentCount
                shouldProcess = false
            } else {
                suppressedChangeCounts = suppressedChangeCounts.filter { $0 > currentCount }
                if currentCount == lastChangeCount {
                    shouldProcess = false
                } else {
                    lastChangeCount = currentCount
                    shouldProcess = true
                }
            }
            stateLock.unlock()

            guard shouldProcess else { return }

            // Priority 1: PNG Image payload
            if let pngData = pasteboard.data(forType: .png) {
                if processImage(data: pngData) { return }
            }

            // Priority 2: TIFF Image payload
            if let tiffData = pasteboard.data(forType: .tiff) {
                if processImage(data: tiffData) { return }
            }

            // Priority 3: Plain text payload
            if let text = pasteboard.string(forType: .string), !text.isEmpty {
                processText(string: text)
                return
            }
        }
    }

    private func processText(string: String) {
        guard !string.isEmpty else { return }

        stateLock.lock()
        self.lastExtractedImageHash = nil
        stateLock.unlock()

        let item = ClipItem(
            id: UUID(),
            contentType: .text,
            textContent: string,
            imageFileName: nil,
            thumbnailFileName: nil,
            imageWidth: nil,
            imageHeight: nil,
            byteSize: string.utf8.count,
            createdAt: Date(),
            isPinned: false
        )

        DispatchQueue.main.async { [weak self] in
            self?.onNewClip?(item, nil, nil)
        }
    }

    @discardableResult
    private func processImage(data: Data) -> Bool {
        guard !data.isEmpty else { return false }

        var hasher = Hasher()
        hasher.combine(data.count)
        data.withUnsafeBytes { hasher.combine(bytes: $0) }
        let imageHash = hasher.finalize()

        stateLock.lock()
        if imageHash == self.lastExtractedImageHash {
            stateLock.unlock()
            return true
        }
        self.lastExtractedImageHash = imageHash
        stateLock.unlock()

        let pngData = convertToPNG(data: data) ?? data
        guard let dims = ThumbnailGenerator.extractDimensions(from: pngData) else {
            // Revert image hash on corrupt image to avoid blocking subsequent valid payloads
            stateLock.lock()
            if self.lastExtractedImageHash == imageHash {
                self.lastExtractedImageHash = nil
            }
            stateLock.unlock()
            return false
        }

        let thumbData = ThumbnailGenerator.generateThumbnail(from: pngData, maxPixelSize: 180)
        let width = dims.width
        let height = dims.height

        let id = UUID()
        let item = ClipItem(
            id: id,
            contentType: .image,
            textContent: "Image (\(width)x\(height))",
            imageFileName: "\(id.uuidString).png",
            thumbnailFileName: "\(id.uuidString)_thumb.png",
            imageWidth: width,
            imageHeight: height,
            byteSize: pngData.count,
            createdAt: Date(),
            isPinned: false
        )

        DispatchQueue.main.async { [weak self] in
            self?.onNewClip?(item, pngData, thumbData)
        }

        return true
    }

    private func convertToPNG(data: Data) -> Data? {
        // Fast magic bytes check for PNG header: 0x89, 'P', 'N', 'G'
        if data.count >= 4 && data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47 {
            return data
        }
        if let rep = NSBitmapImageRep(data: data) {
            return rep.representation(using: .png, properties: [:])
        }
        return nil
    }

    deinit {
        stopPolling()
    }
}
