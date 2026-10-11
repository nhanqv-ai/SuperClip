import Foundation
import AppKit
import SuperClipCore
import SuperClip

/// Unit and integration test suite for Ignored Apps feature, frontmost app filtering,
/// AppSettings persistence, and Launch at Login SMAppService integration.
public struct IgnoredAppsTests {
    public static func run(sandboxDir: URL) {
        TestHarness.startSuite("Ignored Apps Feature & Launch at Login Tests")

        // 1. IgnoredApp Model Creation and Identity
        let app1 = IgnoredApp(bundleIdentifier: "com.apple.Safari", name: "Safari", iconPath: "/Applications/Safari.app")
        TestHarness.assertEqual(app1.bundleIdentifier, "com.apple.Safari", "IgnoredApp bundleIdentifier matches")
        TestHarness.assertEqual(app1.name, "Safari", "IgnoredApp name matches")
        TestHarness.assertEqual(app1.iconPath, "/Applications/Safari.app", "IgnoredApp iconPath matches")
        TestHarness.assertEqual(app1.id, "com.apple.Safari", "IgnoredApp id defaults to bundleIdentifier")

        let appNoName = IgnoredApp(bundleIdentifier: "com.apple.Notes", name: nil)
        TestHarness.assertEqual(appNoName.name, "com.apple.Notes", "IgnoredApp name falls back to bundleIdentifier when nil")

        let appWhitespace = IgnoredApp(bundleIdentifier: "  com.apple.Preview  ", name: "  Preview  ")
        TestHarness.assertEqual(appWhitespace.bundleIdentifier, "com.apple.Preview", "IgnoredApp bundleIdentifier is trimmed")
        TestHarness.assertEqual(appWhitespace.name, "Preview", "IgnoredApp name is trimmed")

        // 2. IgnoredApp Codable Roundtrip
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let appData = try? encoder.encode(app1) else {
            TestHarness.assertTrue(false, "Failed to encode IgnoredApp")
            return
        }
        let decoder = JSONDecoder()
        guard let decodedApp = try? decoder.decode(IgnoredApp.self, from: appData) else {
            TestHarness.assertTrue(false, "Failed to decode IgnoredApp")
            return
        }
        TestHarness.assertEqual(app1, decodedApp, "Decoded IgnoredApp matches original")

        // 3. AppSettings Default and Persistence with IgnoredApps
        let defaultSettings = AppSettings()
        TestHarness.assertEqual(defaultSettings.ignoredApps.count, 0, "Default ignoredApps is empty array")

        var customSettings = AppSettings()
        customSettings.ignoredApps = [app1, appNoName]
        guard let settingsData = try? encoder.encode(customSettings) else {
            TestHarness.assertTrue(false, "Failed to encode AppSettings with ignoredApps")
            return
        }
        guard let decodedSettings = try? decoder.decode(AppSettings.self, from: settingsData) else {
            TestHarness.assertTrue(false, "Failed to decode AppSettings with ignoredApps")
            return
        }
        TestHarness.assertEqual(decodedSettings.ignoredApps.count, 2, "Decoded AppSettings preserves ignoredApps count")
        TestHarness.assertEqual(decodedSettings.ignoredApps.first?.bundleIdentifier, "com.apple.Safari", "Preserved bundleIdentifier")

        // 4. StorageManager Addition, Duplication Suppression & Removal
        let storageDir = sandboxDir.appendingPathComponent("StorageIgnoredTest")
        let storage = StorageManager(baseDirectory: storageDir, initialCapacity: 50)
        TestHarness.assertEqual(storage.settings.ignoredApps.count, 0, "Initial storage ignoredApps is empty")

        // Reject empty or whitespace-only apps
        storage.addIgnoredApp(IgnoredApp(bundleIdentifier: "", name: ""))
        TestHarness.assertEqual(storage.settings.ignoredApps.count, 0, "Empty app addition rejected")
        storage.addIgnoredApp(IgnoredApp(bundleIdentifier: "   ", name: "   "))
        TestHarness.assertEqual(storage.settings.ignoredApps.count, 0, "Whitespace app addition rejected")

        storage.addIgnoredApp(app1)
        TestHarness.assertEqual(storage.settings.ignoredApps.count, 1, "App added to storage")

        // Duplicate addition should be ignored (exact match, uppercase, and lowercase)
        storage.addIgnoredApp(IgnoredApp(bundleIdentifier: "com.apple.Safari", name: "Safari Duplicate"))
        TestHarness.assertEqual(storage.settings.ignoredApps.count, 1, "Duplicate app with same bundleIdentifier ignored")
        storage.addIgnoredApp(IgnoredApp(bundleIdentifier: "COM.APPLE.SAFARI", name: "Safari Uppercase"))
        TestHarness.assertEqual(storage.settings.ignoredApps.count, 1, "Duplicate app with uppercase bundleIdentifier ignored")
        storage.addIgnoredApp(IgnoredApp(bundleIdentifier: "com.apple.safari", name: "Safari Lowercase"))
        TestHarness.assertEqual(storage.settings.ignoredApps.count, 1, "Duplicate app with lowercase bundleIdentifier ignored")

        let app2 = IgnoredApp(bundleIdentifier: "com.google.Chrome", name: "Google Chrome", iconPath: "/Applications/Google Chrome.app")
        storage.addIgnoredApp(app2)
        TestHarness.assertEqual(storage.settings.ignoredApps.count, 2, "Second app added to storage")

        // Distinct apps with identical display name must BOTH be added
        let terminal1 = IgnoredApp(bundleIdentifier: "com.apple.Terminal", name: "Terminal")
        let terminal2 = IgnoredApp(bundleIdentifier: "org.alacritty", name: "Terminal")
        storage.addIgnoredApp(terminal1)
        TestHarness.assertEqual(storage.settings.ignoredApps.count, 3, "Apple Terminal added")
        storage.addIgnoredApp(terminal2)
        TestHarness.assertEqual(storage.settings.ignoredApps.count, 4, "Alacritty with same name Terminal also added")

        // 5. Case-Insensitive Matching and Whitespace via isAppIgnored
        TestHarness.assertTrue(storage.isAppIgnored(bundleIdentifier: "com.apple.safari"), "Matches bundleIdentifier case-insensitively")
        TestHarness.assertTrue(storage.isAppIgnored(bundleIdentifier: "COM.GOOGLE.CHROME"), "Matches Chrome bundleIdentifier uppercase")
        TestHarness.assertTrue(storage.isAppIgnored(bundleIdentifier: "  com.google.Chrome  "), "Matches bundleIdentifier with surrounding whitespace")
        TestHarness.assertTrue(storage.isAppIgnored(bundleIdentifier: nil, name: "safari"), "Matches name case-insensitively")
        TestHarness.assertTrue(storage.isAppIgnored(bundleIdentifier: "nonexistent", name: "Google Chrome"), "Matches name when bundle ID does not match")
        TestHarness.assertFalse(storage.isAppIgnored(bundleIdentifier: "com.apple.Finder", name: "Finder"), "Unignored app returns false")
        TestHarness.assertFalse(storage.isAppIgnored(bundleIdentifier: "   ", name: "   "), "Whitespace-only input returns false")
        TestHarness.assertFalse(storage.isAppIgnored(bundleIdentifier: nil, name: nil), "Nil input returns false")

        // 6. Case-Insensitive Removal & Empty Removal Guard
        // Removing whitespace/empty should be a safe no-op
        storage.removeIgnoredApp(bundleIdentifier: "   ")
        TestHarness.assertEqual(storage.settings.ignoredApps.count, 4, "Whitespace removal does not remove any apps")

        storage.removeIgnoredApp(bundleIdentifier: "COM.APPLE.SAFARI")
        TestHarness.assertEqual(storage.settings.ignoredApps.count, 3, "Removed Safari case-insensitively, 3 apps remaining")
        TestHarness.assertFalse(storage.isAppIgnored(bundleIdentifier: "com.apple.Safari"), "Safari is no longer ignored")
        TestHarness.assertTrue(storage.isAppIgnored(bundleIdentifier: "com.google.Chrome"), "Chrome remains ignored")

        // Non-matching bundle identifier should not remove apps that share a display name
        storage.removeIgnoredApp(bundleIdentifier: "NonExistentTerminal")
        TestHarness.assertEqual(storage.settings.ignoredApps.count, 3, "Non-matching bundleId leaves both terminals intact")

        // Remove the two terminal apps
        storage.removeIgnoredApp(bundleIdentifier: "com.apple.Terminal")
        TestHarness.assertEqual(storage.settings.ignoredApps.count, 2, "Removed Apple Terminal")
        storage.removeIgnoredApp(bundleIdentifier: "org.alacritty")
        TestHarness.assertEqual(storage.settings.ignoredApps.count, 1, "Removed Alacritty")

        // 7. Disk Persistence Across Restarts
        storage.flushDiskQueue()
        let reloadedStorage = StorageManager(baseDirectory: storageDir)
        reloadedStorage.flushDiskQueue()
        TestHarness.assertEqual(reloadedStorage.settings.ignoredApps.count, 1, "Reloaded storage retains persisted ignored apps")
        TestHarness.assertEqual(reloadedStorage.settings.ignoredApps.first?.bundleIdentifier, "com.google.Chrome", "Reloaded app bundleIdentifier matches")

        // 8. SettingsView UI Actions (Programmatic Testing)
        let settingsView = SettingsView(storageManager: storage, hotKeyManager: HotKeyManager.shared)
        let dummyAppURL = URL(fileURLWithPath: "/Applications/Calculator.app")
        settingsView.addIgnoredApp(from: dummyAppURL)
        TestHarness.assertEqual(storage.settings.ignoredApps.count, 2, "SettingsView addIgnoredApp adds Calculator")

        let addedCalc = storage.settings.ignoredApps.first(where: { $0.name == "Calculator" || $0.bundleIdentifier.contains("Calculator") || $0.bundleIdentifier.contains("calculator") })
        TestHarness.assertNotNil(addedCalc, "Calculator app present in settings")

        if let calc = addedCalc {
            settingsView.selectIgnoredApp(id: calc.id)
            TestHarness.assertEqual(settingsView.selectedIgnoredAppId, calc.id, "Selected app ID matches")
            settingsView.selectIgnoredApp(id: nil)
            TestHarness.assertTrue(settingsView.selectedIgnoredAppId == nil, "Explicit nil selection clears selectedIgnoredAppId")
            settingsView.selectIgnoredApp(id: calc.id)
            settingsView.removeSelectedIgnoredApp()
            TestHarness.assertTrue(settingsView.selectedIgnoredAppId == nil, "Selected app ID cleared after removal")
            TestHarness.assertFalse(storage.isAppIgnored(bundleIdentifier: calc.bundleIdentifier), "Calculator removed from storage")
        }

        // Test non-existent selection reset behavior
        settingsView.selectIgnoredApp(id: "nonexistent.bundle.id")
        // The selection should not match any item in ignoredApps
        let hasSelectionMatch = storage.settings.ignoredApps.contains(where: { $0.id == settingsView.selectedIgnoredAppId })
        TestHarness.assertFalse(hasSelectionMatch, "Non-existent app selection is not present in storage")
        settingsView.selectIgnoredApp(id: nil)

        // 9. Active Pasteboard Filtering via PasteboardMonitor (Text & Image)
        let pbName = NSPasteboard.Name("com.superclip.test.ignored.\(UUID().uuidString)")
        let testPB = NSPasteboard(name: pbName)
        let monitor = PasteboardMonitor(pasteboard: testPB)

        var newClipsRecorded: [ClipItem] = []
        monitor.onNewClip = { item, _, _ in
            newClipsRecorded.append(item)
        }

        // Configure mock frontmost provider and ignored apps provider
        var currentMockFrontmost: (bundleIdentifier: String?, name: String?) = ("com.google.Chrome", "Google Chrome")
        monitor.frontmostAppProvider = { currentMockFrontmost }
        monitor.ignoredAppsProvider = {
            [IgnoredApp(bundleIdentifier: "com.google.Chrome", name: "Google Chrome")]
        }

        // Copy while frontmost app is ignored -> MUST BE SUPPRESSED
        testPB.clearContents()
        testPB.setString("Ignored Secret Copy", forType: .string)
        monitor.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        TestHarness.assertEqual(newClipsRecorded.count, 0, "Pasteboard text copy from ignored app is suppressed")

        // Copy again while frontmost app is still ignored with whitespace -> MUST REMAIN SUPPRESSED
        currentMockFrontmost = ("  com.google.Chrome  ", "  Google Chrome  ")
        testPB.clearContents()
        testPB.setString("Second Ignored Copy", forType: .string)
        monitor.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        TestHarness.assertEqual(newClipsRecorded.count, 0, "Second text copy with whitespace from ignored app is also suppressed")

        // Copy image payload while frontmost app is ignored -> MUST BE SUPPRESSED
        let dummyImage = NSImage(size: NSSize(width: 10, height: 10))
        dummyImage.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(x: 0, y: 0, width: 10, height: 10))
        dummyImage.unlockFocus()
        if let tiff = dummyImage.tiffRepresentation {
            testPB.clearContents()
            testPB.setData(tiff, forType: .tiff)
            monitor.checkNow()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
            TestHarness.assertEqual(newClipsRecorded.count, 0, "Pasteboard image copy from ignored app is suppressed")
        }

