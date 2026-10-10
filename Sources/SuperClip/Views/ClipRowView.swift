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

/// ClipRowView presents an individual clipboard item (text or image) with shortcut badge,
/// truncated preview, metadata, pinned status indicator, selection highlight, and per-row hover action controls.
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
        HStack(spacing: 8) {
            // Clickable main content body
            Button(action: { onSelect?(item) }) {
                HStack(spacing: 8) {
                    shortcutBadge
                    contentIconOrThumbnail
                    contentDetails
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Trailing actions on hover / pinned indicator when idle
            trailingControls
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(backgroundFillColor)
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(borderStrokeColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
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

    // MARK: - Shortcut Badge (1..9)

    @ViewBuilder
    private var shortcutBadge: some View {
        if let index = shortcutIndex, (1...9).contains(index) {
            Text("\(index)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 18, height: 18)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                        )
                )
        } else {
            Spacer()
                .frame(width: 18, height: 18)
        }
    }

    // MARK: - Icon / Thumbnail

    @ViewBuilder
    private var contentIconOrThumbnail: some View {
        switch item.contentType {
        case .text:
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
                Image(systemName: "doc.text")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
            }
            .frame(width: 32, height: 32)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            )

        case .image:
            ClipThumbnailView(item: item, thumbnailURL: thumbnailURL)
        }
    }

    // MARK: - Content Details & Metadata

    private var contentDetails: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.displayTitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)

            Text(metadataString)
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    private var metadataString: String {
        let relativeTime = RelativeTimeFormatter.format(item.createdAt)
        switch item.contentType {
        case .text:
            let count = item.textContent?.count ?? 0
            let countLabel = count == 1 ? "1 char" : "\(count) chars"
            return "\(countLabel) - \(relativeTime)"
        case .image:
            var parts: [String] = []
            if let w = item.imageWidth, let h = item.imageHeight, w > 0, h > 0 {
                parts.append("\(w)x\(h)")
            }
            if item.byteSize > 0 {
                parts.append(item.formattedByteSize)
            }
            parts.append(relativeTime)
            return parts.joined(separator: " - ")
        }
    }

    // MARK: - Trailing Controls & Hover Actions

    @ViewBuilder
    private var trailingControls: some View {
        if isHovered {
            HStack(spacing: 4) {
                // Pin / Unpin Button
                Button(action: { onTogglePin?(item) }) {
                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(item.isPinned ? .accentColor : .secondary)
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.secondary.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .help(item.isPinned ? "Unpin clip" : "Pin clip")

                // Dedicated Copy Button
                Button(action: { onCopy?(item) }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.secondary.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .help("Copy to clipboard")

                // Delete Button
                Button(action: { onDelete?(item) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.red)
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.red.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .help("Delete clip")
            }
        } else {
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .padding(.trailing, 4)
            }
        }
    }
}
