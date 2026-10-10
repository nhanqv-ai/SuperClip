import SwiftUI
import AppKit

/// SearchBarView provides an instant search text field with an auto-focus guarantee
/// upon presentation in FloatingClipPanel and StatusItemManager NSPopover.
///
/// Features:
/// - Auto-focused search bar using @FocusState and NSWindow.didBecomeKeyNotification dual-layer focus acquisition.
/// - Text field binding with real-time query updates.
/// - SF Symbols: magnifyingglass prefix, xmark.circle.fill clear button.
/// - Flat design styling with 0 emojis invariant.
public struct SearchBarView: View {
    @Binding public var text: String
    public var placeholder: String
    public var onCommit: (() -> Void)?

    @FocusState private var isFieldFocused: Bool

    public init(
        text: Binding<String>,
        placeholder: String = "Search clips...",
        onCommit: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onCommit = onCommit
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isFieldFocused)
                .onSubmit {
                    onCommit?()
                }

            if !text.isEmpty {
                Button(action: {
                    text = ""
                    // Reclaim focus immediately upon clearing query
                    DispatchQueue.main.async {
                        isFieldFocused = true
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search query")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
                )
        )
        .onAppear {
            requestFieldFocus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            requestFieldFocus()
        }
    }

    /// Requests first responder focus for the search text field on the main runloop.
    private func requestFieldFocus() {
        DispatchQueue.main.async {
            self.isFieldFocused = true
        }
    }
}
