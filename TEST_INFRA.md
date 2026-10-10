# SuperClip Test Infrastructure & 4-Tier E2E Testing Specification

## 1. Overview & Test Infrastructure Architecture

This document establishes the comprehensive end-to-end (E2E) testing methodology and specification for **SuperClip**, the native macOS menu bar clipboard manager. The testing infrastructure is designed to validate all 38 system features across functional, boundary, combinatorial, and realistic workload dimensions while maintaining complete isolation from the host user environment.

### 1.1 Core Testing Principles
1. **Opaque-Box E2E Derivation**: Every test case directly derives its expected behavior from `ORIGINAL_REQUEST.md` and `PROJECT.md` requirements rather than internal implementation quirks.
2. **Deterministic Isolation**: Tests execute in ephemeral sandbox directories created under `NSTemporaryDirectory()`. No test shall read, write, modify, or pollute the real host directory `~/Library/Application Support/SuperClip/`.
3. **Zero-Emoji Enforcement**: Strict, zero-tolerance ban on emoji characters across all source code, test code, assertion messages, test fixtures, comments, and console outputs. Validated via static code analysis.
4. **Toolchain Resilience**: All test executions explicitly target `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk` to guarantee flawless compilation on macOS systems without Xcode IDE dependencies.
5. **Headless Execution**: The test suite executes in headless CLI environments, validating AppKit, CoreGraphics, ImageIO, and Carbon constructs programmatically without requiring manual user clicks or window interaction.

---

## 2. Sandboxing & Test Runner Architecture

### 2.1 Ephemeral Sandbox Lifecycle
For every test suite and run:
- A unique sandbox directory `SuperClip_Test_<UUID>` is created inside `NSTemporaryDirectory()`.
- Isolated subdirectories are provisioned:
  - `metadata.json`: Clip and preference storage metadata.
  - `images/`: Original image payloads (`<UUID>.png`).
  - `thumbnails/`: Downscaled thumbnail assets (`<UUID>_thumb.png`).
- On suite completion, all sandbox artifacts are atomically purged.

### 2.2 Dual-Execution Strategy
1. **Automated Verification Runner (`Tests/VerificationRunner/main.swift`)**:
   - Compiles into a standalone native binary `SuperClipVerifier`.
   - Executes programmatic assertions across the core domain engines: persistence, thumbnail generation, capacity eviction, pin protection, search engine, coordinate clamping, and pasteboard copy.
2. **Test Shell Harness (`Scripts/verify.sh`)**:
   - Configures SDKROOT and execution environment.
   - Runs `Scripts/lint_emojis.py` static scanner.
   - Compiles and runs `Tests/VerificationRunner/main.swift`.
   - Compiles and executes modular test suites under `Tests/SuperClipTests/`.
   - Emits structured ANSI reports with pass/fail counts and timing metrics.

---

## 3. Tier 1: Feature Coverage (>=5 Test Cases per Feature for all 38 Features)

Total Tier 1 Test Cases: **190 test cases** (38 features x 5 test cases).

### Feature 1: ChangeCount Polling Monitor
- **T1-F01-01 (Baseline Polling)**: Monitor detects pasteboard change when `changeCount` increments from N to N+1 within polling interval.
- **T1-F01-02 (Idle Steady-State)**: Monitor consumes zero excess CPU and triggers no events when `changeCount` remains unchanged over multiple polling cycles.
- **T1-F01-03 (Timer Start/Stop)**: Calling `stopPolling()` pauses timer firing; `startPolling()` resumes polling without thread leakage.
- **T1-F01-04 (Configurable Interval)**: Polling interval configured to 100ms fires approximately every 100ms (+/- 25ms tolerance).
- **T1-F01-05 (Background Queue Safety)**: Polling execution occurs on dedicated background dispatch queue without blocking main dispatch thread.

### Feature 2: Plain Text Capture
- **T1-F02-01 (ASCII Text Ingestion)**: Capturing standard ASCII string `"Hello World"` creates a `ClipItem` with `.text` type and identical payload.
- **T1-F02-02 (UTF-8 Multilingual Text)**: Capturing accented and non-Latin characters (e.g., German umlauts, Japanese Hiragana, Vietnamese accents) preserves full UTF-8 encoding.
- **T1-F02-03 (Multiline Text Ingestion)**: Capturing strings containing `\n` and `\r\n` line breaks preserves newline structure.
- **T1-F02-04 (Byte Size Calculation)**: `byteSize` attribute correctly reflects the UTF-8 byte count of captured string.
- **T1-F02-05 (Timestamp Assignment)**: `createdAt` timestamp matches the pasteboard capture instant within 500ms.

### Feature 3: Image Payload Capture
- **T1-F03-01 (PNG Ingestion)**: Copying raw PNG bytes produces a `ClipItem` with `.image` type and stored image asset file.
- **T1-F03-02 (TIFF Ingestion)**: Copying TIFF format image extracts bitmap data, converts to standard PNG disk storage, and assigns correct dimensions.
- **T1-F03-03 (Dimension Extraction)**: Capturing an 800x600 image records `imageWidth = 800` and `imageHeight = 600`.
- **T1-F03-04 (Asset Filename Mapping)**: Generated image filename follows `<UUID>.png` convention under `images/` directory.
- **T1-F03-05 (Image Byte Size Tracking)**: `byteSize` field matches disk payload size of the saved image file.

### Feature 4: Thumbnail Generation
- **T1-F04-01 (Proportional Downscaling)**: Downscaling 1920x1080 image produces thumbnail with max dimension <= 180px (180x101).
- **T1-F04-02 (Compact File Size)**: Generated thumbnail PNG disk footprint is strictly less than 50KB (typically < 2KB).
- **T1-F04-03 (Thumbnail Path Binding)**: `thumbnailFileName` attribute resolves to existing thumbnail file under `thumbnails/`.
- **T1-F04-04 (Square Image Scaling)**: Downscaling 500x500 square image produces exactly 180x180 thumbnail.
- **T1-F04-05 (Tall Image Scaling)**: Downscaling 400x1200 portrait image produces 60x180 thumbnail preserving aspect ratio.

### Feature 5: Self-Copy Loop Suppression
- **T1-F05-01 (Self-Copy Suppression Flag)**: Invoking `markSelfCopy(newChangeCount:)` ensures next polling tick ignores that change count.
- **T1-F05-02 (External Copy Follow-Up)**: Subsequent external copy after self-copy with incremented `changeCount` is successfully captured.
- **T1-F05-03 (Synchronous ChangeCount Sync)**: Synchronizing `lastChangeCount` during internal pasteboard write prevents duplicate clip insertion.
- **T1-F05-04 (Multi-Write Suppression)**: Two consecutive internal writes each marked via `markSelfCopy` create zero duplicate history items.
- **T1-F05-05 (Rapid Writeback Guard)**: Fast selection and pasteboard copy does not trigger re-ingestion of the copied item.

### Feature 6: Duplicate Promotion
- **T1-F06-01 (Identical Text Promotion)**: Copying text identical to an existing unpinned clip moves that clip to the top of the history list.
- **T1-F06-02 (Timestamp Refresh)**: Promoted duplicate updates its `createdAt` timestamp to current time.
- **T1-F06-03 (Item Count Preservation)**: Duplicate promotion does not increment the total count of stored items.
- **T1-F06-04 (UUID Preservation)**: Duplicate promotion maintains the original clip UUID identifier.
- **T1-F06-05 (Pinned Duplicate Promotion)**: Copying text identical to a pinned clip updates its position or recency without unpinning it.

### Feature 7: File System Persistence
- **T1-F07-01 (JSON Serialization)**: In-memory clips serialize into valid JSON at `metadata.json`.
- **T1-F07-02 (Cold-Start Deserialization)**: Instantiating a new `StorageManager` loads all clips, attributes, and flags identically from disk.
- **T1-F07-03 (Atomic Write Protection)**: Metadata persistence uses atomic write options (`Data.WritingOptions.atomic`) preventing file truncation.
- **T1-F07-04 (Directory Auto-Creation)**: Missing `images/` or `thumbnails/` directories are automatically created on initialization.
- **T1-F07-05 (Pretty Print & Key Sorting)**: Metadata JSON is encoded with sorted keys for deterministic file formatting.

