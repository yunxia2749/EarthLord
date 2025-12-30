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
    /// ⚠️ 重要：请在Google Cloud Console创建OAuth 2.0客户端ID后，将Client ID填入这里
    /// 例如：123456789-abcdefg.apps.googleusercontent.com
    private let googleClientID = "YOUR_GOOGLE_CLIENT_ID"

    private init() {}

    // MARK: - 配置方法

    /// 配置 Google Sign-In
    /// 在应用启动时调用
    func configure() {
        print("🔧 [Google登录] 开始配置 Google Sign-In")

        guard let clientID = getClientID() else {
            print("❌ [Google登录] 配置失败：Client ID未设置")
            return
        }

        let configuration = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = configuration

        print("✅ [Google登录] Google Sign-In 配置完成")
        print("📝 [Google登录] Client ID: \(clientID)")
    }

    /// 处理 URL 回调
    /// 在 AppDelegate 或 SceneDelegate 的 URL 处理方法中调用
    func handleURL(_ url: URL) -> Bool {
        print("🔗 [Google登录] 处理URL回调: \(url.absoluteString)")
        let handled = GIDSignIn.sharedInstance.handle(url)
        print(handled ? "✅ [Google登录] URL处理成功" : "⚠️ [Google登录] URL未被处理")
        return handled
    }

    // MARK: - 登录方法

    /// 执行 Google 登录
    /// - Parameter presentingViewController: 用于展示登录界面的视图控制器
    /// - Returns: Google ID Token（用于Supabase认证）
    func signIn(presentingViewController: UIViewController) async throws -> String {
        print("🚀 [Google登录] 开始Google登录流程")

        // 检查配置
        guard getClientID() != nil else {
            print("❌ [Google登录] Client ID未配置")
            throw GoogleSignInError.clientIDNotConfigured
        }

        do {
            print("📱 [Google登录] 正在展示Google登录界面...")

            // 执行Google登录
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presentingViewController
            )

            print("✅ [Google登录] 用户成功登录Google账号")
            print("📝 [Google登录] 用户信息: \(result.user.profile?.email ?? "未知邮箱")")

            // 获取 ID Token
            guard let idToken = result.user.idToken?.tokenString else {
                print("❌ [Google登录] 无法获取ID Token")
                throw GoogleSignInError.noIDToken
            }

            print("✅ [Google登录] 成功获取ID Token")
            print("📝 [Google登录] Token前缀: \(String(idToken.prefix(20)))...")

            return idToken

        } catch {
            print("❌ [Google登录] 登录失败: \(error.localizedDescription)")
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
