import AppKit
import SwiftUI
import SuperClipCore

/// Content type represented in the hover preview panel.
public enum ClipPreviewContent {
    case image(ClipItem, URL?)
    case text(String)
}

/// Host view displaying either the image thumbnail card or the full text tooltip card.
public struct ClipPreviewHostView: View {
    public let content: ClipPreviewContent?

    public init(content: ClipPreviewContent? = nil) {
        self.content = content
    }

    public var body: some View {
        switch content {
        case .image(let item, let url):
            ThumbnailPreviewHostView(item: item, thumbnailURL: url)
        case .text(let text):
            TextPreviewHostView(text: text)
        case .none:
            Color.clear.frame(width: 1, height: 1)
        }
    }
}

/// Fast, native-styled text tooltip card displaying full content for long or multiline clips.
public struct TextPreviewHostView: View {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(text)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.primary)
                .lineSpacing(2)
                .lineLimit(12)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: 340, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
        )
    }
}

/// Host view displaying the floating thumbnail preview card on hover.
public struct ThumbnailPreviewHostView: View {
    public let item: ClipItem?
    public let thumbnailURL: URL?
    @State private var image: NSImage?

    public init(item: ClipItem? = nil, thumbnailURL: URL? = nil) {
        self.item = item
        self.thumbnailURL = thumbnailURL
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 5)

            VStack(spacing: 8) {
                // Thumbnail display container
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))

                    if let img = image {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 216, maxHeight: 130)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: "photo")
                                .font(.system(size: 26, weight: .light))
                                .foregroundColor(.secondary)
                            Text(LocalizationManager.shared.tr(.imageTagBare))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 216, height: 130)
                    }
                }
                .frame(width: 216, height: 130)

                // Footer with dimensions / tag
                HStack(spacing: 5) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.accentColor)

                    if let item = item, let w = item.imageWidth, let h = item.imageHeight, w > 0, h > 0 {
                        Text("\(w) x \(h) px")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    } else {
                        Text(LocalizationManager.shared.tr(.imageTagBare))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
            .padding(10)
        }
        .frame(width: 236, height: 175)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
        )
        .onAppear {
            loadImage()
        }
        .onChange(of: thumbnailURL) { _ in
            loadImage()
        }
    }

    private func loadImage() {
        guard let item = item else { return }

        // 1. Try provided thumbnailURL
        if let url = thumbnailURL {
            if let cached = ThumbnailImageCache.shared.image(for: url) {
                self.image = cached
                return
            }
            if let loaded = NSImage(contentsOf: url) {
                ThumbnailImageCache.shared.setImage(loaded, for: url)
                self.image = loaded
                return
            }
        }

        // 2. Try application support thumbnails directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let superClipDir = appSupport?.appendingPathComponent("SuperClip", isDirectory: true)

        let thName = item.thumbnailFileName ?? "\(item.id.uuidString)_thumb.png"
        if let thURL = superClipDir?.appendingPathComponent("thumbnails").appendingPathComponent(thName) {
            if let cached = ThumbnailImageCache.shared.image(for: thURL) {
                self.image = cached
                return
            }
            if let loaded = NSImage(contentsOf: thURL) {
                ThumbnailImageCache.shared.setImage(loaded, for: thURL)
                self.image = loaded
                return
            }
        }

        // 3. Fallback to full images directory
        let imgName = item.imageFileName ?? "\(item.id.uuidString).png"
        if let imgURL = superClipDir?.appendingPathComponent("images").appendingPathComponent(imgName) {
            if let cached = ThumbnailImageCache.shared.image(for: imgURL) {
                self.image = cached
                return
            }
            if let loaded = NSImage(contentsOf: imgURL) {
                ThumbnailImageCache.shared.setImage(loaded, for: imgURL)
                self.image = loaded
                return
            }
        }
    }
}

/// Floating NSPanel displaying thumbnail preview for image clips and instant text tooltips on hover.
public final class ThumbnailHoverPreviewPanel: NSPanel {
    public static let shared = ThumbnailHoverPreviewPanel()

    public private(set) var currentItemId: UUID?
    private var hostingView: NSHostingView<ClipPreviewHostView>
    private var showTimer: Timer?
    private var hideTimer: Timer?

