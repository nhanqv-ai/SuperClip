import Foundation

public enum ClipType: String, Codable, CaseIterable, Sendable {
    case text
    case image

    public var displayName: String {
        switch self {
        case .text:
            return "Text"
        case .image:
            return "Image"
        }
    }

    public var sfSymbolName: String {
        switch self {
        case .text:
            return "text.alignleft"
        case .image:
            return "photo"
        }
    }
}
