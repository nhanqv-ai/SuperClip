import Foundation
import SuperClipCore

public struct SearchFilterTests {
    public static func run() {
        TestHarness.startSuite("Search Engine & Filtering")
        
        let c1 = ClipItem(id: UUID(), contentType: .text, textContent: "SwiftUI macOS Development", byteSize: 26, isPinned: true)
        let c2 = ClipItem(id: UUID(), contentType: .text, textContent: "NSPasteboard Polling Architecture", byteSize: 33, isPinned: false)
        let c3 = ClipItem(id: UUID(), contentType: .text, textContent: "Apple Carbon HotKey Registration", byteSize: 33, isPinned: false)
        let c4 = ClipItem(id: UUID(), contentType: .image, imageWidth: 1920, imageHeight: 1080, byteSize: 1000, isPinned: false)
        let c5 = ClipItem(id: UUID(), contentType: .text, textContent: "Café Menu Pricing", byteSize: 17, isPinned: true)
        
        let items = [c1, c2, c3, c4, c5]
        
        // Test 1: Empty query returns full collection
        let emptyResult = SearchEngine.filter(items: items, query: "")
        TestHarness.assertEqual(emptyResult.count, items.count, "Empty search query returns all items")
        
        // Test 2: Whitespace-only query returns full collection
        let spaceResult = SearchEngine.filter(items: items, query: "   \t\n  ")
        TestHarness.assertEqual(spaceResult.count, items.count, "Whitespace query returns all items")
        
        // Test 3: Case-insensitive substring query
        let swiftResult = SearchEngine.filter(items: items, query: "swiftui")
        TestHarness.assertEqual(swiftResult.count, 1, "Query 'swiftui' matches exactly 1 item")
        TestHarness.assertEqual(swiftResult.first?.id, c1.id, "Query matches target item c1")
        
        // Test 4: Diacritic insensitive query (e.g. cafe matching Café)
        let cafeResult = SearchEngine.filter(items: items, query: "cafe")
        TestHarness.assertEqual(cafeResult.count, 1, "Query 'cafe' matches 'Café Menu Pricing'")
        TestHarness.assertEqual(cafeResult.first?.id, c5.id, "Diacritic folding matches target clip")
        
        // Test 5: Image label query
        let imgResult = SearchEngine.filter(items: items, query: "1920")
        TestHarness.assertEqual(imgResult.count, 1, "Query '1920' matches image label 'Image (1920x1080)'")
        TestHarness.assertEqual(imgResult.first?.id, c4.id, "Image query matches item c4")

        let anhResult = SearchEngine.filter(items: items, query: "Ảnh")
        TestHarness.assertEqual(anhResult.count, 1, "Query 'Ảnh' matches image item c4")
        TestHarness.assertEqual(anhResult.first?.id, c4.id, "Query 'Ảnh' matches item c4")

        let bracketAnhResult = SearchEngine.filter(items: items, query: "[Ảnh]")
        TestHarness.assertEqual(bracketAnhResult.count, 1, "Query '[Ảnh]' matches image item c4")

        let foldedAnhResult = SearchEngine.filter(items: items, query: "anh")
        TestHarness.assertEqual(foldedAnhResult.count, 1, "Query 'anh' (diacritic folded) matches image item c4")

        let dimsResult = SearchEngine.filter(items: items, query: "1920x1080")
        TestHarness.assertEqual(dimsResult.count, 1, "Query '1920x1080' matches image item c4")
        
        // Test 6: Multi-word disjoint tokens
        let multiTokenResult = SearchEngine.filter(items: items, query: "carbon registration")
        TestHarness.assertEqual(multiTokenResult.count, 1, "Multi-token query matches item containing both words")
        TestHarness.assertEqual(multiTokenResult.first?.id, c3.id, "Multi-token query matches c3")
        
        // Test 7: Non-matching query returns empty list
        let noneResult = SearchEngine.filter(items: items, query: "nonexistent_token_xyz")
        TestHarness.assertEqual(noneResult.count, 0, "Non-matching query returns empty array")
        
        // Test 8: Partitioning into Pinned and Unpinned sections
        let partitioned = SearchEngine.partition(items: items)
        TestHarness.assertEqual(partitioned.pinned.count, 2, "Partitioning correctly segregates 2 pinned items")
        TestHarness.assertEqual(partitioned.unpinned.count, 3, "Partitioning correctly segregates 3 unpinned items")
    }
}
