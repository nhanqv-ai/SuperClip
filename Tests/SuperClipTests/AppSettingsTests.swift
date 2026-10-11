import Foundation
import SuperClipCore

/// Unit tests for AppSettings model, boundary clamping, aliases, and JSON serialization.
public struct AppSettingsTests {
    public static func run(sandboxDir: URL) {
        TestHarness.startSuite("AppSettings Model & Persistence Tests")

        // 1. Default values
        let defaults = AppSettings()
        TestHarness.assertEqual(defaults.capacity, 100, "Default capacity is 100")
        TestHarness.assertEqual(defaults.hotKeyKeyCode, 9, "Default hotKeyKeyCode is 9 (kVK_ANSI_V)")
        TestHarness.assertEqual(defaults.hotKeyModifiers, 2048, "Default hotKeyModifiers is 2048 (optionKey)")
        TestHarness.assertEqual(defaults.pollIntervalMs, 250, "Default pollIntervalMs is 250")
        TestHarness.assertEqual(defaults.maxThumbnailPixelSize, 180, "Default maxThumbnailPixelSize is 180")
        TestHarness.assertFalse(defaults.launchAtLogin, "Default launchAtLogin is false")
        TestHarness.assertEqual(defaults.language, "system", "Default language is system")
        TestHarness.assertTrue(defaults.automaticallyCheckForUpdates, "Default automaticallyCheckForUpdates is true")
        TestHarness.assertNil(defaults.lastUpdateCheckDate, "Default lastUpdateCheckDate is nil")

        // 2. Convenience aliases
        var settingsWithAliases = AppSettings()
        TestHarness.assertEqual(settingsWithAliases.historyCapacity, 100, "historyCapacity getter returns capacity")
        TestHarness.assertEqual(settingsWithAliases.hotkeyKeyCode, 9, "hotkeyKeyCode getter returns hotKeyKeyCode")
        TestHarness.assertEqual(settingsWithAliases.hotkeyModifiers, 2048, "hotkeyModifiers getter returns hotKeyModifiers")

        settingsWithAliases.historyCapacity = 200
        TestHarness.assertEqual(settingsWithAliases.capacity, 200, "historyCapacity setter updates capacity")
        settingsWithAliases.hotkeyKeyCode = 49
        TestHarness.assertEqual(settingsWithAliases.hotKeyKeyCode, 49, "hotkeyKeyCode setter updates hotKeyKeyCode")
        settingsWithAliases.hotkeyModifiers = 256
        TestHarness.assertEqual(settingsWithAliases.hotKeyModifiers, 256, "hotkeyModifiers setter updates hotKeyModifiers")

        // 3. Boundary clamping on initialization
        let lowCapacity = AppSettings(capacity: 5)
        TestHarness.assertEqual(lowCapacity.capacity, 10, "Capacity below 10 is clamped to 10")

        let highCapacity = AppSettings(capacity: 2000)
        TestHarness.assertEqual(highCapacity.capacity, 1000, "Capacity above 1000 is clamped to 1000")

        let lowPoll = AppSettings(pollIntervalMs: 10)
        TestHarness.assertEqual(lowPoll.pollIntervalMs, 50, "Poll interval below 50 is clamped to 50")

        let highPoll = AppSettings(pollIntervalMs: 5000)
        TestHarness.assertEqual(highPoll.pollIntervalMs, 2000, "Poll interval above 2000 is clamped to 2000")

        let lowThumb = AppSettings(maxThumbnailPixelSize: 20)
        TestHarness.assertEqual(lowThumb.maxThumbnailPixelSize, 60, "Thumbnail size below 60 is clamped to 60")

        let highThumb = AppSettings(maxThumbnailPixelSize: 1000)
        TestHarness.assertEqual(highThumb.maxThumbnailPixelSize, 512, "Thumbnail size above 512 is clamped to 512")

        // 4. JSON Serialization & Deserialization Round-Trip
        let original = AppSettings(
            capacity: 75,
            hotKeyKeyCode: 11,
            hotKeyModifiers: 256 | 512,
            pollIntervalMs: 300,
            maxThumbnailPixelSize: 200,
            launchAtLogin: true,
            automaticallyCheckForUpdates: false,
            lastUpdateCheckDate: Date(timeIntervalSince1970: 1700000000)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(original) else {
            TestHarness.assertTrue(false, "Failed to encode AppSettings to JSON")
            return
        }
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(AppSettings.self, from: data) else {
            TestHarness.assertTrue(false, "Failed to decode AppSettings from JSON")
            return
        }
        TestHarness.assertEqual(original, decoded, "Decoded AppSettings exactly matches original")

        // 5. Disk persistence via StorageManager
        let storage = StorageManager(baseDirectory: sandboxDir, initialCapacity: 150)
        TestHarness.assertEqual(storage.settings.capacity, 150, "StorageManager initialized with initialCapacity 150")

        var mutated = storage.settings
        mutated.hotKeyKeyCode = 49 // Space
        mutated.hotKeyModifiers = 2048 // Option
        mutated.capacity = 300
        mutated.automaticallyCheckForUpdates = false
        let checkDate = Date(timeIntervalSince1970: 1700000000)
        mutated.lastUpdateCheckDate = checkDate
        storage.settings = mutated
        storage.flushDiskQueue()

        // Reload fresh instance from same directory
        let reloadedStorage = StorageManager(baseDirectory: sandboxDir)
        reloadedStorage.flushDiskQueue()
        TestHarness.assertEqual(reloadedStorage.settings.capacity, 300, "Persisted capacity reloaded correctly from disk")
        TestHarness.assertEqual(reloadedStorage.settings.hotKeyKeyCode, 49, "Persisted hotkey keyCode reloaded correctly")
        TestHarness.assertEqual(reloadedStorage.settings.hotKeyModifiers, 2048, "Persisted hotkey modifiers reloaded correctly")
        TestHarness.assertFalse(reloadedStorage.settings.automaticallyCheckForUpdates, "Persisted automaticallyCheckForUpdates reloaded correctly")
        TestHarness.assertNotNil(reloadedStorage.settings.lastUpdateCheckDate, "Persisted lastUpdateCheckDate reloaded correctly")
    }
}
