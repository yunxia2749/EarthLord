//
//  SplashView.swift
//  EarthLord
//
//  Created by 赵云霞 on 2025/12/24.
//

import SwiftUI

/// 启动页视图
struct SplashView: View {
    /// 认证管理器
    @StateObject private var authManager = AuthManager.shared

    /// 是否显示加载动画
    @State private var isAnimating = false

    /// 加载进度文字
    @State private var loadingText = "正在初始化..."

    /// Logo 缩放动画
    @State private var logoScale: CGFloat = 0.8

    /// Logo 透明度
    @State private var logoOpacity: Double = 0

    /// 是否完成加载
    @Binding var isFinished: Bool

    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.10, green: 0.10, blue: 0.18),
                    Color(red: 0.09, green: 0.13, blue: 0.24),
                    Color(red: 0.06, green: 0.06, blue: 0.10)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // Logo
                ZStack {
                    // 外圈光晕（呼吸动画）
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    ApocalypseTheme.primary.opacity(0.3),
                                    ApocalypseTheme.primary.opacity(0)
                                ],
                                center: .center,
                                startRadius: 50,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: isAnimating
                        )

                    // Logo 圆形背景
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    ApocalypseTheme.primary,
                                    ApocalypseTheme.primary.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: ApocalypseTheme.primary.opacity(0.5), radius: 20)

                    // 地球图标
                    Image(systemName: "globe.asia.australia.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                // 标题
                VStack(spacing: 8) {
                    Text("地球新主")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("EARTH LORD")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .tracking(4)
                }
                .opacity(logoOpacity)

                Spacer()

                // 加载指示器
                VStack(spacing: 16) {
                    // 三点加载动画
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(ApocalypseTheme.primary)
                                .frame(width: 10, height: 10)
                                .scaleEffect(isAnimating ? 1.0 : 0.5)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                    value: isAnimating
                                )
                        }
                    }

                    // 加载文字
                    Text(loadingText)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            startAnimations()
            simulateLoading()
        }
    }

    // MARK: - 动画方法

    private func startAnimations() {
        // Logo 入场动画
        withAnimation(.easeOut(duration: 0.8)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }

        // 启动循环动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isAnimating = true
        }
    }

    // MARK: - 模拟加载

    private func simulateLoading() {
        Task {
            print("🔵 [SplashView] simulateLoading 开始")

            // 等待 AuthManager 完成会话检查
            await MainActor.run {
                loadingText = "正在检查登录状态..."
            }

            print("⏰ [SplashView] 等待 AuthManager 会话检查完成...")

            // 等待会话检查完成（最多等待 10 秒）
            var waitCount = 0
            while !authManager.isSessionChecked && waitCount < 100 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                waitCount += 1
            }

            if authManager.isSessionChecked {
                print("✅ [SplashView] 会话检查已完成")
            } else {
                print("⚠️ [SplashView] 会话检查超时，继续加载")
            }

            // 显示准备就绪
            await MainActor.run {
                loadingText = "准备就绪"
                print("✅ [SplashView] 状态更新：准备就绪")
            }

            // 短暂的视觉缓冲（0.3秒）
            print("⏰ [SplashView] 开始 0.3秒 延迟")
            try? await Task.sleep(nanoseconds: 300_000_000)
            print("✅ [SplashView] 延迟完成")

            // 完成加载，进入主界面
            await MainActor.run {
                print("🎯 [SplashView] 准备设置 isFinished = true, isAuthenticated = \(authManager.isAuthenticated)")
                withAnimation(.easeInOut(duration: 0.3)) {
                    isFinished = true
                }
                print("✅ [SplashView] isFinished 已设置为 true")
            }
        }
    }
}

#Preview {
    SplashView(isFinished: .constant(false))
}
