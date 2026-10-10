# Project: SuperClip

## Architecture
SuperClip is an ultra-lightweight, native macOS menu bar clipboard manager built with Swift 6, AppKit, and SwiftUI without third-party dependencies.

### Architectural Subsystems
1. **Core Domain & Persistence Layer (`SuperClipCore`)**:
   - `ClipItem`, `ClipType`, `AppSettings`: Codable domain models.
   - `StorageManager`: Thread-safe metadata store (`metadata.json`) under `~/Library/Application Support/SuperClip/`, segregated disk storage for image blobs (`images/`) and thumbnails (`thumbnails/`), atomic writes, strict FIFO eviction of unpinned items respecting configurable capacity (default 100), and absolute retention of pinned items.
   - `ThumbnailGenerator`: CoreGraphics / ImageIO downscaling producing compact PNG thumbnails (<2KB) with max pixel size 180.
   - `PasteboardMonitor`: Non-blocking periodic timer polling `NSPasteboard.general.changeCount`, extracting string / PNG / TIFF payloads, with synchronous `markSelfCopy` loop suppression.
   - `HotKeyManager`: Carbon HIToolbox `RegisterEventHotKey` wrapper registering system-wide hotkeys (default Option+V) with zero macOS Accessibility permissions.
   - `SearchEngine`: Real-time case-insensitive search filtering across text content and metadata.

2. **Presentation & Application Layer (`SuperClip`)**:
   - `StatusItemManager`: `NSStatusItem` in the macOS system menu bar hosting an `NSPopover` with flat SF Symbol `doc.on.clipboard`.
   - `FloatingClipPanel`: Borderless floating `NSPanel` (`canBecomeKey = true`, `.floating` level, `.nonactivatingPanel` mask) presenting at mouse coordinates.
   - `PanelFrameCalculator`: Pure mathematical coordinate calculator positioning and clamping the floating panel strictly within `NSScreen.visibleFrame` across multi-monitor setups.
   - `ClipListView`, `ClipRowView`, `SearchBarView`, `SettingsView`: SwiftUI views adhering strictly to Apple flat design and SF Symbols, with a 0-emoji invariant across all UI strings and icons.

3. **Automation & Verification Layer**:
   - `Makefile`: Dual-mode compilation and packaging automation enforcing `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk`.
   - `SuperClip.app`: Standalone application bundle with `Contents/Info.plist` having `LSUIElement = true` (menu bar agent mode) and ad-hoc codesign.
   - `Scripts/lint_emojis.py`: Static scanner verifying zero emoji characters across source code, UI strings, and build files.
   - `Tests/VerificationRunner`: Automated verification runner validating persistence, thumbnails, search, pin protection, and pasteboard copy in an isolated sandbox.

