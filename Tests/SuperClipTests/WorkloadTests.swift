import Foundation
import CoreGraphics
import ImageIO
import AppKit
import SuperClipCore

public struct WorkloadTests {
    public static func run(sandboxDir: URL) {
        TestHarness.startSuite("Tier 4: Real-World Application Workload Scenarios")
        
        // Scenario 1: Developer Full-Day Coding Session
        let devStorage = StorageManager(baseDirectory: sandboxDir.appendingPathComponent("DevSession"), initialCapacity: 50)
        
        // Ingestion of 60 varied technical clips
        let snippets = [
            "git commit -m 'feat: implement clipboard monitor'",
            "docker run -d -p 8080:8080 redis:latest",
            "SELECT id, username, email FROM users WHERE active = 1 ORDER BY created_at DESC;",
            "curl -X POST https://api.superclip.app/v1/sync -H 'Authorization: Bearer test_token'",
            "func applicationDidFinishLaunching(_ notification: Notification) { ... }"
        ]
        
        for i in 1...60 {
            let baseSnippet = snippets[(i - 1) % snippets.count]
            let codeSnippet = "\(baseSnippet) // line \(i)"
            let item = ClipItem(id: UUID(), contentType: .text, textContent: codeSnippet, byteSize: codeSnippet.utf8.count, isPinned: false)
            devStorage.addClip(item: item, imageData: nil, thumbData: nil)
        }
        
        // Pin 3 critical clips
        let pin1 = devStorage.items[0].id
        let pin2 = devStorage.items[15].id
        let pin3 = devStorage.items[30].id
        devStorage.togglePin(id: pin1)
        devStorage.togglePin(id: pin2)
        devStorage.togglePin(id: pin3)
        
        // Add follow-up unpinned clips to test capacity overflow while pins are active
        for i in 61...70 {
            let codeSnippet = "developer followup command \(i)"
            let item = ClipItem(id: UUID(), contentType: .text, textContent: codeSnippet, byteSize: codeSnippet.utf8.count, isPinned: false)
            devStorage.addClip(item: item, imageData: nil, thumbData: nil)
        }
        
        // Execute search query
        let dockerResults = SearchEngine.filter(items: devStorage.items, query: "docker")
        TestHarness.assertTrue(dockerResults.count > 0, "Developer search query 'docker' returned matches")
        
        // Verify capacity is enforced while retaining pins
        let unpinnedCount = devStorage.items.filter { !$0.isPinned }.count
        let pinnedCount = devStorage.items.filter { $0.isPinned }.count
        TestHarness.assertEqual(unpinnedCount, 50, "Unpinned clips bounded at developer capacity 50")
        TestHarness.assertEqual(pinnedCount, 3, "All 3 pinned developer clips retained")
        
        // Scenario 2: Graphic Designer & Digital Asset Curation
        let designStorage = StorageManager(baseDirectory: sandboxDir.appendingPathComponent("DesignSession"), initialCapacity: 20)
        
        // Ingest 15 synthetic image assets with diverse aspect ratios
        let aspectRatios: [(w: Int, h: Int)] = [
            (1920, 1080), // 16:9 widescreen
            (1080, 1920), // 9:16 mobile portrait
            (1200, 1200), // 1:1 square
            (2560, 1440), // 1440p
            (800, 600)    // 4:3 standard
        ]
        
        var generatedThumbnailCount = 0
        for i in 1...15 {
            let dims = aspectRatios[(i - 1) % aspectRatios.count]
            let testImg = NSImage(size: NSSize(width: dims.w, height: dims.h))
            testImg.lockFocus()
            NSColor.systemIndigo.setFill()
            NSRect(origin: .zero, size: NSSize(width: dims.w, height: dims.h)).fill()
            testImg.unlockFocus()
            
            if let tiff = testImg.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                if let thumb = ThumbnailGenerator.generateThumbnail(from: png, maxPixelSize: 180) {
                    generatedThumbnailCount += 1
                    let imgItem = ClipItem(
                        id: UUID(),
                        contentType: .image,
                        imageFileName: "asset_\(i).png",
                        thumbnailFileName: "asset_\(i)_thumb.png",
                        imageWidth: dims.w,
                        imageHeight: dims.h,
                        byteSize: png.count,
                        isPinned: (i <= 2) // pin first 2 assets
                    )
                    designStorage.addClip(item: imgItem, imageData: png, thumbData: thumb)
                }
            }
        }
        TestHarness.assertEqual(generatedThumbnailCount, 15, "Generated 15 thumbnails across diverse aspect ratios")
        TestHarness.assertEqual(designStorage.items.filter { $0.isPinned }.count, 2, "Designer pinned assets successfully preserved")
        