### Feature 8: FIFO Unpinned Eviction
- **T1-F08-01 (Capacity Bound Enforcement)**: Adding 105 unpinned items with capacity 100 leaves exactly 100 items in store.
- **T1-F08-02 (Oldest Item Eviction)**: The 5 oldest unpinned items by `createdAt` are removed first.
- **T1-F08-03 (Disk Asset Cleanup on Eviction)**: Evicting an image clip deletes its associated file from `images/` and thumbnail from `thumbnails/`.
- **T1-F08-04 (Single-Item Eviction)**: Adding item 101 when capacity is 100 evicts exactly 1 oldest unpinned item.
- **T1-F08-05 (Capacity Reduction Eviction)**: Lowering capacity dynamically from 100 to 50 triggers immediate eviction of the 50 oldest unpinned items.

### Feature 9: Pin Persistence & Protection
- **T1-F09-01 (Pin Retention Across Eviction)**: Pinned clips are never evicted when unpinned count exceeds capacity.
- **T1-F09-02 (Pin Flag Inversion)**: Calling `togglePin(id:)` flips `isPinned` from `false` to `true` and vice versa.
- **T1-F09-03 (Pin State Disk Persistence)**: Toggled pin status persists to disk and reloads accurately on restart.
- **T1-F09-04 (All-Pinned Capacity Overflow)**: Having 100 pinned items and adding an unpinned item retains all 100 pinned items.
- **T1-F09-05 (Pinned Asset Protection)**: Pinned image clips never have their disk assets deleted during background pruning.

### Feature 10: Clear Unpinned History
- **T1-F10-01 (Unpinned Item Purge)**: Calling `clearUnpinnedHistory()` removes all items where `isPinned == false`.
- **T1-F10-02 (Pinned Item Preservation)**: All items with `isPinned == true` remain intact after `clearUnpinnedHistory()`.
- **T1-F10-03 (Disk Image Deletion)**: Unpinned image files and thumbnails are deleted from disk upon clearing history.
- **T1-F10-04 (Metadata Synchronization)**: `metadata.json` updates immediately to contain only remaining pinned items.
- **T1-F10-05 (Empty Store Handling)**: Calling `clearUnpinnedHistory()` on an already empty history operates safely with zero errors.

### Feature 11: Status Bar Icon & Popover
- **T1-F11-01 (StatusItem Initialization)**: `NSStatusItem` is created with variable length and system status bar placement.
- **T1-F11-02 (SF Symbol Icon)**: Status button image is configured with SF Symbol `doc.on.clipboard` in flat vector style.
- **T1-F11-03 (Popover Toggle on Click)**: Clicking status bar button displays `NSPopover` if hidden, and closes if visible.
- **T1-F11-04 (Transient Popover Behavior)**: Popover behavior is set to `.transient` to auto-dismiss on outside interactions.
- **T1-F11-05 (Popover Positioning)**: Popover anchors directly below the status item button rect.

### Feature 12: Floating Panel Presentation
- **T1-F12-01 (Floating Panel Instantiation)**: Panel is initialized with `.nonactivatingPanel` mask and `.floating` window level.
- **T1-F12-02 (Borderless Presentation)**: Panel style mask has `.borderless` or custom transparent chrome without standard titlebar.
- **T1-F12-03 (Key Window Acceptance)**: Subclassed panel overrides `canBecomeKey` to return `true`.
- **T1-F12-04 (Mouse Centering Anchor)**: Default positioning centers or places panel origin adjacent to `NSEvent.mouseLocation`.
- **T1-F12-05 (Visibility State Check)**: Summoning panel sets `isVisible` to `true` and orders window front.

### Feature 13: Screen Coordinate Clamping
- **T1-F13-01 (Top Edge Clamping)**: Panel position with cursor near top of screen clamps below menu bar (`visibleFrame.maxY`).
- **T1-F13-02 (Bottom Edge Clamping)**: Panel position with cursor near bottom clamps above Dock (`visibleFrame.minY`).
- **T1-F13-03 (Left Edge Clamping)**: Panel position near left screen edge clamps at `visibleFrame.minX`.
- **T1-F13-04 (Right Edge Clamping)**: Panel position near right edge clamps so `frame.maxX <= visibleFrame.maxX`.
- **T1-F13-05 (Multi-Monitor Target Selection)**: Target screen is determined by checking which `NSScreen` contains cursor coordinates.

### Feature 14: Panel Dismissal on Escape
- **T1-F14-01 (Escape Key Interception)**: Pressing Escape key triggers `cancelOperation:` and hides the floating panel.
- **T1-F14-02 (Popover Escape Dismissal)**: Pressing Escape while popover is active dismisses the popover.
- **T1-F14-03 (Clean Focus Release)**: Dismissal via Escape clears search query and resets active focus.
- **T1-F14-04 (No Side Effects)**: Dismissing via Escape does not modify clipboard contents.
- **T1-F14-05 (Re-Open Clean State)**: Opening panel after Escape dismissal presents initial view ready for input.

### Feature 15: Panel Dismissal on Outside Click
- **T1-F15-01 (Global Click Listener)**: Clicking mouse coordinates outside panel boundary initiates window dismissal.
- **T1-F15-02 (Resign Key Notification)**: Window losing key status triggers panel hiding.
- **T1-F15-03 (Inside Click Non-Dismissal)**: Clicking within search bar or row controls does not dismiss panel.
- **T1-F15-04 (Status Bar Outside Dismissal)**: Popover closes when user clicks anywhere outside popover bounds.
- **T1-F15-05 (Monitor Teardown)**: Dismissal tears down or deactivates active mouse monitors.

### Feature 16: Dismissal on Item Selection
- **T1-F16-01 (Selection Click Dismissal)**: Clicking an item row dismisses the floating panel or popover immediately.
- **T1-F16-02 (Keyboard Return Dismissal)**: Selecting an item via keyboard Enter/Return dismisses the panel.
- **T1-F16-03 (Number Key Dismissal)**: Pressing number keys 1..9 triggers item copy and dismisses panel.
- **T1-F16-04 (Dismissal Timing)**: Panel hides within 50ms of item selection.
- **T1-F16-05 (Pasteboard Update Precedence)**: Clipboard payload is written before panel dismissal completes.

### Feature 17: Carbon Global Hotkey (Zero AX)
- **T1-F17-01 (HotKey Registration)**: `RegisterEventHotKey` successfully returns `noErr` (status 0).
- **T1-F17-02 (Zero Accessibility Dependency)**: Hotkey triggers without requesting or requiring `AXIsProcessTrusted`.
- **T1-F17-03 (HotKey Event Handler)**: Carbon event handler receives `kEventHotKeyPressed` and fires callback.
- **T1-F17-04 (HotKey Unregistration)**: `UnregisterEventHotKey` de-registers hotkey cleanly on termination.
- **T1-F17-05 (Target Window Independence)**: Hotkey triggers regardless of which third-party application is currently active.

### Feature 18: Default Hotkey (Option + V)
- **T1-F18-01 (Default Keycode Mapping)**: Default key code corresponds to `kVK_ANSI_V` (value 9).
- **T1-F18-02 (Default Modifier Mapping)**: Default modifier flags map to Carbon `optionKey` (`0x0800`).
- **T1-F18-03 (Default Action Summons Panel)**: Pressing Option+V executes presentation callback.
- **T1-F18-04 (Toggle Visibility via Hotkey)**: Pressing Option+V when panel is already visible closes the panel.
- **T1-F18-05 (Settings Default Initialization)**: Initializing fresh settings defaults `hotKeyKeyCode` to Option+V.

