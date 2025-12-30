//
//  AuthManager.swift
//  EarthLord
//
//  Created by 赵云霞 on 2025/12/30.
//

import Foundation
import SwiftUI
import Combine
import Supabase

/// 认证管理器 - 管理用户的注册、登录、密码重置等认证流程
/// 使用 @MainActor 确保所有 UI 更新在主线程执行
@MainActor
class AuthManager: ObservableObject {

    // MARK: - Published Properties (发布属性)

    /// 用户是否已完全认证（登录且完成所有必要流程）
    @Published var isAuthenticated: Bool = false

    /// 是否需要设置密码（OTP 验证后的必要步骤）
    @Published var needsPasswordSetup: Bool = false

    /// 当前登录的用户信息
    @Published var currentUser: User? = nil

    /// 是否正在加载（执行异步操作）
    @Published var isLoading: Bool = false

    /// 错误消息
    @Published var errorMessage: String? = nil

    /// OTP 验证码是否已发送
    @Published var otpSent: Bool = false

    /// OTP 验证码是否已验证（等待设置密码）
    @Published var otpVerified: Bool = false

    // MARK: - Singleton (单例)

    static let shared = AuthManager()

    /// Auth 状态监听任务
    private var authStateTask: Task<Void, Never>?

    private init() {
        // 初始化时检查会话
        Task {
            await checkSession()
            // 启动会话监听
            await startAuthStateListener()
        }
    }

    deinit {
        // 取消监听
        authStateTask?.cancel()
    }

    // MARK: - 注册流程

    /// 发送注册验证码
    /// - Parameter email: 用户邮箱
    func sendRegisterOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 调用 Supabase 发送 OTP（shouldCreateUser: true 表示如果用户不存在则创建）
            try await supabase.auth.signInWithOTP(
                email: email,
                shouldCreateUser: true
            )

