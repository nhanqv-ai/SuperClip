import Foundation
import AppKit
import SuperClipCore

@main
struct VerificationRunner {
    static func main() {
        print("\u{001B}[1;36m==================================================\u{001B}[0m")
        print("\u{001B}[1;36m  SuperClip Automated Verification Runner (R5)    \u{001B}[0m")
        print("\u{001B}[1;36m  Isolated Sandbox Mode (0 Emojis Invariant)     \u{001B}[0m")
        print("\u{001B}[1;36m==================================================\u{001B}[0m")
        
        let sandboxURL = TestHarness.createSandbox()
        print("Sandbox provisioned at: \(sandboxURL.path)")
        
        defer {
            TestHarness.cleanupSandbox(sandboxURL)
            print("Sandbox purged safely. Real ~/Library untouched.")
        }
        
        let startTimestamp = Date()
        
        // 1. Storage Tests
        StorageTests.run(sandboxDir: sandboxURL.appendingPathComponent("StorageTest"))
        
        // 2. Search Engine & Filtering Tests
        SearchFilterTests.run()
        
        // 3. Thumbnail Generator Tests
        ThumbnailTests.run(sandboxDir: sandboxURL.appendingPathComponent("ThumbTest"))
        
        // 4. Pin Retention & Capacity Tests
        PinRetentionTests.run(sandboxDir: sandboxURL.appendingPathComponent("PinTest"))
        
        // 5. Window Clamping & Coordinate Calculation Tests
        WindowClampingTests.run()
        
        // 6. FloatingClipPanel Presentation & Dismissal Tests
        FloatingClipPanelTests.run()
        
        // 7. StatusItemManager Dual Presentation & HotKey Tests
        StatusItemManagerTests.run()
        
        // 8. Tier 2: Boundary & Corner Tests
        BoundaryTests.run(sandboxDir: sandboxURL.appendingPathComponent("BoundaryTest"))
        
        // 7. Tier 3: Pairwise Combinations Tests
        PairwiseTests.run(sandboxDir: sandboxURL.appendingPathComponent("PairwiseTest"))
        
        // 8. Tier 4: Real-World Workload Scenarios
        WorkloadTests.run(sandboxDir: sandboxURL.appendingPathComponent("WorkloadTest"))
        
        // 9. Zero-Accessibility Pasteboard Copy Verification
        testZeroAccessibilityPasteboardCopy(sandboxDir: sandboxURL.appendingPathComponent("PasteboardTest"))

        // 10. Number Shortcuts 1..9 Tests
        Shortcut1to9Tests.run()

        // 11. Copy-Only Writeback & Loop Suppression Tests
        CopyWritebackTests.run(sandboxDir: sandboxURL.appendingPathComponent("CopyWritebackTest"))

        // 12. SearchBarView Component Tests
        SearchBarViewTests.run()

        // 13. ClipListView Partitioning Tests
        ClipListViewTests.run(sandboxDir: sandboxURL.appendingPathComponent("ClipListTest"))

        // 14. ClipRowView Presentation & Badge Tests
        ClipRowViewTests.run(sandboxDir: sandboxURL.appendingPathComponent("ClipRowTest"))

        // 15. MainClipView Root Container Integration Tests
        MainClipViewTests.run(sandboxDir: sandboxURL.appendingPathComponent("MainClipTest"))

        // 16. SwiftUI Interface & Navigation Tests (Milestone M3)
        SwiftUIInterfaceTests.run(sandboxDir: sandboxURL.appendingPathComponent("SwiftUIInterfaceTest"))

        // 17. Settings, Capacity Management & App Lifecycle Tests (Milestone M4)
        SettingsTests.run(sandboxDir: sandboxURL.appendingPathComponent("SettingsTest"))

        // 18. SettingsView UI & Model Bindings Tests (Features 29 & 30)
        SettingsViewTests.run(sandboxDir: sandboxURL.appendingPathComponent("SettingsViewTest"))

        // 19. AppSettings Model & Persistence Tests
        AppSettingsTests.run(sandboxDir: sandboxURL.appendingPathComponent("AppSettingsTest"))

        // 20. Localization & Dynamic Multilingual Tests
        LocalizationTests.run(sandboxDir: sandboxURL.appendingPathComponent("LocalizationTest"))

        // 21. Ignored Apps & Launch at Login Tests
        IgnoredAppsTests.run(sandboxDir: sandboxURL.appendingPathComponent("IgnoredAppsTest"))

        let elapsed = Date().timeIntervalSince(startTimestamp)
        print("\nVerification completed in \(String(format: "%.3f", elapsed)) seconds.")
        
        TestHarness.printSummary()
        
        if TestHarness.shared.failedTests > 0 {
            exit(1)
        } else {
            exit(0)
        }
    }
    
    static func testZeroAccessibilityPasteboardCopy(sandboxDir: URL) {
        TestHarness.startSuite("Zero-Accessibility Pasteboard Copy & Monitor")
        
        let testString = "SuperClip_Verified_Copy_\(UUID().uuidString)"
        let pb = NSPasteboard.general
        pb.clearContents()
        let writeSuccess = pb.setString(testString, forType: .string)
        TestHarness.assertTrue(writeSuccess, "NSPasteboard accepts string write without AX permissions")
        
        let readString = pb.string(forType: .string)
        TestHarness.assertEqual(readString, testString, "NSPasteboard returns exact written string")
    }
}