### Feature 19: Auto-Focused Search Bar
- **T1-F19-01 (Search Field First Responder)**: On panel presentation, search text field automatically receives first responder status.
- **T1-F19-02 (Immediate Key Input)**: Typing immediately after summons directs keystrokes into search field without clicking.
- **T1-F19-03 (Clear Button Visibility)**: Typing text renders search field clear ("x") button.
- **T1-F19-04 (Clear Button Action)**: Clicking clear button empties search query and restores full list.
- **T1-F19-05 (Placeholder String)**: Search field displays informative placeholder (e.g., "Search clips...").

### Feature 20: Real-Time Substring Filtering
- **T1-F20-01 (Case-Insensitive Match)**: Searching `"swift"` matches `"Swift"`, `"SWIFT"`, and `"swift"`.
- **T1-F20-02 (Substring Match)**: Searching `"board"` matches `"clipboard manager"`.
- **T1-F20-03 (Empty Query Full Set)**: Empty search query restores 100% of pinned and unpinned clips.
- **T1-F20-04 (Non-Matching Query)**: Query with no matching items produces empty result list and zero-results state.
- **T1-F20-05 (Image Label Search)**: Image clips match queries targeting their label (e.g., `"Image (800x600)"`).

### Feature 21: Partitioned List Sections
- **T1-F21-01 (Section Partitioning)**: List renders distinct "Pinned" section and "Recent History" section.
- **T1-F21-02 (Pinned Section Ordering)**: Pinned section shows pinned clips at the top of the interface.
- **T1-F21-03 (Unpinned Section Ordering)**: Recent History shows unpinned clips ordered newest first.
- **T1-F21-04 (Empty Pinned Section Handling)**: When zero clips are pinned, pinned section header is cleanly hidden or empty.
- **T1-F21-05 (Dynamic Section Relocation)**: Toggling pin on an unpinned clip instantly moves it to the Pinned section.

### Feature 22: Number Shortcuts (1..9)
- **T1-F22-01 (Key 1 Shortcut)**: Pressing key `1` selects and copies the 1st visible item in the list.
- **T1-F22-02 (Key 9 Shortcut)**: Pressing key `9` selects and copies the 9th visible item if at least 9 items exist.
- **T1-F22-03 (Filtered List Shortcut Mapping)**: When search query is active, keys 1..9 map to the filtered visible list.
- **T1-F22-04 (Out-of-Bounds Shortcut)**: Pressing `5` when only 3 items are visible executes no operation safely.
- **T1-F22-05 (Shortcut UI Badge)**: Visible rows display number badge indicators (1 through 9) next to row items.

### Feature 23: Per-Row Pin/Unpin Action
- **T1-F23-01 (Pin Button Presentation)**: Each row displays a pin toggle button using SF Symbol `pin` / `pin.fill`.
- **T1-F23-02 (Unpinned to Pinned Toggle)**: Clicking pin button on unpinned item marks it pinned.
- **T1-F23-03 (Pinned to Unpinned Toggle)**: Clicking pin button on pinned item marks it unpinned and moves to history.
- **T1-F23-04 (Storage State Sync)**: Toggling pin via row action invokes `StorageManager.togglePin(id:)`.
- **T1-F23-05 (Accessibility Label)**: Pin button provides accessible description ("Pin clip" / "Unpin clip").

### Feature 24: Per-Row Copy Action
- **T1-F24-01 (Copy Button Presentation)**: Each row displays a dedicated copy action button (`doc.on.doc`).
- **T1-F24-02 (Copy Action Payload Write)**: Clicking copy button writes exact clip data to `NSPasteboard.general`.
- **T1-F24-03 (Self-Copy Suppression Integration)**: Copy button action marks self-copy to prevent re-recording.
- **T1-F24-04 (Panel Dismissal on Copy Button)**: Clicking copy button dismisses the presentation panel.
- **T1-F24-05 (Image Copy Button Action)**: Clicking copy on an image row writes PNG/TIFF image data to pasteboard.

### Feature 25: Per-Row Delete Action
- **T1-F25-01 (Delete Button Presentation)**: Each row displays a delete button using SF Symbol `trash`.
- **T1-F25-02 (Item Removal from Store)**: Clicking delete button invokes `deleteItem(id:)` and removes clip from memory.
- **T1-F25-03 (Disk File Deletion)**: Deleting image clip deletes original PNG and thumbnail file from disk.
- **T1-F25-04 (Remaining Items Retention)**: Deleting an item leaves all other items intact and correctly positioned.
- **T1-F25-05 (Delete in Search Mode)**: Deleting an item while searching maintains search filter and updates list.

### Feature 26: Flat Design SF Symbols
- **T1-F26-01 (System SF Symbols Availability)**: All referenced SF Symbols exist and load via `NSImage(systemSymbolName:)`.
- **T1-F26-02 (No External Asset Dependencies)**: UI renders entirely using system vectors without external image files.
- **T1-F26-03 (Status Icon Vector Fidelity)**: Status item icon renders cleanly at 16x16 and 32x32 Retina resolutions.
- **T1-F26-04 (Monochrome & Hierarchical Styling)**: Symbols utilize native macOS hierarchical and monochrome color palettes.
- **T1-F26-05 (Consistent Symbol Set)**: UI uses standardized symbols: `doc.on.clipboard`, `pin`, `trash`, `magnifyingglass`, `gearshape`.

### Feature 27: Zero Emojis Constraint
- **T1-F27-01 (Source Code Emoji Audit)**: Static scanner scans all `.swift` files and finds zero emoji unicode codepoints.
- **T1-F27-02 (UI String Emoji Audit)**: All labels, buttons, alerts, and placeholders contain zero emoji characters.
- **T1-F27-03 (Test Code Emoji Audit)**: All test files, test descriptions, and logs contain zero emoji characters.
- **T1-F27-04 (Build Scripts & Makefile Audit)**: Makefile, Info.plist, and scripts contain zero emoji characters.
- **T1-F27-05 (Markdown Documentation Audit)**: Markdown docs (excluding spec quote references) enforce zero emoji symbols.

### Feature 28: Copy-Only Interaction Model
- **T1-F28-01 (Zero Synthetic Keystrokes)**: Selecting an item executes zero `CGEventCreateKeyboardEvent` paste simulations.
- **T1-F28-02 (Accessibility Permission Exemption)**: App operates without prompting for or requiring macOS Accessibility permissions.
- **T1-F28-03 (Direct Pasteboard Write)**: Item payload is written directly to `NSPasteboard.general` via AppKit API.
- **T1-F28-04 (User Control Preservation)**: Selected item is immediately ready in clipboard for manual user pasting via Cmd+V.
- **T1-F28-05 (Clipboard Type Fidelity)**: Plain text is written as `public.utf8-plain-text`; images written as `public.png` and `public.tiff`.

### Feature 29: Hotkey Customization UI
- **T1-F29-01 (Hotkey Settings View)**: Settings interface presents key code and modifier customization controls.
- **T1-F29-02 (Key Combination Validation)**: Modifier validation ensures hotkey includes at least one modifier (e.g. Option, Command).
- **T1-F29-03 (Dynamic Re-Registration)**: Changing hotkey unregisters old hotkey and registers new hotkey in real time.
- **T1-F29-04 (Settings Persistence)**: Custom hotkey preferences persist to disk under `metadata.json` / `AppSettings`.
- **T1-F29-05 (Reset to Default Action)**: "Reset to Default" button restores hotkey to Option+V.

### Feature 30: Capacity Adjustment UI
- **T1-F30-01 (Capacity Slider / Stepper)**: Settings interface provides capacity adjustment control (range: 10 to 500).
- **T1-F30-02 (Capacity State Update)**: Modifying capacity updates `StorageManager.capacity`.
- **T1-F30-03 (Immediate Eviction on Downscale)**: Lowering capacity below current unpinned count evicts excess oldest unpinned items immediately.
- **T1-F30-04 (Capacity Persistence)**: Custom capacity value persists to disk and reloads on app launch.
- **T1-F30-05 (Default Capacity Fallback)**: Fresh configuration defaults unpinned capacity to exactly 100 items.

