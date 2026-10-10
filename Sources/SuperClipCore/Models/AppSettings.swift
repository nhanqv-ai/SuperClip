import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var capacity: Int
    public var hotKeyKeyCode: UInt32
    public var hotKeyModifiers: UInt32
    public var pollIntervalMs: Int
    public var maxThumbnailPixelSize: Int
    public var launchAtLogin: Bool

    public static let defaultCapacity: Int = 100
    public static let defaultHotKeyKeyCode: UInt32 = 9 // kVK_ANSI_V
    public static let defaultHotKeyModifiers: UInt32 = 2048 // optionKey (0x0800)
    public static let defaultPollIntervalMs: Int = 250
    public static let defaultMaxThumbnailPixelSize: Int = 180

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
        launchAtLogin: Bool = false
    ) {
        self.capacity = max(10, min(capacity, 1000))
        self.hotKeyKeyCode = hotKeyKeyCode
        self.hotKeyModifiers = hotKeyModifiers
        self.pollIntervalMs = max(50, min(pollIntervalMs, 2000))
        self.maxThumbnailPixelSize = max(60, min(maxThumbnailPixelSize, 512))
        self.launchAtLogin = launchAtLogin
    }
}