        // Scenario 3: High-Frequency Clipboard Burst Stress
        let burstStorage = StorageManager(baseDirectory: sandboxDir.appendingPathComponent("BurstSession"), initialCapacity: 30)
        let burstStart = Date()
        for i in 1...100 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Burst Item \(i)", byteSize: 14, isPinned: false)
            burstStorage.addClip(item: item, imageData: nil, thumbData: nil)
        }
        let burstDuration = Date().timeIntervalSince(burstStart)
        TestHarness.assertTrue(burstDuration < 2.0, "100 rapid clip additions executed in \(String(format: "%.3f", burstDuration))s (< 2.0s)")
        TestHarness.assertEqual(burstStorage.items.count, 30, "Burst additions strictly capped at capacity 30")
        
        // Scenario 4: Long-Running Session Lifecycle & State Recovery
        let lifecycleDir = sandboxDir.appendingPathComponent("LifecycleSession")
        let lifecycle1 = StorageManager(baseDirectory: lifecycleDir, initialCapacity: 25)
        for i in 1...30 {
            let item = ClipItem(id: UUID(), contentType: .text, textContent: "Lifecycle Item \(i)", byteSize: 18, isPinned: (i == 5 || i == 10))
            lifecycle1.addClip(item: item, imageData: nil, thumbData: nil)
        }
        lifecycle1.flushDiskQueue()
        
        // Clear unpinned history
        lifecycle1.clearUnpinnedHistory()
        lifecycle1.flushDiskQueue()
        TestHarness.assertEqual(lifecycle1.items.count, 2, "Only 2 pinned items remain before restart")
        
        // Cold relaunch
        let lifecycle2 = StorageManager(baseDirectory: lifecycleDir, initialCapacity: 25)
        TestHarness.assertEqual(lifecycle2.items.count, 2, "Cold restart accurately reloads 2 pinned items")
        TestHarness.assertTrue(lifecycle2.items.allSatisfy { $0.isPinned }, "All reloaded items maintain pinned state")
        
        // Scenario 5: Multi-Display Clamping & Coordinate Boundary Migration
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let vFrame = screen.visibleFrame
        let testPoints: [NSPoint] = [
            NSPoint(x: vFrame.minX + 5, y: vFrame.maxY - 5), // top-left
            NSPoint(x: vFrame.minX + 5, y: vFrame.minY + 5), // bottom-left
            NSPoint(x: vFrame.maxX - 5, y: vFrame.maxY - 5), // top-right
            NSPoint(x: vFrame.maxX - 5, y: vFrame.minY + 5), // bottom-right
            NSPoint(x: -5000, y: -5000),                     // offscreen negative
            NSPoint(x: 50000, y: 50000)                      // offscreen positive
        ]
        
        var allClamped = true
        for pt in testPoints {
            let frame = PanelFrameCalculator.calculateClampedPanelFrame(
                mouseLoc: pt,
                panelSize: NSSize(width: 360, height: 480),
                targetScreen: screen
            )
            if frame.minX < vFrame.minX || frame.maxX > vFrame.maxX ||
               frame.minY < vFrame.minY || frame.maxY > vFrame.maxY {
                allClamped = false
            }
        }
        TestHarness.assertTrue(allClamped, "Panel positions across all multi-display test points clamp strictly within visibleFrame")
    }
}
