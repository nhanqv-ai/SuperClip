#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"

# Ensure debug libraries and app bundle are built
make -C "$PROJECT_ROOT" build
make -C "$PROJECT_ROOT" app

RUNNER_SRC="$PROJECT_ROOT/Scripts/challenger_tier5_2_stress_runner.swift"
RUNNER_BIN="$PROJECT_ROOT/.tier5_2_stress_runner"

echo "Compiling Tier 5 Challenger Stress Runner..."
swiftc -sdk "$SDKROOT" \
    -target arm64-apple-macos13.0 \
    -I "$PROJECT_ROOT/.build/modules" \
    -L "$PROJECT_ROOT/.build/lib" \
    -lSuperClipCore \
    -lSuperClip \
    -Xlinker -rpath -Xlinker "$PROJECT_ROOT/.build/lib" \
    -parse-as-library \
    "$RUNNER_SRC" \
    -o "$RUNNER_BIN"

echo "Executing Tier 5 Challenger Stress Runner..."
set +e
"$RUNNER_BIN"
EXIT_CODE=$?
set -e

rm -f "$RUNNER_BIN"
exit $EXIT_CODE
