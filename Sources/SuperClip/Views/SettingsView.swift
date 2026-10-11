import SwiftUI
import AppKit
import Carbon
import UniformTypeIdentifiers
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
        CarbonKeyItem(code: 36, name: "Return"),
        CarbonKeyItem(code: 48, name: "Tab"),
        CarbonKeyItem(code: 53, name: "Escape"),
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
/// native macOS preferences design:
/// - Top icon-above-label tabs: General, Ignored Apps, Clips Management, About
/// - Rounded card containers (RoundedRectangle(cornerRadius: 10))
/// - Clippings card: Remember [ X ] clippings, Display [ Y ] clippings
/// - Options card: Start at startup, Record history, Hotkey customization (default Option + V)
/// - Underlying persistence via StorageManager.settings and Carbon HotKeyManager
/// - Strict 0-emoji invariant across all UI strings and icons
public struct SettingsView: View {
    @ObservedObject public var storageManager: StorageManager
    @ObservedObject public var updateManager: UpdateManager
    @ObservedObject private var localizationManager = LocalizationManager.shared
    public var hotKeyManager: HotKeyManaging
    public var launchAtLoginManager: any LaunchAtLoginManaging
    public var onDismiss: (() -> Void)?

    @State private var selectedTab: SettingsTab = .general
    @State private var isRecordingHotKey: Bool = false
    @State private var localKeyMonitor: Any? = nil
    @State private var showingClearConfirmation: Bool = false
    @State private var showingResetConfirmation: Bool = false
    @State private var hotKeyWarningMessage: String? = nil

    private final class SelectionBox: @unchecked Sendable {
        var id: String? = nil
        var isSet: Bool = false
    }
    private let selectionBox = SelectionBox()
    @State private var internalSelectedIgnoredAppId: String? = nil

    public var selectedIgnoredAppId: String? {
        get {
            if selectionBox.isSet {
                return selectionBox.id
            }
            return internalSelectedIgnoredAppId
        }
        nonmutating set {
            selectionBox.id = newValue
            selectionBox.isSet = true
            internalSelectedIgnoredAppId = newValue
        }
    }

    public enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case ignoredApps = "Ignored Apps"
        case clipsManagement = "Clips Management"
        case about = "About"

        public var id: String { rawValue }