### Feature 31: Menu Bar Agent Mode (LSUIElement)
- **T1-F31-01 (Info.plist LSUIElement Property)**: Application `Info.plist` contains `<key>LSUIElement</key><true/>`.
- **T1-F31-02 (Dock Icon Suppression)**: App runs without appearing in macOS Dock.
- **T1-F31-03 (Force-Quit Menu Discretion)**: App runs as background accessory without appearing in standard Cmd+Tab switcher.
- **T1-F31-04 (plutil Lint Validation)**: Running `plutil -lint` against `SuperClip.app/Contents/Info.plist` reports `OK`.
- **T1-F31-05 (Menu Bar Only Presence)**: User interface interaction is strictly anchored to status item and floating panel.

### Feature 32: App Bundle Packaging (Makefile)
- **T1-F32-01 (Makefile Package Target)**: Executing `make package` produces standalone `SuperClip.app` bundle.
- **T1-F32-02 (Bundle Directory Hierarchy)**: `SuperClip.app` contains `Contents/MacOS/`, `Contents/Resources/`, and `Contents/Info.plist`.
- **T1-F32-03 (ICNS Icon Generation)**: `make package` generates and includes valid `AppIcon.icns`.
- **T1-F32-04 (Ad-Hoc Codesign)**: App bundle is signed with ad-hoc signature (`codesign -s -`).
- **T1-F32-05 (Codesign Verification)**: Running `codesign --verify --verbose SuperClip.app` returns 0 with no errors.

### Feature 33: Programmatic Persistence Test
- **T1-F33-01 (Direct Storage Class Test)**: Automated test verifies `StorageManager` write and read cycle programmatically.
- **T1-F33-02 (Corrupt File Tolerance)**: Test verifies initialization over corrupted JSON falls back to clean state safely.
- **T1-F33-03 (Multi-Thread Concurrent Add)**: Test adds 50 clips concurrently across multiple threads without crashes or data loss.
- **T1-F33-04 (Payload Integrity)**: Test confirms persisted string and metadata match original bytes exactly.
- **T1-F33-05 (Isolated Sandbox Path)**: Test strictly operates inside temporary sandbox URL.

### Feature 34: Programmatic Thumbnail Test
- **T1-F34-01 (Thumbnail Generation Execution)**: Programmatic test passes synthetic bitmap through `ThumbnailGenerator`.
- **T1-F34-02 (Pixel Dimension Assertion)**: Test asserts resulting thumbnail max dimension <= 180px.
- **T1-F34-03 (Disk Existence Check)**: Test asserts thumbnail file exists at generated URL on disk.
- **T1-F34-04 (PNG Format Assertion)**: Test verifies thumbnail file signature matches PNG magic bytes.
- **T1-F34-05 (Invalid Image Rejection)**: Test asserts passing corrupt image bytes returns `nil` safely without crashing.

### Feature 35: Programmatic Search Test
- **T1-F35-01 (Query Match Verification)**: Test adds 20 varied items and queries specific substrings.
- **T1-F35-02 (Case Insensitivity Assertion)**: Test verifies identical results for `"TEST"`, `"test"`, and `"Test"`.
- **T1-F35-03 (Empty Query Restoration Assertion)**: Test asserts empty string query returns all items.
- **T1-F35-04 (Partition Preservation in Search)**: Test verifies search preserves pinned and unpinned grouping.
- **T1-F35-05 (Special Character Query)**: Test queries containing punctuation (e.g. `!`, `?`, `/`, `-`) operate cleanly.

### Feature 36: Programmatic Pin Retention Test
- **T1-F36-01 (Capacity Overflow Retention)**: Automated test fills storage beyond capacity and verifies pinned items remain.
- **T1-F36-02 (Clear History Retention)**: Test invokes `clearUnpinnedHistory()` and verifies pinned items remain.
- **T1-F36-03 (Toggle Pin State Retention)**: Test unpins a pinned item, then confirms it becomes eligible for FIFO eviction.
- **T1-F36-04 (Pinned Image Asset Retention)**: Test confirms image files of pinned clips are retained on disk.
- **T1-F36-05 (100% Pinned Item Capacity Overflow)**: Test fills store with 100 pinned items, adds 1 unpinned, verifies 101 items exist.

### Feature 37: Programmatic Pasteboard Test
- **T1-F37-01 (Headless Pasteboard Write)**: Programmatic test writes text to `NSPasteboard.general` and reads back identical string.
- **T1-F37-02 (Headless Image Pasteboard Write)**: Test writes PNG data to `NSPasteboard.general` and reads back matching data.
- **T1-F37-03 (ChangeCount Increment Assertion)**: Test asserts `changeCount` increments following write.
- **T1-F37-04 (Self-Copy Suppression Integration)**: Test verifies `markSelfCopy` suppresses monitor event for programmatic write.
- **T1-F37-05 (Zero Accessibility Validation)**: Test confirms execution without `AXIsProcessTrusted` requirement.

### Feature 38: Automated Zero-Emoji Scan
- **T1-F38-01 (Source Directory Scan)**: Automated script scans `Sources/` and verifies 0 emoji characters found.
- **T1-F38-02 (Tests Directory Scan)**: Script scans `Tests/` and verifies 0 emoji characters found.
- **T1-F38-03 (Scripts Directory Scan)**: Script scans `Scripts/` and verifies 0 emoji characters found.
- **T1-F38-04 (Configuration Files Scan)**: Script scans `Makefile`, `Package.swift`, `Info.plist` and verifies 0 emojis.
- **T1-F38-05 (Synthesized Emoji Detection Test)**: Test runs scanner against dummy file containing an emoji character and asserts failure exit code (code 1).

---

## 4. Tier 2: Boundary & Corner Cases (>=5 Test Cases per Feature for all 38 Features)

Total Tier 2 Test Cases: **190 test cases** (38 features x 5 boundary test cases).

### Feature 1: ChangeCount Polling Monitor Boundaries
- **T2-F01-01 (Int.max ChangeCount Rollover)**: Monitor handles integer overflow or high `changeCount` values without crashing.
- **T2-F01-02 (Zero Interval Handling)**: Passing 0ms interval clamps to minimum safe interval (e.g. 50ms).
- **T2-F01-03 (Rapid Successive Starts)**: Calling `startPolling()` 10 times in immediate succession creates only 1 timer.
- **T2-F01-04 (Rapid Successive Stops)**: Calling `stopPolling()` 10 times consecutively causes no exceptions.
- **T2-F01-05 (Pasteboard Clear Event)**: Clearing pasteboard without setting new data handled cleanly without crash.

### Feature 2: Plain Text Capture Boundaries
- **T2-F02-01 (Zero-Length Empty String)**: Copying `""` is discarded or handled without creating empty phantom clip.
- **T2-F02-02 (Huge Text Payload 5MB)**: Copying 5MB string succeeds without out-of-memory error and stores payload.
- **T2-F02-03 (Whitespace-Only String)**: Copying strings with only spaces, tabs, or newlines is safely preserved or handled.
- **T2-F02-04 (Control Characters & Null Bytes)**: Copying strings containing null bytes (`\0`) and ANSI escape codes preserves data safely.
- **T2-F02-05 (Complex Unicode Surrogate Pairs)**: Copying math symbols and non-BMP scripts without emojis preserves UTF-8 fidelity.

### Feature 3: Image Payload Capture Boundaries
- **T2-F03-01 (1x1 Pixel Micro Image)**: Ingesting 1x1 pixel PNG processes without division-by-zero or scaling crash.
- **T2-F03-02 (Huge Image Ingestion 10000x10000)**: Ingesting massive image scales down safely without crashing memory.
- **T2-F03-03 (Extreme Aspect Ratio 10000x1)**: Ingesting 10000x1 panoramic strip image downscales to 180x1 thumbnail.
- **T2-F03-04 (Extreme Aspect Ratio 1x10000)**: Ingesting 1x10000 tall vertical strip downscales to 1x180 thumbnail.
- **T2-F03-05 (Corrupted Image Header)**: Pasteboard with invalid PNG header is rejected gracefully without crashing.

