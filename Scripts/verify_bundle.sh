#!/bin/bash
set -euo pipefail

# ==============================================================================
# SuperClip Standalone Bundle Verification Script
# Validates:
# Step 1: Standalone bundle compilation (make bundle)
# Step 2: Complete bundle directory layout & dynamic frameworks
# Step 3: Info.plist structure, LSUIElement=true, and bundle metadata keys
# Step 4: PkgInfo 8-byte signature exact match (APPL????)
# Step 5: Multi-resolution AppIcon.icns asset integrity
# Step 6: Mach-O 64-bit arm64 architecture and runtime rpath linkage
# Step 7: Inside-out ad-hoc code signature verification
# Step 8: Isolated headless runtime launch and clean SIGTERM termination
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$(basename "$SCRIPT_DIR")" = "Scripts" ]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

TARGET_PATH="${1:-$PROJECT_ROOT/SuperClip.app}"
if [ -d "$TARGET_PATH" ]; then
    BUNDLE_PATH="$(cd "$TARGET_PATH" && pwd)"
elif [[ "$TARGET_PATH" = /* ]]; then
    BUNDLE_PATH="$TARGET_PATH"
else
    BUNDLE_PATH="$(pwd)/$TARGET_PATH"
fi
CONTENTS="$BUNDLE_PATH/Contents"
MACOS_BIN="$CONTENTS/MacOS/SuperClip"
FRAMEWORK_DYLIB="$CONTENTS/Frameworks/libSuperClipCore.dylib"
INFO_PLIST="$CONTENTS/Info.plist"
PKGINFO="$CONTENTS/PkgInfo"
APP_ICON="$CONTENTS/Resources/AppIcon.icns"

echo "=================================================="
echo "  SuperClip Standalone Bundle Verification        "
echo "  Bundle Path: $BUNDLE_PATH"
echo "=================================================="

# --- Step 1: Building Standalone Bundle ---
echo ""
echo "--- Step 1: Building Standalone Bundle ---"
if [ "${NO_BUILD:-0}" != "1" ] && [ -z "${1:-}" ]; then
    make -C "$PROJECT_ROOT" bundle
elif [ ! -d "$BUNDLE_PATH" ]; then
    make -C "$PROJECT_ROOT" bundle
else
    echo "Using existing target bundle: $BUNDLE_PATH"
fi

# --- Step 2: Directory Structure Verification ---
echo ""
echo "--- Step 2: Validating Directory Structure ---"
[ -d "$BUNDLE_PATH" ] || { echo "FAILED: SuperClip.app directory missing: $BUNDLE_PATH"; exit 1; }
[ -f "$MACOS_BIN" ] || { echo "FAILED: SuperClip binary missing: $MACOS_BIN"; exit 1; }
[ -x "$MACOS_BIN" ] || { echo "FAILED: SuperClip binary is not executable: $MACOS_BIN"; exit 1; }
[ -f "$FRAMEWORK_DYLIB" ] || { echo "FAILED: libSuperClipCore.dylib missing from Frameworks: $FRAMEWORK_DYLIB"; exit 1; }
[ -x "$FRAMEWORK_DYLIB" ] || { echo "FAILED: libSuperClipCore.dylib is not executable: $FRAMEWORK_DYLIB"; exit 1; }
[ -f "$INFO_PLIST" ] || { echo "FAILED: Info.plist missing: $INFO_PLIST"; exit 1; }
[ -f "$PKGINFO" ] || { echo "FAILED: PkgInfo missing: $PKGINFO"; exit 1; }
[ -f "$APP_ICON" ] || { echo "FAILED: AppIcon.icns missing from Resources: $APP_ICON"; exit 1; }
echo "Structure check passed: all required files and directories exist."

# --- Step 3: Info.plist Validation ---
echo ""
echo "--- Step 3: Validating Info.plist Properties ---"
plutil -lint "$INFO_PLIST" > /dev/null || { echo "FAILED: Info.plist is invalid XML/plist format"; exit 1; }

LS_UI_ELEMENT=$(plutil -extract LSUIElement raw "$INFO_PLIST" 2>/dev/null || echo "")
if [ "$LS_UI_ELEMENT" != "true" ] && [ "$LS_UI_ELEMENT" != "1" ]; then
    echo "FAILED: LSUIElement is not true (got: $LS_UI_ELEMENT)"
    exit 1
fi
echo "LSUIElement verified: $LS_UI_ELEMENT (Agent Mode)"

BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw "$INFO_PLIST" 2>/dev/null || echo "")
if [ "$BUNDLE_ID" != "com.superclip.SuperClip" ]; then
    echo "FAILED: CFBundleIdentifier mismatch (got: $BUNDLE_ID)"
    exit 1
fi
echo "CFBundleIdentifier verified: $BUNDLE_ID"

PKG_TYPE=$(plutil -extract CFBundlePackageType raw "$INFO_PLIST" 2>/dev/null || echo "")
if [ "$PKG_TYPE" != "APPL" ]; then
    echo "FAILED: CFBundlePackageType mismatch (got: $PKG_TYPE)"
    exit 1
fi
echo "CFBundlePackageType verified: $PKG_TYPE"

BUNDLE_EXE=$(plutil -extract CFBundleExecutable raw "$INFO_PLIST" 2>/dev/null || echo "")
if [ "$BUNDLE_EXE" != "SuperClip" ]; then
    echo "FAILED: CFBundleExecutable mismatch (got: $BUNDLE_EXE)"
    exit 1
fi
echo "CFBundleExecutable verified: $BUNDLE_EXE"

ICON_FILE=$(plutil -extract CFBundleIconFile raw "$INFO_PLIST" 2>/dev/null || echo "")
if [ "$ICON_FILE" != "AppIcon" ]; then
    echo "FAILED: CFBundleIconFile mismatch (got: $ICON_FILE)"
    exit 1
fi
echo "CFBundleIconFile verified: $ICON_FILE"

MIN_SYS_VER=$(plutil -extract LSMinimumSystemVersion raw "$INFO_PLIST" 2>/dev/null || echo "")
if [ "$MIN_SYS_VER" != "13.0" ]; then
    echo "FAILED: LSMinimumSystemVersion mismatch (got: $MIN_SYS_VER)"
    exit 1
fi
echo "LSMinimumSystemVersion verified: $MIN_SYS_VER"

# --- Step 4: PkgInfo Content Validation ---
echo ""
echo "--- Step 4: Validating PkgInfo Content ---"
PKG_CONTENT=$(cat "$PKGINFO")
if [ "$PKG_CONTENT" != "APPL????" ]; then
    echo "FAILED: PkgInfo content mismatch: expected 'APPL????', got '$PKG_CONTENT'"
    exit 1
fi
PKG_SIZE=$(stat -f%z "$PKGINFO")
if [ "$PKG_SIZE" -ne 8 ]; then
    echo "FAILED: PkgInfo size mismatch: expected 8 bytes, got $PKG_SIZE bytes"
    exit 1
fi
echo "PkgInfo verified: APPL???? (8 bytes)"

# --- Step 5: AppIcon.icns Multi-Resolution Check ---
echo ""
echo "--- Step 5: Validating AppIcon.icns Multi-Resolution Asset ---"
[ -s "$APP_ICON" ] || { echo "FAILED: AppIcon.icns file is empty"; exit 1; }
if ! file "$APP_ICON" | grep -q "Mac OS X icon"; then
    echo "FAILED: AppIcon.icns is not a valid Mac OS X icon file"
    exit 1
fi
ICON_SIZE=$(stat -f%z "$APP_ICON")
if [ "$ICON_SIZE" -lt 100000 ]; then
    echo "FAILED: AppIcon.icns size unexpectedly small ($ICON_SIZE bytes, multi-resolution asset expected)"
    exit 1
fi
MAGIC_HEADER=$(head -c 4 "$APP_ICON")
if [ "$MAGIC_HEADER" != "icns" ]; then
    echo "FAILED: AppIcon.icns invalid magic header (expected 'icns', got '$MAGIC_HEADER')"
    exit 1
fi
if ! strings "$APP_ICON" | grep -E -q 'ic(04|05|07|08|09|10|11|12|13|14)'; then
    echo "FAILED: AppIcon.icns missing standard multi-resolution bitmap chunk tags"
    exit 1
fi
echo "AppIcon.icns verified: valid multi-resolution Mac OS X icon ($ICON_SIZE bytes)"

# --- Step 6: Mach-O arm64 Architecture & Linkage Check ---
echo ""
echo "--- Step 6: Validating Mach-O arm64 Architecture & Linkage ---"
if ! file "$MACOS_BIN" | grep -q "Mach-O 64-bit executable arm64"; then
    echo "FAILED: SuperClip binary is not arm64 Mach-O: $(file "$MACOS_BIN")"
    exit 1
fi
echo "Executable Mach-O arm64 architecture verified."

if ! file "$FRAMEWORK_DYLIB" | grep -q "Mach-O 64-bit dynamically linked shared library arm64"; then
    echo "FAILED: libSuperClipCore.dylib is not arm64 Mach-O: $(file "$FRAMEWORK_DYLIB")"
    exit 1
fi
echo "Framework Mach-O arm64 architecture verified."

if ! otool -D "$FRAMEWORK_DYLIB" | grep -q "@rpath/libSuperClipCore.dylib"; then
    echo "FAILED: libSuperClipCore.dylib install name mismatch: $(otool -D "$FRAMEWORK_DYLIB")"
    exit 1
fi
echo "Framework install name verified: @rpath/libSuperClipCore.dylib"

if ! otool -l "$MACOS_BIN" | grep -A 3 LC_RPATH | grep -q "@executable_path/../Frameworks"; then
    echo "FAILED: Missing @executable_path/../Frameworks rpath in executable"
    exit 1
fi
echo "RPATH verified: @executable_path/../Frameworks present."

if otool -l "$MACOS_BIN" | grep -A 3 LC_RPATH | grep -q "\.build"; then
    echo "FAILED: Leaked development .build rpath in release binary"
    exit 1
fi
echo "RPATH verified: No development paths leaked."

# --- Step 7: Codesign Deep Strict Verification ---
echo ""
echo "--- Step 7: Validating Ad-hoc Code Signatures Inside-Out ---"
codesign --verify --deep --strict --verbose=2 "$FRAMEWORK_DYLIB" || {
    echo "FAILED: codesign verification failed on $FRAMEWORK_DYLIB"
    exit 1
}
echo "Framework code signature verified."

codesign --verify --deep --strict --verbose=2 "$BUNDLE_PATH" || {
    echo "FAILED: codesign deep strict verification failed on $BUNDLE_PATH"
    exit 1
}
echo "Application bundle code signature verified (deep, strict)."

# --- Step 8: Headless Launch & Clean SIGTERM Termination ---
echo ""
echo "--- Step 8: Validating Headless Process Launch in Isolated Directory ---"
ISOLATED_DIR=$(mktemp -d /tmp/superclip_bundle_test_XXXXXX)
CLEANUP() {
    if [ -n "${APP_PID:-}" ] && kill -0 "$APP_PID" 2>/dev/null; then
        kill -TERM "$APP_PID" 2>/dev/null || kill -9 "$APP_PID" 2>/dev/null
        wait "$APP_PID" 2>/dev/null || true
    fi
    rm -rf "$ISOLATED_DIR"
}
trap CLEANUP EXIT

cd "$ISOLATED_DIR"
"$MACOS_BIN" > "$ISOLATED_DIR/stdout.log" 2> "$ISOLATED_DIR/stderr.log" &
APP_PID=$!

sleep 1.0

if ! kill -0 "$APP_PID" 2>/dev/null; then
    echo "FAILED: SuperClip process exited prematurely upon headless launch"
    if [ -s "$ISOLATED_DIR/stderr.log" ]; then
        cat "$ISOLATED_DIR/stderr.log"
    fi
    exit 1
fi

echo "SuperClip process (PID $APP_PID) running cleanly without dynamic linker errors."
kill -TERM "$APP_PID" 2>/dev/null || kill "$APP_PID" 2>/dev/null
wait "$APP_PID" 2>/dev/null || true
echo "SuperClip process terminated cleanly on SIGTERM."

cd "$PROJECT_ROOT"
trap - EXIT
rm -rf "$ISOLATED_DIR"

echo ""
echo "=================================================="
echo "  SuperClip Standalone Bundle Verification PASSED "
echo "=================================================="
