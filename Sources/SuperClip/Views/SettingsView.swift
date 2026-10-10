import SwiftUI
import AppKit
import Carbon
import SuperClipCore

/// AppSettings convenience extension for specification naming compatibility.
extension AppSettings {
    public var maxItemCount: Int {
        get { capacity }
        set { capacity = newValue }
    }
}

/// Model representing a selectable Carbon keyboard key.
public struct CarbonKeyItem: Identifiable, Hashable, Sendable {
    public let id: UInt32
    public let code: UInt32
    public let name: String

    public init(code: UInt32, name: String) {
        self.id = code
        self.code = code
        self.name = name
    }
}

/// Helper utilities for formatting and validating Carbon global hotkey combinations.
public struct KeyCombinationHelper {
    public static let standardKeys: [CarbonKeyItem] = [
        CarbonKeyItem(code: 0, name: "A"),
        CarbonKeyItem(code: 11, name: "B"),
        CarbonKeyItem(code: 8, name: "C"),
        CarbonKeyItem(code: 2, name: "D"),
        CarbonKeyItem(code: 14, name: "E"),
        CarbonKeyItem(code: 3, name: "F"),
        CarbonKeyItem(code: 5, name: "G"),
        CarbonKeyItem(code: 4, name: "H"),
        CarbonKeyItem(code: 34, name: "I"),
        CarbonKeyItem(code: 38, name: "J"),
        CarbonKeyItem(code: 40, name: "K"),
        CarbonKeyItem(code: 37, name: "L"),
        CarbonKeyItem(code: 46, name: "M"),
        CarbonKeyItem(code: 45, name: "N"),
        CarbonKeyItem(code: 31, name: "O"),
        CarbonKeyItem(code: 35, name: "P"),
        CarbonKeyItem(code: 12, name: "Q"),
        CarbonKeyItem(code: 15, name: "R"),
        CarbonKeyItem(code: 1, name: "S"),
        CarbonKeyItem(code: 17, name: "T"),
        CarbonKeyItem(code: 32, name: "U"),
        CarbonKeyItem(code: 9, name: "V"),
        CarbonKeyItem(code: 13, name: "W"),
        CarbonKeyItem(code: 7, name: "X"),
        CarbonKeyItem(code: 16, name: "Y"),
        CarbonKeyItem(code: 6, name: "Z"),
        CarbonKeyItem(code: 29, name: "0"),
        CarbonKeyItem(code: 18, name: "1"),
        CarbonKeyItem(code: 19, name: "2"),
        CarbonKeyItem(code: 20, name: "3"),
        CarbonKeyItem(code: 21, name: "4"),
        CarbonKeyItem(code: 23, name: "5"),
        CarbonKeyItem(code: 22, name: "6"),
        CarbonKeyItem(code: 26, name: "7"),
        CarbonKeyItem(code: 28, name: "8"),
        CarbonKeyItem(code: 25, name: "9"),
        CarbonKeyItem(code: 49, name: "Space"),
        CarbonKeyItem(code: 48, name: "Tab"),
        CarbonKeyItem(code: 50, name: "`")
    ]

    public static func modifierDescription(for modifiers: UInt32) -> String {
        var parts: [String] = []
        if (modifiers & UInt32(controlKey)) != 0 { parts.append("Control") }
        if (modifiers & UInt32(optionKey)) != 0 { parts.append("Option") }
        if (modifiers & UInt32(shiftKey)) != 0 { parts.append("Shift") }
        if (modifiers & UInt32(cmdKey)) != 0 { parts.append("Command") }
        return parts.joined(separator: " + ")
    }

    public static func keyName(for code: UInt32) -> String {
        if let match = standardKeys.first(where: { $0.code == code }) {
            return match.name
        }
        return "Key \(code)"
    }

    public static func formattedShortcut(keyCode: UInt32, modifiers: UInt32) -> String {
        let modStr = modifierDescription(for: modifiers)
        let key = keyName(for: keyCode)
        if modStr.isEmpty {
            return key
        }
        return "\(modStr) + \(key)"
    }

