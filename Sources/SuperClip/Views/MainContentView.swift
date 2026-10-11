import SwiftUI
import AppKit
import SuperClipCore

/// MainContentView is the primary root SwiftUI container hosted in both
/// FloatingClipPanel and StatusItemManager NSPopover.
///
/// Features:
/// - Auto-focused search bar with instant query filtering via SearchBarView.
/// - Partitioned list via ClipListView: Pinned items first, Recent History second.
/// - Keyboard navigation: Up/Down arrow keys highlight items, Return selects.
/// - Shortcut badges (1..9) and Command+1..9 or bare 1..9 instant selection.
/// - Copy-only writeback to NSPasteboard.general with self-copy loop suppression.
/// - Clean dismissal on item selection, outside click, or Escape.
/// - Zero Accessibility permissions required.
/// - Strictly 0 emojis invariant across all UI strings, icons, and tooltips.
public struct MainContentView: View {

    // MARK: - Dependencies & Callbacks

    @ObservedObject public var storageManager: StorageManager
    @ObservedObject private var localizationManager = LocalizationManager.shared
    public var pasteboardWriter: any PasteboardWriting
    public var pasteboardMonitor: (any PasteboardMonitoring)?
    public var onDismiss: (() -> Void)?
    public var onItemSelected: ((ClipItem) -> Void)?
    public var onOpenSettings: (() -> Void)?

    // MARK: - State

    @State private var searchText: String = ""
    @State private var selectedIndex: Int? = nil
    @State private var localKeyMonitor: Any? = nil

    // MARK: - Initialization

    public init(
        storageManager: StorageManager,
        pasteboardWriter: (any PasteboardWriting)? = nil,
        pasteboardMonitor: (any PasteboardMonitoring)? = nil,
        onDismiss: (() -> Void)? = nil,
        onItemSelected: ((ClipItem) -> Void)? = nil,
        onOpenSettings: (() -> Void)? = nil
    ) {
        self.storageManager = storageManager
        let monitor = pasteboardMonitor ?? PasteboardMonitor.shared
        self.pasteboardMonitor = monitor
        self.pasteboardWriter = pasteboardWriter ?? PasteboardWriter(pasteboard: .general, monitor: monitor)
        self.onDismiss = onDismiss
        self.onItemSelected = onItemSelected
        self.onOpenSettings = onOpenSettings
    }

    // MARK: - Computed Properties

    public var partitionedClips: (pinned: [ClipItem], recent: [ClipItem]) {
        let (pinned, recent) = SearchEngine.partition(items: storageManager.items, query: searchText)
        let maxDisplay = storageManager.settings.displayCapacity
        let cappedRecent = maxDisplay > 0 ? Array(recent.prefix(maxDisplay)) : recent
        return (pinned: pinned, recent: cappedRecent)
    }

    public var visibleItems: [ClipItem] {
        partitionedClips.pinned + partitionedClips.recent
    }

    public var visibleCount: Int {
        visibleItems.count
    }

    public var totalCount: Int {
        storageManager.items.count
    }

    public var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var selectedItemId: UUID? {
        guard let idx = selectedIndex, idx >= 0 && idx < visibleItems.count else {
            return nil
        }
        return visibleItems[idx].id
    }

    // MARK: - Body View

    public var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                headerBar
                searchBarSection
                Divider()
                    .opacity(0.6)
                contentSection
            }
            .frame(width: 380, height: 600)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onAppear {
                installKeyboardMonitor()
            }
            .onDisappear {
                removeKeyboardMonitor()
            }
            .onChange(of: selectedIndex) { newIndex in
                if let idx = newIndex, idx >= 0 && idx < visibleItems.count {
                    let targetID = visibleItems[idx].id
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(targetID, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.accentColor)

            Text("SuperClip")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)

            itemCountBadge

            Spacer()

            Button(action: {
                if let onOpen = onOpenSettings {
                    onOpen()
                } else {
                    SettingsWindowController.shared?.showSettings()
                }
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(LocalizationManager.shared.tr(.preferencesTooltip))

            Button(action: { onDismiss?() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(LocalizationManager.shared.tr(.dismissTooltip))
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var itemCountBadge: some View {
        Group {
            if isSearching || visibleCount < totalCount {
                Text(LocalizationManager.shared.tr(.ofCount(visibleCount, totalCount)))
            } else {
                Text("\(totalCount)")
            }
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundColor(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(Color(nsColor: .quaternaryLabelColor))
        )
    }

    // MARK: - Search Bar Section

    private var searchBarSection: some View {
        SearchBarView(
            text: $searchText,
            placeholder: LocalizationManager.shared.tr(.searchPlaceholder),
            onCommit: {
                handleReturnKey()
            }
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    // MARK: - Content Section

    private var contentSection: some View {
        ClipListView(
            pinnedItems: partitionedClips.pinned,
            recentItems: partitionedClips.recent,
            searchQuery: searchText,
            selectedItemId: selectedItemId,
            onSelect: { item in
                selectItem(item)
            },
            onTogglePin: { item in
                storageManager.togglePin(id: item.id)
            },
            onCopy: { item in
                selectItem(item)
            },
            onDelete: { item in
                storageManager.deleteItem(id: item.id)
            },
            onClearHistory: {
                storageManager.clearUnpinnedHistory()
            },
            thumbnailURLProvider: { item in
                storageManager.getThumbnailURL(for: item)
            }
        )
    }

    // MARK: - Actions & Keyboard Interception

    public func selectItem(_ item: ClipItem) {
        _ = pasteboardWriter.writeClip(item, storageManager: storageManager)
        onItemSelected?(item)
        onDismiss?()
    }

    /// Static helper executing copy-only writeback to NSPasteboard.general with zero accessibility permissions.
    public static func writeItemToPasteboard(item: ClipItem, storageManager: StorageManager) {
        let writer = PasteboardWriter(pasteboard: .general, monitor: PasteboardMonitor.shared)
        _ = writer.writeClip(item, storageManager: storageManager)
    }

    private func handleReturnKey() {
        if let target = ShortcutNavigator.resolveReturnTarget(
            currentIndex: selectedIndex,
            visibleItems: visibleItems
        ) {
            selectItem(target)
        }
    }

    private func installKeyboardMonitor() {
        removeKeyboardMonitor()
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Escape key (53)
            if event.keyCode == 53 {
                onDismiss?()
                return nil
            }

            // Command + Comma (43): Open Preferences
            if event.modifierFlags.contains(.command) && (event.charactersIgnoringModifiers == "," || event.keyCode == 43) {
                if let onOpen = onOpenSettings {
                    onOpen()
                } else {
                    SettingsWindowController.shared?.showSettings()
                }
                return nil
            }

            // Command + Q (12): Quit SuperClip
            if event.modifierFlags.contains(.command) && (event.charactersIgnoringModifiers == "q" || event.keyCode == 12) {
                NSApp.terminate(nil)
                return nil
            }

            // Down Arrow key (125)
            if event.keyCode == 125 {
                selectedIndex = ShortcutNavigator.stepDown(
                    currentIndex: selectedIndex,
                    visibleCount: visibleCount
                )
                return nil
            }

            // Up Arrow key (126)
            if event.keyCode == 126 {
                selectedIndex = ShortcutNavigator.stepUp(
                    currentIndex: selectedIndex,
                    visibleCount: visibleCount
                )
                return nil
            }

            // Return / Enter key (36)
            if event.keyCode == 36 {
                handleReturnKey()
                return nil
            }

            return event
        }
    }

    private func removeKeyboardMonitor() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }
}
