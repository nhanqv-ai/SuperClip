# ==============================================================================
# SuperClip Makefile
# Native macOS Menu Bar Clipboard Manager
# ==============================================================================

APP_NAME = SuperClip
BUNDLE_NAME = $(APP_NAME).app
BUNDLE_DIR = $(BUNDLE_NAME)/Contents
MACOS_DIR = $(BUNDLE_DIR)/MacOS
FRAMEWORKS_DIR = $(BUNDLE_DIR)/Frameworks
RESOURCES_DIR = $(BUNDLE_DIR)/Resources
BUILD_DIR = .build

# Detect or select a valid SDK supporting both arm64 and x86_64
ifneq ($(wildcard /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk),)
    SDK_PATH := /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
else ifneq ($(wildcard /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk),)
    SDK_PATH := /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
else
    SDK_PATH := $(shell xcrun --show-sdk-path)
endif
export SDKROOT := $(SDK_PATH)

SWIFTC = swiftc
SWIFT = swift
PYTHON = python3
CODESIGN = codesign
INSTALL_NAME_TOOL = install_name_tool
LIPO = lipo

# Architecture targets (Universal 2: Apple Silicon arm64 + Intel x86_64)
TARGET_ARM64 = arm64-apple-macos13.0
TARGET_X86_64 = x86_64-apple-macos13.0

# Source file discovery
CORE_SRCS = $(shell find Sources/SuperClipCore -name '*.swift' 2>/dev/null)
APP_SRCS  = $(shell find Sources/SuperClip -name '*.swift' 2>/dev/null)
ALL_SRCS  = $(CORE_SRCS) $(APP_SRCS)

# Compiler flags
SWIFTC_FLAGS_COMMON = -sdk $(SDKROOT)
SWIFTC_FLAGS_DEBUG  = $(SWIFTC_FLAGS_COMMON) -g -Onone
SWIFTC_FLAGS_RELEASE= $(SWIFTC_FLAGS_COMMON) -O -whole-module-optimization

.PHONY: all build release bundle app package icon verify-app test verify lint clean help adversarial

all: build

help:
	@echo "SuperClip Build System Targets:"
	@echo "  make build       - Compile debug dylib and binary artifacts"
	@echo "  make release     - Compile optimized release artifacts"
	@echo "  make icon        - Programmatically generate AppIcon.icns"
	@echo "  make app         - Assemble and codesign standalone SuperClip.app bundle"
	@echo "  make bundle      - Assemble and codesign standalone SuperClip.app bundle (alias for app)"
	@echo "  make package     - Assemble and codesign standalone SuperClip.app bundle (alias for app)"
	@echo "  make verify-app  - Verify SuperClip.app bundle integrity & headless launch"
	@echo "  make lint        - Verify strict 0-emoji constraint"
	@echo "  make test        - Run automated test suite"
	@echo "  make verify      - Run programmatic verification runner (R5)"
	@echo "  make adversarial - Run adversarial stress test suite"
	@echo "  make clean       - Remove build artifacts and app bundle"

