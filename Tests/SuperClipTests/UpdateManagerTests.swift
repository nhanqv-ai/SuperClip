import Foundation
import AppKit
import SuperClipCore

/// Comprehensive unit test suite for UpdateManager, semantic versioning,
/// GitHub release parsing, safe staging, and UI banner / badging state transitions.
public struct UpdateManagerTests {
    public static func run(sandboxDir: URL) {
        TestHarness.startSuite("UpdateManager & Auto-Updater Verification")

        // =========================================================================
        // 1. Semantic Version Parser & Comparator Tests
        // =========================================================================
        TestHarness.assertTrue(
            UpdateManager.isVersion("1.0.1", greaterThan: "1.0.0"),
            "1.0.1 is greater than 1.0.0"
        )
        TestHarness.assertTrue(
            UpdateManager.isVersion("v1.1.0", greaterThan: "1.0.9"),
            "v1.1.0 is greater than 1.0.9"
        )
        TestHarness.assertFalse(
            UpdateManager.isVersion("1.0.0", greaterThan: "1.0.0"),
            "Equal versions 1.0.0 and 1.0.0 return false"
        )
        TestHarness.assertFalse(
            UpdateManager.isVersion("v1.0.0", greaterThan: "1.0.0"),
            "Equal versions v1.0.0 and 1.0.0 return false"
        )
        TestHarness.assertFalse(
            UpdateManager.isVersion("1.0.0", greaterThan: "1.0.1"),
            "Older version 1.0.0 is not greater than 1.0.1"
        )
        TestHarness.assertTrue(
            UpdateManager.isVersion("2.0.0", greaterThan: "1.99.99"),
            "Major increment 2.0.0 is greater than 1.99.99"
        )
        TestHarness.assertTrue(
            UpdateManager.isVersion("v1.2.0", greaterThan: "v1.1.9"),
            "Minor increment v1.2.0 is greater than v1.1.9"
        )
        TestHarness.assertTrue(
            UpdateManager.isVersion("1.0.1-beta.2", greaterThan: "1.0.1-beta.1"),
            "Prerelease beta.2 is greater than beta.1"
        )
        TestHarness.assertTrue(
            UpdateManager.isVersion("1.0.1", greaterThan: "1.0.1-beta"),
            "Full release 1.0.1 is greater than 1.0.1-beta"
        )
        TestHarness.assertTrue(
            UpdateManager.isVersion("  1.0.5  ", greaterThan: "1.0.4"),
            "Trims surrounding whitespace in version string"
        )
        TestHarness.assertFalse(
            UpdateManager.isVersion("0.9.9", greaterThan: "1.0.0"),
            "0.9.9 is not greater than 1.0.0"
        )
        TestHarness.assertTrue(
            UpdateManager.isVersion("1.0.1+build.1", greaterThan: "1.0.0"),
            "1.0.1+build.1 is greater than 1.0.0 ignoring build metadata"
        )
        TestHarness.assertEqual(
            SemanticVersion("v1.0.0"),
            SemanticVersion("1.0.0"),
            "v1.0.0 is equal to 1.0.0 per SemVer equivalence"
        )
        TestHarness.assertEqual(
            SemanticVersion("1.0.0+20261011"),
            SemanticVersion("1.0.0"),
            "1.0.0 with build metadata equals 1.0.0"
        )
        TestHarness.assertEqual(
            SemanticVersion("1.0.0-beta.1+exp"),
            SemanticVersion("1.0.0-beta.1"),
            "1.0.0-beta.1 with build metadata equals 1.0.0-beta.1"
        )

        // =========================================================================
        // 2. GitHub Releases JSON Parsing with Mock Payloads
        // =========================================================================
        let mockValidJSON = """
        {
            "tag_name": "v1.0.1",
            "name": "SuperClip 1.0.1 Release",
            "body": "Fixed clipboard sync and improved performance.",
            "html_url": "https://github.com/nhanqv-ai/SuperClip/releases/tag/v1.0.1",
            "assets": [
                {
                    "name": "SuperClip-v1.0.1.zip",
                    "browser_download_url": "https://github.com/nhanqv-ai/SuperClip/releases/download/v1.0.1/SuperClip-v1.0.1.zip"
                },
                {
                    "name": "source.tar.gz",
                    "browser_download_url": "https://github.com/nhanqv-ai/SuperClip/archive/v1.0.1.tar.gz"
                }
            ]
        }
        """.data(using: .utf8)!

        do {
            let release = try UpdateManager.parseRelease(from: mockValidJSON)
            TestHarness.assertEqual(release.tagName, "v1.0.1", "Parsed tag_name matches v1.0.1")
            TestHarness.assertEqual(release.versionString, "1.0.1", "versionString strips leading v")
            TestHarness.assertEqual(release.name, "SuperClip 1.0.1 Release", "Parsed release name matches")
            TestHarness.assertEqual(release.releaseNotes, "Fixed clipboard sync and improved performance.", "Parsed release notes match")
            TestHarness.assertEqual(
                release.htmlURL.absoluteString,
                "https://github.com/nhanqv-ai/SuperClip/releases/tag/v1.0.1",
                "Parsed html_url matches"
            )
            TestHarness.assertNotNil(release.zipAssetURL, "Discovered zip asset URL")
            TestHarness.assertEqual(
                release.zipAssetURL?.absoluteString,
                "https://github.com/nhanqv-ai/SuperClip/releases/download/v1.0.1/SuperClip-v1.0.1.zip",
                "Selected SuperClip-v1.0.1.zip browser_download_url"
            )
        } catch {
            TestHarness.assertTrue(false, "Failed to parse valid GitHub release JSON: \(error)")
        }

        // Release with no assets
        let mockNoAssetJSON = """
        {
            "tag_name": "v1.0.2",
            "name": "SuperClip 1.0.2",
            "body": "No assets attached.",
            "html_url": "https://github.com/nhanqv-ai/SuperClip/releases/tag/v1.0.2",
            "assets": []
        }
        """.data(using: .utf8)!

        do {
            let release = try UpdateManager.parseRelease(from: mockNoAssetJSON)
            TestHarness.assertEqual(release.tagName, "v1.0.2", "Parsed tag_name without assets")
            TestHarness.assertNil(release.zipAssetURL, "zipAssetURL is nil when assets array is empty")
        } catch {
            TestHarness.assertTrue(false, "Failed to parse release without assets: \(error)")
        }

        // Malformed JSON handling
        let malformedJSON = "{ invalid_json }".data(using: .utf8)!
        var threwOnMalformed = false
        do {
            _ = try UpdateManager.parseRelease(from: malformedJSON)
        } catch {
            threwOnMalformed = true
        }
        TestHarness.assertTrue(threwOnMalformed, "Throws error on malformed release JSON")

        // =========================================================================
        // 3. UpdateManager Instance States & Session Dismissal
        // =========================================================================
        let updateMgr = UpdateManager()
        updateMgr.currentVersion = "1.0.0"

        TestHarness.assertEqual(updateMgr.status, .idle, "Initial status is .idle")
        TestHarness.assertFalse(updateMgr.hasPendingUpdate, "Initially hasPendingUpdate is false")
        TestHarness.assertFalse(updateMgr.shouldShowBanner, "Initially shouldShowBanner is false")
        TestHarness.assertFalse(updateMgr.isBannerDismissedForSession, "Initially isBannerDismissedForSession is false")

        let fakeRelease = ReleaseInfo(
            tagName: "v1.0.1",
            name: "SuperClip v1.0.1",
            releaseNotes: "Minor update",
            htmlURL: URL(string: "https://github.com/nhanqv-ai/SuperClip")!,
            zipAssetURL: URL(string: "https://github.com/nhanqv-ai/SuperClip/SuperClip-v1.0.1.zip")
        )

        updateMgr.status = .updateAvailable(fakeRelease)
        updateMgr.hasPendingUpdate = true

        TestHarness.assertTrue(updateMgr.shouldShowBanner, "shouldShowBanner is true when updateAvailable")
        TestHarness.assertTrue(updateMgr.hasPendingUpdate, "hasPendingUpdate is true when updateAvailable")

        // Click "Later" -> dismisses banner for session but keeps badge
        updateMgr.dismissBannerForSession()
        TestHarness.assertTrue(updateMgr.isBannerDismissedForSession, "isBannerDismissedForSession is true after Later")
        TestHarness.assertFalse(updateMgr.shouldShowBanner, "shouldShowBanner is false after Later")
        TestHarness.assertTrue(updateMgr.hasPendingUpdate, "hasPendingUpdate remains true so settings badge dot stays visible")

        // Transition to readyToRestart resets banner visibility
        updateMgr.status = .readyToRestart(fakeRelease)
        updateMgr.isBannerDismissedForSession = false
        TestHarness.assertTrue(updateMgr.shouldShowBanner, "shouldShowBanner is true when readyToRestart")

        // =========================================================================
        // 4. Background Startup Check Scheduling Logic
        // =========================================================================
        let storage = StorageManager(baseDirectory: sandboxDir.appendingPathComponent("UpdateStorageTest"))

        // When automaticallyCheckForUpdates is false, no check is triggered
        var sDisabled = storage.settings
        sDisabled.automaticallyCheckForUpdates = false
        storage.settings = sDisabled

        let dummySession = URLSession(configuration: .ephemeral)
        let checkMgr = UpdateManager(session: dummySession)
        checkMgr.apiURL = URL(string: "https://127.0.0.1:9/invalid")!
        checkMgr.checkOnStartupIfNeeded(storageManager: storage)
        TestHarness.assertEqual(checkMgr.status, .idle, "Startup check skipped when automaticallyCheckForUpdates is false")

        // When automaticallyCheckForUpdates is true but checked recently (< 24h)
        var sRecent = storage.settings
        sRecent.automaticallyCheckForUpdates = true
        sRecent.lastUpdateCheckDate = Date().addingTimeInterval(-3600) // 1 hour ago
        storage.settings = sRecent

        checkMgr.checkOnStartupIfNeeded(storageManager: storage)
        TestHarness.assertEqual(checkMgr.status, .idle, "Startup check skipped when checked within 24 hours")

        // =========================================================================
        // 5. Silent Archive Unpack, Integrity Verification & Atomic Staging
        // =========================================================================
        let stagingDir = sandboxDir.appendingPathComponent("StagingTest")
        try? FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)

