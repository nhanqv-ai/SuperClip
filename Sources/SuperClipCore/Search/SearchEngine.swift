import Foundation

public enum SearchEngine {
    @inline(__always)
    private static func asciiCaseInsensitiveContains(tBuf: UnsafeBufferPointer<UInt8>, qBuf: UnsafeBufferPointer<UInt8>) -> Bool {
        let tLen = tBuf.count
        let qLen = qBuf.count
        if qLen == 0 { return true }
        if tLen < qLen { return false }

        guard let tBase = tBuf.baseAddress, let qBase = qBuf.baseAddress else { return false }

        let q0 = qBase[0]
        let q0Lower = (q0 >= 65 && q0 <= 90) ? (q0 | 0x20) : q0
        let maxI = tLen - qLen

        var i = 0
        while i <= maxI {
            let tByte = tBase[i]
            let tLower = (tByte >= 65 && tByte <= 90) ? (tByte | 0x20) : tByte
            if tLower == q0Lower {
                var match = true
                var j = 1
                while j < qLen {
                    let tb = tBase[i + j]
                    let qb = qBase[j]
                    let tbL = (tb >= 65 && tb <= 90) ? (tb | 0x20) : tb
                    let qbL = (qb >= 65 && qb <= 90) ? (qb | 0x20) : qb
                    if tbL != qbL {
                        match = false
                        break
                    }
                    j += 1
                }
                if match { return true }
            }
            i += 1
        }
        return false
    }

    @inline(__always)
    private static func matchesSubstring(target: String, query: String, isQueryASCII: Bool) -> Bool {
        if isQueryASCII && target.utf8.allSatisfy({ $0 < 128 }) {
            return target.utf8.withContiguousStorageIfAvailable { tBuf in
                query.utf8.withContiguousStorageIfAvailable { qBuf in
                    asciiCaseInsensitiveContains(tBuf: tBuf, qBuf: qBuf)
                } ?? false
            } ?? (target.range(of: query, options: .caseInsensitive) != nil)
        }
        return target.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    @inline(__always)
    private static func extractTargetText(for item: ClipItem) -> String {
        switch item.contentType {
        case .text:
            let content = item.textContent ?? ""
            if item.isMasked {
                return "\(content) •••••••• ****"
            } else if content.isEmpty {
                return item.displayTitle
            } else if content.first?.isWhitespace == true && content.allSatisfy(\.isWhitespace) {
                return "\(content) \(item.displayTitle)"
            } else {
                return content
            }
        case .image:
            let dims = (item.imageWidth != nil && item.imageHeight != nil && item.imageWidth! > 0 && item.imageHeight! > 0) ? "\(item.imageWidth!)x\(item.imageHeight!)" : ""
            let maskTokens = item.isMasked ? "•••••••• **** " : ""
            return "\(maskTokens)[Ảnh] [Image] [图片] [画像] [이미지] [Imagen] [Bild] Ảnh Image 图片 画像 이미지 Imagen Bild \(dims) \(item.displayTitle)"
        }
    }

    public static func matches(item: ClipItem, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }

        let isTrimmedASCII = trimmed.utf8.allSatisfy { $0 < 128 }
        let targetText = extractTargetText(for: item)

        // Exact substring match (handles regex metacharacters literally)
        if matchesSubstring(target: targetText, query: trimmed, isQueryASCII: isTrimmedASCII) {
            return true
        }

        // Multi-token fallback: space-separated words
        let tokens = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        if tokens.count > 1 {
            for token in tokens {
                let isTokenASCII = token.utf8.allSatisfy { $0 < 128 }
                if !matchesSubstring(target: targetText, query: token, isQueryASCII: isTokenASCII) {
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

        let isTrimmedASCII = trimmed.utf8.allSatisfy { $0 < 128 }
        let tokens = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        let hasMultipleTokens = tokens.count > 1
        let tokensWithASCII = tokens.map { (token: $0, isASCII: $0.utf8.allSatisfy { $0 < 128 }) }

        var results: [ClipItem] = []
        results.reserveCapacity(min(items.count, 100))

        for item in items {
            let targetText = extractTargetText(for: item)

            if matchesSubstring(target: targetText, query: trimmed, isQueryASCII: isTrimmedASCII) {
                results.append(item)
                continue
            }

            if hasMultipleTokens {
                var allMatch = true
                for (token, isTokenASCII) in tokensWithASCII {
                    if !matchesSubstring(target: targetText, query: token, isQueryASCII: isTokenASCII) {
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

        let isTrimmedASCII = trimmed.utf8.allSatisfy { $0 < 128 }
        let tokens = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        let hasMultipleTokens = tokens.count > 1
        let tokensWithASCII = tokens.map { (token: $0, isASCII: $0.utf8.allSatisfy { $0 < 128 }) }

        var pinned: [ClipItem] = []
        var recent: [ClipItem] = []
        pinned.reserveCapacity(items.count / 10)
        recent.reserveCapacity(items.count)

        for item in items {
            let targetText = extractTargetText(for: item)

            var matches = false
            if matchesSubstring(target: targetText, query: trimmed, isQueryASCII: isTrimmedASCII) {
                matches = true
            } else if hasMultipleTokens {
                var allMatch = true
                for (token, isTokenASCII) in tokensWithASCII {
                    if !matchesSubstring(target: targetText, query: token, isQueryASCII: isTokenASCII) {
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