### Feature 4: Thumbnail Generation Boundaries
- **T2-F04-01 (Zero-Byte Image Data)**: Passing empty `Data()` to `ThumbnailGenerator` returns `nil` safely.
- **T2-F04-02 (Non-Image Data Input)**: Passing arbitrary text or binary data returns `nil`.
- **T2-F04-03 (Target Size Equals Input Size)**: Image already exactly 180x180 produces valid 180x180 thumbnail without upscaling.
- **T2-F04-04 (Smaller Than Target Size)**: Image 50x50 maintains original 50x50 resolution without distortion.
- **T2-F04-05 (Transparent Alpha Channel)**: PNG with transparency preserves alpha channel without rendering black background.

### Feature 5: Self-Copy Loop Suppression Boundaries
- **T2-F05-01 (Negative ChangeCount Handling)**: Passing negative change count to `markSelfCopy` handles safely.
- **T2-F05-02 (Out-of-Order ChangeCount)**: Slower asynchronous write arriving with older change count is handled safely.
- **T2-F05-03 (Rapid Writeback Burst)**: 20 rapid self-copy writes back-to-back cause zero feedback loops.
- **T2-F05-04 (External Simultaneous Write)**: User copying in another app simultaneously with self-copy captures external item.
- **T2-F05-05 (Self-Copy Clear Handling)**: Self-copy write that clears pasteboard first is suppressed cleanly.

### Feature 6: Duplicate Promotion Boundaries
- **T2-F06-01 (Duplicate with Trailing Spaces)**: String `"abc"` vs `"abc "` treated as distinct items.
- **T2-F06-02 (Case Sensitivity in Duplicate Check)**: String `"Hello"` vs `"hello"` treated as distinct clips.
- **T2-F06-03 (Duplicate Image Ingestion)**: Copying identical image data promotes existing image clip or handles cleanly.
- **T2-F06-04 (Duplicate at Bottom of 100 Items)**: Promoting item at position 100 moves it to index 0 smoothly.
- **T2-F06-05 (Self-Duplicate Promotion)**: Promoting item already at index 0 is a no-op that leaves list unchanged.

### Feature 7: File System Persistence Boundaries
- **T2-F07-01 (Read-Only Directory)**: Attempting to write to read-only directory fails gracefully without crashing.
- **T2-F07-02 (Truncated JSON Recovery)**: Opening zero-byte or truncated `metadata.json` recovers with empty store.
- **T2-F07-03 (Missing Images Directory)**: Storing image when `images/` directory was deleted recreates directory.
- **T2-F07-04 (Disk Full Emulation)**: Write failure due to disk space throws handled error and preserves in-memory state.
- **T2-F07-05 (Special Characters in Path)**: Sandbox directory path containing spaces and unicode characters functions identically.

### Feature 8: FIFO Unpinned Eviction Boundaries
- **T2-F08-01 (Capacity Zero / Minimum 1)**: Setting capacity to 1 evicts down to 1 unpinned item immediately.
- **T2-F08-02 (Large Capacity 1000)**: Setting capacity to 1000 manages large item sets without performance degradation.
- **T2-F08-03 (Mass Eviction Burst)**: Adding 200 items in a single loop when capacity is 50 leaves exactly 50 items.
- **T2-F08-04 (Eviction with Missing Asset File)**: Evicting clip whose image was already removed on disk succeeds cleanly.
- **T2-F08-05 (Equal Timestamp Eviction)**: Multiple clips with identical timestamps evicted deterministically in order of insertion.

### Feature 9: Pin Persistence & Protection Boundaries
- **T2-F09-01 (100% Pinned Items Eviction Exemption)**: Store containing 50 pinned items and 0 unpinned items evicts 0 items.
- **T2-F09-02 (Pinning and Immediate Unpinning)**: Rapidly toggling pin 10 times leaves state consistent.
- **T2-F09-03 (Pinning Non-Existent UUID)**: Calling `togglePin(id:)` with random UUID causes no crash or side effects.
- **T2-F09-04 (Pin Retention Under Capacity 0)**: Pinned items survive even if capacity is set to minimum.
- **T2-F09-05 (Pinning All Items in History)**: All 100 history items marked pinned are 100% protected.

### Feature 10: Clear Unpinned History Boundaries
- **T2-F10-01 (Clear When All Items Pinned)**: Store with only pinned items retains all items when cleared.
- **T2-F10-02 (Clear When All Items Unpinned)**: Store with only unpinned items becomes completely empty.
- **T2-F10-03 (Clear with Missing Image Assets)**: Disk cleanup tolerates files that were manually deleted beforehand.
- **T2-F10-04 (Rapid Successive Clear Calls)**: Calling `clearUnpinnedHistory()` 5 times consecutively executes cleanly.
- **T2-F10-05 (Clear During Concurrent Ingestion)**: Clearing unpinned history while a new clip arrives handles concurrency safely.

### Feature 11: Status Bar Icon & Popover Boundaries
- **T2-F11-01 (Dark Mode & Light Mode Transition)**: Status bar SF Symbol adapts appearance seamlessly across system appearance changes.
- **T2-F11-02 (Multi-Monitor Menu Bar)**: Status bar item displays correctly regardless of primary display menu bar state.
- **T2-F11-03 (Rapid Click Toggle)**: Clicking status item 10 times in 1 second toggles popover cleanly without glitching.
- **T2-F11-04 (Screen Resolution Change)**: Popover positioning updates cleanly after display resolution change.
- **T2-F11-05 (Popover Content Size Bounds)**: Popover frame respects minimum and maximum content sizing.

### Feature 12: Floating Panel Presentation Boundaries
- **T2-F12-01 (Cursor at Extreme Coordinates)**: Mouse cursor at `(0, 0)` positions panel cleanly without negative origins.
- **T2-F12-02 (Cursor on Secondary Display)**: Summoning on secondary display anchors panel within secondary display bounds.
- **T2-F12-03 (Zero-Size Panel Protection)**: Sizing calculation handles minimum panel size constraints safely.
- **T2-F12-04 (Rapid Summons Hotkey Spam)**: Spamming hotkey summons and re-summons without leaking window instances.
- **T2-F12-05 (Full Screen App Overlay)**: Floating panel displays above full-screen windows due to `.floating` window level.

### Feature 13: Screen Coordinate Clamping Boundaries
- **T2-F13-01 (Negative Mouse Coordinates)**: Mouse at `(-500, -500)` clamps to nearest display visible frame.
- **T2-F13-02 (Massive Out-of-Bounds Coordinates)**: Mouse at `(99999, 99999)` clamps within display frame bounds.
- **T2-F13-03 (Left-Side Dock Clamping)**: When Dock is positioned on left of screen, panel clamps right of Dock boundary.
- **T2-F13-04 (Right-Side Dock Clamping)**: When Dock is positioned on right, panel clamps left of Dock boundary.
- **T2-F13-05 (Zero-Screen Fallback)**: Passing `nil` target screen falls back safely to `NSScreen.main` or primary display.

### Feature 14: Panel Dismissal on Escape Boundaries
- **T2-F14-01 (Escape While Search Field Focused)**: First Escape press when query is non-empty clears query; second dismisses (or dismisses cleanly).
- **T2-F14-02 (Escape While Button Focused)**: Escape dismisses panel even if focus is on a row button.
- **T2-F14-03 (Rapid Escape Presses)**: Pressing Escape multiple times causes no errors or unhandled events.
- **T2-F14-04 (Escape During Item Loading)**: Pressing Escape while thumbnail is decoding cancels cleanly.
- **T2-F14-05 (Escape With No Items in Store)**: Dismissing empty store view via Escape operates cleanly.

