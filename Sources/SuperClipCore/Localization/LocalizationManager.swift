import Foundation
import Combine

/// Supported application languages.
public enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case system = "system"
    case vietnamese = "vi"
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case japanese = "ja"
    case korean = "ko"
    case spanish = "es"
    case french = "fr"
    case german = "de"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "System Default"
        case .vietnamese: return "Tiếng Việt"
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        }
    }
}

/// Centralized localization manager providing dynamic runtime translation across 8+ languages.
public final class LocalizationManager: ObservableObject, @unchecked Sendable {
    public static let shared = LocalizationManager()

    private let lock = NSLock()

    @Published public private(set) var currentLanguage: AppLanguage = .system {
        didSet {
            effectiveLanguage = resolveEffectiveLanguage(currentLanguage)
        }
    }

    @Published public private(set) var effectiveLanguage: AppLanguage = .english

    public init() {
        self.effectiveLanguage = resolveEffectiveLanguage(.system)
    }

    public func setLanguage(_ language: AppLanguage) {
        lock.lock()
        defer { lock.unlock() }
        self.currentLanguage = language
        self.effectiveLanguage = resolveEffectiveLanguage(language)
    }

    public func setLanguage(code: String) {
        let lang = AppLanguage(rawValue: code) ?? .system
        setLanguage(lang)
    }

    private func resolveEffectiveLanguage(_ lang: AppLanguage) -> AppLanguage {
        if lang != .system {
            return lang
        }
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
        if preferred.hasPrefix("vi") { return .vietnamese }
        if preferred.hasPrefix("zh") { return .simplifiedChinese }
        if preferred.hasPrefix("ja") { return .japanese }
        if preferred.hasPrefix("ko") { return .korean }
        if preferred.hasPrefix("es") { return .spanish }
        if preferred.hasPrefix("fr") { return .french }
        if preferred.hasPrefix("de") { return .german }
        return .english
    }

    // MARK: - Localized String Resolution

    public func tr(_ key: L10nKey) -> String {
        lock.lock()
        let lang = effectiveLanguage
        lock.unlock()
        return key.localized(for: lang)
    }
}

/// Strongly-typed localization keys covering all user-facing strings.
public enum L10nKey: Sendable {
    // Header & Navigation
    case appTitle
    case searchPlaceholder
    case ofCount(Int, Int)
    case preferencesTooltip
    case dismissTooltip

    // List Sections & Status
    case pinnedSection
    case recentSection
    case clearHistory
    case noMatchingClips
    case tryRefiningSearch
    case clipboardEmpty
    case copiedWillAppear
    case whitespaceClip
    case imageTag(Int, Int)
    case imageTagBare

    // Row Actions & Context Menu
    case pinClip
    case unpinClip
    case maskClip
    case revealClip
    case copyClip
    case deleteClip

    // Settings Tabs
    case tabGeneral
    case tabIgnoredApps
    case tabClipsManagement
    case tabAbout

    // General Preferences
    case clippingsTitle
    case rememberLabel
    case displayLabel
    case clippingsUnit
    case pinGuaranteeTitle
    case pinGuaranteeNote
    case optionsTitle
    case startAtLogin
    case recordClipboardHistory
    case languageLabel
    case shortcutLabel
    case shortcutHelperText
    case recordButton
    case cancelButton
    case pressShortcutHint
    case quickPresetsTitle

    // Ignored Apps Preferences
    case ignoredAppsDesc
    case noIgnoredApps
    case addAppButton
    case removeButton

    // Clips Management Preferences
    case managementDesc
    case totalStoredClips
    case pinnedClips
    case unpinnedHistory
    case diskSpaceUsed
    case storageLocation
    case clearAllUnpinnedHistory
    case openInFinder
    case clearConfirmTitle
    case clearConfirmMessage

    // About Preferences & Dialogs
    case versionLabel(String)
    case authorLabel
    case licenseLabel
    case resetAllDefaults
    case resetConfirmTitle
    case resetConfirmMessage
    case resetDefaultsButton
    case doneButton

    // Auto-Update & Notifications
    case automaticallyCheckForUpdates
    case checkForUpdates
    case updateAvailableBanner(String)
    case updateNow
    case later
    case releaseNotes
    case updateReadyRestart
    case restart
    case upToDate(String)
    case checkingForUpdates
    case downloadingUpdate
    case versionAvailable(String)