---

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | ChangeCount Polling Monitor | Periodically polls NSPasteboard.general.changeCount without blocking main thread | M1 | ORIGINAL_REQUEST.md:12-14 |
| 2 | Plain Text Capture | Reads string data from pasteboard when changeCount increments | M1 | ORIGINAL_REQUEST.md:13, 44 |
| 3 | Image Payload Capture | Reads image data (TIFF/PNG) from pasteboard | M1 | ORIGINAL_REQUEST.md:13, 45 |
| 4 | Thumbnail Generation | Downscales raw image to compact local thumbnail (max 180px) | M1 | ORIGINAL_REQUEST.md:13, 45 |
| 5 | Self-Copy Loop Suppression | Prevents re-recording clip when SuperClip writes to pasteboard | M1 | ORIGINAL_REQUEST.md:29, 53 |
| 6 | Duplicate Promotion | If identical text is copied, promotes to top instead of duplicating | M1 | Survey / Inferred UX |
| 7 | File System Persistence | Persists clips and settings in JSON under ~/Library/Application Support/SuperClip/ | M1 | ORIGINAL_REQUEST.md:13-14, 44 |
| 8 | FIFO Unpinned Eviction | Caps unpinned items to capacity (default 100); evicts oldest unpinned items | M1 | ORIGINAL_REQUEST.md:13-14, 46 |
| 9 | Pin Persistence & Protection | Pinned clips are permanently protected from capacity eviction & purge | M1 | ORIGINAL_REQUEST.md:13-14, 46 |
| 10 | Clear Unpinned History | Purges all unpinned history items and associated image assets in one action | M1 | ORIGINAL_REQUEST.md:27, 46 |
| 11 | Status Bar Icon & Popover | Displays NSStatusItem in menu bar; toggles attached NSPopover | M2 | ORIGINAL_REQUEST.md:16-17 |
| 12 | Floating Panel Presentation | Summons borderless floating NSPanel centered/clamped near mouse cursor | M2 | ORIGINAL_REQUEST.md:18-19, 54 |
| 13 | Screen Coordinate Clamping | Clamps floating panel within active NSScreen.visibleFrame containing cursor | M2 | ORIGINAL_REQUEST.md:18-19 |
| 14 | Panel Dismissal on Escape | Pressing Escape key dismisses floating panel or popover cleanly | M2 | ORIGINAL_REQUEST.md:19 |
| 15 | Panel Dismissal on Outside Click | Clicking outside panel boundaries dismisses the UI | M2 | ORIGINAL_REQUEST.md:19 |
| 16 | Dismissal on Item Selection | Selecting any clip copies content and immediately dismisses the UI | M2 | ORIGINAL_REQUEST.md:19, 29, 53 |
| 17 | Carbon Global Hotkey (Zero AX) | Registers system hotkey via Carbon RegisterEventHotKey without Accessibility | M2 | ORIGINAL_REQUEST.md:18, 29 |
| 18 | Default Hotkey (Option + V) | Maps default hotkey combination to Option + V (kVK_ANSI_V, optionKey) | M2 | ORIGINAL_REQUEST.md:5, 18, 54 |
| 19 | Auto-Focused Search Bar | Search text field at top of panel automatically gains first responder on open | M3 | ORIGINAL_REQUEST.md:23 |
| 20 | Real-Time Substring Filtering | Filters text clips and image labels as user types into search bar | M3 | ORIGINAL_REQUEST.md:23, 49-50 |
| 21 | Partitioned List Sections | Segregates items into "Pinned" section and "Recent History" section | M3 | ORIGINAL_REQUEST.md:24 |
| 22 | Number Shortcuts (1..9) | Keys 1..9 immediately select and copy the corresponding visible row | M3 | ORIGINAL_REQUEST.md:25 |
| 23 | Per-Row Pin/Unpin Action | Toggle button on each row to pin or unpin the clip | M3 | ORIGINAL_REQUEST.md:26 |
| 24 | Per-Row Copy Action | Dedicated copy button on each row to copy payload without selection click | M3 | ORIGINAL_REQUEST.md:26 |
| 25 | Per-Row Delete Action | Dedicated delete button to remove item permanently from memory & disk | M3 | ORIGINAL_REQUEST.md:26 |
| 26 | Flat Design SF Symbols | Uses Apple SF Symbols and flat vector styling across all UI components | M3 | ORIGINAL_REQUEST.md:28, 57 |
| 27 | Zero Emojis Constraint | Absolute ban on emoji characters across UI, code, comments, and strings | M3 | ORIGINAL_REQUEST.md:28, 57 |
| 28 | Copy-Only Interaction Model | Writing payload back to pasteboard without simulating fake paste keystrokes | M3 | ORIGINAL_REQUEST.md:29, 53 |
| 29 | Hotkey Customization UI | Interface in Settings to modify the global hotkey key code and modifiers | M4 | ORIGINAL_REQUEST.md:31-32 |
| 30 | Capacity Adjustment UI | Control to adjust unpinned history capacity (e.g. 10 to 500 items) | M4 | ORIGINAL_REQUEST.md:31-32 |
| 31 | Menu Bar Agent Mode (LSUIElement) | Info.plist configured with LSUIElement = true | M4 | ORIGINAL_REQUEST.md:32-33, 41 |
| 32 | App Bundle Packaging (Makefile) | Makefile target producing standalone SuperClip.app with Info.plist & codesign | M4 | ORIGINAL_REQUEST.md:32-33, 40-41 |
| 33 | Programmatic Persistence Test | Verifies saving, serializing, reloading clips from disk | M5 | ORIGINAL_REQUEST.md:34-36, 44 |
| 34 | Programmatic Thumbnail Test | Verifies thumbnail generation, scaling, and file creation | M5 | ORIGINAL_REQUEST.md:34-36, 45 |
| 35 | Programmatic Search Test | Verifies query filtering, case insensitivity, empty query restoration | M5 | ORIGINAL_REQUEST.md:34-36, 49-50 |
| 36 | Programmatic Pin Retention Test | Verifies pinned items survive capacity overflow and history clearing | M5 | ORIGINAL_REQUEST.md:34-36, 46 |
| 37 | Programmatic Pasteboard Test | Verifies copying clip populates NSPasteboard.general with exact bytes | M5 | ORIGINAL_REQUEST.md:34-36, 53 |
| 38 | Automated Zero-Emoji Scan | Verifies zero emoji characters exist across all source and config files | M5 | ORIGINAL_REQUEST.md:28, 57 |

