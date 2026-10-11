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
    public var isMasked: Bool

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
        isPinned: Bool = false,
        isMasked: Bool = false
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
        self.isMasked = isMasked
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case contentType
        case textContent
        case imageFileName
        case thumbnailFileName
        case imageWidth
        case imageHeight
        case byteSize
        case createdAt
        case isPinned
        case isMasked
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.contentType = try container.decode(ClipType.self, forKey: .contentType)
        self.textContent = try container.decodeIfPresent(String.self, forKey: .textContent)
        self.imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        self.thumbnailFileName = try container.decodeIfPresent(String.self, forKey: .thumbnailFileName)
        self.imageWidth = try container.decodeIfPresent(Int.self, forKey: .imageWidth)
        self.imageHeight = try container.decodeIfPresent(Int.self, forKey: .imageHeight)
        self.byteSize = try container.decode(Int.self, forKey: .byteSize)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        self.isMasked = try container.decodeIfPresent(Bool.self, forKey: .isMasked) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(contentType, forKey: .contentType)
        try container.encodeIfPresent(textContent, forKey: .textContent)
        try container.encodeIfPresent(imageFileName, forKey: .imageFileName)
        try container.encodeIfPresent(thumbnailFileName, forKey: .thumbnailFileName)
        try container.encodeIfPresent(imageWidth, forKey: .imageWidth)
        try container.encodeIfPresent(imageHeight, forKey: .imageHeight)
        try container.encode(byteSize, forKey: .byteSize)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(isMasked, forKey: .isMasked)
    }

    public mutating func toggleMasked() {
        isMasked.toggle()
    }

    public func toggledMasked() -> ClipItem {
        var copy = self
        copy.isMasked.toggle()
        return copy
    }

    public var displayTitle: String {
        if isMasked {
            return "••••••••"
        }
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