### Feature 15: Panel Dismissal on Outside Click Boundaries
- **T2-F15-01 (Click on Screen Seam Boundary)**: Clicking on exact display edge dismisses panel.
- **T2-F15-02 (Click on Menu Bar Area)**: Clicking menu bar outside status icon dismisses floating panel.
- **T2-F15-03 (Right Click Outside)**: Right-clicking outside panel boundaries dismisses panel.
- **T2-F15-04 (Click on Status Bar Icon While Panel Open)**: Clicking status icon dismisses floating panel.
- **T2-F15-05 (Drag Event Outside Boundary)**: Dragging mouse outside panel dismisses panel.

### Feature 16: Dismissal on Item Selection Boundaries
- **T2-F16-01 (Selection with Corrupted Disk Image)**: Selecting image whose disk asset was removed fails gracefully without crash.
- **T2-F16-02 (Rapid Double Click Selection)**: Rapid double-clicking row triggers single copy and single clean dismissal.
- **T2-F16-03 (Selection During Active Search Filter)**: Selecting item from filtered search results copies correct item.
- **T2-F16-04 (Selection of 100th Item)**: Selecting item at the bottom of long scrolling list operates cleanly.
- **T2-F16-05 (Selection While Background Polling Active)**: Selection and writeback execute atomically without collision with poll tick.

### Feature 17: Carbon Global Hotkey (Zero AX) Boundaries
- **T2-F17-01 (Re-registering Same Hotkey)**: Registering already active hotkey updates reference cleanly.
- **T2-F17-02 (Unregistering Unregistered Hotkey)**: Calling unregister when no hotkey is registered causes no error.
- **T2-F17-03 (System Reserved Key Combination)**: Attempting to register Cmd+Tab or Cmd+Q is handled safely.
- **T2-F17-04 (All Modifiers Active)**: Hotkey with Cmd+Shift+Option+Control registers and fires.
- **T2-F17-05 (Fn / Globe Key Exemption)**: System modifiers handle standard Carbon modifier flags without crash.

### Feature 18: Default Hotkey (Option + V) Boundaries
- **T2-F18-01 (Caps Lock Active)**: Option+V triggers correctly even when Caps Lock is toggled on.
- **T2-F18-02 (Right Option Key vs Left Option Key)**: Both left and right Option keys satisfy the Option+V hotkey.
- **T2-F18-03 (Non-US Keyboard Layout)**: Option+V maps to correct virtual keycode across Dvorak / AZERTY layouts.
- **T2-F18-04 (Holding Hotkey Down)**: Holding Option+V fires single trigger or throttles repeat events.
- **T2-F18-05 (Hotkey Trigger in Terminal)**: Hotkey fires cleanly while active application is fullscreen Terminal.

### Feature 19: Auto-Focused Search Bar Boundaries
- **T2-F19-01 (Search Field With 10,000 Characters)**: Pasting huge string into search field handles text without lagging.
- **T2-F19-02 (Focus Retention After Empty Result)**: Search field retains first responder focus even when 0 matches found.
- **T2-F19-03 (Tab Key Navigation)**: Pressing Tab navigates focus out of search field to first list item.
- **T2-F19-04 (Backspace on Empty Field)**: Pressing Backspace when field is empty produces no error or beep.
- **T2-F19-05 (IME Composition Text)**: Typing Japanese / Chinese IME text filters correctly on marked text commit.

