import AppKit
import SwiftUI
import SuperClipCore

/// Helper utility for deterministic shortcut numbering across list sections.
public enum ClipShortcutMapper {
    /// Computes the shortcut index (1..9) for an item positioned within the partitioned view.
    /// Returns 1..9 for the first 9 visible items overall (pinned first, then recent), or nil if >= 9.
    public static func shortcutIndex(
        isPinned: Bool,
        indexInSection: Int,
        pinnedCount: Int
    ) -> Int? {
        let overallIndex = isPinned ? indexInSection : (pinnedCount + indexInSection)
        if overallIndex < 9 {
            return overallIndex + 1
        }
        return nil
    }

    /// Resolves the section and offset corresponding to a pressed digit key (1..9).
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
        self.pinnedItems = partitioned.pinned
        self.recentItems = partitioned.recent
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
            LazyVStack(alignment: .leading, spacing: 6) {
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
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Section Headers

    private var pinnedSectionHeader: some View {
        HStack(spacing: 5) {
            Image(systemName: "pin.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.accentColor)

            Text("PINNED")
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

            Text("RECENT HISTORY")
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
                        Text("Clear History")
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
                .help("Clear unpinned history clips")
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

            Text("No matching clips found")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            Text("Try refining your search query")
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

            Text("Clipboard history is empty")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            Text("Copied text and images will appear here")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
