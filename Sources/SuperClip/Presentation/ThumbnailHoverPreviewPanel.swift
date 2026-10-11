import AppKit
import SwiftUI
import SuperClipCore

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

/// Floating NSPanel displaying thumbnail preview for image clips on hover.
public final class ThumbnailHoverPreviewPanel: NSPanel {
    public static let shared = ThumbnailHoverPreviewPanel()

    public private(set) var currentItemId: UUID?
    private var hostingView: NSHostingView<ThumbnailPreviewHostView>
    private var showTimer: Timer?

    public init() {
        let initialView = ThumbnailPreviewHostView()
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

    public func show(for item: ClipItem, thumbnailURL: URL?) {
        guard item.contentType == .image else {
            hide()
            return
        }

        if currentItemId == item.id && isVisible {
            return
        }

        showTimer?.invalidate()
        showTimer = nil

        if isVisible {
            // Immediately update content without delay when transitioning between image items
            display(item: item, thumbnailURL: thumbnailURL)
        } else {
            // 80ms debounce for initial hover entry
            showTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: false) { [weak self] _ in
                self?.display(item: item, thumbnailURL: thumbnailURL)
            }
        }
    }

    public func display(item: ClipItem, thumbnailURL: URL?) {
        self.currentItemId = item.id
        hostingView.rootView = ThumbnailPreviewHostView(item: item, thumbnailURL: thumbnailURL)

        let mouseScreen = NSEvent.mouseLocation
        let targetWindow = NSApp.windows.first { win in
            win.isVisible && win != self && !win.className.contains("Preview") &&
            (win.className.contains("Floating") || win.className.contains("Popover") || win.isKeyWindow)
        } ?? NSApp.keyWindow

        let previewWidth: CGFloat = 236
        let previewHeight: CGFloat = 175

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
            if leftSpace >= (previewWidth + 12) {
                targetX = winFrame.minX - previewWidth - 8
            } else {
                targetX = winFrame.maxX + 8
            }
            targetY = mouseScreen.y - (previewHeight / 2)
        } else {
            targetX = mouseScreen.x - previewWidth - 12
            targetY = mouseScreen.y - (previewHeight / 2)
        }

        // Screen boundary safety clamping
        if targetX < screenVisible.minX + 8 {
            targetX = screenVisible.minX + 8
        } else if targetX + previewWidth > screenVisible.maxX - 8 {
            targetX = screenVisible.maxX - previewWidth - 8
        }

        if targetY < screenVisible.minY + 8 {
            targetY = screenVisible.minY + 8
        } else if targetY + previewHeight > screenVisible.maxY - 8 {
            targetY = screenVisible.maxY - previewHeight - 8
        }

        self.setFrame(NSRect(x: targetX, y: targetY, width: previewWidth, height: previewHeight), display: true)
        if !isVisible {
            self.orderFront(nil)
        }
    }

    public func hide() {
        showTimer?.invalidate()
        showTimer = nil
        currentItemId = nil
        if isVisible {
            self.orderOut(nil)
        }
    }
}
