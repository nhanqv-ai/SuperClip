import AppKit
import SwiftUI
import SuperClipCore

/// Formatter utility for relative timestamps adhering to zero emojis invariant.
public enum RelativeTimeFormatter {
    private static let formatter: RelativeDateTimeFormatter = {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return fmt
    }()

    public static func format(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)
        if interval < 5 {
            return "Just now"
        }
        return formatter.localizedString(for: date, relativeTo: now)
    }
}

/// In-memory cache for loaded thumbnail NSImages to avoid redundant disk decoding.
public final class ThumbnailImageCache {
    public static let shared = ThumbnailImageCache()
    private let cache = NSCache<NSURL, NSImage>()

    public init() {
        cache.countLimit = 150
    }

    public func image(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    public func setImage(_ image: NSImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }

    public func removeImage(for url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }
}

/// Thumbnail view supporting async and cached loading from local thumbnail URL with fallback.
public struct ClipThumbnailView: View {
    public let item: ClipItem
    public let thumbnailURL: URL?
    @State private var loadedImage: NSImage?

    public init(item: ClipItem, thumbnailURL: URL?) {
        self.item = item
        self.thumbnailURL = thumbnailURL
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.secondary.opacity(0.1))

            if let image = loadedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 32, height: 32)
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .onAppear {
            loadThumbnail()
        }
        .onChange(of: thumbnailURL) { _ in
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        guard let url = thumbnailURL else { return }
        if let cached = ThumbnailImageCache.shared.image(for: url) {
            self.loadedImage = cached
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            if let image = NSImage(contentsOf: url) {
                ThumbnailImageCache.shared.setImage(image, for: url)
                DispatchQueue.main.async {
                    self.loadedImage = image
                }
            }
        }
    }
}

/// ClipRowView presents an individual clipboard item (text or image) on a clean,
/// ultra-compact single line with right-aligned shortcut indicators, hover actions,
/// and right-click context menu.
public struct ClipRowView: View {
    public let item: ClipItem
    public let shortcutIndex: Int?
    public let thumbnailURL: URL?
    public let isSelected: Bool
    public var onSelect: ((ClipItem) -> Void)?
    public var onTogglePin: ((ClipItem) -> Void)?
    public var onCopy: ((ClipItem) -> Void)?
    public var onDelete: ((ClipItem) -> Void)?

    @State private var isHovered: Bool = false
    @ObservedObject private var localizationManager = LocalizationManager.shared

    public init(
        item: ClipItem,
        shortcutIndex: Int? = nil,
        thumbnailURL: URL? = nil,
        isSelected: Bool = false,
        onSelect: ((ClipItem) -> Void)? = nil,
        onTogglePin: ((ClipItem) -> Void)? = nil,
        onCopy: ((ClipItem) -> Void)? = nil,
        onDelete: ((ClipItem) -> Void)? = nil
    ) {
        self.item = item
        self.shortcutIndex = shortcutIndex
        self.thumbnailURL = thumbnailURL
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onTogglePin = onTogglePin
        self.onCopy = onCopy
        self.onDelete = onDelete
    }

    public var body: some View {
        HStack(spacing: 6) {
            // Clickable row content body (left-aligned)
            Button(action: { onSelect?(item) }) {
                Text(rowContentText)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Right-aligned trailing controls (Pin, Delete on hover, and shortcut badge)
            trailingControls
        }
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(backgroundFillColor)
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(borderStrokeColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button(item.isPinned ? LocalizationManager.shared.tr(.unpinClip) : LocalizationManager.shared.tr(.pinClip)) {
                onTogglePin?(item)
            }
            Button(LocalizationManager.shared.tr(.copyClip)) {
                if let onCopy = onCopy {
                    onCopy(item)
                } else {
                    onSelect?(item)
                }
            }
            Divider()
            Button(LocalizationManager.shared.tr(.deleteClip)) {
                onDelete?(item)
            }
        }
    }

    // MARK: - Row Content Text

    public static func formatContentText(for item: ClipItem) -> String {
        switch item.contentType {
        case .text:
            if let text = item.textContent, !text.isEmpty {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    return LocalizationManager.shared.tr(.whitespaceClip)
                }
                return text.replacingOccurrences(of: "\r\n", with: " ")
                           .replacingOccurrences(of: "\n", with: " ")
                           .replacingOccurrences(of: "\r", with: " ")
            }
            return item.displayTitle
        case .image:
            if let w = item.imageWidth, let h = item.imageHeight, w > 0, h > 0 {
                return LocalizationManager.shared.tr(.imageTag(w, h))
            } else {
                return LocalizationManager.shared.tr(.imageTagBare)
            }
        }
    }

    private var rowContentText: String {
        Self.formatContentText(for: item)
    }

    // MARK: - Trailing Controls

    @ViewBuilder
    private var trailingControls: some View {
        HStack(spacing: 5) {
            if isHovered {
                // Compact Delete Button (on the left)
                Button(action: { onDelete?(item) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.red)
                        .frame(width: 18, height: 18)
                        .background(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color.red.opacity(0.12))
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(LocalizationManager.shared.tr(.deleteClip))

                // Compact Pin / Unpin Button (on the right - maintains position with static pin)
                Button(action: { onTogglePin?(item) }) {
                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(item.isPinned ? .accentColor : .secondary)
                        .frame(width: 18, height: 18)
                        .background(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color.secondary.opacity(0.12))
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(item.isPinned ? LocalizationManager.shared.tr(.unpinClip) : LocalizationManager.shared.tr(.pinClip))
            } else {
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onTogglePin?(item)
                        }
                }
            }
        }
    }

    // MARK: - Visual Helpers

    private var backgroundFillColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.18)
        } else if isHovered {
            return Color.accentColor.opacity(0.10)
        } else {
            return Color.clear
        }
    }

    private var borderStrokeColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.5)
        } else if isHovered {
            return Color(nsColor: .separatorColor).opacity(0.3)
        } else {
            return Color.clear
        }
    }
}