        let mockAppDir = stagingDir.appendingPathComponent("MockSourceApp.app")
        let macosDir = mockAppDir.appendingPathComponent("Contents/MacOS")
        try? FileManager.default.createDirectory(at: macosDir, withIntermediateDirectories: true)

        let mockBinary = macosDir.appendingPathComponent("SuperClip")
        let shellScript = "#!/bin/sh\nexit 0\n"
        try? shellScript.write(to: mockBinary, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: mockBinary.path)

        let mockPlist = mockAppDir.appendingPathComponent("Contents/Info.plist")
        let plistData = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<plist version=\"1.0\"><dict><key>CFBundleExecutable</key><string>SuperClip</string></dict></plist>"
        try? plistData.write(to: mockPlist, atomically: true, encoding: .utf8)

        // Create zip archive containing MockSourceApp.app
        let zipURL = stagingDir.appendingPathComponent("MockUpdate.zip")
        let zipProcess = Process()
        zipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        zipProcess.arguments = ["-c", "-k", "--keepParent", mockAppDir.path, zipURL.path]
        try? zipProcess.run()
        zipProcess.waitUntilExit()

        TestHarness.assertTrue(FileManager.default.fileExists(atPath: zipURL.path), "Mock update zip successfully created")

        // Unpack, verify, and stage to target location
        let targetAppLocation = stagingDir.appendingPathComponent("Destination/SuperClip.app")
        let stageMgr = UpdateManager()
        stageMgr.verifyCodeSignature = false // Skip signature for mock shell script test binary