            // 发送成功
            otpSent = true
            print("✅ 注册验证码已发送至: \(email)")

        } catch {
            // 发送失败
            errorMessage = "发送验证码失败: \(error.localizedDescription)"
            print("❌ 发送注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 验证注册 OTP
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    /// ⚠️ 注意：验证成功后用户已登录，但需要设置密码才能完成注册
    func verifyRegisterOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 验证 OTP
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .email
            )

            // 验证成功，用户已登录
            currentUser = session.user
            otpVerified = true
            needsPasswordSetup = true

            // ⚠️ 重要：此时 isAuthenticated 保持 false，直到完成密码设置
            print("✅ 验证码验证成功，用户已登录但需要设置密码")
            print("用户 ID: \(session.user.id)")

        } catch {
            // 验证失败
            errorMessage = "验证码错误或已过期: \(error.localizedDescription)"
            print("❌ 验证注册 OTP 失败: \(error)")
        }

        isLoading = false
    }

    /// 完成注册（设置密码）
    /// - Parameter password: 用户设置的密码
    func completeRegistration(password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            let updatedUser = try await supabase.auth.update(
                user: UserAttributes(password: password)
            )

            // 完成注册
            currentUser = updatedUser
            needsPasswordSetup = false
            isAuthenticated = true
            otpVerified = false

            print("✅ 注册完成，密码已设置")
            print("用户 ID: \(updatedUser.id)")

        } catch {
            // 设置密码失败
            errorMessage = "设置密码失败: \(error.localizedDescription)"
            print("❌ 完成注册失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 登录

    /// 使用邮箱和密码登录
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - password: 用户密码
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 使用邮箱密码登录
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            // 登录成功
            currentUser = session.user
            isAuthenticated = true
            needsPasswordSetup = false

            print("✅ 登录成功")
            print("用户 ID: \(session.user.id)")
            print("邮箱: \(session.user.email ?? "未知")")

        } catch {
            // 登录失败
            errorMessage = "登录失败: \(error.localizedDescription)"
            print("❌ 登录失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 找回密码流程

    /// 发送密码重置验证码
    /// - Parameter email: 用户邮箱
    func sendResetOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 发送密码重置邮件（会触发 Reset Password 邮件模板）
            try await supabase.auth.resetPasswordForEmail(email)

            // 发送成功
            otpSent = true
            print("✅ 密码重置验证码已发送至: \(email)")

        } catch {
            // 发送失败
            errorMessage = "发送重置验证码失败: \(error.localizedDescription)"
            print("❌ 发送密码重置验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 验证密码重置 OTP
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    /// ⚠️ 注意：type 必须是 .recovery 而不是 .email
    func verifyResetOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 验证密码重置 OTP（type 必须是 .recovery）
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery
            )

            // 验证成功
            currentUser = session.user
            otpVerified = true
            needsPasswordSetup = true

            print("✅ 密码重置验证码验证成功")
            print("用户 ID: \(session.user.id)")

        } catch {
            // 验证失败
            errorMessage = "验证码错误或已过期: \(error.localizedDescription)"
            print("❌ 验证密码重置 OTP 失败: \(error)")
        }

        isLoading = false
    }

    /// 重置密码（设置新密码）
    /// - Parameter newPassword: 新密码
    func resetPassword(newPassword: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            let updatedUser = try await supabase.auth.update(
                user: UserAttributes(password: newPassword)
            )

            // 密码重置成功
            currentUser = updatedUser
            needsPasswordSetup = false
            isAuthenticated = true
            otpVerified = false

            print("✅ 密码重置成功")
            print("用户 ID: \(updatedUser.id)")

        } catch {
            // 密码重置失败
            errorMessage = "密码重置失败: \(error.localizedDescription)"
            print("❌ 密码重置失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 第三方登录（预留）

    /// Apple 登录
    /// TODO: 实现 Apple 登录功能
    func signInWithApple() async {
        // TODO: 集成 Sign in with Apple
        print("⚠️ Apple 登录功能待实现")
        errorMessage = "Apple 登录功能暂未实现"
    }

    /// Google 登录
    /// TODO: 实现 Google 登录功能
    func signInWithGoogle() async {
        // TODO: 集成 Google 登录
        print("⚠️ Google 登录功能待实现")
        errorMessage = "Google 登录功能暂未实现"
    }

    // MARK: - 其他方法

    /// 退出登录
    func signOut() async {
        isLoading = true
        errorMessage = nil

        do {
            // 调用 Supabase 退出登录
            try await supabase.auth.signOut()

            // 清除本地状态
            currentUser = nil
            isAuthenticated = false
            needsPasswordSetup = false
            otpSent = false
            otpVerified = false

            print("✅ 已退出登录")

        } catch {
            // 退出失败
            errorMessage = "退出登录失败: \(error.localizedDescription)"
            print("❌ 退出登录失败: \(error)")
        }

        isLoading = false
    }

    /// 检查当前会话
    /// 在应用启动时调用，恢复用户登录状态
    func checkSession() async {
        isLoading = true

        do {
            // 获取当前会话
            let session = try await supabase.auth.session

            // 会话存在
            currentUser = session.user

            // 检查用户是否已设置密码
            // 注意：这里假设如果能获取到会话，用户就已经完成了所有必要的设置
            // 如果需要更精确的判断，可以在用户元数据中存储标志位
            isAuthenticated = true
            needsPasswordSetup = false

            print("✅ 会话恢复成功")
            print("用户 ID: \(session.user.id)")
            print("邮箱: \(session.user.email ?? "未知")")

        } catch {
            // 没有有效会话
            currentUser = nil
            isAuthenticated = false
            needsPasswordSetup = false

            print("ℹ️ 没有活动会话")
        }

        isLoading = false
    }

    /// 启动会话状态监听
    /// 监听 auth state 变化，处理会话过期等情况
    private func startAuthStateListener() async {
        // 监听 auth state 变化
        authStateTask = Task {
            for await state in supabase.auth.authStateChanges {
                // 确保在主线程更新 UI
                await MainActor.run {
                    handleAuthStateChange(state.event, session: state.session)
                }
            }
        }
    }

    /// 处理认证状态变化
    /// - Parameters:
    ///   - event: 认证事件
    ///   - session: 当前会话
    private func handleAuthStateChange(_ event: AuthChangeEvent, session: Session?) {
        print("🔔 Auth 状态变化: \(event)")

        switch event {
        case .signedIn:
            // 用户登录
            if let session = session {
                currentUser = session.user
                isAuthenticated = true
                needsPasswordSetup = false
                print("✅ 用户已登录: \(session.user.email ?? "未知")")
            }

        case .signedOut:
            // 用户退出登录
            currentUser = nil
            isAuthenticated = false
            needsPasswordSetup = false
            otpSent = false
            otpVerified = false
            print("✅ 用户已退出")

        case .tokenRefreshed:
            // Token 刷新成功
            if let session = session {
                currentUser = session.user
                print("✅ Token 已刷新")
            }

        case .userUpdated:
            // 用户信息更新
            if let session = session {
                currentUser = session.user
                print("✅ 用户信息已更新")
            }

        default:
            print("ℹ️ 其他 Auth 事件: \(event)")
        }
    }

    // MARK: - 辅助方法

    /// 重置所有状态（用于流程切换）
    func resetState() {
        errorMessage = nil
        otpSent = false
        otpVerified = false
    }

    /// 验证邮箱格式
    /// - Parameter email: 邮箱地址
    /// - Returns: 是否有效
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    /// 验证密码强度
    /// - Parameter password: 密码
    /// - Returns: (是否有效, 错误消息)
    func validatePassword(_ password: String) -> (Bool, String?) {
        // 至少 6 位
        guard password.count >= 6 else {
            return (false, "密码至少需要 6 位")
        }

        // 至少 8 位更安全
        guard password.count >= 8 else {
            return (true, "建议密码至少 8 位以提高安全性")
        }

        return (true, nil)
    }
}
