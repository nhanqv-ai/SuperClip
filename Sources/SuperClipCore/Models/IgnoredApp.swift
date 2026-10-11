import Foundation

/// Model representing an application ignored from SuperClip clipboard history recording.
public struct IgnoredApp: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var id: String {
        bundleIdentifier.isEmpty ? name : bundleIdentifier
    }
    public var bundleIdentifier: String
    public var name: String
    public var iconPath: String?

    public init(bundleIdentifier: String, name: String? = nil, iconPath: String? = nil) {
        let trimmedBid = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.bundleIdentifier = trimmedBid
        if let n = trimmedName, !n.isEmpty {
            self.name = n
        } else {
            self.name = trimmedBid
        }
        self.iconPath = iconPath
    }
}