# Compile Debug Binary / Module (Universal 2: arm64 + x86_64)
build: lint
	@if [ -f $(BUILD_DIR)/modules/SuperClipCore.swiftmodule ]; then rm -f $(BUILD_DIR)/modules/SuperClipCore.swiftmodule; fi
	@if [ -f $(BUILD_DIR)/modules/SuperClip.swiftmodule ]; then rm -f $(BUILD_DIR)/modules/SuperClip.swiftmodule; fi
	@mkdir -p $(BUILD_DIR)/modules/SuperClipCore.swiftmodule $(BUILD_DIR)/modules/SuperClip.swiftmodule
	@mkdir -p $(BUILD_DIR)/lib/arm64 $(BUILD_DIR)/lib/x86_64 $(BUILD_DIR)/bin/arm64 $(BUILD_DIR)/bin/x86_64
	@echo "Compiling SuperClipCore slices (Debug)..."
	$(SWIFTC) $(SWIFTC_FLAGS_DEBUG) -target $(TARGET_ARM64) \
		-emit-library \
		-emit-module -emit-module-path $(BUILD_DIR)/modules/SuperClipCore.swiftmodule/arm64-apple-macos.swiftmodule \
		-module-name SuperClipCore \
		-parse-as-library \
		-Xlinker -install_name -Xlinker @rpath/libSuperClipCore.dylib \
		$(CORE_SRCS) \
		-o $(BUILD_DIR)/lib/arm64/libSuperClipCore.dylib
	$(SWIFTC) $(SWIFTC_FLAGS_DEBUG) -target $(TARGET_X86_64) \
		-emit-library \
		-emit-module -emit-module-path $(BUILD_DIR)/modules/SuperClipCore.swiftmodule/x86_64-apple-macos.swiftmodule \
		-module-name SuperClipCore \
		-parse-as-library \
		-Xlinker -install_name -Xlinker @rpath/libSuperClipCore.dylib \
		$(CORE_SRCS) \
		-o $(BUILD_DIR)/lib/x86_64/libSuperClipCore.dylib
	@echo "Merging SuperClipCore dynamic library with lipo..."
	$(LIPO) -create -output $(BUILD_DIR)/lib/libSuperClipCore.dylib \
		$(BUILD_DIR)/lib/arm64/libSuperClipCore.dylib \
		$(BUILD_DIR)/lib/x86_64/libSuperClipCore.dylib
	@if [ -n "$(APP_SRCS)" ]; then \
		echo "Compiling SuperClip module slices (Debug)..."; \
		$(SWIFTC) $(SWIFTC_FLAGS_DEBUG) -target $(TARGET_ARM64) \
			-emit-library \
			-emit-module -emit-module-path $(BUILD_DIR)/modules/SuperClip.swiftmodule/arm64-apple-macos.swiftmodule \
			-module-name SuperClip \
			-parse-as-library \
			-I $(BUILD_DIR)/modules \
			-L $(BUILD_DIR)/lib/arm64 \
			-lSuperClipCore \
			-Xlinker -install_name -Xlinker @rpath/libSuperClip.dylib \
			$(APP_SRCS) \
			-o $(BUILD_DIR)/lib/arm64/libSuperClip.dylib; \
		$(SWIFTC) $(SWIFTC_FLAGS_DEBUG) -target $(TARGET_X86_64) \
			-emit-library \
			-emit-module -emit-module-path $(BUILD_DIR)/modules/SuperClip.swiftmodule/x86_64-apple-macos.swiftmodule \
			-module-name SuperClip \
			-parse-as-library \
			-I $(BUILD_DIR)/modules \
			-L $(BUILD_DIR)/lib/x86_64 \
			-lSuperClipCore \
			-Xlinker -install_name -Xlinker @rpath/libSuperClip.dylib \
			$(APP_SRCS) \
			-o $(BUILD_DIR)/lib/x86_64/libSuperClip.dylib; \
		echo "Merging SuperClip module library with lipo..."; \
		$(LIPO) -create -output $(BUILD_DIR)/lib/libSuperClip.dylib \
			$(BUILD_DIR)/lib/arm64/libSuperClip.dylib \
			$(BUILD_DIR)/lib/x86_64/libSuperClip.dylib; \
	fi
	@if [ -n "$(APP_SRCS)" ] && grep -r -q '@main' Sources/SuperClip 2>/dev/null; then \
		echo "Compiling $(APP_NAME) executable slices (Debug)..."; \
		$(SWIFTC) $(SWIFTC_FLAGS_DEBUG) -target $(TARGET_ARM64) \
			-I $(BUILD_DIR)/modules \
			-L $(BUILD_DIR)/lib/arm64 \
			-lSuperClipCore \
			-Xlinker -rpath -Xlinker $(BUILD_DIR)/lib \
			-parse-as-library \
			$(APP_SRCS) \
			-o $(BUILD_DIR)/bin/arm64/$(APP_NAME); \
		$(SWIFTC) $(SWIFTC_FLAGS_DEBUG) -target $(TARGET_X86_64) \
			-I $(BUILD_DIR)/modules \
			-L $(BUILD_DIR)/lib/x86_64 \
			-lSuperClipCore \
			-Xlinker -rpath -Xlinker $(BUILD_DIR)/lib \
			-parse-as-library \
			$(APP_SRCS) \
			-o $(BUILD_DIR)/bin/x86_64/$(APP_NAME); \
		echo "Merging $(APP_NAME) executable with lipo..."; \
		$(LIPO) -create -output $(BUILD_DIR)/bin/$(APP_NAME) \
			$(BUILD_DIR)/bin/arm64/$(APP_NAME) \
			$(BUILD_DIR)/bin/x86_64/$(APP_NAME); \
	fi
	@echo "Build complete."