### Feature 20: Real-Time Substring Filtering Boundaries
- **T2-F20-01 (Regex Meta-Characters in Query)**: Queries with `.*+?^${}()|[]\` treated as literal substrings.
- **T2-F20-02 (Leading and Trailing Spaces in Query)**: Query with `"  test  "` matches `"test"` properly.
- **T2-F20-03 (Diacritics & Accents Query)**: Searching `"resume"` matches `"résumé"` under localized comparison.
- **T2-F20-04 (1-Character Rapid Query Typing)**: Typing single letters rapidly filters list smoothly without stutter.
- **T2-F20-05 (Query Longer Than Any Item)**: Query longer than 200 characters immediately yields empty list.

### Feature 21: Partitioned List Sections Boundaries
- **T2-F21-01 (Single Item in Each Section)**: Exactly 1 pinned and 1 unpinned item renders both headers properly.
- **T2-F21-02 (Zero Unpinned Items in Store)**: Store with only pinned items hides "Recent History" cleanly.
- **T2-F21-03 (Zero Pinned Items in Store)**: Store with only unpinned items hides "Pinned" section cleanly.
- **T2-F21-04 (Massive Item Count in Pinned 200+)**: Pinned section with 200 items scrolls smoothly.
- **T2-F21-05 (Dynamic Transfer Between Sections)**: Unpinning an item shifts it to unpinned section with smooth visual update.

### Feature 22: Number Shortcuts (1..9) Boundaries
- **T2-F22-01 (Key 0 and Letters)**: Pressing `0` or alphanumeric letters does not trigger shortcut selection.
- **T2-F22-02 (Numpad Digits vs Top-Row Digits)**: Number shortcuts handle both top-row digits and numpad keys.
- **T2-F22-03 (Number Shortcut While Search Has 1 Result)**: Only key `1` triggers selection; keys 2..9 are ignored.
- **T2-F22-04 (Shortcut Trigger During Animation)**: Pressing shortcut key during list load executes safely.
- **T2-F22-05 (Modifier + Number Key)**: Pressing Cmd+1 or Option+1 is not consumed by the 1..9 row shortcut handler.

### Feature 23: Per-Row Pin/Unpin Action Boundaries
- **T2-F23-01 (Toggling Pin While Filtered in Search)**: Toggling pin during active search updates item without losing filter.
- **T2-F23-02 (Repeated Rapid Pin Clicks)**: Double-clicking pin button rapidly toggles state deterministically.
- **T2-F23-03 (Pinning Last Eviction Candidate)**: Pinning oldest item instantly protects it from impending eviction.
- **T2-F23-04 (Hover State Visuals)**: Hovering over pin button provides visual feedback without triggering action.
- **T2-F23-05 (Keyboard Spacebar on Pin Button)**: Activating pin button via keyboard Space/Return toggles pin.

### Feature 24: Per-Row Copy Action Boundaries
- **T2-F24-01 (Copying Extremely Large Text Row)**: Copy button on 1MB text item executes copy without UI lag.
- **T2-F24-02 (Copying Damaged Thumbnail Row)**: Copy button succeeds even if thumbnail file is missing on disk.
- **T2-F24-03 (Copy Button When Pasteboard Is Locked)**: Handled gracefully if another app locks pasteboard temporarily.
- **T2-F24-04 (Consecutive Copy Button Clicks)**: Clicking copy button on same row multiple times is handled safely.
- **T2-F24-05 (Copy Button on Filtered Search View)**: Copy button copies correct underlying model item.

### Feature 25: Per-Row Delete Action Boundaries
- **T2-F25-01 (Deleting Only Item in List)**: Deleting single remaining item leaves UI in clean empty state.
- **T2-F25-02 (Deleting First Pinned Item)**: Deleting top pinned item preserves remaining pinned items order.
- **T2-F25-03 (Deleting While Image File Inaccessible)**: Delete removes metadata even if disk file is locked or missing.
- **T2-F25-04 (Deleting Middle Item in 100-Item List)**: Deleting item at index 50 updates index mapping cleanly.
- **T2-F25-05 (Deleting All Items One-by-One)**: Deleting all items iteratively completes with zero memory leaks.

### Feature 26: Flat Design SF Symbols Boundaries
- **T2-F26-01 (Missing Symbol Fallback)**: In the event of system symbol failure, safe fallback renders cleanly.
- **T2-F26-02 (Dynamic Type Scaling)**: SF Symbols scale gracefully under larger system text accessibility sizes.
- **T2-F26-03 (High-Contrast Accessibility Mode)**: Icons remain clearly visible in macOS Increase Contrast mode.
- **T2-F26-04 (Retina @2x and @3x Scaling)**: Symbols render sharp vectors without pixelation on Retina screens.
- **T2-F26-05 (Zero Color Glitches)**: Monochrome tints render consistently across accent color changes.

### Feature 27: Zero Emojis Constraint Boundaries
- **T2-F27-01 (Unicode Symbols vs Emojis)**: Technical symbols (e.g. `⌘`, `⌥`, `⇧`, `⏎`) are permitted; emojis (e.g. U+1F4CB clipboard) blocked.
- **T2-F27-02 (Dingbats & Pictographs Blocked)**: Unicode range `0x2700-0x27BF` dingbats flagged by linter.
- **T2-F27-03 (Variation Selectors Blocked)**: Variation selectors `0xFE0E` and `0xFE0F` flagged by linter.
- **T2-F27-04 (Emoticon Codepoints Blocked)**: `0x1F600-0x1F64F` emoticons strictly blocked.
- **T2-F27-05 (Zero Emoji In User-Visible Labels)**: Window titles, tooltips, and buttons contain 0 emojis.

### Feature 28: Copy-Only Interaction Model Boundaries
- **T2-F28-01 (Copying 10MB Raw Text)**: Copy-only writes 10MB text directly to pasteboard without timeout.
- **T2-F28-02 (Non-String Non-Image Clip Handling)**: Gracefully rejects or handles unsupported types.
- **T2-F28-03 (No CGEvent Invocations)**: Binary contains zero references to `CGEventCreateKeyboardEvent`.
- **T2-F28-04 (Zero Carbon Key Injection)**: Zero synthetic key codes dispatched to target process.
- **T2-F28-05 (Multi-Format Pasteboard Write)**: Text item written with both UTF-8 and plain text flavors.

### Feature 29: Hotkey Customization UI Boundaries
- **T2-F29-01 (No Modifiers Selected)**: Custom hotkey without modifiers is rejected with validation notice.
- **T2-F29-02 (Escape Key as Hotkey)**: Attempting to assign Escape key as global hotkey is blocked.
- **T2-F29-03 (Duplicate Existing Shortcut)**: Reassigning existing hotkey updates safely.
- **T2-F29-04 (Function Keys F1..F12)**: Function keys with modifiers register cleanly.
- **T2-F29-05 (Invalid Key Code Recovery)**: Corrupted key code in settings falls back to Option+V.

### Feature 30: Capacity Adjustment UI Boundaries
- **T2-F30-01 (Minimum Capacity Boundary 10)**: Stepper / slider cannot decrease capacity below 10.
- **T2-F30-02 (Maximum Capacity Boundary 500)**: Stepper / slider cannot increase capacity above 500.
- **T2-F30-03 (Direct Text Input NaN)**: Passing invalid characters to capacity field reverts to previous value.
- **T2-F30-04 (Negative Capacity Value)**: Negative capacity loaded from corrupt config clamps to default 100.
- **T2-F30-05 (Zero Capacity Value)**: Zero capacity loaded from config clamps to default 100.

### Feature 31: Menu Bar Agent Mode (LSUIElement) Boundaries
- **T2-F31-01 (LSUIElement String vs Boolean)**: Info.plist enforces boolean `<true/>` rather than string `"true"`.
- **T2-F31-02 (No Main Menu Bar Bar Nib)**: App runs without requiring `MainMenu.xib`.
- **T2-F31-03 (Background Activation Policy)**: `NSApplication.setActivationPolicy(.accessory)` maintained.
- **T2-F31-04 (Window Order Front Independence)**: Floating panel displays without bringing hidden app to front.
- **T2-F31-05 (Termination from Menu Bar)**: Status bar menu or settings provides clean "Quit SuperClip" action.

### Feature 32: App Bundle Packaging Boundaries
- **T2-F32-01 (Bundle Overwrite Clean)**: Running `make package` over existing `SuperClip.app` updates cleanly.
- **T2-F32-02 (Missing CommandLineTools SDK)**: Build script reports actionable error if SDK path missing.
- **T2-F32-03 (Codesign Re-Signing Integrity)**: Re-signing existing bundle succeeds without signature mismatch.
- **T2-F32-04 (Strict File Permissions in Bundle)**: Executable inside `Contents/MacOS/` has `755` executable permissions.
- **T2-F32-05 (Clean Target Execution)**: `make clean` completely deletes build output and temporary bundles.

### Feature 33: Programmatic Persistence Test Boundaries
- **T2-F33-01 (10,000 Clips Persistence Stress)**: Writing 10,000 clips completes without running out of memory.
- **T2-F33-02 (Special JSON Characters)**: Text containing quotes, backslashes, tabs, and unicode escapes parses back identically.
- **T2-F33-03 (Simultaneous Storage Instances)**: Two `StorageManager` instances pointing to same directory synchronize safely.
- **T2-F33-04 (Corrupted Directory Permissions)**: Read-only storage directory handled with handled error.
- **T2-F33-05 (UUID Collision Impossibility)**: Creating 1,000 items generates 1,000 unique UUIDs.

### Feature 34: Programmatic Thumbnail Test Boundaries
- **T2-F34-01 (1-Byte File Input)**: Single byte passed to thumbnail generator returns `nil` safely.
- **T2-F34-02 (Huge Pixel Dimensions 20,000x20,000)**: Huge image downscaled via ImageIO without memory crash.
- **T2-F34-03 (Grayscale Image Input)**: Grayscale PNG converts to valid thumbnail maintaining color space.
- **T2-F34-04 (CMYK Image Input)**: CMYK TIFF converts to standard RGB thumbnail.
- **T2-F34-05 (Animated GIF First Frame)**: Animated GIF input generates thumbnail from first frame.

### Feature 35: Programmatic Search Test Boundaries
- **T2-F35-01 (Empty String Query)**: Empty string query returns complete item list in identical order.
- **T2-F35-02 (Search with Only Punctuation)**: Querying `"!@#$%"` matches only clips containing those characters.
- **T2-F35-03 (Case Invariance on All ASCII)**: Querying uppercase matches lowercase for all 26 English letters.
- **T2-F35-04 (Search Result Ordering)**: Filtered results maintain chronological order within sections.
- **T2-F35-05 (Search Over 5,000 Items)**: Filtering 5,000 items takes under 15ms.

### Feature 36: Programmatic Pin Retention Test Boundaries
- **T2-F36-01 (Pin Retention at Capacity 1)**: Capacity 1 with 1 pinned item accepts new unpinned item; pinned remains.
- **T2-F36-02 (Pin Retention Under 500 Additions)**: Adding 500 unpinned items retains all pinned items.
- **T2-F36-03 (Unpinning Evicts Immediately If Oldest)**: Unpinning an item older than the capacity window evicts it on next cycle.
- **T2-F36-04 (Multiple Pins Deleted Sequentially)**: Explicitly deleting pinned items works while auto-eviction does not.
- **T2-F36-05 (Clear Unpinned While All Pinned)**: Clear operation leaves 100% of store intact.

### Feature 37: Programmatic Pasteboard Test Boundaries
- **T2-F37-01 (Zero-Byte String Write)**: Writing empty string writes empty pasteboard type without error.
- **T2-F37-02 (Pasteboard Type Precedence)**: String write does not leave stale image data on pasteboard.
- **T2-F37-03 (Image Write Clears String Type)**: Image write does not leave stale string data on pasteboard.
- **T2-F37-04 (Concurrent External Pasteboard Writes)**: External write during read captured accurately.
- **T2-F37-05 (Pasteboard Ownership Transition)**: App releases pasteboard ownership cleanly.

### Feature 38: Automated Zero-Emoji Scan Boundaries
- **T2-F38-01 (Emoji in Comment Block)**: Scanner detects emoji even inside multi-line `/* ... */` comment.
- **T2-F38-02 (Emoji in Single Line Comment)**: Scanner detects emoji inside `//` comment.
- **T2-F38-03 (Emoji in String Literal)**: Scanner detects emoji inside `"hello \u{1F600}"`.
- **T2-F38-04 (Emoji in File Name)**: Scanner flags files with emojis in filename.
- **T2-F38-05 (Zero-Emoji in Makefile Comments)**: Scanner validates Makefile comments and echo commands.

---

