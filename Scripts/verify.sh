#!/bin/bash
set -euo pipefail

# SuperClip Automated Verification Script
# Strictly enforces:
# 1. Isolated sandboxing (never touches ~/Library/Application Support/SuperClip/)
# 2. SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
# 3. 0 Emojis invariant across all files
# 4. Direct linkage against genuine SuperClipCore library (.build/lib/libSuperClipCore.dylib)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk" ]; then
    export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
elif [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk" ]; then
    export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
else
    export SDKROOT="$(xcrun --show-sdk-path)"
fi

echo "=================================================="
echo "  SuperClip Test Suite Verification"
echo "  Project Root: $PROJECT_ROOT"
echo "  SDKROOT:      $SDKROOT"
echo "=================================================="

# Step 1: Run Static Zero-Emoji Scanner
echo ""
echo "--- Step 1: Scanning for Zero-Emoji Invariant ---"
python3 "$PROJECT_ROOT/Scripts/lint_emojis.py" \
    "$PROJECT_ROOT/Sources" \
    "$PROJECT_ROOT/Tests" \
    "$PROJECT_ROOT/Scripts" \
    "$PROJECT_ROOT/README.md" \
    "$PROJECT_ROOT/LICENSE"

# Step 2: Ensure Core Library Artifacts Exist
echo ""
echo "--- Step 2: Ensuring SuperClipCore Library is Built ---"
if [ ! -f "$PROJECT_ROOT/.build/lib/libSuperClipCore.dylib" ] || [ ! -e "$PROJECT_ROOT/.build/modules/SuperClipCore.swiftmodule" ]; then
    echo "SuperClipCore library artifacts not found. Building..."
    make -C "$PROJECT_ROOT" build
fi

# Step 3: Compile Verification Runner & Test Suites against SuperClipCore
echo ""
echo "--- Step 3: Compiling SuperClipVerifier via swiftc ---"
SWIFT_FILES=(
    "$PROJECT_ROOT/Tests/Common/TestHarness.swift"
    "$PROJECT_ROOT/Sources/SuperClip/Presentation/PanelFrameCalculator.swift"
    "$PROJECT_ROOT/Sources/SuperClip/Presentation/FloatingClipPanel.swift"
    "$PROJECT_ROOT/Sources/SuperClip/Presentation/FloatingClipPanelPlaceholderView.swift"
    "$PROJECT_ROOT/Sources/SuperClip/Presentation/ThumbnailHoverPreviewPanel.swift"
    "$PROJECT_ROOT/Sources/SuperClip/Presentation/StatusItemManager.swift"
    "$PROJECT_ROOT/Sources/SuperClip/Services/ShortcutNavigator.swift"
    "$PROJECT_ROOT/Sources/SuperClip/Services/PasteboardWriter.swift"
    "$PROJECT_ROOT/Sources/SuperClip/Services/PreviousAppTracker.swift"
    "$PROJECT_ROOT/Sources/SuperClip/Services/AutoPasteService.swift"
    "$PROJECT_ROOT/Sources/SuperClip/Services/ClipboardActionCoordinator.swift"
    "$PROJECT_ROOT/Sources/SuperClip/Views/SearchBarView.swift"
    "$PROJECT_ROOT/Sources/SuperClip/Views/ClipRowView.swift"
    "$PROJECT_ROOT/Sources/SuperClip/Views/ClipListView.swift"
    "$PROJECT_ROOT/Sources/SuperClip/Views/MainContentView.swift"
    "$PROJECT_ROOT/Sources/SuperClip/Views/MainClipView.swift"
    "$PROJECT_ROOT/Sources/SuperClip/Views/SettingsView.swift"
    "$PROJECT_ROOT/Sources/SuperClip/Presentation/SettingsWindowController.swift"
    "$PROJECT_ROOT/Sources/SuperClip/App/AppDelegate.swift"
    "$PROJECT_ROOT/Tests/SuperClipTests/StorageTests.swift"
    "$PROJECT_ROOT/Tests/SuperClipTests/SearchFilterTests.swift"
    "$PROJECT_ROOT/Tests/SuperClipTests/ThumbnailTests.swift"
    "$PROJECT_ROOT/Tests/SuperClipTests/PinRetentionTests.swift"
    "$PROJECT_ROOT/Tests/SuperClipTests/WindowClampingTests.swift"
    "$PROJECT_ROOT/Tests/SuperClipTests/FloatingClipPanelTests.swift"
    "$PROJECT_ROOT/Tests/SuperClipTests/StatusItemManagerTests.swift"
    "$PROJECT_ROOT/Tests/SuperClipTests/Shortcut1to9Tests.swift"
    "$PROJECT_ROOT/Tests/SuperClipTests/CopyWritebackTests.swift"
    "$PROJECT_ROOT/Tests/SuperClipTests/SearchBarViewTests.swift"
    "$PROJECT_ROOT/Tests/SuperClipTests/ClipListViewTests.swift"
    "$PROJECT_ROOT/Tests/SuperClipTests/ClipRowViewTests.swift"
    "$PROJECT_ROOT/Tests/SuperClipTests/MainClipViewTests.swift"
    "$PROJECT_ROOT/Tests/SuperClipTests/SwiftUIInterfaceTests.swift"
    "$PROJECT_ROOT/Tests/SuperClipTests/SettingsTests.swift"
    "$PROJECT_ROOT/Tests/SuperClipTests/SettingsViewTests.swift"
    "$PROJECT_ROOT/Tests/SuperClipTests/AppSettingsTests.swift"
    "$PROJECT_ROOT/Tests/SuperClipTests/LocalizationTests.swift"
    "$PROJECT_ROOT/Tests/SuperClipTests/IgnoredAppsTests.swift"
    "$PROJECT_ROOT/Tests/SuperClipTests/UpdateManagerTests.swift"
    "$PROJECT_ROOT/Tests/SuperClipTests/BoundaryTests.swift"
    "$PROJECT_ROOT/Tests/SuperClipTests/PairwiseTests.swift"
    "$PROJECT_ROOT/Tests/SuperClipTests/WorkloadTests.swift"
    "$PROJECT_ROOT/Tests/SuperClipTests/AutoPasteTests.swift"
    "$PROJECT_ROOT/Tests/VerificationRunner/main.swift"
)

VERIFIER_BIN="$PROJECT_ROOT/.verifier_bin"

HOST_ARCH="${HOST_ARCH:-$(uname -m)}"

swiftc -sdk "$SDKROOT" \
    -target "${HOST_ARCH}-apple-macos13.0" \
    -I "$PROJECT_ROOT/.build/modules" \
    -L "$PROJECT_ROOT/.build/lib" \
    -lSuperClipCore \
    -Xlinker -rpath -Xlinker "$PROJECT_ROOT/.build/lib" \
    -parse-as-library \
    -O \
    "${SWIFT_FILES[@]}" \
    -o "$VERIFIER_BIN"

# Step 4: Execute Headless Verification Runner in Sandbox
echo ""
echo "--- Step 4: Executing Verification Runner ---"
"$VERIFIER_BIN"

# Step 5: Cleanup Binary
rm -f "$VERIFIER_BIN"

echo ""
echo "=================================================="
echo "  SuperClip Verification Completed Successfully   "
echo "=================================================="