    public init() {
        let initialView = ClipPreviewHostView()
        self.hostingView = NSHostingView(rootView: initialView)

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 236, height: 175),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .popUpMenu
        self.hasShadow = true
        self.ignoresMouseEvents = true
        self.isReleasedWhenClosed = false
        self.contentView = hostingView
    }

    /// Unified presentation method: routes image clips to thumbnail preview and text clips to instant tooltip.
    public func show(for item: ClipItem, thumbnailURL: URL?) {
        hideTimer?.invalidate()
        hideTimer = nil

        if item.contentType == .image {
            showImage(item: item, thumbnailURL: thumbnailURL)
        } else if item.contentType == .text {
            let tooltip = ClipRowView.textTooltip(for: item)
            if !tooltip.isEmpty {
                showText(item: item, text: tooltip)
            } else {
                hide(immediate: true)
            }
        } else {
            hide(immediate: true)
        }
    }

    private func showImage(item: ClipItem, thumbnailURL: URL?) {
        if currentItemId == item.id && isVisible {
            return
        }

        showTimer?.invalidate()
        showTimer = nil

        if isVisible {
            // Already visible: transition immediately with 0ms delay!
            displayImage(item: item, thumbnailURL: thumbnailURL)
        } else {
            // Initial hover entry debounce (100ms)
            showTimer = Timer.scheduledTimer(withTimeInterval: 0.10, repeats: false) { [weak self] _ in
                self?.displayImage(item: item, thumbnailURL: thumbnailURL)
            }
        }
    }

    private func showText(item: ClipItem, text: String) {
        if currentItemId == item.id && isVisible {
            return
        }

        showTimer?.invalidate()
        showTimer = nil

        if isVisible {
            // Already visible: transition immediately with 0ms delay!
            displayText(item: item, text: text)
        } else {
            // Initial hover entry debounce (100ms)
            showTimer = Timer.scheduledTimer(withTimeInterval: 0.10, repeats: false) { [weak self] _ in
                self?.displayText(item: item, text: text)
            }
        }
    }

    public func display(item: ClipItem, thumbnailURL: URL?) {
        if item.contentType == .image {
            displayImage(item: item, thumbnailURL: thumbnailURL)
        } else {
            let tooltip = ClipRowView.textTooltip(for: item)
            if !tooltip.isEmpty {
                displayText(item: item, text: tooltip)
            }
        }
    }

    public func displayImage(item: ClipItem, thumbnailURL: URL?) {
        self.currentItemId = item.id
        hostingView.rootView = ClipPreviewHostView(content: .image(item, thumbnailURL))
        positionPanel(width: 236, height: 175)
    }

    public func displayText(item: ClipItem, text: String) {
        self.currentItemId = item.id
        hostingView.rootView = ClipPreviewHostView(content: .text(text))
        hostingView.layoutSubtreeIfNeeded()

        let fit = hostingView.fittingSize
        let previewWidth = max(min(fit.width, 360), 100)
        let previewHeight = max(min(fit.height, 300), 30)
        positionPanel(width: previewWidth, height: previewHeight)
    }

    private func positionPanel(width: CGFloat, height: CGFloat) {
        let mouseScreen = NSEvent.mouseLocation
        let targetWindow = NSApp.windows.first { win in
            win.isVisible && win != self && !win.className.contains("Preview") &&
            (win.className.contains("Floating") || win.className.contains("Popover") || win.isKeyWindow)
        } ?? NSApp.keyWindow

        var targetX: CGFloat
        var targetY: CGFloat

        let screen = NSScreen.screens.first { NSMouseInRect(mouseScreen, $0.frame, false) }
            ?? targetWindow?.screen
            ?? NSScreen.main
            ?? NSScreen.screens.first

        let screenVisible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

        if let win = targetWindow {
            let winFrame = win.frame
            let leftSpace = winFrame.minX - screenVisible.minX
            if leftSpace >= (width + 12) {
                targetX = winFrame.minX - width - 8
            } else {
                targetX = winFrame.maxX + 8
            }
            targetY = mouseScreen.y - (height / 2)
        } else {
            targetX = mouseScreen.x - width - 12
            targetY = mouseScreen.y - (height / 2)
        }

        // Screen boundary safety clamping
        if targetX < screenVisible.minX + 8 {
            targetX = screenVisible.minX + 8
        } else if targetX + width > screenVisible.maxX - 8 {
            targetX = screenVisible.maxX - width - 8
        }

        if targetY < screenVisible.minY + 8 {
            targetY = screenVisible.minY + 8
        } else if targetY + height > screenVisible.maxY - 8 {
            targetY = screenVisible.maxY - height - 8
        }

        self.setFrame(NSRect(x: targetX, y: targetY, width: width, height: height), display: true)
        if !isVisible {
            self.orderFront(nil)
        }
    }

    public func hide(immediate: Bool = false) {
        showTimer?.invalidate()
        showTimer = nil

        if immediate {
            hideTimer?.invalidate()
            hideTimer = nil
            currentItemId = nil
            if isVisible {
                self.orderOut(nil)
            }
            return
        }

        // 60ms grace timer to allow seamless transitions when moving across adjacent rows
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.currentItemId = nil
            if self.isVisible {
                self.orderOut(nil)
            }
        }
    }
}