    public static func isValidHotKey(modifiers: UInt32) -> Bool {
        let meaningful = modifiers & (UInt32(cmdKey) | UInt32(optionKey) | UInt32(controlKey))
        return meaningful != 0
    }
}

/// SettingsView provides configuration for SuperClip preferences (Features 29 & 30):
/// - Capacity adjustment UI: Slider and Stepper / Text field (range: 10 to 500 items, default 100)
/// - Explanatory note: "Pinned clips are permanently protected and do not count toward this limit."
/// - Hotkey customization UI: displays current hotkey, key combination recorder and manual pickers
/// - Dynamic binding and live registration on HotKeyManager and StorageManager
/// - Flat design SF Symbols; strictly 0 emojis invariant across all UI strings and icons
public struct SettingsView: View {
    @ObservedObject public var storageManager: StorageManager
    public var hotKeyManager: HotKeyManaging
    public var onDismiss: (() -> Void)?

    @State private var selectedTab: SettingsTab = .hotkey
    @State private var isRecordingHotKey: Bool = false
    @State private var localKeyMonitor: Any? = nil
    @State private var showingClearConfirmation: Bool = false
    @State private var showingResetConfirmation: Bool = false
    @State private var hotKeyWarningMessage: String? = nil

    public enum SettingsTab: String, CaseIterable, Identifiable {
        case hotkey = "HotKey"
        case retention = "Retention"
        case storage = "Storage"
        case general = "General"

        public var id: String { rawValue }

        public var iconName: String {
            switch self {
            case .hotkey: return "keyboard"
            case .retention: return "slider.horizontal.3"
            case .storage: return "internaldrive"
            case .general: return "gearshape"
            }
        }
    }

