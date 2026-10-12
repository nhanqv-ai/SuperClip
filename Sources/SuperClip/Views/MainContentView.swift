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
    @ObservedObject public var updateManager: UpdateManager
    @ObservedObject private var localizationManager = LocalizationManager.shared
    public var pasteboardWriter: any PasteboardWriting
    public var pasteboardMonitor: (any PasteboardMonitoring)?
    public var coordinator: ClipboardActionCoordinator
    public var onDismiss: (() -> Void)?
    public var onItemSelected: ((ClipItem) -> Void)?
    public var onOpenSettings: (() -> Void)?

    // MARK: - State

    @State private var searchText: String = ""
    @State private var selectedIndex: Int? = nil
    @State private var localKeyMonitor: Any? = nil
    @State private var hostWindow: NSWindow? = nil

    // MARK: - Initialization

    public init(
        storageManager: StorageManager,
        pasteboardWriter: (any PasteboardWriting)? = nil,
        pasteboardMonitor: (any PasteboardMonitoring)? = nil,
        updateManager: UpdateManager = UpdateManager.shared,
        autoPasteService: (any AutoPasteServicing)? = nil,
        previousAppTracker: (any PreviousAppTracking)? = nil,
        coordinator: ClipboardActionCoordinator? = nil,
        onDismiss: (() -> Void)? = nil,
        onItemSelected: ((ClipItem) -> Void)? = nil,
        onOpenSettings: (() -> Void)? = nil
    ) {
        self.storageManager = storageManager
        let monitor = pasteboardMonitor ?? PasteboardMonitor.shared
        self.pasteboardMonitor = monitor
        let writer = pasteboardWriter ?? PasteboardWriter(pasteboard: .general, monitor: monitor)
        self.pasteboardWriter = writer
        self.updateManager = updateManager
        self.onDismiss = onDismiss
        self.onItemSelected = onItemSelected
        self.onOpenSettings = onOpenSettings
        self.coordinator = coordinator ?? ClipboardActionCoordinator(
            storageManager: storageManager,
            pasteboardWriter: writer,
            autoPasteService: autoPasteService ?? AutoPasteService.shared,
            previousAppTracker: previousAppTracker ?? PreviousAppTracker.shared,
            onDismiss: onDismiss
        )
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
                if updateManager.shouldShowBanner {
                    updateBannerView
                }
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
            .background(
                WindowAccessor { win in
                    if let win = win {
                        self.hostWindow = win
                    }
                }
            )
            .onAppear {
                installKeyboardMonitor()
                resetSelection(scrollProxy: proxy)
            }
            .onDisappear {
                ThumbnailHoverPreviewPanel.shared.hide()
                removeKeyboardMonitor()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notif in
                guard let win = notif.object as? NSWindow else { return }
                if let host = hostWindow {
                    guard win === host else { return }
                } else if win.title == "SuperClip Settings" || win.title.hasPrefix("About") {
                    return
                }
                installKeyboardMonitor()
                resetSelection(scrollProxy: proxy)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { notif in
                guard let win = notif.object as? NSWindow else { return }
                if let host = hostWindow, win === host {
                    removeKeyboardMonitor()
                }
            }
            .onChange(of: searchText) { newQuery in
                resetSelection(query: newQuery, scrollProxy: proxy)
            }
            .onChange(of: storageManager.items) { _ in
                resetSelection(scrollProxy: proxy)
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

            Spacer()

            Button(action: {
                if let onOpen = onOpenSettings {
                    onOpen()
                } else {
                    SettingsWindowController.shared?.showSettings()
                }
            }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(4)

                    if updateManager.hasPendingUpdate {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                            .offset(x: 2, y: -2)
                    }
                }
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

    // MARK: - Update Banner View

    public var updateBannerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .foregroundColor(.accentColor)
                .font(.system(size: 13))

            VStack(alignment: .leading, spacing: 1) {
                switch updateManager.status {
                case .readyToRestart:
                    Text(LocalizationManager.shared.tr(.updateReadyRestart))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)

                case .downloading:
                    Text(LocalizationManager.shared.tr(.downloadingUpdate))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)

                case .updateAvailable(let release):
                    let tag = release.tagName.lowercased().hasPrefix("v") ? release.tagName : "v\(release.tagName)"
                    Text(LocalizationManager.shared.tr(.updateAvailableBanner(tag)))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)

                case .error(let msg):
                    Text(msg)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.red)
                        .lineLimit(1)

                default:
                    EmptyView()
                }
            }

            Spacer()

            switch updateManager.status {
            case .readyToRestart:
                Button(action: {
                    updateManager.dismissBannerForSession()
                }) {
                    Text(LocalizationManager.shared.tr(.later))
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Button(action: {
                    updateManager.restartApp()
                }) {
                    Text(LocalizationManager.shared.tr(.restart))
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

            case .downloading:
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.6)

            case .updateAvailable(let release):
                Button(action: {
                    NSWorkspace.shared.open(release.htmlURL)
                }) {
                    Text(LocalizationManager.shared.tr(.releaseNotes))
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Button(action: {
                    updateManager.dismissBannerForSession()
                }) {
                    Text(LocalizationManager.shared.tr(.later))
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Button(action: {
                    updateManager.startDownloadAndInstall(release: release)
                }) {
                    Text(LocalizationManager.shared.tr(.updateNow))
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

            case .error:
                if let release = updateManager.latestRelease {
                    Button(action: {
                        NSWorkspace.shared.open(release.htmlURL)
                    }) {
                        Text(LocalizationManager.shared.tr(.releaseNotes))
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }

                Button(action: {
                    updateManager.dismissBannerForSession()
                }) {
                    Text(LocalizationManager.shared.tr(.later))
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                if let release = updateManager.latestRelease {
                    Button(action: {
                        updateManager.startDownloadAndInstall(release: release)
                    }) {
                        Text(LocalizationManager.shared.tr(.updateNow))
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

            default:
                EmptyView()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.12))
        .cornerRadius(6)
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
            onToggleMask: { item in
                storageManager.toggleMaskItem(id: item.id)
            },
            onCopy: { item in
                copyItem(item)
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
        ThumbnailHoverPreviewPanel.shared.hide()
        coordinator.onDismiss = onDismiss
        coordinator.selectAndCopy(item: item)
        onItemSelected?(item)
    }

    public func copyItem(_ item: ClipItem) {
        ThumbnailHoverPreviewPanel.shared.hide()
        coordinator.onDismiss = onDismiss
        coordinator.copyItem(item: item, dismiss: true)
    }

    /// Static helper executing copy-only writeback to NSPasteboard.general with zero accessibility permissions.
    public static func writeItemToPasteboard(item: ClipItem, storageManager: StorageManager) {
        let writer = PasteboardWriter(pasteboard: .general, monitor: PasteboardMonitor.shared)
        _ = writer.writeClip(item, storageManager: storageManager)
    }

    private func resetSelection(query: String? = nil, scrollProxy: ScrollViewProxy? = nil) {
        let q = query ?? searchText
        let (pinned, recent) = SearchEngine.partition(items: storageManager.items, query: q)
        let maxDisplay = storageManager.settings.displayCapacity
        let cappedRecent = maxDisplay > 0 ? Array(recent.prefix(maxDisplay)) : recent
        let count = pinned.count + cappedRecent.count
        selectedIndex = count > 0 ? 0 : nil

        if count > 0, let firstID = (pinned.first ?? cappedRecent.first)?.id {
            withAnimation(.easeInOut(duration: 0.15)) {
                scrollProxy?.scrollTo(firstID, anchor: .center)
            }
        }
    }

    private var isSearchFieldFocused: Bool {
        let keyWin = hostWindow ?? NSApp.keyWindow
        if let responder = keyWin?.firstResponder {
            return responder is NSTextView
        }
        return false
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
            // Window isolation guard: only intercept events targeted at our hosting window
            if let host = hostWindow {
                guard let eventWin = event.window, eventWin === host, host.isKeyWindow, host.isVisible else {
                    return event
                }
            } else if let eventWin = event.window {
                if eventWin.title == "SuperClip Settings" || eventWin.title.hasPrefix("About") || !eventWin.isKeyWindow {
                    return event
                }
            }

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

            // IME marked text guard: If composition/marked text is active in the search field,
            // yield arrow keys and Enter/Return to the input method editor for candidate selection.
            let targetWin = hostWindow ?? NSApp.keyWindow
            let hasMarkedText = (targetWin?.firstResponder as? NSTextView)?.hasMarkedText() ?? false
            if !hasMarkedText {
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

                // Return / Enter key (36: Return, 76: Keypad Enter)
                if event.keyCode == 36 || event.keyCode == 76 {
                    handleReturnKey()
                    return nil
                }
            }

            // Section-Aware Shortcuts (Option for pinned, Command for recent)
            if let sectionShortcut = ShortcutNavigator.parseSectionShortcut(from: event, searchFieldHasFocus: isSearchFieldFocused) {
                if let target = ShortcutNavigator.targetItem(
                    forSectionShortcut: sectionShortcut,
                    pinnedItems: partitionedClips.pinned,
                    recentItems: partitionedClips.recent
                ) {
                    selectItem(target)
                    return nil
                }
            }

            // Command + 1..9 or bare 1..9 (if list focused)
            if let shortcutDigit = ShortcutNavigator.parseShortcut(from: event, searchFieldHasFocus: isSearchFieldFocused) {
                if let target = ShortcutNavigator.targetItem(forShortcut: shortcutDigit, in: visibleItems) {
                    selectItem(target)
                    return nil
                }
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

// MARK: - Window Accessor Supporting View

private struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = WindowObserverView()
        view.onWindowChange = onWindow
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            onWindow(window)
        }
    }
}

private final class WindowObserverView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?(self.window)
    }
}
