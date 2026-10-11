import AppKit
import SwiftUI
import SuperClipCore

/// Helper utility for deterministic shortcut numbering across list sections.
public enum ClipShortcutMapper {
    /// Computes the shortcut index (1..9) for an item positioned within its section.
    /// Pinned items are numbered 1..9 (with Option modifier), and recent history items are independently numbered 1..9 (with Command modifier).
    public static func shortcutIndex(
        isPinned: Bool,
        indexInSection: Int,
        pinnedCount: Int = 0
    ) -> Int? {
        if indexInSection >= 0 && indexInSection < 9 {
            return indexInSection + 1
        }
        return nil
    }

    /// Resolves the section and offset corresponding to a section shortcut.
    public static func itemIndexForShortcut(
        _ keyNumber: Int,
        isPinned: Bool,
        pinnedCount: Int,
        recentCount: Int
    ) -> (isPinned: Bool, indexInSection: Int)? {
        guard (1...9).contains(keyNumber) else { return nil }
        let targetIndex = keyNumber - 1
        if isPinned {
            guard targetIndex < pinnedCount else { return nil }
            return (isPinned: true, indexInSection: targetIndex)
        } else {
            guard targetIndex < recentCount else { return nil }
            return (isPinned: false, indexInSection: targetIndex)
        }
    }

    /// Sequential reverse lookup for backwards compatibility.
    public static func itemIndexForShortcut(
        _ keyNumber: Int,
        pinnedCount: Int,
        recentCount: Int
    ) -> (isPinned: Bool, indexInSection: Int)? {
        guard (1...9).contains(keyNumber) else { return nil }
        let targetIndex = keyNumber - 1
        if targetIndex < pinnedCount {
            return (isPinned: true, indexInSection: targetIndex)
        }
        let recentIndex = targetIndex - pinnedCount
        if recentIndex < recentCount {
            return (isPinned: false, indexInSection: recentIndex)
        }
        return nil
    }
}

/// ClipListView manages the scrollable, partitioned clipboard history display.
///
/// Features:
/// - Partitioned into two distinct sections: "PINNED" and "RECENT HISTORY".
/// - Sticky/clean section headers with count badges.
/// - "Clear History" button in recent history section calling storageManager.clearUnpinnedHistory().
/// - Sequential shortcut badges (1..9) mapped across pinned, then recent items.
/// - Empty state views: magnifyingglass for no search matches, tray for empty clipboard.
/// - Flat design with strict 0 emojis invariant.
public struct ClipListView: View {
    public let pinnedItems: [ClipItem]
    public let recentItems: [ClipItem]
    public let searchQuery: String
    public let selectedItemId: UUID?
    public var onSelect: ((ClipItem) -> Void)?
    public var onTogglePin: ((ClipItem) -> Void)?
    public var onCopy: ((ClipItem) -> Void)?
    public var onDelete: ((ClipItem) -> Void)?
    public var onClearHistory: (() -> Void)?
    public var thumbnailURLProvider: ((ClipItem) -> URL?)?
    @ObservedObject private var localizationManager = LocalizationManager.shared

    public init(
        pinnedItems: [ClipItem],
        recentItems: [ClipItem],
        searchQuery: String = "",
        selectedItemId: UUID? = nil,
        onSelect: ((ClipItem) -> Void)? = nil,
        onTogglePin: ((ClipItem) -> Void)? = nil,
        onCopy: ((ClipItem) -> Void)? = nil,
        onDelete: ((ClipItem) -> Void)? = nil,
        onClearHistory: (() -> Void)? = nil,
        thumbnailURLProvider: ((ClipItem) -> URL?)? = nil
    ) {
        self.pinnedItems = pinnedItems
        self.recentItems = recentItems
        self.searchQuery = searchQuery
        self.selectedItemId = selectedItemId
        self.onSelect = onSelect
        self.onTogglePin = onTogglePin
        self.onCopy = onCopy
        self.onDelete = onDelete
        self.onClearHistory = onClearHistory
        self.thumbnailURLProvider = thumbnailURLProvider
    }

