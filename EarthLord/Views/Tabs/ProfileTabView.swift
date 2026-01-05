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

    /// 显示确认删除账户对话框
    @State private var showDeleteConfirmation = false

    /// 删除确认输入文本
    @State private var deleteConfirmationText = ""

    /// 显示 Toast 提示
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastType: ToastType = .success

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

                    // 危险区域
                    dangerZoneSection

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
        .sheet(isPresented: $showDeleteConfirmation) {
            deleteAccountSheet
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

    // MARK: - Danger Zone Section

    /// 危险区域 - 删除账户
    private var dangerZoneSection: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(ApocalypseTheme.danger)
                Text("危险区域")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.danger)
                Spacer()
            }

            // 删除账户按钮
            Button(action: {
                print("🔴 [设置] 用户点击删除账户按钮")
                deleteConfirmationText = ""
                showDeleteConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash.fill")
                        .font(.headline)

                    Text("删除账户")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .foregroundColor(ApocalypseTheme.danger)
                .padding()
                .background(ApocalypseTheme.danger.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ApocalypseTheme.danger.opacity(0.3), lineWidth: 1)
                )
            }

            // 警告文字
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(ApocalypseTheme.textMuted)
                Text("删除账户将永久删除您的所有数据，此操作不可撤销")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding(.horizontal, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ApocalypseTheme.danger.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Delete Account Sheet

    /// 删除账户确认弹窗
    private var deleteAccountSheet: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        Spacer().frame(height: 20)

                        // 警告图标
                        ZStack {
                            Circle()
                                .fill(ApocalypseTheme.danger.opacity(0.2))
                                .frame(width: 100, height: 100)

                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(ApocalypseTheme.danger)
                        }
                        .padding(.top, 20)

                        // 警告标题
                        VStack(spacing: 12) {
                            Text("删除账户")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Text("此操作不可撤销")
                                .font(.subheadline)
                                .foregroundColor(ApocalypseTheme.danger)
                        }

                        // 警告内容
                        VStack(spacing: 16) {
                            warningItem(
                                icon: "trash.fill",
                                text: "您的所有数据将被永久删除"
                            )

                            warningItem(
                                icon: "person.crop.circle.badge.xmark",
                                text: "您的账户将无法恢复"
                            )

                            warningItem(
                                icon: "clock.arrow.circlepath",
                                text: "此操作立即生效且无法撤销"
                            )
                        }
                        .padding(.horizontal)

                        // 确认输入框
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "keyboard")
                                        .foregroundColor(ApocalypseTheme.textSecondary)
                                    Text("请输入 \"删除\" 以确认操作")
                                        .font(.subheadline)
                                        .foregroundColor(ApocalypseTheme.textSecondary)
                                }

                                TextField("输入：删除", text: $deleteConfirmationText)
                                    .padding()
                                    .background(ApocalypseTheme.cardBackground)
                                    .foregroundColor(ApocalypseTheme.textPrimary)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                deleteConfirmationText == "删除" ?
                                                ApocalypseTheme.danger : ApocalypseTheme.primary.opacity(0.2),
                                                lineWidth: 1
                                            )
                                    )
                                    .onChange(of: deleteConfirmationText) { newValue in
                                        print("📝 [删除确认] 用户输入: \(newValue)")
                                    }
                            }

                            // 确认删除按钮
                            Button(action: {
                                print("🚨 [删除确认] 用户确认删除账户")
                                showDeleteConfirmation = false
                                Task {
                                    await performDeleteAccount()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "trash.fill")
                                    Text("确认删除账户")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    deleteConfirmationText == "删除" ?
                                    LinearGradient(
                                        colors: [ApocalypseTheme.danger, ApocalypseTheme.danger.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ) :
                                    LinearGradient(
                                        colors: [ApocalypseTheme.textMuted.opacity(0.3)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                                .shadow(
                                    color: deleteConfirmationText == "删除" ?
                                    ApocalypseTheme.danger.opacity(0.3) : .clear,
                                    radius: 10
                                )
                            }
                            .disabled(deleteConfirmationText != "删除")
                        }
                        .padding(.horizontal)

                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        print("ℹ️ [删除确认] 用户取消删除")
                        showDeleteConfirmation = false
                        deleteConfirmationText = ""
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    /// 警告项
    private func warningItem(icon: String, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.danger)
                .frame(width: 24)

            Text(text)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()
        }
        .padding()
        .background(ApocalypseTheme.danger.opacity(0.1))
        .cornerRadius(12)
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
                Image(systemName: toastType == .success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                Text(toastMessage)
                    .font(.subheadline)
            }
            .foregroundColor(.white)
            .padding()
            .background(toastType == .success ? ApocalypseTheme.success : ApocalypseTheme.danger)
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
            showToastMessage("已退出登录", type: .success)
        }
    }

    /// 执行删除账户
    private func performDeleteAccount() async {
        print("🚀 [设置] 开始执行删除账户操作")

        let success = await authManager.deleteAccount()

        if success {
            print("✅ [设置] 账户删除成功")
            showToastMessage("账户已删除", type: .success)
            // 账户删除成功后，AuthManager 会清除登录状态，RootView 会自动跳转到登录页
        } else {
            print("❌ [设置] 账户删除失败: \(authManager.errorMessage ?? "未知错误")")
            showToastMessage(authManager.errorMessage ?? "删除失败", type: .error)
        }
    }

    /// 显示 Toast 消息
    private func showToastMessage(_ message: String, type: ToastType = .success) {
        toastMessage = message
        toastType = type
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

// MARK: - Supporting Types

/// Toast 类型
enum ToastType {
    case success
    case error
}

// MARK: - Preview

#Preview {
    ProfileTabView()
}
