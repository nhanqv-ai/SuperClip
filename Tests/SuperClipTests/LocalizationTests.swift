import Foundation
import SuperClipCore

/// Unit tests for AppLanguage, LocalizationManager, and multilingual search.
public struct LocalizationTests {
    public static func run(sandboxDir: URL) {
        TestHarness.startSuite("Localization & Multilingual Tests")

        // 1. AppLanguage cases and display names
        TestHarness.assertEqual(AppLanguage.allCases.count, 9, "9 supported languages in AppLanguage")
        TestHarness.assertEqual(AppLanguage.vietnamese.displayName, "Tiếng Việt", "Vietnamese display name matches")
        TestHarness.assertEqual(AppLanguage.simplifiedChinese.displayName, "简体中文", "Simplified Chinese display name matches")
        TestHarness.assertEqual(AppLanguage.japanese.displayName, "日本語", "Japanese display name matches")
        TestHarness.assertEqual(AppLanguage.korean.displayName, "한국어", "Korean display name matches")
        TestHarness.assertEqual(AppLanguage.spanish.displayName, "Español", "Spanish display name matches")
        TestHarness.assertEqual(AppLanguage.french.displayName, "Français", "French display name matches")
        TestHarness.assertEqual(AppLanguage.german.displayName, "Deutsch", "German display name matches")
        TestHarness.assertEqual(AppLanguage.english.displayName, "English", "English display name matches")
        TestHarness.assertEqual(AppLanguage.system.displayName, "System Default", "System display name matches")

        // 2. LocalizationManager runtime dynamic language switching
        let loc = LocalizationManager.shared

        loc.setLanguage(.vietnamese)
        TestHarness.assertEqual(loc.effectiveLanguage, .vietnamese, "Effective language is Vietnamese")
        TestHarness.assertEqual(loc.tr(.searchPlaceholder), "Tìm kiếm clip...", "Search placeholder translated to Vietnamese")
        TestHarness.assertEqual(loc.tr(.pinnedSection), "ĐÃ GHIM", "Pinned section translated to Vietnamese")
        TestHarness.assertEqual(loc.tr(.clearHistory), "Xóa lịch sử", "Clear history translated to Vietnamese")
        TestHarness.assertEqual(loc.tr(.languageLabel), "Ngôn ngữ:", "Language label translated to Vietnamese")
        TestHarness.assertEqual(loc.tr(.tabGeneral), "Cài đặt chung", "Tab General translated to Vietnamese")
        TestHarness.assertEqual(loc.tr(.authorLabel), "Tác giả", "Author label translated to Vietnamese")
        TestHarness.assertEqual(loc.tr(.licenseLabel), "Giấy phép", "License label translated to Vietnamese")

        loc.setLanguage(.simplifiedChinese)
        TestHarness.assertEqual(loc.effectiveLanguage, .simplifiedChinese, "Effective language is Simplified Chinese")
        TestHarness.assertEqual(loc.tr(.searchPlaceholder), "搜索剪贴板...", "Search placeholder translated to Chinese")
        TestHarness.assertEqual(loc.tr(.pinnedSection), "已置顶", "Pinned section translated to Chinese")
        TestHarness.assertEqual(loc.tr(.languageLabel), "语言:", "Language label translated to Chinese")
        TestHarness.assertEqual(loc.tr(.authorLabel), "作者", "Author label translated to Chinese")
        TestHarness.assertEqual(loc.tr(.licenseLabel), "许可证", "License label translated to Chinese")

        loc.setLanguage(.japanese)
        TestHarness.assertEqual(loc.effectiveLanguage, .japanese, "Effective language is Japanese")
        TestHarness.assertEqual(loc.tr(.searchPlaceholder), "クリップを検索...", "Search placeholder translated to Japanese")
        TestHarness.assertEqual(loc.tr(.pinnedSection), "ピン留め", "Pinned section translated to Japanese")
        TestHarness.assertEqual(loc.tr(.languageLabel), "言語:", "Language label translated to Japanese")
        TestHarness.assertEqual(loc.tr(.authorLabel), "開発者", "Author label translated to Japanese")
        TestHarness.assertEqual(loc.tr(.licenseLabel), "ライセンス", "License label translated to Japanese")

        loc.setLanguage(.english)
        TestHarness.assertEqual(loc.effectiveLanguage, .english, "Effective language is English")
        TestHarness.assertEqual(loc.tr(.searchPlaceholder), "Search clips...", "Search placeholder translated to English")
        TestHarness.assertEqual(loc.tr(.pinnedSection), "PINNED", "Pinned section translated to English")
        TestHarness.assertEqual(loc.tr(.languageLabel), "Language:", "Language label translated to English")
        TestHarness.assertEqual(loc.tr(.authorLabel), "Author", "Author label translated to English")
        TestHarness.assertEqual(loc.tr(.licenseLabel), "License", "License label translated to English")

        // 3. Image tag localization
        TestHarness.assertEqual(L10nKey.imageTag(800, 600).localized(for: .vietnamese), "[Ảnh] 800x600", "Vietnamese image tag")
        TestHarness.assertEqual(L10nKey.imageTag(800, 600).localized(for: .simplifiedChinese), "[图片] 800x600", "Chinese image tag")
        TestHarness.assertEqual(L10nKey.imageTag(800, 600).localized(for: .japanese), "[画像] 800x600", "Japanese image tag")
        TestHarness.assertEqual(L10nKey.imageTag(800, 600).localized(for: .english), "[Image] 800x600", "English image tag")

        // 4. Multilingual image search matching
        let imageItem = ClipItem(
            id: UUID(),
            contentType: .image,
            textContent: nil,
            imageWidth: 1920,
            imageHeight: 1080,
            createdAt: Date(),
            isPinned: false
        )
        TestHarness.assertTrue(SearchEngine.matches(item: imageItem, query: "[Ảnh]"), "Search matches Vietnamese image tag")
        TestHarness.assertTrue(SearchEngine.matches(item: imageItem, query: "[Image]"), "Search matches English image tag")
        TestHarness.assertTrue(SearchEngine.matches(item: imageItem, query: "[图片]"), "Search matches Chinese image tag")
        TestHarness.assertTrue(SearchEngine.matches(item: imageItem, query: "[画像]"), "Search matches Japanese image tag")
        TestHarness.assertTrue(SearchEngine.matches(item: imageItem, query: "1920x1080"), "Search matches image dimension")

        // 5. StorageManager settings synchronization
        let storage = StorageManager(baseDirectory: sandboxDir)
        var s = storage.settings
        s.language = "vi"
        storage.settings = s

        TestHarness.assertEqual(LocalizationManager.shared.currentLanguage, .vietnamese, "Storage settings update updates LocalizationManager")
        TestHarness.assertEqual(LocalizationManager.shared.effectiveLanguage, .vietnamese, "Storage settings update reflects effectiveLanguage")

        // Reset to system
        s.language = "system"
        storage.settings = s
        TestHarness.assertEqual(LocalizationManager.shared.currentLanguage, .system, "Reset language back to system")
    }
}
