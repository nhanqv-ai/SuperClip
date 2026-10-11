import Foundation

public enum SearchEngine {
    public static func matches(item: ClipItem, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }

        let targetText: String
        switch item.contentType {
        case .text:
            let content = item.textContent ?? ""
            if item.isMasked {
                targetText = "\(content) •••••••• ****"
            } else if content.allSatisfy(\.isWhitespace) {
                targetText = "\(content) \(item.displayTitle)"
            } else {
                targetText = content
            }
        case .image:
            let dims = (item.imageWidth != nil && item.imageHeight != nil && item.imageWidth! > 0 && item.imageHeight! > 0) ? "\(item.imageWidth!)x\(item.imageHeight!)" : ""
            let maskTokens = item.isMasked ? "•••••••• **** " : ""
            targetText = "\(maskTokens)[Ảnh] [Image] [图片] [画像] [이미지] [Imagen] [Bild] Ảnh Image 图片 画像 이미지 Imagen Bild \(dims) \(item.displayTitle)"
        }

        // Exact substring match (handles regex metacharacters literally)
        if targetText.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
            return true
        }

        // Multi-token fallback: space-separated words
        let tokens = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        if tokens.count > 1 {
            for token in tokens {
                if targetText.range(of: token, options: [.caseInsensitive, .diacriticInsensitive]) == nil {
                    return false
                }
            }
            return true
        }

        return false
    }

    public static func filter(items: [ClipItem], query: String) -> [ClipItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return items }

        let tokens = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        let hasMultipleTokens = tokens.count > 1

        var results: [ClipItem] = []
        results.reserveCapacity(min(items.count, 100))

        for item in items {
            let targetText: String
            switch item.contentType {
            case .text:
                let content = item.textContent ?? ""
                if item.isMasked {
                    targetText = "\(content) •••••••• ****"
                } else if content.allSatisfy(\.isWhitespace) {
                    targetText = "\(content) \(item.displayTitle)"
                } else {
                    targetText = content
                }
            case .image:
                let dims = (item.imageWidth != nil && item.imageHeight != nil && item.imageWidth! > 0 && item.imageHeight! > 0) ? "\(item.imageWidth!)x\(item.imageHeight!)" : ""
                let maskTokens = item.isMasked ? "•••••••• **** " : ""
                targetText = "\(maskTokens)[Ảnh] [Image] [图片] [画像] [이미지] [Imagen] [Bild] Ảnh Image 图片 画像 이미지 Imagen Bild \(dims) \(item.displayTitle)"
            }

            if targetText.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                results.append(item)
                continue
            }

            if hasMultipleTokens {
                var allMatch = true
                for token in tokens {
                    if targetText.range(of: token, options: [.caseInsensitive, .diacriticInsensitive]) == nil {
                        allMatch = false
                        break
                    }
                }
                if allMatch {
                    results.append(item)
                }
            }
        }

        return results
    }

    public static func partition(items: [ClipItem]) -> (pinned: [ClipItem], unpinned: [ClipItem]) {
        var pinned: [ClipItem] = []
        var unpinned: [ClipItem] = []
        pinned.reserveCapacity(items.count / 10)
        unpinned.reserveCapacity(items.count)

        for item in items {
            if item.isPinned {
                pinned.append(item)
            } else {
                unpinned.append(item)
            }
        }
        return (pinned: pinned, unpinned: unpinned)
    }

    public static func partition(
        items: [ClipItem],
        query: String
    ) -> (pinned: [ClipItem], recent: [ClipItem]) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            let (pinned, unpinned) = partition(items: items)
            return (pinned: pinned, recent: unpinned)
        }

        let tokens = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        let hasMultipleTokens = tokens.count > 1

        var pinned: [ClipItem] = []
        var recent: [ClipItem] = []
        pinned.reserveCapacity(items.count / 10)
        recent.reserveCapacity(items.count)

        for item in items {
            let targetText: String
            switch item.contentType {
            case .text:
                let content = item.textContent ?? ""
                if item.isMasked {
                    targetText = "\(content) •••••••• ****"
                } else if content.allSatisfy(\.isWhitespace) {
                    targetText = "\(content) \(item.displayTitle)"
                } else {
                    targetText = content
                }
            case .image:
                let dims = (item.imageWidth != nil && item.imageHeight != nil && item.imageWidth! > 0 && item.imageHeight! > 0) ? "\(item.imageWidth!)x\(item.imageHeight!)" : ""
                let maskTokens = item.isMasked ? "•••••••• **** " : ""
                targetText = "\(maskTokens)[Ảnh] [Image] [图片] [画像] [이미지] [Imagen] [Bild] Ảnh Image 图片 画像 이미지 Imagen Bild \(dims) \(item.displayTitle)"
            }

            var matches = false
            if targetText.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                matches = true
            } else if hasMultipleTokens {
                var allMatch = true
                for token in tokens {
                    if targetText.range(of: token, options: [.caseInsensitive, .diacriticInsensitive]) == nil {
                        allMatch = false
                        break
                    }
                }
                matches = allMatch
            }

            if matches {
                if item.isPinned {
                    pinned.append(item)
                } else {
                    recent.append(item)
                }
            }
        }

        return (pinned: pinned, recent: recent)
    }
}