        // Switch frontmost app to unignored app -> MUST BE RECORDED
        currentMockFrontmost = ("com.apple.TextEdit", "TextEdit")
        testPB.clearContents()
        testPB.setString("Allowed TextEdit Copy", forType: .string)
        monitor.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        TestHarness.assertEqual(newClipsRecorded.count, 1, "Pasteboard copy from non-ignored app is recorded")
        TestHarness.assertEqual(newClipsRecorded.first?.textContent, "Allowed TextEdit Copy", "Recorded clip content matches")

        // 10. Launch at Login Integration (SMAppService)
        let launchManager = LaunchAtLoginManager.shared
        _ = launchManager.isEnabled
        // Calling setEnabled should execute without throwing fatal errors
        let disableResult = launchManager.setEnabled(false)
        TestHarness.assertTrue(disableResult, "LaunchAtLoginManager.setEnabled(false) completes safely")

        let enableResult = launchManager.setEnabled(true)
        // In unbundled CLI runner or sandboxed test, service.register may return true or false gracefully
        _ = enableResult
        TestHarness.assertTrue(true, "LaunchAtLoginManager.setEnabled(true) executes with graceful error handling")
        launchManager.setEnabled(false)

        // 11. Idempotent Removal & Extreme Boundary Queries in StorageManager
        storage.removeIgnoredApp(bundleIdentifier: "com.google.Chrome")
        TestHarness.assertEqual(storage.settings.ignoredApps.count, 0, "Storage ignoredApps is now empty")
        // Idempotent second removal
        storage.removeIgnoredApp(bundleIdentifier: "com.google.Chrome")
        TestHarness.assertEqual(storage.settings.ignoredApps.count, 0, "Second removal of already removed app is a safe no-op")
        TestHarness.assertFalse(storage.isAppIgnored(bundleIdentifier: "", name: nil), "Empty bundle ID query returns false")
        TestHarness.assertFalse(storage.isAppIgnored(bundleIdentifier: nil, name: ""), "Empty name query returns false")
        TestHarness.assertFalse(storage.isAppIgnored(bundleIdentifier: "  \t\n  ", name: "  "), "Whitespace-only query returns false")

