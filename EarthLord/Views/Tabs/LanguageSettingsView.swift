//
//  LanguageSettingsView.swift
//  EarthLord
//
//  Created by 赵云霞 on 2025/12/27.
//

import SwiftUI

/// 语言设置页面
struct LanguageSettingsView: View {

    // MARK: - Properties

    /// 语言管理器
    @StateObject private var languageManager = LanguageManager.shared

    /// 显示切换成功提示
    @State private var showSuccessToast = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // 顶部说明
                    infoCard

                    // 语言选项列表
                    languageOptions

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }

            // 成功提示 Toast
            if showSuccessToast {
                successToast
            }
        }
        .navigationTitle(L("language_settings"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Info Card

    /// 顶部说明卡片
    private var infoCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(ApocalypseTheme.info)
                .font(.title3)

            Text(L("language_change_takes_effect_immediately"))
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ApocalypseTheme.info.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Language Options

    /// 语言选项列表
    private var languageOptions: some View {
        VStack(spacing: 0) {
            ForEach(AppLanguage.allCases, id: \.self) { language in
                LanguageOptionRow(
                    language: language,
                    isSelected: languageManager.currentLanguage == language,
                    action: {
                        switchLanguage(to: language)
                    }
                )

                if language != AppLanguage.allCases.last {
                    Divider()
                        .background(ApocalypseTheme.textMuted.opacity(0.2))
                        .padding(.leading, 68)
                }
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ApocalypseTheme.primary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Success Toast

    /// 成功提示 Toast
    private var successToast: some View {
        VStack {
            Spacer()

            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)

                Text(L("language_switched"))
                    .foregroundColor(.white)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding()
            .background(ApocalypseTheme.success)
            .cornerRadius(12)
            .shadow(color: ApocalypseTheme.success.opacity(0.3), radius: 10)
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Actions

    /// 切换语言
    /// - Parameter language: 目标语言
    private func switchLanguage(to language: AppLanguage) {
        guard languageManager.currentLanguage != language else {
            return
        }

        print("🌐 [语言设置] 用户选择语言: \(language.displayName)")

        // 切换语言
        withAnimation(.spring(response: 0.3)) {
            languageManager.switchLanguage(to: language)
        }

        // 显示成功提示
        withAnimation {
            showSuccessToast = true
        }

        // 2 秒后隐藏提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showSuccessToast = false
            }
        }

        // 轻触反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - Language Option Row

/// 语言选项行
struct LanguageOptionRow: View {
    let language: AppLanguage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // 语言图标
                ZStack {
                    Circle()
                        .fill(
                            isSelected ?
                            ApocalypseTheme.primary.opacity(0.2) :
                            ApocalypseTheme.textMuted.opacity(0.1)
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: language.icon)
                        .font(.title3)
                        .foregroundColor(
                            isSelected ?
                            ApocalypseTheme.primary :
                            ApocalypseTheme.textSecondary
                        )
                }

                // 语言名称
                VStack(alignment: .leading, spacing: 4) {
                    Text(language.displayName)
                        .font(.body)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(
                            isSelected ?
                            ApocalypseTheme.primary :
                            ApocalypseTheme.textPrimary
                        )

                    if language == .system {
                        Text(L("follow_system_language"))
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                Spacer()

                // 选中标记
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(ApocalypseTheme.primary)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LanguageSettingsView()
    }
}
