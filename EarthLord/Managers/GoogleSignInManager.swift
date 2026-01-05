//
//  GoogleSignInManager.swift
//  EarthLord
//
//  Created by Claude on 2025/12/31.
//

import Foundation
import GoogleSignIn
import GoogleSignInSwift

/// Google登录配置管理器
class GoogleSignInManager {

    // MARK: - 单例
    static let shared = GoogleSignInManager()

    // MARK: - 配置

    /// Google Client ID
    /// ✅ 已配置
    private let googleClientID = "266403203192-rgsoii96s3vqgo77254d9limum8toeu6.apps.googleusercontent.com"

    private init() {}

    // MARK: - 配置方法

    /// 配置 Google Sign-In
    /// 在应用启动时调用
    func configure() {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔧 [Google登录] 开始配置 Google Sign-In")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        guard let clientID = getClientID() else {
            print("❌ [Google登录] ⚠️ 配置失败：Client ID 未设置！")
            print("💡 [Google登录] 请在 GoogleSignInManager.swift 中填入你的 Client ID")
            print("📍 [Google登录] 位置：第 27 行 googleClientID 变量")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            return
        }

        let configuration = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = configuration

        print("✅ [Google登录] ✓ Google Sign-In 配置成功！")
        print("📝 [Google登录] Client ID: \(clientID.prefix(30))...")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }

    /// 处理 URL 回调
    /// 在 AppDelegate 或 SceneDelegate 的 URL 处理方法中调用
    func handleURL(_ url: URL) -> Bool {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔗 [Google登录] 📲 收到 URL 回调")
        print("📝 [Google登录] URL: \(url.absoluteString)")

        let handled = GIDSignIn.sharedInstance.handle(url)

        if handled {
            print("✅ [Google登录] ✓ URL 处理成功！Google SDK 已接收")
        } else {
            print("⚠️ [Google登录] ⚠️ URL 未被处理（可能不是 Google 登录回调）")
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

        return handled
    }

    // MARK: - 登录方法

    /// 执行 Google 登录
    /// - Parameter presentingViewController: 用于展示登录界面的视图控制器
    /// - Returns: Google ID Token（用于Supabase认证）
    func signIn(presentingViewController: UIViewController) async throws -> String {
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🚀 [Google登录] 开始 Google 登录流程")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // 步骤 1: 检查配置
        print("📍 [Google登录] 步骤 1/4: 检查 Client ID 配置")
        guard let clientID = getClientID() else {
            print("❌ [Google登录] ✗ Client ID 未配置！")
            print("💡 [Google登录] 请先在 GoogleSignInManager.swift 中填入 Client ID")
            throw GoogleSignInError.clientIDNotConfigured
        }
        print("✅ [Google登录] ✓ Client ID 配置正确")
        print("📝 [Google登录] Client ID: \(clientID.prefix(30))...")

        do {
            // 步骤 2: 展示登录界面
            print("\n📍 [Google登录] 步骤 2/4: 展示 Google 登录界面")
            print("📱 [Google登录] 等待用户选择 Google 账号...")

            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presentingViewController
            )

            // 步骤 3: 获取用户信息
            print("\n📍 [Google登录] 步骤 3/4: 获取用户信息")
            print("✅ [Google登录] ✓ 用户成功授权登录！")
            print("👤 [Google登录] 邮箱: \(result.user.profile?.email ?? "未知")")
            print("👤 [Google登录] 姓名: \(result.user.profile?.name ?? "未知")")

            // 步骤 4: 提取 ID Token
            print("\n📍 [Google登录] 步骤 4/4: 提取 ID Token")
            guard let idToken = result.user.idToken?.tokenString else {
                print("❌ [Google登录] ✗ 无法获取 ID Token！")
                throw GoogleSignInError.noIDToken
            }

            print("✅ [Google登录] ✓ 成功获取 ID Token")
            print("📝 [Google登录] Token 前缀: \(String(idToken.prefix(20)))...")
            print("🔐 [Google登录] Token 长度: \(idToken.count) 字符")
            print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("🎉 [Google登录] Google 登录流程完成！")
            print("📤 [Google登录] 准备发送 Token 到 Supabase 认证")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

            return idToken

        } catch {
            print("\n❌ [Google登录] ✗ 登录失败！")
            print("📝 [Google登录] 错误信息: \(error.localizedDescription)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
            throw error
        }
    }

    /// 退出 Google 登录
    func signOut() {
        print("🚪 [Google登录] 执行Google登出")
        GIDSignIn.sharedInstance.signOut()
        print("✅ [Google登录] Google登出成功")
    }

    /// 恢复之前的登录状态
    func restorePreviousSignIn() async throws -> String? {
        print("🔄 [Google登录] 尝试恢复之前的登录状态")

        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()

            print("✅ [Google登录] 成功恢复登录状态")
            print("📝 [Google登录] 用户: \(user.profile?.email ?? "未知")")

            guard let idToken = user.idToken?.tokenString else {
                print("❌ [Google登录] 无法获取ID Token")
                return nil
            }

            return idToken

        } catch {
            print("⚠️ [Google登录] 无法恢复登录状态: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 辅助方法

    /// 获取 Client ID
    private func getClientID() -> String? {
        // 检查是否已配置
        if googleClientID == "YOUR_GOOGLE_CLIENT_ID" {
            return nil
        }
        return googleClientID
    }
}

// MARK: - 错误类型

enum GoogleSignInError: LocalizedError {
    case clientIDNotConfigured
    case noIDToken
    case cancelled

    var errorDescription: String? {
        switch self {
        case .clientIDNotConfigured:
            return "Google Client ID 未配置，请在 GoogleSignInManager 中设置正确的 Client ID"
        case .noIDToken:
            return "无法获取 Google ID Token"
        case .cancelled:
            return "用户取消了登录"
        }
    }
}