    public init(
        storageManager: StorageManager,
        hotKeyManager: HotKeyManaging = HotKeyManager.shared,
        onClose: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.storageManager = storageManager
        self.hotKeyManager = hotKeyManager
        self.onDismiss = onClose ?? onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            tabPicker
            Divider()
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedTab {
                    case .hotkey:
                        hotKeySection
                    case .retention:
                        retentionSection
                    case .storage:
                        storageSection
                    case .general:
                        generalSection
                    }
                }
                .padding(16)
            }
            Divider()
            footerBar
        }
        .frame(width: 440, height: 340)
        .background(Color(nsColor: .windowBackgroundColor))
        .onDisappear {
            stopRecordingHotKey()
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "gearshape")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.accentColor)
            Text("Settings")
                .font(.system(size: 14, weight: .bold))
            Spacer()
            if let dismiss = onDismiss {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("Close Settings")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        Picker("Category", selection: $selectedTab) {
            ForEach(SettingsTab.allCases) { tab in
                Label(tab.rawValue, systemImage: tab.iconName).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - HotKey Section (Feature 29)

    private var hotKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Global Hotkey Customization")
                    .font(.system(size: 13, weight: .bold))
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("Summons the floating clipboard panel centered at the mouse cursor.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 8) {
                HStack {
                    Text("Current Hotkey:")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text(KeyCombinationHelper.formattedShortcut(
                        keyCode: storageManager.settings.hotKeyKeyCode,
                        modifiers: storageManager.settings.hotKeyModifiers
                    ))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                }

                HStack {
                    if isRecordingHotKey {
                        Text("Press desired key combination...")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.accentColor)
                        Spacer()
                        Button("Cancel") {
                            stopRecordingHotKey()
                        }
                    } else {
                        Button("Record Shortcut") {
                            startRecordingHotKey()
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 6) {
                Text("Modifier Flags")
                    .font(.system(size: 12, weight: .semibold))

                HStack(spacing: 14) {
                    Toggle("Option (Alt)", isOn: Binding(
                        get: { (storageManager.settings.hotKeyModifiers & UInt32(optionKey)) != 0 },
                        set: { toggleModifier(flag: UInt32(optionKey), enable: $0) }
                    ))
                    Toggle("Command", isOn: Binding(
                        get: { (storageManager.settings.hotKeyModifiers & UInt32(cmdKey)) != 0 },
                        set: { toggleModifier(flag: UInt32(cmdKey), enable: $0) }
                    ))
                    Toggle("Control", isOn: Binding(
                        get: { (storageManager.settings.hotKeyModifiers & UInt32(controlKey)) != 0 },
                        set: { toggleModifier(flag: UInt32(controlKey), enable: $0) }
                    ))
                    Toggle("Shift", isOn: Binding(
                        get: { (storageManager.settings.hotKeyModifiers & UInt32(shiftKey)) != 0 },
                        set: { toggleModifier(flag: UInt32(shiftKey), enable: $0) }
                    ))
                }
                .toggleStyle(.checkbox)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Key Code")
                    .font(.system(size: 12, weight: .semibold))
                Picker("Key", selection: Binding(
                    get: { storageManager.settings.hotKeyKeyCode },
                    set: { updateKeyCode($0) }
                )) {
                    ForEach(KeyCombinationHelper.standardKeys) { item in
                        Text(item.name).tag(item.code)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Quick Presets")
                    .font(.system(size: 12, weight: .semibold))
                HStack(spacing: 8) {
                    Button("Option + V (Default)") {
                        applyHotKey(keyCode: 9, modifiers: UInt32(optionKey))
                    }
                    Button("Cmd + Shift + V") {
                        applyHotKey(keyCode: 9, modifiers: UInt32(cmdKey | shiftKey))
                    }
                    Button("Option + Space") {
                        applyHotKey(keyCode: 49, modifiers: UInt32(optionKey))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if let warning = hotKeyWarningMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(warning)
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            }
        }
    }

    // MARK: - Retention Section (Feature 30)

    private var retentionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("History Retention Capacity")
                    .font(.system(size: 13, weight: .bold))
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("Maximum number of unpinned history clips retained in local storage.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 10) {
                HStack {
                    Text("Retention Capacity:")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Stepper(
                        value: Binding(
                            get: { storageManager.capacity },
                            set: { storageManager.capacity = max(10, min($0, 500)) }
                        ),
                        in: 10...500,
                        step: 10
                    ) {
                        Text("\(storageManager.capacity) clips")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.accentColor)
                    }
                }

                Slider(
                    value: Binding(
                        get: { Double(storageManager.capacity) },
                        set: { storageManager.capacity = Int($0) }
                    ),
                    in: 10...500,
                    step: 10
                ) {
                    Text("Capacity Slider")
                } minimumValueLabel: {
                    Text("10")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                } maximumValueLabel: {
                    Text("500")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 6) {
                Text("Presets")
                    .font(.system(size: 12, weight: .semibold))
                HStack(spacing: 8) {
                    Button("25") { storageManager.capacity = 25 }
                    Button("50") { storageManager.capacity = 50 }
                    Button("100 (Default)") { storageManager.capacity = 100 }
                    Button("250") { storageManager.capacity = 250 }
                    Button("500") { storageManager.capacity = 500 }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.accentColor)
                    Text("Pin Protection Guarantee")
                        .font(.system(size: 12, weight: .semibold))
                }
                Text("Pinned clips are permanently protected and do not count toward this limit.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
            .cornerRadius(6)
        }
    }

    // MARK: - Storage Section

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Storage Statistics & Maintenance")
                    .font(.system(size: 13, weight: .bold))
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("Overview of local clipboard storage statistics and maintenance actions.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 6) {
                metricRow(label: "Total Stored Clips", value: "\(storageManager.items.count)")
                metricRow(label: "Pinned Clips", value: "\(storageManager.pinnedItems.count)")
                metricRow(label: "Unpinned History", value: "\(storageManager.historyItems.count)")
                metricRow(label: "Disk Space Used", value: calculateDiskUsageFormatted())
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text("Storage Location")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Text(storageManager.baseDirectory.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(4)
            }

            HStack(spacing: 12) {
                Button(action: { showingClearConfirmation = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Clear All Unpinned History")
                    }
                }
                .buttonStyle(.bordered)
                .confirmationDialog(
                    "Clear all unpinned clips?",
                    isPresented: $showingClearConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Clear History", role: .destructive) {
                        storageManager.clearUnpinnedHistory()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This permanently deletes unpinned items. All pinned clips will be preserved.")
                }

                Button(action: openStorageFolder) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                        Text("Open in Finder")
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("General Preferences")
                    .font(.system(size: 13, weight: .bold))
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("Application configuration and defaults.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 8) {
                HStack {
                    Text("Pasteboard Poll Interval:")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text("\(storageManager.settings.pollIntervalMs) ms")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }

                Divider()

                HStack {
                    Text("Thumbnail Downscale Target:")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text("Max \(storageManager.settings.maxThumbnailPixelSize) px")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)

            Button(action: { showingResetConfirmation = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset All to Defaults")
                }
            }
            .buttonStyle(.bordered)
            .confirmationDialog(
                "Reset settings to defaults?",
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset Defaults", role: .destructive) {
                    resetToDefaults()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This resets hotkey to Option+V and capacity to 100 items.")
            }

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                Text("SuperClip 1.0.0")
                    .font(.system(size: 11, weight: .semibold))
                Text("Native macOS clipboard manager. SF Symbols flat design. 0 emojis.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        HStack {
            Spacer()
            Button("Done") {
                onDismiss?()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Helper Methods

    private func metricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
        }
    }

    private func toggleModifier(flag: UInt32, enable: Bool) {
        var current = storageManager.settings.hotKeyModifiers
        if enable {
            current |= flag
        } else {
            current &= ~flag
        }
        if KeyCombinationHelper.isValidHotKey(modifiers: current) {
            hotKeyWarningMessage = nil
            applyHotKey(keyCode: storageManager.settings.hotKeyKeyCode, modifiers: current)
        } else {
            hotKeyWarningMessage = "At least one modifier (Option, Command, Control) is required."
        }
    }

    private func updateKeyCode(_ newCode: UInt32) {
        let currentMods = storageManager.settings.hotKeyModifiers
        applyHotKey(keyCode: newCode, modifiers: currentMods)
    }

    private func applyHotKey(keyCode: UInt32, modifiers: UInt32) {
        guard KeyCombinationHelper.isValidHotKey(modifiers: modifiers) else {
            hotKeyWarningMessage = "At least one modifier (Option, Command, Control) is required."
            return
        }
        hotKeyWarningMessage = nil
        var updated = storageManager.settings
        updated.hotKeyKeyCode = keyCode
        updated.hotKeyModifiers = modifiers
        storageManager.settings = updated
        hotKeyManager.register(keyCode: keyCode, modifiers: modifiers)
    }

    private func startRecordingHotKey() {
        stopRecordingHotKey()
        isRecordingHotKey = true

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                stopRecordingHotKey()
                return nil
            }
            let mods = event.modifierFlags
            var carbonFlags: UInt32 = 0
            if mods.contains(.command) { carbonFlags |= UInt32(cmdKey) }
            if mods.contains(.option) { carbonFlags |= UInt32(optionKey) }
            if mods.contains(.control) { carbonFlags |= UInt32(controlKey) }
            if mods.contains(.shift) { carbonFlags |= UInt32(shiftKey) }

            if KeyCombinationHelper.isValidHotKey(modifiers: carbonFlags) {
                let code = UInt32(event.keyCode)
                applyHotKey(keyCode: code, modifiers: carbonFlags)
                stopRecordingHotKey()
                return nil
            }
            return event
        }
    }

    private func stopRecordingHotKey() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        isRecordingHotKey = false
    }

    private func resetToDefaults() {
        let def = AppSettings()
        storageManager.capacity = AppSettings.defaultCapacity
        storageManager.settings = def
        hotKeyManager.register(
            keyCode: AppSettings.defaultHotKeyKeyCode,
            modifiers: AppSettings.defaultHotKeyModifiers
        )
    }

    private func calculateDiskUsageFormatted() -> String {
        let url = storageManager.baseDirectory
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return "0 KB"
        }
        var totalBytes: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let vals = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
               vals.isRegularFile == true,
               let sz = vals.fileSize {
                totalBytes += Int64(sz)
            }
        }
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useBytes, .useKB, .useMB]
        bcf.countStyle = .file
        return bcf.string(fromByteCount: totalBytes)
    }

    private func openStorageFolder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: storageManager.baseDirectory.path)
    }
}
