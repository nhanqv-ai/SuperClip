#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"

# Ensure core and app libraries are built
make -C "$PROJECT_ROOT" build

ADVERSARIAL_SRC="$PROJECT_ROOT/Tests/AdversarialRunner/M2AdversarialRunner.swift"
ADVERSARIAL_BIN="$PROJECT_ROOT/.m2_adversarial_bin"

swiftc -sdk "$SDKROOT" \
    -target arm64-apple-macos13.0 \
    -I "$PROJECT_ROOT/.build/modules" \
    -L "$PROJECT_ROOT/.build/lib" \
    -lSuperClipCore \
    -lSuperClip \
    -Xlinker -rpath -Xlinker "$PROJECT_ROOT/.build/lib" \
    -parse-as-library \
    "$ADVERSARIAL_SRC" \
    -o "$ADVERSARIAL_BIN"

set +e
"$ADVERSARIAL_BIN"
EXIT_CODE=$?
set -e

rm -f "$ADVERSARIAL_BIN"
exit $EXIT_CODE
