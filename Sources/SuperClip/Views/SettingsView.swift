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

/// SettingsView provides configuration for SuperClip preferences matching
/// the native macOS CopyClip preferences design:
/// - Top icon-above-label tabs: General, Ignored Apps, Clips Management, About
/// - Rounded card containers (RoundedRectangle(cornerRadius: 10))
/// - Clippings card: Remember [ X ] clippings, Display [ Y ] clippings
/// - Options card: Start at startup, Record history, Hotkey customization (default Option + V)
/// - Underlying persistence via StorageManager.settings and Carbon HotKeyManager
/// - Strict 0-emoji invariant across all UI strings and icons
public struct SettingsView: View {
    @ObservedObject public var storageManager: StorageManager
    public var hotKeyManager: HotKeyManaging
    public var onDismiss: (() -> Void)?

    @State private var selectedTab: SettingsTab = .general
    @State private var isRecordingHotKey: Bool = false
    @State private var localKeyMonitor: Any? = nil
    @State private var showingClearConfirmation: Bool = false
    @State private var showingResetConfirmation: Bool = false
    @State private var hotKeyWarningMessage: String? = nil

    public enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case ignoredApps = "Ignored Apps"
        case clipsManagement = "Clips Management"
        case about = "About"

        public var id: String { rawValue }

        public var iconName: String {
            switch self {
            case .general: return "gear"
            case .ignoredApps: return "eye.slash"
            case .clipsManagement: return "doc.on.clipboard"
            case .about: return "info.circle"
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
            topTabBar
            Divider()
            contentArea
            Divider()
            footerBar
        }
        .frame(width: 460, height: 420)
        .background(Color(nsColor: .windowBackgroundColor))
        .onDisappear {
            stopRecordingHotKey()
        }
    }

    // MARK: - Top Tab Bar (Icon above Label with Active Highlight)

    private var topTabBar: some View {
        HStack(spacing: 24) {
            ForEach(SettingsTab.allCases) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 20, weight: .regular))
                            .frame(height: 24)
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                    }
                    .foregroundColor(selectedTab == tab ? .primary : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selectedTab == tab ? Color.secondary.opacity(0.15) : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        ScrollView {
            VStack(spacing: 14) {
                switch selectedTab {
                case .general:
                    generalTabContent
                case .ignoredApps:
                    ignoredAppsTabContent
                case .clipsManagement:
                    clipsManagementTabContent
                case .about:
                    aboutTabContent
                }
            }
            .padding(16)
        }
    }

    // MARK: - General Tab Content (CopyClip Cards)

    private var generalTabContent: some View {
        VStack(spacing: 14) {
            clippingsCard
            optionsCard
        }
    }

    // MARK: - Clippings Card

    private var clippingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Clippings")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("Remember:")
                        .font(.system(size: 12))
                        .frame(width: 80, alignment: .leading)

                    TextField("", value: Binding(
                        get: { storageManager.capacity },
                        set: { storageManager.capacity = max(10, min($0, 500)) }
                    ), formatter: NumberFormatter())
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)

                    Stepper("", value: Binding(
                        get: { storageManager.capacity },
                        set: { storageManager.capacity = max(10, min($0, 500)) }
                    ), in: 10...500, step: 10)
                    .labelsHidden()

                    Text("clippings")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    Text("Display:")
                        .font(.system(size: 12))
                        .frame(width: 80, alignment: .leading)

                    TextField("", value: Binding(
                        get: { storageManager.settings.displayCapacity },
                        set: { newDisp in
                            var s = storageManager.settings
                            s.displayCapacity = max(5, min(newDisp, 200))
                            storageManager.settings = s
                        }
                    ), formatter: NumberFormatter())
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)

                    Stepper("", value: Binding(
                        get: { storageManager.settings.displayCapacity },
                        set: { newDisp in
                            var s = storageManager.settings
                            s.displayCapacity = max(5, min(newDisp, 200))
                            storageManager.settings = s
                        }
                    ), in: 5...200, step: 5)
                    .labelsHidden()

                    Text("clippings")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Text("Pinned clips are permanently protected and do not count toward this limit.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Options Card

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Options")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Start SuperClip at system startup", isOn: Binding(
                    get: { storageManager.settings.launchAtLogin },
                    set: { newVal in
                        var s = storageManager.settings
                        s.launchAtLogin = newVal
                        storageManager.settings = s
                    }
                ))
                .toggleStyle(.checkbox)
                .font(.system(size: 12))

                Toggle("Record clipboard history", isOn: Binding(
                    get: { storageManager.settings.recordClipboardHistory },
                    set: { newVal in
                        var s = storageManager.settings
                        s.recordClipboardHistory = newVal
                        storageManager.settings = s
                    }
                ))
                .toggleStyle(.checkbox)
                .font(.system(size: 12))
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Shortcut:")
                        .font(.system(size: 12))
                        .frame(width: 80, alignment: .leading)

                    Text(KeyCombinationHelper.formattedShortcut(
                        keyCode: storageManager.settings.hotKeyKeyCode,
                        modifiers: storageManager.settings.hotKeyModifiers
                    ))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 0.8)
                    )

                    if isRecordingHotKey {
                        Text("Press shortcut...")
                            .font(.system(size: 11))
                            .foregroundColor(.accentColor)

                        Button("Cancel") {
                            stopRecordingHotKey()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Button("Record") {
                            startRecordingHotKey()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Menu("Presets") {
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
                    .menuStyle(.borderedButton)
                    .controlSize(.small)
                }

                HStack(spacing: 12) {
                    Toggle("Option", isOn: Binding(
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

                    Picker("", selection: Binding(
                        get: { storageManager.settings.hotKeyKeyCode },
                        set: { updateKeyCode($0) }
                    )) {
                        ForEach(KeyCombinationHelper.standardKeys) { item in
                            Text(item.name).tag(item.code)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 75)
                }
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
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
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Ignored Apps Tab Content

    private var ignoredAppsTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ignored Applications")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)

            Text("SuperClip will not record clippings copied from applications in this list.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .frame(height: 120)
                    .overlay(
                        VStack(spacing: 6) {
                            Image(systemName: "eye.slash")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                            Text("No ignored applications")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("Clipboard items will be recorded from all applications.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 0.8)
                    )

                HStack {
                    Button(action: {}) {
                        Image(systemName: "plus")
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(action: {}) {
                        Image(systemName: "minus")
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(true)

                    Spacer()
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Clips Management Tab Content

    private var clipsManagementTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Clips Management")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)

            VStack(spacing: 6) {
                metricRow(label: "Total Stored Clips", value: "\(storageManager.items.count)")
                metricRow(label: "Pinned Clips", value: "\(storageManager.pinnedItems.count)")
                metricRow(label: "Unpinned History", value: "\(storageManager.historyItems.count)")
                metricRow(label: "Disk Space Used", value: calculateDiskUsageFormatted())
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(6)

            VStack(alignment: .leading, spacing: 4) {
                Text("Storage Location:")
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
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - About Tab Content

    private var aboutTabContent: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
                .padding(.top, 8)

            Text("SuperClip")
                .font(.system(size: 18, weight: .bold))

            Text("Version 1.0.0")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Text("Native ultra-compact clipboard manager for macOS inspired by CopyClip.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Divider()

            HStack(spacing: 16) {
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
            }
            .padding(.bottom, 8)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
                )
        )
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