        public var localizedTitle: String {
            switch self {
            case .general: return LocalizationManager.shared.tr(.tabGeneral)
            case .ignoredApps: return LocalizationManager.shared.tr(.tabIgnoredApps)
            case .clipsManagement: return LocalizationManager.shared.tr(.tabClipsManagement)
            case .about: return LocalizationManager.shared.tr(.tabAbout)
            }
        }

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
        launchAtLoginManager: any LaunchAtLoginManaging = LaunchAtLoginManager.shared,
        updateManager: UpdateManager = UpdateManager.shared,
        onClose: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.storageManager = storageManager
        self.hotKeyManager = hotKeyManager
        self.launchAtLoginManager = launchAtLoginManager
        self.updateManager = updateManager
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
        .frame(width: 490, height: 475)
        .background(Color(nsColor: .windowBackgroundColor))
        .onDisappear {
            stopRecordingHotKey()
        }
    }

    // MARK: - Top Tab Bar (Icon above Label with Active Highlight)

    private var topTabBar: some View {
        HStack(spacing: 20) {
            ForEach(SettingsTab.allCases) { tab in
                Button(action: {
                    stopRecordingHotKey()
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 20, weight: .regular))
                            .frame(height: 24)
                        Text(tab.localizedTitle)
                            .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                            .lineLimit(1)
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

    // MARK: - General Tab Content

    private var generalTabContent: some View {
        VStack(spacing: 14) {
            clippingsCard
            optionsCard
        }
    }

    // MARK: - Clippings Card

    private var clippingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizationManager.shared.tr(.clippingsTitle))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(LocalizationManager.shared.tr(.rememberLabel))
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

                    Text(LocalizationManager.shared.tr(.clippingsUnit))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    Text(LocalizationManager.shared.tr(.displayLabel))
                        .font(.system(size: 12))
                        .frame(width: 80, alignment: .leading)

                    TextField("", value: Binding(
                        get: { storageManager.settings.displayCapacity },
                        set: { newDisp in
                            var s = storageManager.settings
                            s.displayCapacity = max(5, min(newDisp, 500))
                            storageManager.settings = s
                        }
                    ), formatter: NumberFormatter())
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)

                    Stepper("", value: Binding(
                        get: { storageManager.settings.displayCapacity },
                        set: { newDisp in
                            var s = storageManager.settings
                            s.displayCapacity = max(5, min(newDisp, 500))
                            storageManager.settings = s
                        }
                    ), in: 5...500, step: 5)
                    .labelsHidden()

                    Text(LocalizationManager.shared.tr(.clippingsUnit))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Text(LocalizationManager.shared.tr(.pinGuaranteeNote))
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
            Text(LocalizationManager.shared.tr(.optionsTitle))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 8) {
                Toggle(LocalizationManager.shared.tr(.startAtLogin), isOn: Binding(
                    get: { storageManager.settings.launchAtLogin },
                    set: { newVal in
                        var s = storageManager.settings
                        s.launchAtLogin = newVal
                        storageManager.settings = s
                        launchAtLoginManager.setEnabled(newVal)
                    }
                ))
                .toggleStyle(.checkbox)
                .font(.system(size: 12))

                Toggle(LocalizationManager.shared.tr(.recordClipboardHistory), isOn: Binding(
                    get: { storageManager.settings.recordClipboardHistory },
                    set: { newVal in
                        var s = storageManager.settings
                        s.recordClipboardHistory = newVal
                        storageManager.settings = s
                    }
                ))
                .toggleStyle(.checkbox)
                .font(.system(size: 12))

                Toggle(LocalizationManager.shared.tr(.automaticallyCheckForUpdates), isOn: Binding(
                    get: { storageManager.settings.automaticallyCheckForUpdates },
                    set: { newVal in
                        var s = storageManager.settings
                        s.automaticallyCheckForUpdates = newVal
                        storageManager.settings = s
                    }
                ))
                .toggleStyle(.checkbox)
                .font(.system(size: 12))

                HStack(spacing: 8) {
                    Text(LocalizationManager.shared.tr(.languageLabel))
                        .font(.system(size: 12))
                        .frame(width: 80, alignment: .leading)

                    Picker("", selection: Binding(
                        get: { storageManager.settings.language },
                        set: { newLang in
                            var s = storageManager.settings
                            s.language = newLang
                            storageManager.settings = s
                        }
                    )) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 180)
                }
                .padding(.top, 2)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                // Top Action Bar (shortcut label + badge + Spacer + Action buttons)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        Text(LocalizationManager.shared.tr(.shortcutLabel))
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .fixedSize()

                        shortcutBadgeView

                        Spacer()

                        recordActionButton

                        quickPresetsMenuView
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(LocalizationManager.shared.tr(.shortcutLabel))
                                .font(.system(size: 12))
                                .lineLimit(1)
                                .fixedSize()

                            shortcutBadgeView

                            Spacer()
                        }

                        HStack(spacing: 8) {
                            Spacer()
                            recordActionButton
                            quickPresetsMenuView
                        }
                    }
                }

                // Dedicated Recording State Banner
                if isRecordingHotKey {
                    HStack(spacing: 6) {
                        Image(systemName: "record.circle")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 11, weight: .medium))
                        Text(LocalizationManager.shared.tr(.pressShortcutBannerHint))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.accentColor)
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Helper description text
                Text(LocalizationManager.shared.tr(.shortcutHelperText))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Modifiers Row
                HStack(spacing: 16) {
                    Toggle("Option (⌥)", isOn: Binding(
                        get: { (storageManager.settings.hotKeyModifiers & UInt32(optionKey)) != 0 },
                        set: { toggleModifier(flag: UInt32(optionKey), enable: $0) }
                    ))
                    Toggle("Command (⌘)", isOn: Binding(
                        get: { (storageManager.settings.hotKeyModifiers & UInt32(cmdKey)) != 0 },
                        set: { toggleModifier(flag: UInt32(cmdKey), enable: $0) }
                    ))
                    Toggle("Control (⌃)", isOn: Binding(
                        get: { (storageManager.settings.hotKeyModifiers & UInt32(controlKey)) != 0 },
                        set: { toggleModifier(flag: UInt32(controlKey), enable: $0) }
                    ))
                    Toggle("Shift (⇧)", isOn: Binding(
                        get: { (storageManager.settings.hotKeyModifiers & UInt32(shiftKey)) != 0 },
                        set: { toggleModifier(flag: UInt32(shiftKey), enable: $0) }
                    ))
                    Spacer()
                }
                .toggleStyle(.checkbox)
                .font(.system(size: 11))

                // Key Selection Row
                HStack(spacing: 8) {
                    Text(LocalizationManager.shared.tr(.keyLabel))
                        .font(.system(size: 12))
                        .frame(width: 80, alignment: .leading)

                    Picker("", selection: Binding(
                        get: { storageManager.settings.hotKeyKeyCode },
                        set: { updateKeyCode($0) }
                    )) {
                        ForEach(KeyCombinationHelper.standardKeys) { item in
                            Text(item.name).tag(item.code)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)

                    if storageManager.settings.hotKeyKeyCode != AppSettings.defaultHotKeyKeyCode || storageManager.settings.hotKeyModifiers != AppSettings.defaultHotKeyModifiers {
                        Button(action: {
                            applyHotKey(keyCode: AppSettings.defaultHotKeyKeyCode, modifiers: AppSettings.defaultHotKeyModifiers)
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.borderless)
                        .help("Reset shortcut to default (Option + V)")
                    }

                    Spacer()
                }
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

    // MARK: - Hotkey Subviews

    private var shortcutBadgeView: some View {
        Text(KeyCombinationHelper.formattedShortcut(
            keyCode: storageManager.settings.hotKeyKeyCode,
            modifiers: storageManager.settings.hotKeyModifiers
        ))
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(5)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(isRecordingHotKey ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isRecordingHotKey ? 1.5 : 0.8)
        )
    }

    private var recordActionButton: some View {
        Group {
            if isRecordingHotKey {
                Button(LocalizationManager.shared.tr(.cancelButton)) {
                    stopRecordingHotKey()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .fixedSize()
            } else {
                Button(LocalizationManager.shared.tr(.recordShortcutButton)) {
                    startRecordingHotKey()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .fixedSize()
            }
        }
    }

    private var quickPresetsMenuView: some View {
        Menu(LocalizationManager.shared.tr(.quickPresetsTitle)) {
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
        .fixedSize()
    }

    // MARK: - Ignored Apps Tab Content

    private var ignoredAppsTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizationManager.shared.tr(.tabIgnoredApps))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)

            Text(LocalizationManager.shared.tr(.ignoredAppsDesc))
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                if storageManager.settings.ignoredApps.isEmpty {
                    emptyIgnoredAppsView
                } else {
                    ignoredAppsListView
                }

                HStack(spacing: 8) {
                    Button(action: { openAppSelectionPanel() }) {
                        Image(systemName: "plus")
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(LocalizationManager.shared.tr(.addAppButton))

                    Button(action: { removeSelectedIgnoredApp() }) {
                        Image(systemName: "minus")
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(selectedIgnoredAppId == nil || !storageManager.settings.ignoredApps.contains(where: { $0.id == selectedIgnoredAppId }))
                    .help(LocalizationManager.shared.tr(.removeButton))

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

    private var emptyIgnoredAppsView: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color(nsColor: .textBackgroundColor))
            .frame(height: 140)
            .overlay(
                VStack(spacing: 6) {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text(LocalizationManager.shared.tr(.noIgnoredApps))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.8)
            )
    }

    private var ignoredAppsListView: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(storageManager.settings.ignoredApps) { app in
                    ignoredAppRow(app)
                }
            }
            .padding(4)
        }
        .frame(height: 140)
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.8)
        )
    }

    private func ignoredAppRow(_ app: IgnoredApp) -> some View {
        let isSelected = selectedIgnoredAppId == app.id
        return HStack(spacing: 8) {
            appIconImage(for: app)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)

            Text(app.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            Text(app.bundleIdentifier)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedIgnoredAppId = app.id
        }
    }

    private func appIconImage(for app: IgnoredApp) -> Image {
        if let path = app.iconPath, FileManager.default.fileExists(atPath: path) {
            let icon = NSWorkspace.shared.icon(forFile: path)
            return Image(nsImage: icon)
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            return Image(nsImage: icon)
        }
        let icon = NSWorkspace.shared.icon(for: .application)
        return Image(nsImage: icon)
    }

    public func openAppSelectionPanel() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = LocalizationManager.shared.tr(.addAppButton)
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [.applicationBundle, .application]
        } else {
            panel.allowedFileTypes = ["app"]
        }
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.treatsFilePackagesAsDirectories = false

        if panel.runModal() == .OK {
            for url in panel.urls {
                addIgnoredApp(from: url)
            }
        }
    }

    public func addIgnoredApp(from url: URL) {
        let name: String
        let bundleId: String

        if let bundle = Bundle(url: url) {
            let localizedDisplayName = (bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayName = (bundle.infoDictionary?["CFBundleDisplayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let bundleName = (bundle.infoDictionary?["CFBundleName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let finderName = FileManager.default.displayName(atPath: url.path).trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackName = url.deletingPathExtension().lastPathComponent
            let candidateName: String
            if let ld = localizedDisplayName, !ld.isEmpty {
                candidateName = ld
            } else if let d = displayName, !d.isEmpty {
                candidateName = d
            } else if let b = bundleName, !b.isEmpty {
                candidateName = b
            } else if !finderName.isEmpty {
                candidateName = finderName
            } else {
                candidateName = fallbackName
            }
            name = candidateName

            if let bid = bundle.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines), !bid.isEmpty {
                bundleId = bid
            } else {
                bundleId = candidateName
            }
        } else {
            let finderName = FileManager.default.displayName(atPath: url.path).trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackName = url.deletingPathExtension().lastPathComponent
            name = !finderName.isEmpty ? finderName : fallbackName
            bundleId = name
        }

        let newApp = IgnoredApp(bundleIdentifier: bundleId, name: name, iconPath: url.path)
        storageManager.addIgnoredApp(newApp)
    }

    public func removeSelectedIgnoredApp() {
        guard let id = selectedIgnoredAppId else { return }
        storageManager.removeIgnoredApp(bundleIdentifier: id)
        selectedIgnoredAppId = nil
    }

    public func selectIgnoredApp(id: String?) {
        selectedIgnoredAppId = id
    }

    // MARK: - Clips Management Tab Content

    private var clipsManagementTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizationManager.shared.tr(.tabClipsManagement))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)

            VStack(spacing: 6) {
                metricRow(label: LocalizationManager.shared.tr(.totalStoredClips), value: "\(storageManager.items.count)")
                metricRow(label: LocalizationManager.shared.tr(.pinnedClips), value: "\(storageManager.pinnedItems.count)")
                metricRow(label: LocalizationManager.shared.tr(.unpinnedHistory), value: "\(storageManager.historyItems.count)")
                metricRow(label: LocalizationManager.shared.tr(.diskSpaceUsed), value: calculateDiskUsageFormatted())
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(6)

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizationManager.shared.tr(.storageLocation) + ":")
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
                        Text(LocalizationManager.shared.tr(.clearAllUnpinnedHistory))
                    }
                }
                .buttonStyle(.bordered)
                .confirmationDialog(
                    LocalizationManager.shared.tr(.clearConfirmTitle),
                    isPresented: $showingClearConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(LocalizationManager.shared.tr(.clearHistory), role: .destructive) {
                        storageManager.clearUnpinnedHistory()
                    }
                    Button(LocalizationManager.shared.tr(.cancelButton), role: .cancel) {}
                } message: {
                    Text(LocalizationManager.shared.tr(.clearConfirmMessage))
                }

                Button(action: openStorageFolder) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                        Text(LocalizationManager.shared.tr(.openInFinder))
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
        VStack(spacing: 12) {
            if let appIcon = NSApp?.applicationIconImage, appIcon.isValid {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                    .padding(.top, 4)
            } else {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 36))
                    .foregroundColor(.accentColor)
                    .padding(.top, 6)
            }

            VStack(spacing: 2) {
                Text(LocalizationManager.shared.tr(.appTitle))
                    .font(.system(size: 16, weight: .bold))

                Text(LocalizationManager.shared.tr(.versionLabel(updateManager.currentVersion)))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Divider()

            VStack(spacing: 8) {
                HStack {
                    Text(LocalizationManager.shared.tr(.authorLabel) + ":")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Nhan Quach (@nhanqv-ai)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                }

                HStack {
                    Text(LocalizationManager.shared.tr(.licenseLabel) + ":")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("MIT License")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                }

                HStack {
                    Text("GitHub:")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: {
                        if let url = URL(string: "https://github.com/nhanqv-ai/SuperClip") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text("nhanqv-ai/SuperClip")
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: "arrow.up.forward.square")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }

                Divider()
                    .padding(.vertical, 2)

                HStack {
                    Button(action: {
                        updateManager.checkForUpdates(userInitiated: true)
                    }) {
                        HStack(spacing: 4) {
                            if case .checking = updateManager.status {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.6)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 11))
                            }
                            Text(LocalizationManager.shared.tr(.checkForUpdates))
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(updateManager.isBusy)

                    Spacer()

                    updateStatusLabel
                }
            }
            .padding(.horizontal, 14)

            Divider()

            HStack(spacing: 16) {
                Button(action: { showingResetConfirmation = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text(LocalizationManager.shared.tr(.resetAllDefaults))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .confirmationDialog(
                    LocalizationManager.shared.tr(.resetConfirmTitle),
                    isPresented: $showingResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(LocalizationManager.shared.tr(.resetDefaultsButton), role: .destructive) {
                        resetToDefaults()
                    }
                    Button(LocalizationManager.shared.tr(.cancelButton), role: .cancel) {}
                } message: {
                    Text(LocalizationManager.shared.tr(.resetConfirmMessage))
                }
            }
            .padding(.bottom, 4)
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

    private var updateStatusLabel: some View {
        Group {
            switch updateManager.status {
            case .idle:
                EmptyView()
            case .checking:
                Text(LocalizationManager.shared.tr(.checkingForUpdates))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            case .upToDate(let ver):
                Text(LocalizationManager.shared.tr(.upToDate(ver)))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            case .updateAvailable(let release):
                HStack(spacing: 6) {
                    Text(LocalizationManager.shared.tr(.versionAvailable(release.versionString)))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.accentColor)
                    Button(LocalizationManager.shared.tr(.updateNow)) {
                        updateManager.startDownloadAndInstall(release: release)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                }
            case .downloading:
                Text(LocalizationManager.shared.tr(.downloadingUpdate))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            case .readyToRestart:
                HStack(spacing: 6) {
                    Text(LocalizationManager.shared.tr(.updateReadyRestart))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.accentColor)
                    Button(LocalizationManager.shared.tr(.restart)) {
                        updateManager.restartApp()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                }
            case .error(let msg):
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        HStack {
            Spacer()
            Button(LocalizationManager.shared.tr(.doneButton)) {
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
        hotKeyWarningMessage = nil
        let def = AppSettings()
        storageManager.capacity = AppSettings.defaultCapacity
        storageManager.settings = def
        launchAtLoginManager.setEnabled(false)
        selectedIgnoredAppId = nil
        LocalizationManager.shared.setLanguage(code: def.language)
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