# Compile Release Binary / Module (Universal 2: arm64 + x86_64)
release: lint
	@if [ -f $(BUILD_DIR)/modules/SuperClipCore.swiftmodule ]; then rm -f $(BUILD_DIR)/modules/SuperClipCore.swiftmodule; fi
	@if [ -f $(BUILD_DIR)/modules/SuperClip.swiftmodule ]; then rm -f $(BUILD_DIR)/modules/SuperClip.swiftmodule; fi
	@mkdir -p $(BUILD_DIR)/modules/SuperClipCore.swiftmodule $(BUILD_DIR)/modules/SuperClip.swiftmodule
	@mkdir -p $(BUILD_DIR)/lib/arm64 $(BUILD_DIR)/lib/x86_64 $(BUILD_DIR)/bin/arm64 $(BUILD_DIR)/bin/x86_64
	@echo "Compiling SuperClipCore slices (Release)..."
	$(SWIFTC) $(SWIFTC_FLAGS_RELEASE) -target $(TARGET_ARM64) \
		-emit-library \
		-emit-module -emit-module-path $(BUILD_DIR)/modules/SuperClipCore.swiftmodule/arm64-apple-macos.swiftmodule \
		-module-name SuperClipCore \
		-parse-as-library \
		-Xlinker -install_name -Xlinker @rpath/libSuperClipCore.dylib \
		$(CORE_SRCS) \
		-o $(BUILD_DIR)/lib/arm64/libSuperClipCore.dylib
	$(SWIFTC) $(SWIFTC_FLAGS_RELEASE) -target $(TARGET_X86_64) \
		-emit-library \
		-emit-module -emit-module-path $(BUILD_DIR)/modules/SuperClipCore.swiftmodule/x86_64-apple-macos.swiftmodule \
		-module-name SuperClipCore \
		-parse-as-library \
		-Xlinker -install_name -Xlinker @rpath/libSuperClipCore.dylib \
		$(CORE_SRCS) \
		-o $(BUILD_DIR)/lib/x86_64/libSuperClipCore.dylib
	@echo "Merging SuperClipCore dynamic library with lipo..."
	$(LIPO) -create -output $(BUILD_DIR)/lib/libSuperClipCore.dylib \
		$(BUILD_DIR)/lib/arm64/libSuperClipCore.dylib \
		$(BUILD_DIR)/lib/x86_64/libSuperClipCore.dylib
	@if [ -n "$(APP_SRCS)" ]; then \
		echo "Compiling SuperClip module slices (Release)..."; \
		$(SWIFTC) $(SWIFTC_FLAGS_RELEASE) -target $(TARGET_ARM64) \
			-emit-library \
			-emit-module -emit-module-path $(BUILD_DIR)/modules/SuperClip.swiftmodule/arm64-apple-macos.swiftmodule \
			-module-name SuperClip \
			-parse-as-library \
			-I $(BUILD_DIR)/modules \
			-L $(BUILD_DIR)/lib/arm64 \
			-lSuperClipCore \
			-Xlinker -install_name -Xlinker @rpath/libSuperClip.dylib \
			$(APP_SRCS) \
			-o $(BUILD_DIR)/lib/arm64/libSuperClip.dylib; \
		$(SWIFTC) $(SWIFTC_FLAGS_RELEASE) -target $(TARGET_X86_64) \
			-emit-library \
			-emit-module -emit-module-path $(BUILD_DIR)/modules/SuperClip.swiftmodule/x86_64-apple-macos.swiftmodule \
			-module-name SuperClip \
			-parse-as-library \
			-I $(BUILD_DIR)/modules \
			-L $(BUILD_DIR)/lib/x86_64 \
			-lSuperClipCore \
			-Xlinker -install_name -Xlinker @rpath/libSuperClip.dylib \
			$(APP_SRCS) \
			-o $(BUILD_DIR)/lib/x86_64/libSuperClip.dylib; \
		echo "Merging SuperClip module library with lipo..."; \
		$(LIPO) -create -output $(BUILD_DIR)/lib/libSuperClip.dylib \
			$(BUILD_DIR)/lib/arm64/libSuperClip.dylib \
			$(BUILD_DIR)/lib/x86_64/libSuperClip.dylib; \
	fi
	@if [ -n "$(APP_SRCS)" ] && grep -r -q '@main' Sources/SuperClip 2>/dev/null; then \
		echo "Compiling $(APP_NAME) binary slices (Release)..."; \
		$(SWIFTC) $(SWIFTC_FLAGS_RELEASE) -target $(TARGET_ARM64) \
			-I $(BUILD_DIR)/modules \
			-L $(BUILD_DIR)/lib/arm64 \
			-lSuperClipCore \
			-Xlinker -rpath -Xlinker $(BUILD_DIR)/lib \
			-parse-as-library \
			$(APP_SRCS) \
			-o $(BUILD_DIR)/bin/arm64/$(APP_NAME); \
		$(SWIFTC) $(SWIFTC_FLAGS_RELEASE) -target $(TARGET_X86_64) \
			-I $(BUILD_DIR)/modules \
			-L $(BUILD_DIR)/lib/x86_64 \
			-lSuperClipCore \
			-Xlinker -rpath -Xlinker $(BUILD_DIR)/lib \
			-parse-as-library \
			$(APP_SRCS) \
			-o $(BUILD_DIR)/bin/x86_64/$(APP_NAME); \
		echo "Merging $(APP_NAME) executable with lipo..."; \
		$(LIPO) -create -output $(BUILD_DIR)/bin/$(APP_NAME) \
			$(BUILD_DIR)/bin/arm64/$(APP_NAME) \
			$(BUILD_DIR)/bin/x86_64/$(APP_NAME); \
	fi
	@echo "Release build complete."