    public func localized(for lang: AppLanguage) -> String {
        switch self {
        case .appTitle:
            return "SuperClip"

        case .searchPlaceholder:
            switch lang {
            case .vietnamese: return "Tìm kiếm clip..."
            case .simplifiedChinese: return "搜索剪贴板..."
            case .japanese: return "クリップを検索..."
            case .korean: return "클립보드 검색..."
            case .spanish: return "Buscar clips..."
            case .french: return "Rechercher des clips..."
            case .german: return "Clips suchen..."
            default: return "Search clips..."
            }

        case .ofCount(let visible, let total):
            switch lang {
            case .vietnamese: return "\(visible) / \(total)"
            case .simplifiedChinese: return "\(visible) / \(total)"
            case .japanese: return "\(visible) / \(total)"
            case .korean: return "\(visible) / \(total)"
            case .spanish: return "\(visible) de \(total)"
            case .french: return "\(visible) sur \(total)"
            case .german: return "\(visible) von \(total)"
            default: return "\(visible) of \(total)"
            }

        case .preferencesTooltip:
            switch lang {
            case .vietnamese: return "Cài đặt (Cmd+,)"
            case .simplifiedChinese: return "偏好设置 (Cmd+,)"
            case .japanese: return "環境設定 (Cmd+,)"
            case .korean: return "환경설정 (Cmd+,)"
            case .spanish: return "Preferencias (Cmd+,)"
            case .french: return "Préférences (Cmd+,)"
            case .german: return "Einstellungen (Cmd+,)"
            default: return "Preferences (Cmd+,)"
            }

        case .dismissTooltip:
            switch lang {
            case .vietnamese: return "Đóng (Escape)"
            case .simplifiedChinese: return "关闭 (Escape)"
            case .japanese: return "閉じる (Escape)"
            case .korean: return "닫기 (Escape)"
            case .spanish: return "Cerrar (Escape)"
            case .french: return "Fermer (Escape)"
            case .german: return "Schließen (Escape)"
            default: return "Dismiss (Escape)"
            }

        case .pinnedSection:
            switch lang {
            case .vietnamese: return "ĐÃ GHIM"
            case .simplifiedChinese: return "已置顶"
            case .japanese: return "ピン留め"
            case .korean: return "고정됨"
            case .spanish: return "FIJADOS"
            case .french: return "ÉPINGLÉS"
            case .german: return "ANGEHEFTET"
            default: return "PINNED"
            }

        case .recentSection:
            switch lang {
            case .vietnamese: return "LỊCH SỬ GẦN ĐÂY"
            case .simplifiedChinese: return "最近历史"
            case .japanese: return "最近の履歴"
            case .korean: return "최근 기록"
            case .spanish: return "HISTORIAL RECIENTE"
            case .french: return "HISTORIQUE RÉCENT"
            case .german: return "VERLAUF"
            default: return "RECENT HISTORY"
            }

        case .clearHistory:
            switch lang {
            case .vietnamese: return "Xóa lịch sử"
            case .simplifiedChinese: return "清除历史"
            case .japanese: return "履歴を消去"
            case .korean: return "기록 지우기"
            case .spanish: return "Borrar historial"
            case .french: return "Effacer l'historique"
            case .german: return "Verlauf löschen"
            default: return "Clear History"
            }

        case .noMatchingClips:
            switch lang {
            case .vietnamese: return "Không tìm thấy kết quả phù hợp"
            case .simplifiedChinese: return "未找到匹配项"
            case .japanese: return "一致するクリップがありません"
            case .korean: return "일치하는 클립이 없습니다"
            case .spanish: return "No se encontraron clips coincidentes"
            case .french: return "Aucun clip correspondant trouvé"
            case .german: return "Keine passenden Clips gefunden"
            default: return "No matching clips found"
            }

        case .tryRefiningSearch:
            switch lang {
            case .vietnamese: return "Thử tìm kiếm với từ khóa khác"
            case .simplifiedChinese: return "尝试优化搜索关键字"
            case .japanese: return "検索キーワードを変更してください"
            case .korean: return "검색어를 구체화해 보세요"
            case .spanish: return "Intenta refinar tu búsqueda"
            case .french: return "Essayez d'affiner votre recherche"
            case .german: return "Versuchen Sie, die Suchanfrage zu verfeinern"
            default: return "Try refining your search query"
            }

        case .clipboardEmpty:
            switch lang {
            case .vietnamese: return "Lịch sử clipboard trống"
            case .simplifiedChinese: return "剪贴板历史为空"
            case .japanese: return "クリップボードの履歴は空です"
            case .korean: return "클립보드 기록이 비어 있습니다"
            case .spanish: return "El historial del portapapeles está vacío"
            case .french: return "L'historique du presse-papiers est vide"
            case .german: return "Zwischenablage-Verlauf ist leer"
            default: return "Clipboard history is empty"
            }

        case .copiedWillAppear:
            switch lang {
            case .vietnamese: return "Văn bản và hình ảnh sao chép sẽ xuất hiện ở đây"
            case .simplifiedChinese: return "复制的文本和图片将显示在此处"
            case .japanese: return "コピーしたテキストや画像がここに表示されます"
            case .korean: return "복사한 텍스트와 이미지가 여기에 표시됩니다"
            case .spanish: return "El texto y las imágenes copiadas aparecerán aquí"
            case .french: return "Le texte et les images copiés apparaîtront ici"
            case .german: return "Kopierter Text und Bilder werden hier angezeigt"
            default: return "Copied text and images will appear here"
            }

        case .whitespaceClip:
            switch lang {
            case .vietnamese: return "(Khoảng trắng)"
            case .simplifiedChinese: return "(空格字符)"
            case .japanese: return "(空白文字)"
            case .korean: return "(공백 문자)"
            case .spanish: return "(Espacio en blanco)"
            case .french: return "(Espace blanc)"
            case .german: return "(Leerzeichen)"
            default: return "(Whitespace)"
            }

        case .imageTag(let w, let h):
            switch lang {
            case .vietnamese: return "[Ảnh] \(w)x\(h)"
            case .simplifiedChinese: return "[图片] \(w)x\(h)"
            case .japanese: return "[画像] \(w)x\(h)"
            case .korean: return "[이미지] \(w)x\(h)"
            case .spanish: return "[Imagen] \(w)x\(h)"
            case .french: return "[Image] \(w)x\(h)"
            case .german: return "[Bild] \(w)x\(h)"
            default: return "[Image] \(w)x\(h)"
            }

        case .imageTagBare:
            switch lang {
            case .vietnamese: return "[Ảnh]"
            case .simplifiedChinese: return "[图片]"
            case .japanese: return "[画像]"
            case .korean: return "[이미지]"
            case .spanish: return "[Imagen]"
            case .french: return "[Image]"
            case .german: return "[Bild]"
            default: return "[Image]"
            }

        case .pinClip:
            switch lang {
            case .vietnamese: return "Ghim clip"
            case .simplifiedChinese: return "置顶"
            case .japanese: return "ピン留め"
            case .korean: return "클립 고정"
            case .spanish: return "Fijar clip"
            case .french: return "Épingler le clip"
            case .german: return "Clip anheften"
            default: return "Pin clip"
            }

        case .unpinClip:
            switch lang {
            case .vietnamese: return "Bỏ ghim clip"
            case .simplifiedChinese: return "取消置顶"
            case .japanese: return "ピン留め解除"
            case .korean: return "클립 고정 해제"
            case .spanish: return "Desfijar clip"
            case .french: return "Désépingler le clip"
            case .german: return "Clip lösen"
            default: return "Unpin clip"
            }

        case .maskClip:
            switch lang {
            case .vietnamese: return "Ẩn thông tin nhạy cảm"
            case .simplifiedChinese: return "隐藏敏感信息"
            case .japanese: return "機密情報を非表示"
            case .korean: return "민감한 정보 숨기기"
            case .spanish: return "Ocultar información confidencial"
            case .french: return "Masquer les informations sensibles"
            case .german: return "Vertrauliche Informationen ausblenden"
            default: return "Mask Sensitive Information"
            }

        case .revealClip:
            switch lang {
            case .vietnamese: return "Hiện thông tin nhạy cảm"
            case .simplifiedChinese: return "显示敏感信息"
            case .japanese: return "機密情報を表示"
            case .korean: return "민감한 정보 표시"
            case .spanish: return "Mostrar información confidencial"
            case .french: return "Afficher les informations sensibles"
            case .german: return "Vertrauliche Informationen anzeigen"
            default: return "Reveal Sensitive Information"
            }

        case .copyClip:
            switch lang {
            case .vietnamese: return "Sao chép clip"
            case .simplifiedChinese: return "复制"
            case .japanese: return "コピー"
            case .korean: return "클립 복사"
            case .spanish: return "Copiar clip"
            case .french: return "Copier le clip"
            case .german: return "Clip kopieren"
            default: return "Copy clip"
            }

        case .deleteClip:
            switch lang {
            case .vietnamese: return "Xóa clip"
            case .simplifiedChinese: return "删除"
            case .japanese: return "削除"
            case .korean: return "클립 삭제"
            case .spanish: return "Eliminar clip"
            case .french: return "Supprimer le clip"
            case .german: return "Clip löschen"
            default: return "Delete clip"
            }

        case .tabGeneral:
            switch lang {
            case .vietnamese: return "Cài đặt chung"
            case .simplifiedChinese: return "通用"
            case .japanese: return "一般"
            case .korean: return "일반"
            case .spanish: return "General"
            case .french: return "Général"
            case .german: return "Allgemein"
            default: return "General"
            }

        case .tabIgnoredApps:
            switch lang {
            case .vietnamese: return "Ứng dụng bỏ qua"
            case .simplifiedChinese: return "忽略应用"
            case .japanese: return "除外アプリ"
            case .korean: return "제외 앱"
            case .spanish: return "Apps ignoradas"
            case .french: return "Apps ignorées"
            case .german: return "Ausnahmen"
            default: return "Ignored Apps"
            }

        case .tabClipsManagement:
            switch lang {
            case .vietnamese: return "Quản lý dữ liệu"
            case .simplifiedChinese: return "剪贴管理"
            case .japanese: return "クリップ管理"
            case .korean: return "클립 관리"
            case .spanish: return "Gestión"
            case .french: return "Gestion"
            case .german: return "Verwaltung"
            default: return "Clips Management"
            }

        case .tabAbout:
            switch lang {
            case .vietnamese: return "Giới thiệu"
            case .simplifiedChinese: return "关于"
            case .japanese: return "情報"
            case .korean: return "정보"
            case .spanish: return "Acerca de"
            case .french: return "À propos"
            case .german: return "Über"
            default: return "About"
            }

        case .clippingsTitle:
            switch lang {
            case .vietnamese: return "Dữ liệu lưu trữ"
            case .simplifiedChinese: return "剪贴记录"
            case .japanese: return "クリップ保持"
            case .korean: return "클립보드 보관"
            case .spanish: return "Recortes"
            case .french: return "Éléments"
            case .german: return "Ablagen"
            default: return "Clippings"
            }

        case .rememberLabel:
            switch lang {
            case .vietnamese: return "Lưu giữ:"
            case .simplifiedChinese: return "保存数量:"
            case .japanese: return "記憶数:"
            case .korean: return "보관 수:"
            case .spanish: return "Recordar:"
            case .french: return "Mémoriser :"
            case .german: return "Merken:"
            default: return "Remember:"
            }

        case .displayLabel:
            switch lang {
            case .vietnamese: return "Hiển thị:"
            case .simplifiedChinese: return "显示数量:"
            case .japanese: return "表示数:"
            case .korean: return "표시 수:"
            case .spanish: return "Mostrar:"
            case .french: return "Afficher :"
            case .german: return "Anzeigen:"
            default: return "Display:"
            }

        case .clippingsUnit:
            switch lang {
            case .vietnamese: return "mục"
            case .simplifiedChinese: return "条"
            case .japanese: return "件"
            case .korean: return "개"
            case .spanish: return "elementos"
            case .french: return "éléments"
            case .german: return "Elemente"
            default: return "clippings"
            }

        case .pinGuaranteeTitle:
            switch lang {
            case .vietnamese: return "Bảo vệ mục đã ghim"
            case .simplifiedChinese: return "置顶项保护"
            case .japanese: return "ピン留め保護"
            case .korean: return "고정 항목 영구 보관"
            case .spanish: return "Protección de fijados"
            case .french: return "Protection des épinglés"
            case .german: return "Schutz für Angeheftetes"
            default: return "Pin Protection Guarantee"
            }

        case .pinGuaranteeNote:
            switch lang {
            case .vietnamese: return "Các mục đã ghim được bảo vệ vĩnh viễn và không bị xóa bởi giới hạn này."
            case .simplifiedChinese: return "已置顶项受到永久保护，不会计入此数量限制。"
            case .japanese: return "ピン留めされたクリップは永久に保護され、上限数にはカウントされません。"
            case .korean: return "고정된 클립은 영구적으로 보호되며 이 제한에 포함되지 않습니다."
            case .spanish: return "Los clips fijados están protegidos permanentemente y no cuentan para este límite."
            case .french: return "Les clips épinglés sont protégés de façon permanente et ne comptent pas dans cette limite."
            case .german: return "Angeheftete Clips sind dauerhaft geschützt und zählen nicht zu diesem Limit."
            default: return "Pinned clips are permanently protected and do not count toward this limit."
            }

        case .optionsTitle:
            switch lang {
            case .vietnamese: return "Tùy chọn"
            case .simplifiedChinese: return "选项"
            case .japanese: return "オプション"
            case .korean: return "옵션"
            case .spanish: return "Opciones"
            case .french: return "Options"
            case .german: return "Optionen"
            default: return "Options"
            }

        case .startAtLogin:
            switch lang {
            case .vietnamese: return "Khởi động SuperClip cùng hệ thống"
            case .simplifiedChinese: return "开机自动启动 SuperClip"
            case .japanese: return "システム起動時に SuperClip を起動"
            case .korean: return "시스템 시작 시 SuperClip 시작"
            case .spanish: return "Iniciar SuperClip al arrancar el sistema"
            case .french: return "Lancer SuperClip au démarrage"
            case .german: return "SuperClip beim Systemstart starten"
            default: return "Start SuperClip at system startup"
            }

        case .recordClipboardHistory:
            switch lang {
            case .vietnamese: return "Tự động ghi lại lịch sử clipboard"
            case .simplifiedChinese: return "记录剪贴板历史"
            case .japanese: return "クリップボードの履歴を記録"
            case .korean: return "클립보드 기록 저장"
            case .spanish: return "Registrar historial del portapapeles"
            case .french: return "Enregistrer l'historique du presse-papiers"
            case .german: return "Zwischenablage aufzeichnen"
            default: return "Record clipboard history"
            }

        case .languageLabel:
            switch lang {
            case .vietnamese: return "Ngôn ngữ:"
            case .simplifiedChinese: return "语言:"
            case .japanese: return "言語:"
            case .korean: return "언어:"
            case .spanish: return "Idioma:"
            case .french: return "Langue :"
            case .german: return "Sprache:"
            default: return "Language:"
            }

        case .shortcutLabel:
            switch lang {
            case .vietnamese: return "Mở bảng clipboard:"
            case .simplifiedChinese: return "呼出剪贴板:"
            case .japanese: return "クリップボード表示:"
            case .korean: return "클립보드 열기:"
            case .spanish: return "Abrir portapapeles:"
            case .french: return "Ouvrir le presse-papiers :"
            case .german: return "Zwischenablage öffnen:"
            default: return "Open clipboard:"
            }

        case .shortcutHelperText:
            switch lang {
            case .vietnamese: return "Bấm phím tắt này ở bất kỳ đâu để mở nhanh bảng clipboard ngay tại con trỏ chuột."
            case .simplifiedChinese: return "在任意应用中按下此快捷键即可在鼠标光标处呼出剪贴板历史。"
            case .japanese: return "任意の場所でこのキーを押すと、マウスカーソル位置に履歴を表示します。"
            case .korean: return "어디서나 이 단축키를 눌러 마우스 커서 위치에 클립보드 기록을 엽니다."
            case .spanish: return "Pulsa este atajo en cualquier lugar para abrir el portapapeles en el cursor."
            case .french: return "Appuyez sur ce raccourci n'importe où pour ouvrir le presse-papiers sous le curseur."
            case .german: return "Diesen Kurzbefehl überall drücken, um den Verlauf direkt am Mauszeiger zu öffnen."
            default: return "Press this shortcut anywhere to open clipboard history at your mouse cursor."
            }

        case .recordButton:
            switch lang {
            case .vietnamese: return "Ghi phím"
            case .simplifiedChinese: return "录制"
            case .japanese: return "記録"
            case .korean: return "녹음"
            case .spanish: return "Grabar"
            case .french: return "Enregistrer"
            case .german: return "Aufnehmen"
            default: return "Record"
            }

        case .cancelButton:
            switch lang {
            case .vietnamese: return "Hủy"
            case .simplifiedChinese: return "取消"
            case .japanese: return "キャンセル"
            case .korean: return "취소"
            case .spanish: return "Cancelar"
            case .french: return "Annuler"
            case .german: return "Abbrechen"
            default: return "Cancel"
            }

        case .pressShortcutHint:
            switch lang {
            case .vietnamese: return "Nhấn tổ hợp phím mong muốn..."
            case .simplifiedChinese: return "按下所需快捷键组合..."
            case .japanese: return "希望のショートカットキーを押してください..."
            case .korean: return "원하는 단축키 조합을 누르세요..."
            case .spanish: return "Presiona la combinación deseada..."
            case .french: return "Appuyez sur le raccourci souhaité..."
            case .german: return "Tastenkombination drücken..."
            default: return "Press desired key combination..."
            }

        case .quickPresetsTitle:
            switch lang {
            case .vietnamese: return "Phím tắt gợi ý"
            case .simplifiedChinese: return "快捷预设"
            case .japanese: return "クイックプリセット"
            case .korean: return "빠른 프리셋"
            case .spanish: return "Preajustes rápidos"
            case .french: return "Préréglages rapides"
            case .german: return "Schnellvoreinstellungen"
            default: return "Quick Presets"
            }

        case .ignoredAppsDesc:
            switch lang {
            case .vietnamese: return "Các ứng dụng bị loại trừ khỏi lịch sử lưu clipboard."
            case .simplifiedChinese: return "已从剪贴板历史记录中排除的应用程序。"
            case .japanese: return "クリップボードの記録から除外されたアプリです。"
            case .korean: return "클립보드 기록에서 제외된 애플리케이션입니다."
            case .spanish: return "Aplicaciones excluidas del registro del portapapeles."
            case .french: return "Applications exclues de l'historique du presse-papiers."
            case .german: return "Von der Zwischenablage-Aufzeichnung ausgeschlossene Apps."
            default: return "Applications excluded from clipboard history recording."
            }

        case .noIgnoredApps:
            switch lang {
            case .vietnamese: return "Chưa có ứng dụng nào bị loại trừ."
            case .simplifiedChinese: return "当前没有被忽略的应用。"
            case .japanese: return "現在除外されているアプリはありません。"
            case .korean: return "현재 제외된 앱이 없습니다."
            case .spanish: return "No hay aplicaciones ignoradas actualmente."
            case .french: return "Aucune application n'est actuellement ignorée."
            case .german: return "Derzeit sind keine Apps ignoriert."
            default: return "No applications are currently ignored."
            }

        case .addAppButton:
            switch lang {
            case .vietnamese: return "Thêm ứng dụng..."
            case .simplifiedChinese: return "添加应用..."
            case .japanese: return "アプリを追加..."
            case .korean: return "앱 추가..."
            case .spanish: return "Añadir app..."
            case .french: return "Ajouter une app..."
            case .german: return "App hinzufügen..."
            default: return "Add App..."
            }

        case .removeButton:
            switch lang {
            case .vietnamese: return "Xóa"
            case .simplifiedChinese: return "移除"
            case .japanese: return "削除"
            case .korean: return "제거"
            case .spanish: return "Eliminar"
            case .french: return "Supprimer"
            case .german: return "Entfernen"
            default: return "Remove"
            }

        case .managementDesc:
            switch lang {
            case .vietnamese: return "Thống kê lưu trữ dữ liệu và các tác vụ bảo trì."
            case .simplifiedChinese: return "本地剪贴板存储统计概览与维护操作。"
            case .japanese: return "ローカルストレージの統計概要とメンテナンス。"
            case .korean: return "로컬 클립보드 저장소 통계 개요 및 유지 관리 작업입니다."
            case .spanish: return "Estadísticas de almacenamiento local y mantenimiento."
            case .french: return "Aperçu du stockage local et maintenance."
            case .german: return "Speicherübersicht und Wartung."
            default: return "Overview of local clipboard storage statistics and maintenance actions."
            }

        case .totalStoredClips:
            switch lang {
            case .vietnamese: return "Tổng số mục đã lưu"
            case .simplifiedChinese: return "已保存剪贴总数"
            case .japanese: return "保存されたクリップ合計"
            case .korean: return "저장된 총 클립"
            case .spanish: return "Total de clips guardados"
            case .french: return "Total des clips enregistrés"
            case .german: return "Gespeicherte Clips insgesamt"
            default: return "Total Stored Clips"
            }

        case .pinnedClips:
            switch lang {
            case .vietnamese: return "Mục đã ghim"
            case .simplifiedChinese: return "已置顶项"
            case .japanese: return "ピン留めクリップ"
            case .korean: return "고정된 클립"
            case .spanish: return "Clips fijados"
            case .french: return "Clips épinglés"
            case .german: return "Angeheftete Clips"
            default: return "Pinned Clips"
            }

        case .unpinnedHistory:
            switch lang {
            case .vietnamese: return "Lịch sử chưa ghim"
            case .simplifiedChinese: return "未置顶历史"
            case .japanese: return "通常の履歴"
            case .korean: return "고정되지 않은 기록"
            case .spanish: return "Historial no fijado"
            case .french: return "Historique non épinglé"
            case .german: return "Nicht angehefteter Verlauf"
            default: return "Unpinned History"
            }

        case .diskSpaceUsed:
            switch lang {
            case .vietnamese: return "Dung lượng ổ đĩa đã dùng"
            case .simplifiedChinese: return "已用磁盘空间"
            case .japanese: return "使用ディスク容量"
            case .korean: return "사용된 디스크 공간"
            case .spanish: return "Espacio en disco usado"
            case .french: return "Espace disque utilisé"
            case .german: return "Belegter Speicherplatz"
            default: return "Disk Space Used"
            }

        case .storageLocation:
            switch lang {
            case .vietnamese: return "Vị trí lưu trữ"
            case .simplifiedChinese: return "存储位置"
            case .japanese: return "保存場所"
            case .korean: return "저장 위치"
            case .spanish: return "Ubicación de almacenamiento"
            case .french: return "Emplacement du stockage"
            case .german: return "Speicherort"
            default: return "Storage Location"
            }

        case .clearAllUnpinnedHistory:
            switch lang {
            case .vietnamese: return "Xóa tất cả mục chưa ghim"
            case .simplifiedChinese: return "清除所有未置顶项"
            case .japanese: return "ピン留めされていない履歴をすべて消去"
            case .korean: return "고정되지 않은 모든 기록 지우기"
            case .spanish: return "Borrar todo el historial no fijado"
            case .french: return "Effacer tous les éléments non épinglés"
            case .german: return "Alle nicht angehefteten Elemente löschen"
            default: return "Clear All Unpinned History"
            }

        case .openInFinder:
            switch lang {
            case .vietnamese: return "Mở trong Finder"
            case .simplifiedChinese: return "在访达中显示"
            case .japanese: return "Finderで表示"
            case .korean: return "Finder에서 보기"
            case .spanish: return "Abrir en Finder"
            case .french: return "Ouvrir dans le Finder"
            case .german: return "Im Finder anzeigen"
            default: return "Open in Finder"
            }

        case .clearConfirmTitle:
            switch lang {
            case .vietnamese: return "Xóa tất cả mục chưa ghim?"
            case .simplifiedChinese: return "清除所有未置顶项？"
            case .japanese: return "ピン留めされていないクリップをすべて消去しますか？"
            case .korean: return "고정되지 않은 모든 클립을 지우시겠습니까?"
            case .spanish: return "¿Borrar todos los clips no fijados?"
            case .french: return "Effacer tous les clips non épinglés ?"
            case .german: return "Alle nicht angehefteten Clips löschen?"
            default: return "Clear all unpinned clips?"
            }

        case .clearConfirmMessage:
            switch lang {
            case .vietnamese: return "Thao tác này sẽ xóa vĩnh viễn các mục chưa ghim. Các mục đã ghim sẽ được giữ nguyên."
            case .simplifiedChinese: return "此操作将永久删除未置顶项。所有已置顶项将被保留。"
            case .japanese: return "これによりピン留めされていない項目は完全に削除されます。ピン留めされた項目は保護されます。"
            case .korean: return "고정되지 않은 항목이 영구적으로 삭제됩니다. 고정된 모든 클립은 보존됩니다."
            case .spanish: return "Esto elimina permanentemente los elementos no fijados. Todos los clips fijados se conservarán."
            case .french: return "Cela supprime définitivement les éléments non épinglés. Tous les clips épinglés seront conservés."
            case .german: return "Dies löscht nicht angeheftete Elemente dauerhaft. Alle angehefteten Clips bleiben erhalten."
            default: return "This permanently deletes unpinned items. All pinned clips will be preserved."
            }

        case .versionLabel(let ver):
            return "Version \(ver)"

        case .authorLabel:
            switch lang {
            case .vietnamese: return "Tác giả"
            case .simplifiedChinese: return "作者"
            case .japanese: return "開発者"
            case .korean: return "개발자"
            case .spanish: return "Autor"
            case .french: return "Auteur"
            case .german: return "Autor"
            default: return "Author"
            }

        case .licenseLabel:
            switch lang {
            case .vietnamese: return "Giấy phép"
            case .simplifiedChinese: return "许可证"
            case .japanese: return "ライセンス"
            case .korean: return "라이선스"
            case .spanish: return "Licencia"
            case .french: return "Licence"
            case .german: return "Lizenz"
            default: return "License"
            }

        case .resetAllDefaults:
            switch lang {
            case .vietnamese: return "Khôi phục cài đặt gốc"
            case .simplifiedChinese: return "恢复默认设置"
            case .japanese: return "デフォルトに戻す"
            case .korean: return "기본값으로 재설정"
            case .spanish: return "Restablecer valores predeterminados"
            case .french: return "Rétablir les paramètres par défaut"
            case .german: return "Auf Standard zurücksetzen"
            default: return "Reset All to Defaults"
            }

        case .resetConfirmTitle:
            switch lang {
            case .vietnamese: return "Khôi phục toàn bộ cài đặt gốc?"
            case .simplifiedChinese: return "恢复所有设置到默认值？"
            case .japanese: return "すべての設定をデフォルトに戻しますか？"
            case .korean: return "모든 설정을 기본값으로 재설정하시겠습니까?"
            case .spanish: return "¿Restablecer todos los ajustes a los valores predeterminados?"
            case .french: return "Rétablir tous les paramètres par défaut ?"
            case .german: return "Alle Einstellungen auf Standard zurücksetzen?"
            default: return "Reset settings to defaults?"
            }

        case .resetConfirmMessage:
            switch lang {
            case .vietnamese: return "Thao tác này sẽ đặt lại phím tắt về Option+V, số lượng lưu giữ về 100 và ngôn ngữ về Mặc định."
            case .simplifiedChinese: return "这会将快捷键重置为 Option+V，容量重置为 100，并将语言重置为系统默认。"
            case .japanese: return "ショートカットを Option+V、保存上限を 100、言語をシステムデフォルトに戻します。"
            case .korean: return "단축키를 Option+V로, 저장 용량을 100으로, 언어를 시스템 기본값으로 재설정합니다."
            case .spanish: return "Esto restablece el atajo a Option+V, la capacidad a 100 y el idioma al predeterminado."
            case .french: return "Cela réinitialise le raccourci sur Option+V, la capacité à 100 et la langue par défaut."
            case .german: return "Dies setzt den Kurzbefehl auf Option+V, die Kapazität auf 100 und die Sprache auf Standard zurück."
            default: return "This resets hotkey to Option+V, capacity to 100 items, and language to System Default."
            }

        case .resetDefaultsButton:
            switch lang {
            case .vietnamese: return "Khôi phục mặc định"
            case .simplifiedChinese: return "恢复默认"
            case .japanese: return "デフォルトに戻す"
            case .korean: return "기본값 재설정"
            case .spanish: return "Restablecer"
            case .french: return "Réinitialiser"
            case .german: return "Zurücksetzen"
            default: return "Reset Defaults"
            }

        case .doneButton:
            switch lang {
            case .vietnamese: return "Xong"
            case .simplifiedChinese: return "完成"
            case .japanese: return "完了"
            case .korean: return "완료"
            case .spanish: return "Listo"
            case .french: return "Terminé"
            case .german: return "Fertig"
            default: return "Done"
            }

        case .automaticallyCheckForUpdates:
            switch lang {
            case .vietnamese: return "Tự động kiểm tra bản cập nhật"
            case .simplifiedChinese: return "自动检查更新"
            case .japanese: return "アップデートを自動的に確認"
            case .korean: return "자동으로 업데이트 확인"
            case .spanish: return "Buscar actualizaciones automáticamente"
            case .french: return "Rechercher automatiquement les mises à jour"
            case .german: return "Automatisch nach Updates suchen"
            default: return "Automatically check for updates"
            }

        case .checkForUpdates:
            switch lang {
            case .vietnamese: return "Kiểm tra bản cập nhật..."
            case .simplifiedChinese: return "检查更新..."
            case .japanese: return "アップデートを確認..."
            case .korean: return "업데이트 확인..."
            case .spanish: return "Buscar actualizaciones..."
            case .french: return "Vérifier les mises à jour..."
            case .german: return "Nach Updates suchen..."
            default: return "Check for Updates..."
            }

        case .updateAvailableBanner(let ver):
            switch lang {
            case .vietnamese: return "Đã có SuperClip \(ver)"
            case .simplifiedChinese: return "SuperClip \(ver) 现已可用"
            case .japanese: return "SuperClip \(ver) が利用可能です"
            case .korean: return "SuperClip \(ver) 사용 가능"
            case .spanish: return "SuperClip \(ver) está disponible"
            case .french: return "SuperClip \(ver) est disponible"
            case .german: return "SuperClip \(ver) ist verfügbar"
            default: return "SuperClip \(ver) is available"
            }

        case .updateNow:
            switch lang {
            case .vietnamese: return "Cập nhật ngay"
            case .simplifiedChinese: return "立即更新"
            case .japanese: return "今すぐアップデート"
            case .korean: return "지금 업데이트"
            case .spanish: return "Actualizar ahora"
            case .french: return "Mettre à jour maintenant"
            case .german: return "Jetzt aktualisieren"
            default: return "Update Now"
            }

        case .later:
            switch lang {
            case .vietnamese: return "Để sau"
            case .simplifiedChinese: return "稍后"
            case .japanese: return "後で"
            case .korean: return "나중에"
            case .spanish: return "Más tarde"
            case .french: return "Plus tard"
            case .german: return "Später"
            default: return "Later"
            }

        case .releaseNotes:
            switch lang {
            case .vietnamese: return "Chi tiết phát hành"
            case .simplifiedChinese: return "发行说明"
            case .japanese: return "リリースノート"
            case .korean: return "릴리스 노트"
            case .spanish: return "Notas de versión"
            case .french: return "Notes de version"
            case .german: return "Versionshinweise"
            default: return "Release Notes"
            }

        case .updateReadyRestart:
            switch lang {
            case .vietnamese: return "Bản cập nhật đã sẵn sàng, khởi động lại ngay"
            case .simplifiedChinese: return "更新已就绪，立即重启"
            case .japanese: return "アップデートの準備完了、今すぐ再起動"
            case .korean: return "업데이트 준비 완료, 지금 재시작"
            case .spanish: return "Actualización lista, reiniciar ahora"
            case .french: return "Mise à jour prête, redémarrer maintenant"
            case .german: return "Update bereit, jetzt neu starten"
            default: return "Update ready, restart now"
            }

        case .restart:
            switch lang {
            case .vietnamese: return "Khởi động lại"
            case .simplifiedChinese: return "重启"
            case .japanese: return "再起動"
            case .korean: return "재시작"
            case .spanish: return "Reiniciar"
            case .french: return "Redémarrer"
            case .german: return "Neu starten"
            default: return "Restart"
            }

        case .upToDate(let ver):
            switch lang {
            case .vietnamese: return "Bạn đang dùng bản mới nhất (\(ver))"
            case .simplifiedChinese: return "已是最新版本 (\(ver))"
            case .japanese: return "最新バージョンです (\(ver))"
            case .korean: return "최신 버전입니다 (\(ver))"
            case .spanish: return "Está actualizado (\(ver))"
            case .french: return "À jour (\(ver))"
            case .german: return "Auf neuestem Stand (\(ver))"
            default: return "You're up to date (\(ver))"
            }

        case .checkingForUpdates:
            switch lang {
            case .vietnamese: return "Đang kiểm tra bản cập nhật..."
            case .simplifiedChinese: return "正在检查更新..."
            case .japanese: return "アップデートを確認中..."
            case .korean: return "업데이트 확인 중..."
            case .spanish: return "Buscando actualizaciones..."
            case .french: return "Vérification des mises à jour..."
            case .german: return "Suche nach Updates..."
            default: return "Checking for updates..."
            }

        case .downloadingUpdate:
            switch lang {
            case .vietnamese: return "Đang tải bản cập nhật..."
            case .simplifiedChinese: return "正在下载更新..."
            case .japanese: return "アップデートをダウンロード中..."
            case .korean: return "업데이트 다운로드 중..."
            case .spanish: return "Descargando actualización..."
            case .french: return "Téléchargement de la mise à jour..."
            case .german: return "Update wird heruntergeladen..."
            default: return "Downloading update..."
            }

        case .versionAvailable(let ver):
            switch lang {
            case .vietnamese: return "Có phiên bản \(ver)"
            case .simplifiedChinese: return "版本 \(ver) 可用"
            case .japanese: return "バージョン \(ver) が利用可能"
            case .korean: return "버전 \(ver) 사용 가능"
            case .spanish: return "Versión \(ver) disponible"
            case .french: return "Version \(ver) disponible"
            case .german: return "Version \(ver) verfügbar"
            default: return "Version \(ver) available"
            }
        }
    }
}

/// Global helper shortcut for localization lookup.
public func tr(_ key: L10nKey) -> String {
    LocalizationManager.shared.tr(key)
}
