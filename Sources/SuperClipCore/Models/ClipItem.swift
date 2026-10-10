import Foundation

public struct ClipItem: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let contentType: ClipType
    public var textContent: String?
    public let imageFileName: String?
    public let thumbnailFileName: String?
    public let imageWidth: Int?
    public let imageHeight: Int?
    public let byteSize: Int
    public var createdAt: Date
    public var isPinned: Bool

    public init(
        id: UUID = UUID(),
        contentType: ClipType,
        textContent: String? = nil,
        imageFileName: String? = nil,
        thumbnailFileName: String? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        byteSize: Int = 0,
        createdAt: Date = Date(),
        isPinned: Bool = false
    ) {
        self.id = id
        self.contentType = contentType
        self.textContent = textContent
        self.imageFileName = imageFileName ?? (contentType == .image ? "\(id.uuidString).png" : nil)
        self.thumbnailFileName = thumbnailFileName ?? (contentType == .image ? "\(id.uuidString)_thumb.png" : nil)
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.byteSize = byteSize
        self.createdAt = createdAt
        self.isPinned = isPinned
    }

    public var displayTitle: String {
        switch contentType {
        case .text:
            guard let text = textContent, !text.isEmpty else { return "(Empty)" }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "(Whitespace)" }
            let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
            if firstLine.count > 60 {
                return String(firstLine.prefix(57)) + "..."
            }
            return firstLine
        case .image:
            if let w = imageWidth, let h = imageHeight, w > 0, h > 0 {
                return "Image (\(w)x\(h))"
            } else {
                return "Image"
            }
        }
    }

    public var formattedByteSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(byteSize))
    }

    public var searchableText: String {
        textContent ?? displayTitle
    }
}
