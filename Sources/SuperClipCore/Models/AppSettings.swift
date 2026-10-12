import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var capacity: Int
    public var hotKeyKeyCode: UInt32
    public var hotKeyModifiers: UInt32
    public var pollIntervalMs: Int
    public var maxThumbnailPixelSize: Int
    public var launchAtLogin: Bool
    public var recordClipboardHistory: Bool
    public var displayCapacity: Int
    public var language: String
    public var ignoredApps: [IgnoredApp]
    public var automaticallyCheckForUpdates: Bool
    public var lastUpdateCheckDate: Date?
    public var autoPasteOnSelection: Bool

    public static let defaultCapacity: Int = 100
    public static let defaultHotKeyKeyCode: UInt32 = 9 // kVK_ANSI_V
    public static let defaultHotKeyModifiers: UInt32 = 2048 // optionKey (0x0800)
    public static let defaultPollIntervalMs: Int = 250
    public static let defaultMaxThumbnailPixelSize: Int = 180
    public static let defaultLaunchAtLogin: Bool = false
    public static let defaultRecordClipboardHistory: Bool = true
    public static let defaultDisplayCapacity: Int = 20
    public static let defaultLanguage: String = "system"
    public static let defaultIgnoredApps: [IgnoredApp] = []
    public static let defaultAutomaticallyCheckForUpdates: Bool = true
    public static let defaultLastUpdateCheckDate: Date? = nil
    public static let defaultAutoPasteOnSelection: Bool = true

    public var historyCapacity: Int {
        get { capacity }
        set { capacity = newValue }
    }

    public var hotkeyKeyCode: UInt32 {
        get { hotKeyKeyCode }
        set { hotKeyKeyCode = newValue }
    }

    public var hotkeyModifiers: UInt32 {
        get { hotKeyModifiers }
        set { hotKeyModifiers = newValue }
    }

    public init(
        capacity: Int = AppSettings.defaultCapacity,
        hotKeyKeyCode: UInt32 = AppSettings.defaultHotKeyKeyCode,
        hotKeyModifiers: UInt32 = AppSettings.defaultHotKeyModifiers,
        pollIntervalMs: Int = AppSettings.defaultPollIntervalMs,
        maxThumbnailPixelSize: Int = AppSettings.defaultMaxThumbnailPixelSize,
        launchAtLogin: Bool = false,
        recordClipboardHistory: Bool = true,
        displayCapacity: Int = 20,
        language: String = AppSettings.defaultLanguage,
        ignoredApps: [IgnoredApp] = [],
        automaticallyCheckForUpdates: Bool = AppSettings.defaultAutomaticallyCheckForUpdates,
        lastUpdateCheckDate: Date? = AppSettings.defaultLastUpdateCheckDate,
        autoPasteOnSelection: Bool = AppSettings.defaultAutoPasteOnSelection
    ) {
        self.capacity = max(10, min(capacity, 1000))
        self.hotKeyKeyCode = hotKeyKeyCode
        self.hotKeyModifiers = hotKeyModifiers
        self.pollIntervalMs = max(50, min(pollIntervalMs, 2000))
        self.maxThumbnailPixelSize = max(60, min(maxThumbnailPixelSize, 512))
        self.launchAtLogin = launchAtLogin
        self.recordClipboardHistory = recordClipboardHistory
        self.displayCapacity = max(5, min(displayCapacity, 500))
        self.language = language
        self.ignoredApps = ignoredApps
        self.automaticallyCheckForUpdates = automaticallyCheckForUpdates
        self.lastUpdateCheckDate = lastUpdateCheckDate
        self.autoPasteOnSelection = autoPasteOnSelection
    }

    private enum CodingKeys: String, CodingKey {
        case capacity
        case hotKeyKeyCode
        case hotKeyModifiers
        case pollIntervalMs
        case maxThumbnailPixelSize
        case launchAtLogin
        case recordClipboardHistory
        case displayCapacity
        case language
        case ignoredApps
        case automaticallyCheckForUpdates
        case lastUpdateCheckDate
        case autoPasteOnSelection
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let cap = try container.decode(Int.self, forKey: .capacity)
        self.capacity = max(1, min(cap, 1000))
        self.hotKeyKeyCode = try container.decode(UInt32.self, forKey: .hotKeyKeyCode)
        self.hotKeyModifiers = try container.decode(UInt32.self, forKey: .hotKeyModifiers)
        let poll = try container.decode(Int.self, forKey: .pollIntervalMs)
        self.pollIntervalMs = max(50, min(poll, 2000))
        let thumb = try container.decode(Int.self, forKey: .maxThumbnailPixelSize)
        self.maxThumbnailPixelSize = max(60, min(thumb, 512))
        self.launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        self.recordClipboardHistory = try container.decodeIfPresent(Bool.self, forKey: .recordClipboardHistory) ?? true
        let disp = try container.decodeIfPresent(Int.self, forKey: .displayCapacity) ?? 20
        self.displayCapacity = max(5, min(disp, 500))
        self.language = try container.decodeIfPresent(String.self, forKey: .language) ?? AppSettings.defaultLanguage
        self.ignoredApps = try container.decodeIfPresent([IgnoredApp].self, forKey: .ignoredApps) ?? []
        self.automaticallyCheckForUpdates = try container.decodeIfPresent(Bool.self, forKey: .automaticallyCheckForUpdates) ?? true
        self.lastUpdateCheckDate = try container.decodeIfPresent(Date.self, forKey: .lastUpdateCheckDate)
        self.autoPasteOnSelection = try container.decodeIfPresent(Bool.self, forKey: .autoPasteOnSelection) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(capacity, forKey: .capacity)
        try container.encode(hotKeyKeyCode, forKey: .hotKeyKeyCode)
        try container.encode(hotKeyModifiers, forKey: .hotKeyModifiers)
        try container.encode(pollIntervalMs, forKey: .pollIntervalMs)
        try container.encode(maxThumbnailPixelSize, forKey: .maxThumbnailPixelSize)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(recordClipboardHistory, forKey: .recordClipboardHistory)
        try container.encode(displayCapacity, forKey: .displayCapacity)
        try container.encode(language, forKey: .language)
        try container.encode(ignoredApps, forKey: .ignoredApps)
        try container.encode(automaticallyCheckForUpdates, forKey: .automaticallyCheckForUpdates)
        try container.encodeIfPresent(lastUpdateCheckDate, forKey: .lastUpdateCheckDate)
        try container.encode(autoPasteOnSelection, forKey: .autoPasteOnSelection)
    }
}
