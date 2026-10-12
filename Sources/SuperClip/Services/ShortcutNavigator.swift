import AppKit
import SuperClipCore

/// Pure navigation and shortcut resolver for SuperClip keyboard interaction.
public struct ShortcutNavigator {

    /// Resolves the unified visible items list matching the current search query,
    /// maintaining the invariant: Pinned items first, followed by Recent History.
    public static func resolveVisibleItems(
        items: [ClipItem],
        query: String
    ) -> [ClipItem] {
        let (pinned, recent) = SearchEngine.partition(items: items, query: query)
        return pinned + recent
    }

    /// Resolves the target clip item for a 1-based shortcut index (1..9).
    /// Returns nil if the index is out of bounds (< 1, > 9, or >= visibleItems.count).
    public static func targetItem(
        forShortcut index: Int,
        in visibleItems: [ClipItem]
    ) -> ClipItem? {
        guard index >= 1 && index <= 9 else { return nil }
        let itemIndex = index - 1
        guard itemIndex >= 0 && itemIndex < visibleItems.count else { return nil }
        return visibleItems[itemIndex]
    }

    /// Steps selection down (Down Arrow key navigation).
    /// - If visibleCount <= 0: returns nil.
    /// - If currentIndex == nil, current < 0, or current >= visibleCount - 1: wraps around and returns 0.
    /// - Otherwise: returns current + 1.
    public static func stepDown(
        currentIndex: Int?,
        visibleCount: Int
    ) -> Int? {
        guard visibleCount > 0 else { return nil }
        guard let current = currentIndex else { return 0 }
        if current < 0 || current >= visibleCount - 1 {
            return 0
        }
        return current + 1
    }

    /// Steps selection up (Up Arrow key navigation).
    /// - If visibleCount <= 0: returns nil.
    /// - If currentIndex == nil, current <= 0, or current >= visibleCount: wraps around and returns visibleCount - 1.
    /// - Otherwise: returns current - 1.
    public static func stepUp(
        currentIndex: Int?,
        visibleCount: Int
    ) -> Int? {
        guard visibleCount > 0 else { return nil }
        guard let current = currentIndex else { return visibleCount - 1 }
        if current <= 0 || current >= visibleCount {
            return visibleCount - 1
        }
        return current - 1
    }

    /// Resolves the target item for Return/Enter key selection.
    /// If an item is currently selected by index, returns that item.
    /// Otherwise defaults to the first visible item. Returns nil if list is empty.
    public static func resolveReturnTarget(
        currentIndex: Int?,
        visibleItems: [ClipItem]
    ) -> ClipItem? {
        guard !visibleItems.isEmpty else { return nil }
        if let idx = currentIndex, idx >= 0 && idx < visibleItems.count {
            return visibleItems[idx]
        }
        return visibleItems.first
    }

    /// Evaluates an NSEvent to determine if it represents a valid number shortcut (1..9).
    /// - Parameters:
    ///   - event: The keyDown NSEvent to evaluate.
    ///   - searchFieldHasFocus: Indicates whether the search text input currently holds first responder.
    /// - Returns: 1-based shortcut index (1..9) if recognized, or nil.
    public static func parseShortcut(
        from event: NSEvent,
        searchFieldHasFocus: Bool
    ) -> Int? {
        guard event.type == .keyDown else { return nil }

        // Extract single digit character ignoring layout modifiers
        guard let chars = event.charactersIgnoringModifiers,
              chars.count == 1,
              let char = chars.first,
              let digit = char.wholeNumberValue,
              digit >= 1 && digit <= 9 else {
            return nil
        }

        let flags = event.modifierFlags
        let hasCommand = flags.contains(.command)
        let hasControl = flags.contains(.control)
        let hasOption = flags.contains(.option)

        // Ignore if Control or Option is active (e.g. Option+V or Ctrl+1)
        guard !hasControl && !hasOption else { return nil }

        if hasCommand {
            // Command + 1..9 triggers unconditionally across the window
            return digit
        } else if !searchFieldHasFocus {
            // Bare 1..9 triggers when list has focus (search field blurred)
            return digit
        }

        return nil
    }

    /// Resolves the badge label for a visible row index (0..8 -> "1".."9", 9+ -> nil).
    public static func badgeLabel(forIndex index: Int) -> String? {
        guard index >= 0 && index < 9 else { return nil }
        return "\(index + 1)"
    }

    /// Target section for differentiated shortcuts.
    public enum ShortcutSection: Sendable, Equatable {
        case pinned
        case recent
    }

    /// Evaluates an NSEvent to determine section-aware shortcut:
    /// - Option + 1..9: target pinned items
    /// - Command + 1..9: target normal / recent history items
    /// - Bare 1..9 (when search field is blurred): target normal / recent history items
    public static func parseSectionShortcut(
        from event: NSEvent,
        searchFieldHasFocus: Bool
    ) -> (section: ShortcutSection, digit: Int)? {
        guard event.type == .keyDown else { return nil }

        guard let chars = event.charactersIgnoringModifiers,
              chars.count == 1,
              let char = chars.first,
              let digit = char.wholeNumberValue,
              digit >= 1 && digit <= 9 else {
            return nil
        }

        let flags = event.modifierFlags
        let hasCommand = flags.contains(.command)
        let hasControl = flags.contains(.control)
        let hasOption = flags.contains(.option)

        // Ignore if Control modifier is active
        guard !hasControl else { return nil }

        if hasOption && !hasCommand {
            return (.pinned, digit)
        } else if hasCommand && !hasOption {
            return (.recent, digit)
        } else if !hasOption && !hasCommand && !searchFieldHasFocus {
            return (.recent, digit)
        }

        return nil
    }

    /// Resolves the target item for a section shortcut.
    public static func targetItem(
        forSectionShortcut resolved: (section: ShortcutSection, digit: Int),
        pinnedItems: [ClipItem],
        recentItems: [ClipItem]
    ) -> ClipItem? {
        let index = resolved.digit - 1
        guard index >= 0 else { return nil }

        switch resolved.section {
        case .pinned:
            guard index < pinnedItems.count else { return nil }
            return pinnedItems[index]
        case .recent:
            guard index < recentItems.count else { return nil }
            return recentItems[index]
        }
    }
}
