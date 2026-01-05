//
//  MoreTabView.swift
//  EarthLord
//
//  Created by 赵云霞 on 2025/12/24.
//

import SwiftUI

struct MoreTabView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // 开发工具部分
                        SectionHeader(title: "开发工具")

                        VStack(spacing: 0) {
                            NavigationLink(destination: SupabaseTestView()) {
                                MoreMenuItem(
                                    icon: "server.rack",
                                    title: "Supabase 连接测试",
                                    subtitle: "测试后端服务连接状态",
                                    iconColor: ApocalypseTheme.info
                                )
                            }
                        }
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)

                        // 占位：其他功能区域
                        SectionHeader(title: "游戏功能")

                        VStack(spacing: 0) {
                            NavigationLink(destination: LanguageSettingsView()) {
                                MoreMenuItem(
                                    icon: "globe",
                                    title: "语言设置",
                                    subtitle: "切换 App 显示语言",
                                    iconColor: ApocalypseTheme.primary
                                )
                            }

                            Divider()
                                .background(ApocalypseTheme.background)
                                .padding(.leading, 60)

                            MoreMenuItem(
                                icon: "gearshape.fill",
                                title: "设置",
                                subtitle: "应用设置和偏好",
                                iconColor: ApocalypseTheme.textMuted
                            )

                            Divider()
                                .background(ApocalypseTheme.background)
                                .padding(.leading, 60)

                            MoreMenuItem(
                                icon: "info.circle.fill",
                                title: "关于",
                                subtitle: "版本信息和帮助",
                                iconColor: ApocalypseTheme.textMuted
                            )
                        }
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("更多")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - 子视图

/// 分组标题
struct SectionHeader: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(ApocalypseTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 24)
            .padding(.bottom, 8)
    }
}

/// 菜单项
struct MoreMenuItem: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let iconColor: Color

    var body: some View {
        HStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }

            // 文字
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 箭头
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

#Preview {
    MoreTabView()
}
