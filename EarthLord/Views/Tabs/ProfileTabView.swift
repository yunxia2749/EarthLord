//
//  ProfileTabView.swift
//  EarthLord
//
//  Created by 赵云霞 on 2025/12/24.
//

import SwiftUI
import Supabase

/// 个人页面 - 显示用户信息和退出登录按钮
struct ProfileTabView: View {

    // MARK: - Properties

    /// 认证管理器
    @StateObject private var authManager = AuthManager.shared

    /// 显示确认退出对话框
    @State private var showLogoutConfirmation = false

    /// 显示 Toast 提示
    @State private var showToast = false
    @State private var toastMessage = ""

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景渐变
            backgroundGradient

            ScrollView {
                VStack(spacing: 32) {
                    // 顶部间距
                    Spacer().frame(height: 20)

                    // 用户信息卡片
                    userInfoCard

                    // 设置选项
                    settingsSection

                    // 退出登录按钮
                    logoutButton

                    Spacer()
                }
                .padding(.horizontal, 24)
            }

            // Toast 提示
            if showToast {
                toastView
            }

            // 加载指示器
            if authManager.isLoading {
                loadingOverlay
            }
        }
        .confirmationDialog("确认退出", isPresented: $showLogoutConfirmation) {
            Button("退出登录", role: .destructive) {
                Task {
                    await performLogout()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要退出登录吗？")
        }
    }

    // MARK: - Background

    /// 背景渐变
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.1, green: 0.1, blue: 0.15),
                Color(red: 0.15, green: 0.1, blue: 0.1),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - User Info Card

    /// 用户信息卡片
    private var userInfoCard: some View {
        VStack(spacing: 20) {
            // 用户头像
            userAvatar

            // 用户名
            if let email = authManager.currentUser?.email {
                Text(email)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            // 用户 ID
            if let userId = authManager.currentUser?.id {
                Text("ID: \(userId.uuidString.prefix(8))...")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .fontDesign(.monospaced)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ApocalypseTheme.cardBackground)
                .shadow(color: ApocalypseTheme.primary.opacity(0.1), radius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [ApocalypseTheme.primary.opacity(0.3), ApocalypseTheme.secondary.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    /// 用户头像
    private var userAvatar: some View {
        ZStack {
            // 渐变圆环
            Circle()
                .fill(
                    LinearGradient(
                        colors: [ApocalypseTheme.primary, ApocalypseTheme.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .shadow(color: ApocalypseTheme.primary.opacity(0.5), radius: 20)

            // 内部图标
            Image(systemName: "person.fill")
                .font(.system(size: 40))
                .foregroundColor(.white)
        }
    }

    // MARK: - Settings Section

    /// 设置选项区域
    private var settingsSection: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Text("设置")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
            }

            // 设置选项卡片
            VStack(spacing: 0) {
                SettingRow(
                    icon: "envelope.fill",
                    title: "邮箱",
                    value: authManager.currentUser?.email ?? "未知",
                    showDivider: true
                )

                SettingRow(
                    icon: "calendar",
                    title: "注册时间",
                    value: formatDate(authManager.currentUser?.createdAt),
                    showDivider: false
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ApocalypseTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(ApocalypseTheme.primary.opacity(0.2), lineWidth: 1)
            )
        }
    }

    // MARK: - Logout Button

    /// 退出登录按钮
    private var logoutButton: some View {
        Button(action: {
            showLogoutConfirmation = true
        }) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.headline)

                Text("退出登录")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [ApocalypseTheme.danger, ApocalypseTheme.danger.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: ApocalypseTheme.danger.opacity(0.3), radius: 10)
        }
    }

    // MARK: - Loading Overlay

    /// 加载遮罩
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                Text("请稍候...")
                    .foregroundColor(.white)
                    .font(.subheadline)
            }
            .padding(32)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
            .shadow(radius: 20)
        }
    }

    // MARK: - Toast View

    /// Toast 提示视图
    private var toastView: some View {
        VStack {
            Spacer()

            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text(toastMessage)
                    .font(.subheadline)
            }
            .foregroundColor(.white)
            .padding()
            .background(ApocalypseTheme.success)
            .cornerRadius(12)
            .shadow(radius: 10)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Actions

    /// 执行退出登录
    private func performLogout() async {
        await authManager.signOut()

        if !authManager.isAuthenticated {
            showToastMessage("已退出登录")
        }
    }

    /// 显示 Toast 消息
    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showToast = false
            }
        }
    }

    // MARK: - Helper Methods

    /// 格式化日期
    /// - Parameter date: 日期
    /// - Returns: 格式化后的字符串
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else {
            return "未知"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: date)
    }
}

// MARK: - Setting Row Component

/// 设置选项行组件
struct SettingRow: View {
    let icon: String
    let title: String
    let value: String
    let showDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // 图标
                Image(systemName: icon)
                    .foregroundColor(ApocalypseTheme.primary)
                    .frame(width: 24)

                // 标题
                Text(title)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                // 值
                Text(value)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .fontDesign(.default)
            }
            .padding()

            // 分隔线
            if showDivider {
                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.2))
                    .padding(.leading, 56)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileTabView()
}