# Programmatic App Icon Generation
icon: $(BUILD_DIR)/Resources/AppIcon.icns

$(BUILD_DIR)/Resources/AppIcon.icns: Scripts/generate_icon.swift
	@mkdir -p $(BUILD_DIR)/Resources $(BUILD_DIR)/bin
	@echo "Generating SuperClip AppIcon.icns..."
	$(SWIFTC) $(SWIFTC_FLAGS_COMMON) -target $(TARGET_ARM64) Scripts/generate_icon.swift -o $(BUILD_DIR)/bin/generate_icon
	$(BUILD_DIR)/bin/generate_icon $@
	@echo "AppIcon generation complete: $@"

# Standalone Application Bundle Packaging (Universal 2: arm64 + x86_64)
app: lint icon
	@echo "Packaging SuperClip.app standalone application bundle..."
	@mkdir -p $(MACOS_DIR) $(FRAMEWORKS_DIR) $(RESOURCES_DIR)
	@if [ -f $(BUILD_DIR)/modules/SuperClipCore.swiftmodule ]; then rm -f $(BUILD_DIR)/modules/SuperClipCore.swiftmodule; fi
	@if [ -f $(BUILD_DIR)/modules/SuperClip.swiftmodule ]; then rm -f $(BUILD_DIR)/modules/SuperClip.swiftmodule; fi
	@mkdir -p $(BUILD_DIR)/modules/SuperClipCore.swiftmodule $(BUILD_DIR)/modules/SuperClip.swiftmodule
	@mkdir -p $(BUILD_DIR)/lib/arm64 $(BUILD_DIR)/lib/x86_64 $(BUILD_DIR)/bin/arm64 $(BUILD_DIR)/bin/x86_64
	@echo "Compiling SuperClipCore dynamic library slices (arm64 + x86_64)..."
	$(SWIFTC) $(SWIFTC_FLAGS_RELEASE) -target $(TARGET_ARM64) \
		-emit-library \
		-emit-module -emit-module-path $(BUILD_DIR)/modules/SuperClipCore.swiftmodule/arm64-apple-macos.swiftmodule \
		-module-name SuperClipCore \
		-parse-as-library \
		-Xlinker -install_name -Xlinker @rpath/libSuperClipCore.dylib \
		$(CORE_SRCS) \
		-o $(BUILD_DIR)/lib/arm64/libSuperClipCore.dylib
	$(SWIFTC) $(SWIFTC_FLAGS_RELEASE) -target $(TARGET_X86_64) \
		-emit-library \
		-emit-module -emit-module-path $(BUILD_DIR)/modules/SuperClipCore.swiftmodule/x86_64-apple-macos.swiftmodule \
		-module-name SuperClipCore \
		-parse-as-library \
		-Xlinker -install_name -Xlinker @rpath/libSuperClipCore.dylib \
		$(CORE_SRCS) \
		-o $(BUILD_DIR)/lib/x86_64/libSuperClipCore.dylib
	@echo "Merging SuperClipCore dynamic library with lipo..."
	$(LIPO) -create -output $(BUILD_DIR)/lib/libSuperClipCore.dylib \
		$(BUILD_DIR)/lib/arm64/libSuperClipCore.dylib \
		$(BUILD_DIR)/lib/x86_64/libSuperClipCore.dylib
	@echo "Compiling SuperClip standalone executable slices (arm64 + x86_64)..."
	$(SWIFTC) $(SWIFTC_FLAGS_RELEASE) -target $(TARGET_ARM64) \
		-I $(BUILD_DIR)/modules \
		-L $(BUILD_DIR)/lib/arm64 \
		-lSuperClipCore \
		-parse-as-library \
		-Xlinker -rpath -Xlinker @executable_path/../Frameworks \
		$(APP_SRCS) \
		-o $(BUILD_DIR)/bin/arm64/$(APP_NAME)
	$(SWIFTC) $(SWIFTC_FLAGS_RELEASE) -target $(TARGET_X86_64) \
		-I $(BUILD_DIR)/modules \
		-L $(BUILD_DIR)/lib/x86_64 \
		-lSuperClipCore \
		-parse-as-library \
		-Xlinker -rpath -Xlinker @executable_path/../Frameworks \
		$(APP_SRCS) \
		-o $(BUILD_DIR)/bin/x86_64/$(APP_NAME)
	@echo "Merging SuperClip standalone executable with lipo..."
	$(LIPO) -create -output $(MACOS_DIR)/$(APP_NAME) \
		$(BUILD_DIR)/bin/arm64/$(APP_NAME) \
		$(BUILD_DIR)/bin/x86_64/$(APP_NAME)
	@chmod 755 $(MACOS_DIR)/$(APP_NAME)
	@echo "Installing dynamic framework into bundle..."
	@cp -f $(BUILD_DIR)/lib/libSuperClipCore.dylib $(FRAMEWORKS_DIR)/libSuperClipCore.dylib
	@chmod 755 $(FRAMEWORKS_DIR)/libSuperClipCore.dylib
	$(INSTALL_NAME_TOOL) -id @rpath/libSuperClipCore.dylib $(FRAMEWORKS_DIR)/libSuperClipCore.dylib
	@echo "Installing bundle metadata and icon resources..."
	@cp -f Sources/SuperClip/App/Info.plist $(BUNDLE_DIR)/Info.plist
	@chmod 644 $(BUNDLE_DIR)/Info.plist
	@printf "APPL????" > $(BUNDLE_DIR)/PkgInfo
	@chmod 644 $(BUNDLE_DIR)/PkgInfo
	@cp -f $(BUILD_DIR)/Resources/AppIcon.icns $(RESOURCES_DIR)/AppIcon.icns
	@chmod 644 $(RESOURCES_DIR)/AppIcon.icns
	@echo "Signing application bundle inside-out..."
	$(CODESIGN) --force --sign - $(FRAMEWORKS_DIR)/libSuperClipCore.dylib
	$(CODESIGN) --force --deep --sign - $(BUNDLE_NAME)
	@echo "Verifying code signature integrity..."
	$(CODESIGN) -v --deep --strict $(BUNDLE_NAME)
	$(CODESIGN) --verify --verbose=4 $(FRAMEWORKS_DIR)/libSuperClipCore.dylib
	@echo "SuperClip.app standalone packaging complete."

bundle: app
package: app

# Standalone App Bundle Verification
verify-app: bundle
	@echo "Executing SuperClip.app standalone bundle verifications..."
	@bash Scripts/verify_app.sh $(BUNDLE_NAME)
	@bash Scripts/verify_bundle.sh
	@echo "All standalone bundle verifications PASSED."

# Static Zero-Emoji Lint Check
lint:
	@echo "Verifying strict styling constraints (0 emojis)..."
	@$(PYTHON) Scripts/lint_emojis.py Sources/ Tests/ Scripts/ Makefile Package.swift README.md LICENSE
	@echo "Styling check passed: 0 emojis detected, SF Symbols compliant."

# Automated Verification Runner (R5)
verify: build
	@echo "Executing SuperClip automated verification suite..."
	@bash Scripts/verify.sh

# Unit Tests
test: verify

# Adversarial Stress Tests
adversarial: build
	@echo "Executing SuperClip adversarial stress test suite..."
	@bash Scripts/run_adversarial.sh

# Clean Artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR) $(BUNDLE_NAME) SuperClip-*.zip .verifier_bin .adversarial_runner /tmp/SuperClip_*
	@echo "Clean completed."
