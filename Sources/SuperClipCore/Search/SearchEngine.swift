import Foundation

public enum SearchEngine {
    public static func matches(item: ClipItem, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }

        let targetText: String
        switch item.contentType {
        case .text:
            let content = item.textContent ?? ""
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                targetText = "\(content) \(item.displayTitle)"
            } else {
                targetText = content
            }
        case .image:
            let dims = (item.imageWidth != nil && item.imageHeight != nil && item.imageWidth! > 0 && item.imageHeight! > 0) ? "\(item.imageWidth!)x\(item.imageHeight!)" : ""
            targetText = "[Ảnh] [Image] [图片] [画像] [이미지] [Imagen] [Bild] Ảnh Image 图片 画像 이미지 Imagen Bild \(dims) \(item.displayTitle)"
        }

        // Exact substring match (handles regex metacharacters literally)
        if targetText.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
            return true
        }

        // Multi-token fallback: space-separated words
        let tokens = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if tokens.count > 1 {
            return tokens.allSatisfy { token in
                targetText.range(of: token, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }

        return false
    }

    public static func filter(items: [ClipItem], query: String) -> [ClipItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return items }
        return items.filter { matches(item: $0, query: trimmed) }
    }

    public static func partition(items: [ClipItem]) -> (pinned: [ClipItem], unpinned: [ClipItem]) {
        let pinned = items.filter { $0.isPinned }
        let unpinned = items.filter { !$0.isPinned }
        return (pinned: pinned, unpinned: unpinned)
    }

    public static func partition(
        items: [ClipItem],
        query: String
    ) -> (pinned: [ClipItem], recent: [ClipItem]) {
        let filtered = filter(items: items, query: query)
        let pinned = filtered.filter { $0.isPinned }
        let recent = filtered.filter { !$0.isPinned }
        return (pinned: pinned, recent: recent)
    }
}