---

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Core Models, Storage & Monitor | ClipItem, ClipType, AppSettings, StorageManager, ThumbnailGenerator, PasteboardMonitor (Features 1-10) | none | DONE |
| M2 | Window Management & Hotkey | FloatingClipPanel, PanelFrameCalculator, StatusItemManager, HotKeyManager, Dismissal logic (Features 11-18) | M1 | DONE |
| M3 | SwiftUI Interface & Navigation | SearchBarView, SearchEngine, ClipListView, ClipRowView, 1-9 shortcuts, copy writeback, SF Symbols flat styling (Features 19-28) | M1, M2 | DONE |
| M5 | Automated Verification & Hardening | SuperClipVerifier headless runner, E2E test suite (Tiers 1-4), adversarial test hardening, zero-emoji verification (Features 33-38) | M1, M2, M3, M4 | DONE |


---

## Interface Contracts

### SuperClipCore ↔ Storage
```swift
public protocol StorageManaging: ObservableObject {
    var items: [ClipItem] { get }
    var capacity: Int { get set }
    func addClip(item: ClipItem, imageData: Data?, thumbData: Data?)
    func togglePin(id: UUID)
    func deleteItem(id: UUID)
    func clearUnpinnedHistory()
    func getThumbnailURL(for item: ClipItem) -> URL?
    func getImageData(for item: ClipItem) -> Data?
}
```

### SuperClipCore ↔ PasteboardMonitor
```swift
public protocol PasteboardMonitoring {
    var onNewClip: ((ClipItem, Data?, Data?) -> Void)? { get set }
    func startPolling(intervalMs: Int)
    func stopPolling()
    func markSelfCopy(newChangeCount: Int)
}
```

### SuperClipCore ↔ HotKey
```swift
public protocol HotKeyManaging {
    var onTrigger: (() -> Void)? { get set }
    func register(keyCode: UInt32, modifiers: UInt32)
    func unregister()
}
```

### SuperClip ↔ Window Presentation
```swift
public protocol PanelPositioning {
    static func calculateClampedPanelFrame(
        mouseLoc: NSPoint,
        panelSize: NSSize,
        targetScreen: NSScreen?
    ) -> NSRect
}
```

---

## Code Layout
```
Sources/
├── SuperClipCore/
│   ├── Models/
│   │   ├── ClipItem.swift
│   │   ├── ClipType.swift
│   │   └── AppSettings.swift
│   ├── Storage/
│   │   ├── StorageManager.swift
│   │   └── ThumbnailGenerator.swift
│   ├── Monitor/
│   │   └── PasteboardMonitor.swift
│   ├── HotKey/
│   │   └── HotKeyManager.swift
│   └── Search/
│       └── SearchEngine.swift
└── SuperClip/
    ├── App/
    │   ├── SuperClipApp.swift
    │   └── AppDelegate.swift
    ├── Presentation/
    │   ├── FloatingClipPanel.swift
    │   ├── PanelFrameCalculator.swift
    │   └── StatusItemManager.swift
    └── Views/
        ├── ClipListView.swift
        ├── ClipRowView.swift
        ├── SearchBarView.swift
        └── SettingsView.swift

Tests/
├── SuperClipTests/
│   ├── StorageTests.swift
│   ├── SearchFilterTests.swift
│   ├── ThumbnailTests.swift
│   └── PinRetentionTests.swift
└── VerificationRunner/
    └── main.swift

Scripts/
├── generate_icon.swift
├── lint_emojis.py
└── verify.sh

Package.swift
Makefile
```