        do {
            let stagedURL = try stageMgr.unpackAndVerify(zipURL: zipURL, destinationURL: targetAppLocation)
            TestHarness.assertTrue(
                FileManager.default.fileExists(atPath: stagedURL.path),
                "Application bundle safely staged into destination"
            )
            let binaryPath = stagedURL.appendingPathComponent("Contents/MacOS/SuperClip").path
            TestHarness.assertTrue(
                FileManager.default.isExecutableFile(atPath: binaryPath),
                "Staged application executable is present and executable"
            )
        } catch {
            TestHarness.assertTrue(false, "Unpack and staging threw unexpected error: \(error)")
        }

        // Test restart trigger invokes appLauncher and terminationHandler
        var launcherTarget: URL? = nil
        var terminationCalled = false
        stageMgr.stagedAppURL = targetAppLocation
        stageMgr.appLauncher = { target in launcherTarget = target }
        stageMgr.terminationHandler = { terminationCalled = true }
        stageMgr.restartApp()

        TestHarness.assertEqual(launcherTarget?.path, targetAppLocation.path, "appLauncher called with staged app destination")
        TestHarness.assertTrue(terminationCalled, "terminationHandler called cleanly on restart")

        // =========================================================================
        // 6. StatusItemManager "Check for Updates..." Context Menu Item
        // =========================================================================
        let dummyVC = NSViewController()
        let statusManager = StatusItemManager(contentViewController: dummyVC)
        statusManager.addCheckForUpdatesMenuItem()
        let menuItems = statusManager.contextMenu.items
        let directUpdateItem = menuItems.first { $0.title == "Check for Updates..." }
        TestHarness.assertNotNil(directUpdateItem, "Context menu contains 'Check for Updates...' item after addCheckForUpdatesMenuItem")
        TestHarness.assertEqual(directUpdateItem?.action, #selector(StatusItemManager.checkUpdatesMenuItemClicked(_:)), "Context menu item action matches checkUpdatesMenuItemClicked")

        // Idempotence test
        statusManager.addCheckForUpdatesMenuItem()
        let duplicateCount = statusManager.contextMenu.items.filter { $0.title == "Check for Updates..." }.count
        TestHarness.assertEqual(duplicateCount, 1, "addCheckForUpdatesMenuItem is idempotent and creates no duplicates")

        var updateCallbackInvoked = false
        statusManager.onCheckForUpdatesRequested = {
            updateCallbackInvoked = true
        }
        statusManager.checkUpdatesMenuItemClicked(nil)
        TestHarness.assertTrue(updateCallbackInvoked, "Invoking checkUpdatesMenuItemClicked fires onCheckForUpdatesRequested")

        // =========================================================================
        // 7. Missing Executable Integrity Check Rejection
        // =========================================================================
        let corruptAppDir = stagingDir.appendingPathComponent("CorruptApp.app")
        let corruptContents = corruptAppDir.appendingPathComponent("Contents/MacOS")
        try? FileManager.default.createDirectory(at: corruptContents, withIntermediateDirectories: true)
        // Note: Missing SuperClip executable

        let corruptZip = stagingDir.appendingPathComponent("Corrupt.zip")
        let corruptDitto = Process()
        corruptDitto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        corruptDitto.arguments = ["-c", "-k", "--keepParent", corruptAppDir.path, corruptZip.path]
        try? corruptDitto.run()
        corruptDitto.waitUntilExit()

        var caughtCorrupt = false
        do {
            _ = try stageMgr.unpackAndVerify(
                zipURL: corruptZip,
                destinationURL: stagingDir.appendingPathComponent("CorruptDest/SuperClip.app")
            )
        } catch UpdateError.binaryNotExecutable {
            caughtCorrupt = true
        } catch {
            // Other error
        }
        TestHarness.assertTrue(caughtCorrupt, "Unpack and verify cleanly rejects corrupt bundle missing executable")

        // =========================================================================
        // 8. Nested App Bundle Discovery in Subfolder
        // =========================================================================
        let nestedTopDir = stagingDir.appendingPathComponent("NestedSubfolder/SuperClip-v1.0.1")
        let nestedAppDir = nestedTopDir.appendingPathComponent("SuperClip.app")
        let nestedMacosDir = nestedAppDir.appendingPathComponent("Contents/MacOS")
        try? FileManager.default.createDirectory(at: nestedMacosDir, withIntermediateDirectories: true)

        let nestedBinary = nestedMacosDir.appendingPathComponent("SuperClip")
        try? shellScript.write(to: nestedBinary, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: nestedBinary.path)

        let nestedZip = stagingDir.appendingPathComponent("NestedUpdate.zip")
        let nestedDitto = Process()
        nestedDitto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        nestedDitto.arguments = ["-c", "-k", "--keepParent", nestedTopDir.path, nestedZip.path]
        try? nestedDitto.run()
        nestedDitto.waitUntilExit()

        let nestedDest = stagingDir.appendingPathComponent("NestedDest/SuperClip.app")
        do {
            let nestedStagedURL = try stageMgr.unpackAndVerify(zipURL: nestedZip, destinationURL: nestedDest)
            TestHarness.assertTrue(FileManager.default.fileExists(atPath: nestedStagedURL.path), "Nested application bundle safely staged into destination")
        } catch {
            TestHarness.assertTrue(false, "Unpack and staging for nested archive failed: \(error)")
        }

        // =========================================================================
        // 9. Error Descriptions & HTTP Error Cases
        // =========================================================================
        TestHarness.assertEqual(UpdateError.noReleaseFound.errorDescription, "No releases found on GitHub.", "noReleaseFound description matches")
        TestHarness.assertEqual(UpdateError.rateLimitExceeded.errorDescription, "GitHub API rate limit exceeded. Please try again later.", "rateLimitExceeded description matches")
        TestHarness.assertEqual(UpdateError.httpError(404).errorDescription, "GitHub API returned HTTP status 404.", "httpError description matches")

        // =========================================================================
        // 10. Extended Semantic Versioning & Component Length Invariants
        // =========================================================================
        TestHarness.assertTrue(UpdateManager.isVersion("2.1", greaterThan: "2.0.9"), "2.1 is greater than 2.0.9")
        TestHarness.assertTrue(UpdateManager.isVersion("1.0.0.1", greaterThan: "1.0.0"), "1.0.0.1 is greater than 1.0.0")
        TestHarness.assertFalse(UpdateManager.isVersion("1.0.0", greaterThan: "1.0"), "1.0.0 is not greater than 1.0")
        TestHarness.assertEqual(SemanticVersion("1.0.0"), SemanticVersion("1.0"), "1.0.0 equals 1.0 with zero component padding")

        // =========================================================================
        // 11. isBusy State & Active Download Guard
        // =========================================================================
        let busyMgr = UpdateManager()
        busyMgr.status = .idle
        TestHarness.assertFalse(busyMgr.isBusy, "isBusy is false when status is idle")
        busyMgr.status = .checking
        TestHarness.assertTrue(busyMgr.isBusy, "isBusy is true when status is checking")
        busyMgr.status = .downloading(progress: 0.5)
        TestHarness.assertTrue(busyMgr.isBusy, "isBusy is true when status is downloading")
        busyMgr.status = .readyToRestart(fakeRelease)
        TestHarness.assertFalse(busyMgr.isBusy, "isBusy is false when status is readyToRestart")

        // Active download prevents duplicate check
        busyMgr.status = .downloading(progress: 0.5)
        busyMgr.latestRelease = fakeRelease
        var returnedRelease: ReleaseInfo? = nil
        busyMgr.checkForUpdates { result in
            if case .success(let rel) = result {
                returnedRelease = rel
            }
        }
        TestHarness.assertEqual(returnedRelease, fakeRelease, "checkForUpdates during download returns existing release without clobbering")
        TestHarness.assertEqual(busyMgr.status, .downloading(progress: 0.5), "status remains downloading during concurrent check request")

        // =========================================================================
        // 12. Empty & Malformed Release URL Fallback (No Crash)
        // =========================================================================
        let emptyURLJSON = """
        {
            "tag_name": "v1.0.3",
            "name": "SuperClip 1.0.3",
            "body": "Empty html url test",
            "html_url": "",
            "assets": []
        }
        """.data(using: .utf8)!
        do {
            let parsedEmpty = try UpdateManager.parseRelease(from: emptyURLJSON)
            TestHarness.assertEqual(
                parsedEmpty.htmlURL.absoluteString,
                "https://github.com/nhanqv-ai/SuperClip/releases",
                "Empty html_url safely falls back to default repository releases URL"
            )
        } catch {
            TestHarness.assertTrue(false, "parseRelease threw on empty html_url: \(error)")
        }

        // =========================================================================
        // 13. Preservation of readyToRestart State Against Background Checks
        // =========================================================================
        let restartMgr = UpdateManager()
        restartMgr.currentVersion = "1.0.0"
        restartMgr.status = .readyToRestart(fakeRelease)
        restartMgr.latestRelease = fakeRelease

        var backgroundResult: ReleaseInfo? = nil
        restartMgr.checkForUpdates(userInitiated: false) { result in
            if case .success(let rel) = result {
                backgroundResult = rel
            }
        }
        TestHarness.assertEqual(backgroundResult, fakeRelease, "Background check preserves readyToRestart release")
        TestHarness.assertEqual(restartMgr.status, .readyToRestart(fakeRelease), "Status remains readyToRestart across background check")

        // =========================================================================
        // 14. Concurrent Check Deduplication While Checking
        // =========================================================================
        let dedupMgr = UpdateManager()
        dedupMgr.status = .checking
        dedupMgr.latestRelease = fakeRelease
        var dedupRelease: ReleaseInfo? = nil
        dedupMgr.checkForUpdates(userInitiated: true) { result in
            if case .success(let rel) = result {
                dedupRelease = rel
            }
        }
        TestHarness.assertEqual(dedupRelease, fakeRelease, "Concurrent check returns existing release without starting second task")
        TestHarness.assertEqual(dedupMgr.status, .checking, "Status remains checking during concurrent check call")

        // =========================================================================
        // 15. Notification Safety Outside App Bundle
        // =========================================================================
        // When running in headless/CLI test process where Bundle.main.bundleIdentifier is nil,
        // calling postUpdateNotification and postUpToDateNotification must not crash with NSInternalInconsistencyException
        restartMgr.postUpdateNotification(release: fakeRelease)
        restartMgr.postUpToDateNotification(currentVersion: "1.0.0")
        TestHarness.assertTrue(true, "postUpdateNotification and postUpToDateNotification executed safely without crash")

        // =========================================================================
        // 16. Dismiss Banner For Session in readyToRestart State
        // =========================================================================
        let dismissMgr = UpdateManager()
        dismissMgr.status = .readyToRestart(fakeRelease)
        dismissMgr.hasPendingUpdate = true
        TestHarness.assertTrue(dismissMgr.shouldShowBanner, "shouldShowBanner is true initially in readyToRestart")
        dismissMgr.dismissBannerForSession()
        TestHarness.assertFalse(dismissMgr.shouldShowBanner, "shouldShowBanner is false after dismissBannerForSession in readyToRestart")
        TestHarness.assertTrue(dismissMgr.hasPendingUpdate, "hasPendingUpdate remains true after dismissing banner")

        // =========================================================================
        // 17. Download Failure Cache Cleanup
        // =========================================================================
        let failMgr = UpdateManager()
        let nonExistentRelease = ReleaseInfo(
            tagName: "v9.9.9",
            name: "SuperClip v9.9.9",
            releaseNotes: "Failing test",
            htmlURL: URL(string: "https://github.com/nhanqv-ai/SuperClip")!,
            zipAssetURL: sandboxDir.appendingPathComponent("NonExistentUpdateFile_\(UUID().uuidString).zip")
        )

        var downloadFailed = false
        failMgr.startDownloadAndInstall(release: nonExistentRelease) { result in
            if case .failure = result {
                downloadFailed = true
            }
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        TestHarness.assertTrue(downloadFailed, "startDownloadAndInstall fails cleanly for non-existent local file")
        if case .error = failMgr.status {
            TestHarness.assertTrue(true, "failMgr status transitioned to error on failed download")
        } else {
            TestHarness.assertTrue(false, "Expected error status on failed download, got: \(failMgr.status)")
        }
    }
}
