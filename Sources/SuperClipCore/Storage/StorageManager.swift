import Foundation
import Combine

public protocol StorageManaging: AnyObject, ObservableObject {
    var items: [ClipItem] { get }
    var capacity: Int { get set }
    func addClip(item: ClipItem, imageData: Data?, thumbData: Data?)
    func togglePin(id: UUID)
    func deleteItem(id: UUID)
    func clearUnpinnedHistory()
    func getThumbnailURL(for item: ClipItem) -> URL?
    func getImageData(for item: ClipItem) -> Data?
    func flushDiskQueue()
}

public final class StorageManager: ObservableObject, StorageManaging {
    private let lock = NSRecursiveLock()
    private var _items: [ClipItem] = []
    private var _settings: AppSettings
    private var _capacity: Int

    public var items: [ClipItem] {
        lock.lock()
        defer { lock.unlock() }
        return _items
    }

    public var settings: AppSettings {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _settings
        }
        set {
            lock.lock()
            _settings = newValue
            _capacity = max(1, newValue.capacity)
            enforceCapacity()
            saveMetadata()
            saveSettings()
            lock.unlock()
            LocalizationManager.shared.setLanguage(code: newValue.language)
            notifyChange()
        }
    }

    public var capacity: Int {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _capacity
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            let clamped = max(1, newValue)
            _capacity = clamped
            if _settings.capacity != clamped {
                _settings.capacity = clamped
            }
            enforceCapacity()
            saveMetadata()
            saveSettings()
            notifyChange()
        }
    }

    public var pinnedItems: [ClipItem] {
        lock.lock()
        defer { lock.unlock() }
        return _items.filter { $0.isPinned }
    }

    public var historyItems: [ClipItem] {
        lock.lock()
        defer { lock.unlock() }
        return _items.filter { !$0.isPinned }
    }

    public let baseDirectory: URL
    public let imagesDirectory: URL
    public let thumbnailsDirectory: URL
    public let metadataURL: URL
    public let settingsURL: URL

    private let fileQueue = DispatchQueue(label: "com.superclip.storage.fileio", qos: .utility)
    private let imageCache = NSCache<NSString, NSData>()
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(baseDirectory: URL? = nil, initialCapacity: Int? = nil) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = baseDirectory ?? appSupport.appendingPathComponent("SuperClip", isDirectory: true)
        self.baseDirectory = dir
        self.imagesDirectory = dir.appendingPathComponent("images", isDirectory: true)
        self.thumbnailsDirectory = dir.appendingPathComponent("thumbnails", isDirectory: true)
        self.metadataURL = dir.appendingPathComponent("metadata.json")
        self.settingsURL = dir.appendingPathComponent("settings.json")

        imageCache.countLimit = 50

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec

        var loadedSettings = AppSettings()
        if let data = try? Data(contentsOf: settingsURL),
           let s = try? dec.decode(AppSettings.self, from: data) {
            loadedSettings = s
        }

        if let initCap = initialCapacity {
            loadedSettings.capacity = max(1, initCap)
        }

        self._settings = loadedSettings
        self._capacity = loadedSettings.capacity
        LocalizationManager.shared.setLanguage(code: loadedSettings.language)

        createDirectoriesIfNeeded()
        loadFromDisk()
    }

    private func notifyChange() {
        if Thread.isMainThread {
            self.objectWillChange.send()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.objectWillChange.send()
            }
        }
    }

    private func createDirectoriesIfNeeded() {
        try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
    }

    public func addClip(item: ClipItem, imageData: Data?, thumbData: Data?) {
        lock.lock()
        defer { lock.unlock() }

        guard _settings.recordClipboardHistory else { return }

        let resolvedImageName = item.imageFileName ?? (item.contentType == .image ? "\(item.id.uuidString).png" : nil)
        let resolvedThumbName = item.thumbnailFileName ?? (item.contentType == .image ? "\(item.id.uuidString)_thumb.png" : nil)

        // Cache image data in memory immediately to guarantee synchronous read availability
        if let imgData = imageData, let imgName = resolvedImageName {
            imageCache.setObject(imgData as NSData, forKey: imgName as NSString)
        }

        // Suppress consecutive identical text clip
        if item.contentType == .text,
           let text = item.textContent {
            if let first = _items.first,
               first.contentType == .text,
               first.textContent == text {
                return
            }

            // Promote existing duplicate text clip if found elsewhere in history
            if let existingIndex = _items.firstIndex(where: { $0.contentType == .text && $0.textContent == text }) {
                var existing = _items.remove(at: existingIndex)
                existing.createdAt = Date()
                _items.insert(existing, at: 0)
                saveMetadata()
                notifyChange()
                return
            }
        }

        // Write image files to disk on background file queue
        if let imgData = imageData, let imgName = resolvedImageName {
            let url = imagesDirectory.appendingPathComponent(imgName)
            fileQueue.async {
                try? imgData.write(to: url, options: .atomic)
            }
        }
        if let thData = thumbData, let thName = resolvedThumbName {
            let url = thumbnailsDirectory.appendingPathComponent(thName)
            fileQueue.async {
                try? thData.write(to: url, options: .atomic)
            }
        }

        var itemToStore = item
        if itemToStore.contentType == .image && (itemToStore.imageFileName == nil || itemToStore.thumbnailFileName == nil) {
            itemToStore = ClipItem(
                id: item.id,
                contentType: item.contentType,
                textContent: item.textContent,
                imageFileName: resolvedImageName,
                thumbnailFileName: resolvedThumbName,
                imageWidth: item.imageWidth,
                imageHeight: item.imageHeight,
                byteSize: item.byteSize,
                createdAt: item.createdAt,
                isPinned: item.isPinned
            )
        }

        // Insert new item at index 0 (chronological descending)
        _items.insert(itemToStore, at: 0)
        enforceCapacity()
        saveMetadata()
        notifyChange()
    }

    public func togglePin(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        guard let index = _items.firstIndex(where: { $0.id == id }) else { return }
        _items[index].isPinned.toggle()
        enforceCapacity()
        saveMetadata()
        notifyChange()
    }

    public func deleteItem(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        guard let index = _items.firstIndex(where: { $0.id == id }) else { return }
        let item = _items.remove(at: index)
        cleanupFiles(for: item)
        saveMetadata()
        notifyChange()
    }

    public func clearUnpinnedHistory() {
        lock.lock()
        defer { lock.unlock() }
        let unpinned = _items.filter { !$0.isPinned }
        for item in unpinned {
            cleanupFiles(for: item)
        }
        _items.removeAll { !$0.isPinned }
        saveMetadata()
        notifyChange()
    }

    private func enforceCapacity() {
        let unpinned = _items.filter { !$0.isPinned }
        if unpinned.count > _capacity {
            let excess = unpinned.count - _capacity
            let toEvict = Array(unpinned.suffix(excess))
            let toEvictIDs = Set(toEvict.map { $0.id })
            for item in toEvict {
                cleanupFiles(for: item)
            }
            _items.removeAll { toEvictIDs.contains($0.id) }
        }
    }

    private func cleanupFiles(for item: ClipItem) {
        if let img = item.imageFileName {
            imageCache.removeObject(forKey: img as NSString)
            let url = imagesDirectory.appendingPathComponent(img)
            fileQueue.async {
                try? FileManager.default.removeItem(at: url)
            }
        }
        if let th = item.thumbnailFileName {
            let url = thumbnailsDirectory.appendingPathComponent(th)
            fileQueue.async {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    public func getThumbnailURL(for item: ClipItem) -> URL? {
        let th = item.thumbnailFileName ?? (item.contentType == .image ? "\(item.id.uuidString)_thumb.png" : nil)
        guard let thName = th else { return nil }
        return thumbnailsDirectory.appendingPathComponent(thName)
    }

    public func getImageData(for item: ClipItem) -> Data? {
        let img = item.imageFileName ?? (item.contentType == .image ? "\(item.id.uuidString).png" : nil)
        guard let imgName = img else { return nil }
        if let cached = imageCache.object(forKey: imgName as NSString) {
            return cached as Data
        }
        let url = imagesDirectory.appendingPathComponent(imgName)
        return fileQueue.sync {
            if let data = try? Data(contentsOf: url) {
                self.imageCache.setObject(data as NSData, forKey: imgName as NSString)
                return data
            }
            return nil
        }
    }

    public func flushDiskQueue() {
        fileQueue.sync {}
    }

    private func saveMetadata() {
        let snapshot = self._items
        let url = self.metadataURL
        let enc = self.encoder
        fileQueue.async {
            if let data = try? enc.encode(snapshot) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    private func saveSettings() {
        let snapshot = self._settings
        let url = self.settingsURL
        let enc = self.encoder
        fileQueue.async {
            if let data = try? enc.encode(snapshot) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: metadataURL.path),
              let data = try? Data(contentsOf: metadataURL) else {
            self._items = []
            return
        }
        if let loaded = try? decoder.decode([ClipItem].self, from: data) {
            self._items = loaded
        } else {
            // Corrupt file recovery
            self._items = []
        }
    }
}