## 5. Tier 3: Pairwise Combinations & Cross-Feature Interactions

Total Pairwise Suites: **20 interaction scenarios**.

| ID | Feature A | Feature B | Interaction Scenario & Expected Behavior |
|---|---|---|---|
| T3-P01 | F02 (Plain Text) | F08 (FIFO Eviction) | Adding text clips past capacity evicts oldest text clips in exact FIFO order. |
| T3-P02 | F03 (Image Capture) | F09 (Pin Retention) | Pinning an image clip prevents its metadata and original PNG file from being deleted during capacity overflow. |
| T3-P03 | F04 (Thumbnail) | F10 (Clear Unpinned) | Clearing unpinned history deletes unpinned thumbnail files while preserving pinned thumbnail files on disk. |
| T3-P04 | F05 (Self-Copy) | F24 (Per-Row Copy) | Clicking copy button on a row writes to pasteboard and marks self-copy, preventing duplicate clip recording. |
| T3-P05 | F06 (Duplicate) | F08 (FIFO Eviction) | Promoting a duplicate unpinned clip refreshes its recency, preventing it from being next in line for FIFO eviction. |
| T3-P06 | F07 (Persistence) | F09 (Pin Retention) | Cold restart of application retains all pinned flags and prevents eviction on subsequent additions. |
| T3-P07 | F09 (Pin Retention) | F30 (Capacity Adjustment) | Dynamically lowering capacity from 100 to 20 evicts 80 oldest unpinned items while retaining 100% of pinned items. |
| T3-P08 | F12 (Floating Panel) | F13 (Screen Clamping) | Summoning floating panel on multi-display setup positions window clamped strictly within visible frame of active screen. |
| T3-P09 | F14 (Escape Key) | F19 (Auto-Focused Search) | Pressing Escape when search field is focused cleanly dismisses the panel and clears first responder. |
| T3-P10 | F16 (Selection Dismissal)| F28 (Copy-Only Model) | Selecting row copies payload to pasteboard and immediately dismisses panel without injecting fake keystrokes. |
| T3-P11 | F18 (Default Hotkey) | F29 (Hotkey Customization)| Reconfiguring hotkey from Option+V to Option+C unregisters Option+V and binds Option+C dynamically. |
| T3-P12 | F20 (Search Filter) | F21 (Partitioned Sections)| Active search query filters items within both Pinned and Recent History sections independently. |
| T3-P13 | F20 (Search Filter) | F22 (Number Shortcuts) | Number keys 1..9 map directly to the filtered visible rows rather than hidden unfiltered items. |
| T3-P14 | F23 (Pin/Unpin) | F20 (Search Filter) | Toggling pin on a filtered search result moves it across sections while preserving the active query filter. |
| T3-P15 | F25 (Delete Action) | F07 (Disk Persistence) | Deleting an item removes its metadata entry and deletes associated disk assets from `images/` and `thumbnails/`. |
| T3-P16 | F26 (SF Symbols) | F27 (Zero Emojis) | UI renders all controls using SF Symbols with 0 emoji characters in icons, titles, or descriptions. |
| T3-P17 | F30 (Capacity Adjust) | F10 (Clear Unpinned) | Adjusting capacity after clearing unpinned history maintains clean state without re-creating ghost items. |
| T3-P18 | F31 (LSUIElement) | F11 (Status Bar Popover) | Menu bar agent app presents popover directly beneath status item without showing Dock icon. |
| T3-P19 | F01 (Monitor Polling) | F03 (Image Capture Burst) | Rapidly copying 5 large images in succession extracts and downscales thumbnails on background queue without dropped items. |
| T3-P20 | F06 (Duplicate) | F09 (Pin Retention) | Copying text identical to an already pinned item promotes/updates timestamp while strictly maintaining its pinned status. |

---

## 6. Tier 4: Real-World Workloads & Scenarios (>=5 Scenarios)

### Scenario 1: Developer Full-Day Coding Session
- **Workload**:
  - Ingestion of 75 varied clips: shell commands, multi-line stack traces, Git hashes, API endpoints, JSON snippets, and SQL queries.
  - User pins 5 critical clips (database connection string, JWT token, AWS account ID, Git branch name, common Docker run command).
  - Rapid search queries filtering for `"docker"`, `"select"`, `"error"`, `"git"`.
  - Sequential execution of number shortcuts `1` through `5`.
- **Verification Criteria**:
  - All 5 pinned items remain pinned throughout the session.
  - Search queries execute in < 5ms per keystroke.
  - Number shortcuts copy the exact code snippets back to pasteboard.
  - Zero corruption of multi-line indentation or quotes in JSON/SQL.

### Scenario 2: Graphic Designer & Digital Asset Curation
- **Workload**:
  - Ingestion of 30 high-resolution images (PNG and TIFF formats) varying from 4K screenshots to 10000x1 panorama strips.
  - User pins 3 brand logo assets.
  - Image thumbnails generated for all 30 assets.
  - History capacity reached; 10 oldest unpinned images evicted.
- **Verification Criteria**:
  - All generated thumbnails maintain dimensions <= 180px and file size < 50KB.
  - Evicted image files and thumbnails are deleted from disk, freeing storage.
  - Pinned logo assets remain present on disk and in UI.
  - Total memory usage remains stable without leaks during heavy image ingestion.

### Scenario 3: High-Frequency Clipboard Burst Stress
- **Workload**:
  - Automated simulation generating 300 rapid-fire clipboard copy operations in under 3 seconds (100 operations/sec).
  - Mix of short text, Unicode strings, and small image payloads.
  - 10 items pinned mid-burst.
- **Verification Criteria**:
  - Pasteboard monitor catches all changes without crashing or thread deadlocks.
  - Unpinned storage caps at exactly configured capacity (default 100).
  - The 10 pinned items survive capacity overflow.
  - All disk writes complete atomically without JSON corruption or zero-byte metadata.

### Scenario 4: Long-Running Session Lifecycle & State Recovery
- **Workload**:
  - Initial launch with cold start in isolated sandbox.
  - Ingestion of 120 text items; capacity set to 100.
  - User toggles pins on items 10, 20, 30.
  - User modifies capacity setting from 100 to 50 via settings.
  - User invokes "Clear unpinned history".
  - Simulated application crash / abrupt termination.
  - Cold relaunch and re-instantiation of `StorageManager`.
- **Verification Criteria**:
  - Post-recovery store contains exactly the 3 pinned items.
  - Unpinned items cleared prior to restart are completely absent.
  - Configured capacity of 50 persists accurately.
  - Metadata reloads cleanly with zero schema errors.

### Scenario 5: Multi-Display Clamping & Coordinate Migration
- **Workload**:
  - Synthetic simulation of multi-monitor environment (Retina primary display 2560x1600 with 25pt menu bar, external secondary display 3840x2160 positioned to the right).
  - Cursor positioned at:
    - Display 1 top-left `(10, 1590)`
    - Display 1 bottom-left `(10, 10)` (above Dock)
    - Seam boundary between displays `(2560, 800)`
    - Display 2 top-right corner `(6390, 2150)`
    - Off-screen virtual coordinates `(-1000, -1000)` and `(99999, 99999)`
- **Verification Criteria**:
  - Panel frame coordinates clamp 100% within the visible frame of the appropriate screen.
  - Panel never overlaps macOS Menu Bar or Dock.
  - Out-of-bounds coordinates recover safely to visible screen area.

---

## 7. Execution Harness & Toolchain Verification

### 7.1 Running the Full Test Suite
To execute the automated verification suite, static emoji scanner, and tests:
```bash
./Scripts/verify.sh
```

### 7.2 Verifying Zero Emojis
```bash
python3 Scripts/lint_emojis.py Sources/ Tests/ Scripts/ Makefile Package.swift
```

### 7.3 Standalone Programmatic Verification Runner
```bash
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk swiftc \
  -parse-as-library \
  Tests/VerificationRunner/main.swift \
  -o SuperClipVerifier
./SuperClipVerifier
```
