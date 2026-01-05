//
//  LanguageManager.swift
//  EarthLord
//
//  Created by 赵云霞 on 2025/12/27.
//

import Foundation
import SwiftUI
import Combine

/// 语言类型
enum AppLanguage: String, CaseIterable {
    case system = "system"      // 跟随系统
    case chinese = "zh-Hans"    // 简体中文
    case english = "en"         // English

    var displayName: String {
        switch self {
        case .system:
            return "跟随系统"
        case .chinese:
            return "简体中文"
        case .english:
            return "English"
        }
    }

    var icon: String {
        switch self {
        case .system:
            return "globe"
        case .chinese:
            return "character.textbox"
        case .english:
            return "textformat.abc"
        }
    }
}

/// 语言管理器 - 管理 App 内的语言切换
class LanguageManager: ObservableObject {

    // MARK: - Singleton

    static let shared = LanguageManager()

    // MARK: - Properties

    /// 当前选择的语言
    @Published var currentLanguage: AppLanguage {
        didSet {
            saveLanguage()
            updateBundle()
        }
    }

    /// 实际使用的语言代码（解析系统语言后的结果）
    @Published private(set) var effectiveLanguageCode: String

    /// 自定义 Bundle（用于加载本地化字符串）
    private var customBundle: Bundle?

    // MARK: - UserDefaults Key

    private let languageKey = "app_language"

    // MARK: - Initialization

    private init() {
        // 从 UserDefaults 读取保存的语言设置
        let savedLanguage: AppLanguage
        if let savedRawValue = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedRawValue) {
            savedLanguage = language
        } else {
            // 默认跟随系统
            savedLanguage = .system
        }

        // 初始化属性
        self.currentLanguage = savedLanguage
        self.effectiveLanguageCode = Self.resolveLanguageCode(savedLanguage)

        // 更新 Bundle
        updateBundle()

        print("🌐 [LanguageManager] 初始化完成，当前语言: \(currentLanguage.displayName), 有效语言代码: \(effectiveLanguageCode)")
    }

    // MARK: - Public Methods

    /// 切换语言
    /// - Parameter language: 目标语言
    func switchLanguage(to language: AppLanguage) {
        print("🌐 [LanguageManager] 切换语言: \(currentLanguage.displayName) -> \(language.displayName)")
        currentLanguage = language
    }

    /// 获取本地化字符串
    /// - Parameters:
    ///   - key: 本地化 key
    ///   - defaultValue: 默认值
    /// - Returns: 本地化后的字符串
    func localizedString(_ key: String, defaultValue: String? = nil) -> String {
        guard let bundle = customBundle else {
            return defaultValue ?? key
        }

        let localizedString = bundle.localizedString(forKey: key, value: defaultValue, table: nil)
        return localizedString != key ? localizedString : (defaultValue ?? key)
    }

    // MARK: - Private Methods

    /// 保存语言设置到 UserDefaults
    private func saveLanguage() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
        print("💾 [LanguageManager] 语言设置已保存: \(currentLanguage.displayName)")
    }

    /// 更新 Bundle（用于加载对应语言的本地化资源）
    private func updateBundle() {
        let languageCode = Self.resolveLanguageCode(currentLanguage)
        effectiveLanguageCode = languageCode

        // 查找对应语言的 Bundle
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            customBundle = bundle
            print("✅ [LanguageManager] Bundle 更新成功: \(languageCode)")
        } else {
            // 如果找不到，使用主 Bundle
            customBundle = Bundle.main
            print("⚠️ [LanguageManager] 未找到语言包，使用主 Bundle: \(languageCode)")
        }

        // 触发 UI 更新
        objectWillChange.send()
    }

    /// 解析语言代码（将 system 转换为实际的系统语言）
    /// - Parameter language: App 语言设置
    /// - Returns: 实际的语言代码
    private static func resolveLanguageCode(_ language: AppLanguage) -> String {
        switch language {
        case .system:
            // 获取系统首选语言
            let preferredLanguage = Locale.preferredLanguages.first ?? "en"

            // 简化语言代码（例如 "zh-Hans-CN" -> "zh-Hans"）
            if preferredLanguage.hasPrefix("zh-Hans") {
                return "zh-Hans"
            } else if preferredLanguage.hasPrefix("zh-Hant") {
                return "zh-Hant"
            } else if preferredLanguage.hasPrefix("en") {
                return "en"
            } else {
                return "en" // 默认英文
            }

        case .chinese:
            return "zh-Hans"

        case .english:
            return "en"
        }
    }
}

// MARK: - SwiftUI Extension

/// 自定义本地化字符串函数
/// - Parameter key: 本地化 key
/// - Returns: 本地化后的字符串
func L(_ key: String) -> String {
    LanguageManager.shared.localizedString(key, defaultValue: key)
}

/// 本地化字符串 LocalizedStringKey 扩展
extension String {
    /// 使用 LanguageManager 获取本地化字符串
    var localized: String {
        LanguageManager.shared.localizedString(self, defaultValue: self)
    }
}