    /// Convenience initializer binding directly to StorageManager and SearchEngine.
    public init(
        storageManager: StorageManager,
        searchQuery: String = "",
        selectedItemId: UUID? = nil,
        onSelect: ((ClipItem) -> Void)? = nil,
        onCopy: ((ClipItem) -> Void)? = nil
    ) {
        let partitioned = SearchEngine.partition(items: storageManager.items, query: searchQuery)
        let maxDisplay = storageManager.settings.displayCapacity
        let cappedRecent = maxDisplay > 0 ? Array(partitioned.recent.prefix(maxDisplay)) : partitioned.recent
        self.pinnedItems = partitioned.pinned
        self.recentItems = cappedRecent
        self.searchQuery = searchQuery
        self.selectedItemId = selectedItemId
        self.thumbnailURLProvider = { item in storageManager.getThumbnailURL(for: item) }
        self.onSelect = onSelect
        self.onCopy = onCopy
        self.onTogglePin = { item in storageManager.togglePin(id: item.id) }
        self.onDelete = { item in storageManager.deleteItem(id: item.id) }
        self.onClearHistory = { storageManager.clearUnpinnedHistory() }
    }

    public var totalVisibleCount: Int {
        pinnedItems.count + recentItems.count
    }

    public var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var body: some View {
        Group {
            if totalVisibleCount == 0 {
                if isSearching {
                    emptySearchView
                } else {
                    emptyStorageView
                }
            } else {
                partitionedListView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Partitioned List View

    private var partitionedListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                // PINNED SECTION
                if !pinnedItems.isEmpty {
                    pinnedSectionHeader

                    ForEach(Array(pinnedItems.enumerated()), id: \.element.id) { index, item in
                        let shortcut = ClipShortcutMapper.shortcutIndex(
                            isPinned: true,
                            indexInSection: index,
                            pinnedCount: pinnedItems.count
                        )
                        ClipRowView(
                            item: item,
                            shortcutIndex: shortcut,
                            thumbnailURL: thumbnailURLProvider?(item),
                            isSelected: item.id == selectedItemId,
                            onSelect: onSelect,
                            onTogglePin: onTogglePin,
                            onCopy: onCopy,
                            onDelete: onDelete
                        )
                        .id(item.id)
                    }
                }

                // RECENT HISTORY SECTION
                if !recentItems.isEmpty {
                    recentSectionHeader

                    ForEach(Array(recentItems.enumerated()), id: \.element.id) { index, item in
                        let shortcut = ClipShortcutMapper.shortcutIndex(
                            isPinned: false,
                            indexInSection: index,
                            pinnedCount: pinnedItems.count
                        )
                        ClipRowView(
                            item: item,
                            shortcutIndex: shortcut,
                            thumbnailURL: thumbnailURLProvider?(item),
                            isSelected: item.id == selectedItemId,
                            onSelect: onSelect,
                            onTogglePin: onTogglePin,
                            onCopy: onCopy,
                            onDelete: onDelete
                        )
                        .id(item.id)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Section Headers

    private var pinnedSectionHeader: some View {
        HStack(spacing: 5) {
            Image(systemName: "pin.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.accentColor)

            Text(LocalizationManager.shared.tr(.pinnedSection))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            Spacer()

            Text("\(pinnedItems.count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary.opacity(0.8))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    Capsule()
                        .fill(Color(nsColor: .quaternaryLabelColor))
                )
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private var recentSectionHeader: some View {
        HStack(spacing: 5) {
            Image(systemName: "clock")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)

            Text(LocalizationManager.shared.tr(.recentSection))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            Text("\(recentItems.count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary.opacity(0.8))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    Capsule()
                        .fill(Color(nsColor: .quaternaryLabelColor))
                )

            Spacer()

            if onClearHistory != nil {
                Button(action: { onClearHistory?() }) {
                    HStack(spacing: 3) {
                        Image(systemName: "trash")
                            .font(.system(size: 9))
                        Text(LocalizationManager.shared.tr(.clearHistory))
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.6))
                    )
                }
                .buttonStyle(.plain)
                .help(LocalizationManager.shared.tr(.clearHistory))
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, pinnedItems.isEmpty ? 4 : 8)
        .padding(.bottom, 2)
    }

    // MARK: - Empty States

    private var emptySearchView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.secondary)

            Text(LocalizationManager.shared.tr(.noMatchingClips))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            Text(LocalizationManager.shared.tr(.tryRefiningSearch))
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStorageView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 30, weight: .light))
                .foregroundColor(.secondary)

            Text(LocalizationManager.shared.tr(.clipboardEmpty))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            Text(LocalizationManager.shared.tr(.copiedWillAppear))
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
