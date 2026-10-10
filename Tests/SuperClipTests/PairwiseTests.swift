import Foundation
import AppKit
import SuperClipCore

public struct PairwiseTests {
    public static func run(sandboxDir: URL) {
        TestHarness.startSuite("Tier 3: Pairwise Combinations & Cross-Feature Interactions")
        
        // Pairwise 1: F02 (Text) + F08 (FIFO Eviction)
        let storage = StorageManager(baseDirectory: sandboxDir, initialCapacity: 3)
        for i in 1...5 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Pairwise Text \(i)", byteSize: 15, isPinned: false)
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }
        TestHarness.assertEqual(storage.items.count, 3, "FIFO eviction maintains capacity 3 across sequential text additions")
        TestHarness.assertEqual(storage.items.first?.textContent, "Pairwise Text 5", "Most recent text item is at index 0")
        TestHarness.assertEqual(storage.items.last?.textContent, "Pairwise Text 3", "Oldest retained text item is Pairwise Text 3")
        
        // Pairwise 2: F03 (Image) + F09 (Pin Retention)
        let pinnedImgID = UUID()
        let fakeImgData = Data(repeating: 0x7F, count: 300)
        let pinnedImg = ClipItem(id: pinnedImgID, contentType: .image, imageFileName: "\(pinnedImgID.uuidString).png", imageWidth: 400, imageHeight: 300, byteSize: 300, isPinned: true)
        storage.addClip(item: pinnedImg, imageData: fakeImgData, thumbData: nil)
        
        // Add 5 more unpinned text items
        for i in 6...10 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Overflow Text \(i)", byteSize: 15, isPinned: false)
            storage.addClip(item: item, imageData: nil, thumbData: nil)
        }
        TestHarness.assertTrue(storage.items.contains(where: { $0.id == pinnedImgID }), "Pinned image survives subsequent unpinned overflow additions")
        
        // Pairwise 3: F05 (Self-Copy Suppression) + F28 (Pasteboard Write)
        let monitor = PasteboardMonitor()
        let pb = NSPasteboard.general
        
        // External copy
        pb.clearContents()
        pb.setString("External Payload", forType: .string)
        let detectedExternal = monitor.pollTick()
        TestHarness.assertTrue(detectedExternal, "PasteboardMonitor detects external change")
        
        // Self-copy simulation
        pb.clearContents()
        pb.setString("SuperClip Self Copy Write", forType: .string)
        monitor.markSelfCopy(newChangeCount: pb.changeCount)
        let detectedSelf = monitor.pollTick()
        TestHarness.assertFalse(detectedSelf, "PasteboardMonitor suppresses internal write after markSelfCopy")
        
        // Subsequent external copy after self-copy
        pb.clearContents()
        pb.setString("Followup External Payload", forType: .string)
        let detectedFollowup = monitor.pollTick()
        TestHarness.assertTrue(detectedFollowup, "PasteboardMonitor resumes capturing external changes after suppression")
        
        // Pairwise 4: F20 (Search Filter) + F22 (Number Shortcuts Mapping)
        let sItems = [
            ClipItem(id: UUID(), contentType: .text, textContent: "Alpha Report", byteSize: 12, isPinned: false),
            ClipItem(id: UUID(), contentType: .text, textContent: "Beta Summary", byteSize: 12, isPinned: false),
            ClipItem(id: UUID(), contentType: .text, textContent: "Gamma Details", byteSize: 13, isPinned: false),
            ClipItem(id: UUID(), contentType: .text, textContent: "Alpha Analysis", byteSize: 14, isPinned: false)
        ]
        let filtered = SearchEngine.filter(items: sItems, query: "alpha")
        TestHarness.assertEqual(filtered.count, 2, "Filtered search yields 2 items")
        // Number shortcut 1 maps to filtered[0], shortcut 2 maps to filtered[1]
        let shortcut1Target = filtered.indices.contains(0) ? filtered[0] : nil
        let shortcut2Target = filtered.indices.contains(1) ? filtered[1] : nil
        let shortcut3Target = filtered.indices.contains(2) ? filtered[2] : nil
        TestHarness.assertEqual(shortcut1Target?.textContent, "Alpha Report", "Shortcut 1 maps to 1st visible filtered item")
        TestHarness.assertEqual(shortcut2Target?.textContent, "Alpha Analysis", "Shortcut 2 maps to 2nd visible filtered item")
        TestHarness.assertNil(shortcut3Target, "Shortcut 3 is safely out of bounds on 2-item filtered list")
    }
}