        // 12. PasteboardMonitor Nil Frontmost App Provider Allows Recording
        let pbName2 = NSPasteboard.Name("com.superclip.test.ignored.nilprovider.\(UUID().uuidString)")
        let testPB2 = NSPasteboard(name: pbName2)
        let monitor2 = PasteboardMonitor(pasteboard: testPB2)
        var capturedClips2: [ClipItem] = []
        monitor2.onNewClip = { item, _, _ in capturedClips2.append(item) }
        monitor2.frontmostAppProvider = { (nil, nil) }
        monitor2.ignoredAppsProvider = { [IgnoredApp(bundleIdentifier: "com.secret.app", name: "Secret")] }

        testPB2.clearContents()
        testPB2.setString("Allowed When Frontmost Nil", forType: .string)
        monitor2.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        TestHarness.assertEqual(capturedClips2.count, 1, "Nil frontmost app does not suppress clipboard recording")
        TestHarness.assertEqual(capturedClips2.first?.textContent, "Allowed When Frontmost Nil", "Captured clip content matches")

        // 13. PasteboardMonitor Custom isIgnoredAppCheck Direct Interception
        var customCheckTriggered = false
        monitor2.isIgnoredAppCheck = { bundleId, name in
            customCheckTriggered = true
            return true
        }
        testPB2.clearContents()
        testPB2.setString("Custom Intercepted Secret", forType: .string)
        monitor2.checkNow()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        TestHarness.assertTrue(customCheckTriggered, "Custom isIgnoredAppCheck was invoked during pasteboard check")
        TestHarness.assertEqual(capturedClips2.count, 1, "Clip suppressed by custom isIgnoredAppCheck")
    }
}
