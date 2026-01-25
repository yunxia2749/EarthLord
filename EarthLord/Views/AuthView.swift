//
//  AuthView.swift
//  EarthLord
//
//  Created by 赵云霞 on 2025/12/30.
//

import SwiftUI

/// 认证页面 - 包含登录、注册、找回密码功能
struct AuthView: View {

    // MARK: - State Properties

    /// 认证管理器
    @StateObject private var authManager = AuthManager.shared

    /// 当前选中的 Tab（登录/注册）
    @State private var selectedTab: AuthTab = .login

    // 登录相关
    @State private var loginEmail = ""
    @State private var loginPassword = ""

    // 注册相关
    @State private var registerEmail = ""
    @State private var registerOTP = ""
    @State private var registerPassword = ""
    @State private var registerConfirmPassword = ""
    @State private var registerStep: RegisterStep = .emailInput

    // 找回密码相关
    @State private var showForgotPassword = false
    @State private var resetEmail = ""
    @State private var resetOTP = ""
    @State private var resetNewPassword = ""
    @State private var resetConfirmPassword = ""
    @State private var resetStep: ResetStep = .emailInput

    // 验证码倒计时
    @State private var countdown = 0
    @State private var timer: Timer?

    // Toast 提示
    @State private var showToast = false
    @State private var toastMessage = ""

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景渐变
            backgroundGradient

            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 40)

                    // Logo 和标题
                    headerSection

                    // Tab 切换
                    tabSelector

                    // 内容区域
                    contentSection

                    // 第三方登录
                    thirdPartySection

                    Spacer().frame(height: 40)
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
        .sheet(isPresented: $showForgotPassword) {
            forgotPasswordSheet
        }
        .onChange(of: authManager.isAuthenticated) { newValue in
            // 认证成功后的处理在 RootView 中完成
        }
        .onChange(of: authManager.otpVerified) { verified in
            // OTP 验证成功后，自动跳转到密码设置步骤
            if verified && selectedTab == .register {
                withAnimation {
                    registerStep = .passwordSetup
                }
            } else if verified && showForgotPassword {
                withAnimation {
                    resetStep = .passwordSetup
                }
            }
        }
        .onChange(of: authManager.errorMessage) { error in
            if let error = error {
                showToastMessage(error)
            }
        }
        .onAppear {
            // 恢复注册状态：如果已经发送了验证码但还没验证，恢复到验证步骤
            if selectedTab == .register && authManager.otpSent && !authManager.otpVerified {
                registerStep = .otpVerification
            }
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

    // MARK: - Header

    /// 顶部区域
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Logo
            Image(systemName: "globe.asia.australia.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [ApocalypseTheme.primary, ApocalypseTheme.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: ApocalypseTheme.primary.opacity(0.5), radius: 20)

            // 标题
            Text("地球新主")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, ApocalypseTheme.textPrimary],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text("EARTH LORD")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .tracking(4)
        }
    }

    // MARK: - Tab Selector

    /// Tab 切换器
    private var tabSelector: some View {
        HStack(spacing: 0) {
            // 登录 Tab
            TabButton(
                title: "登录",
                isSelected: selectedTab == .login,
                action: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = .login
                        authManager.resetState()
                    }
                }
            )

            // 注册 Tab
            TabButton(
                title: "注册",
                isSelected: selectedTab == .register,
                action: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = .register
                        registerStep = .emailInput
                        authManager.resetState()
                    }
                }
            )
        }
        .background(ApocalypseTheme.cardBackground.opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ApocalypseTheme.primary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Content Section

    /// 内容区域
    @ViewBuilder
    private var contentSection: some View {
        VStack(spacing: 20) {
            if selectedTab == .login {
                loginContent
            } else {
                registerContent
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Login Content

    /// 登录内容
    private var loginContent: some View {
        VStack(spacing: 16) {
            // 邮箱输入
            CustomTextField(
                icon: "envelope.fill",
                placeholder: "邮箱",
                text: $loginEmail,
                keyboardType: .emailAddress
            )
            .onChange(of: loginEmail) { newValue in
                // 自动清理 mailto: 前缀
                if newValue.lowercased().hasPrefix("mailto:") {
                    loginEmail = String(newValue.dropFirst(7))
                }
            }

            // 密码输入
            CustomSecureField(
                icon: "lock.fill",
                placeholder: "密码",
                text: $loginPassword
            )

            // 忘记密码
            HStack {
                Spacer()
                Button(action: {
                    showForgotPassword = true
                    resetStep = .emailInput
                    resetEmail = loginEmail
                    authManager.resetState()
                }) {
                    Text("忘记密码？")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .padding(.horizontal, 4)

            // 登录按钮
            PrimaryButton(title: "登录", icon: "arrow.right.circle.fill") {
                Task {
                    await performLogin()
                }
            }
            .disabled(loginEmail.isEmpty || loginPassword.isEmpty)
        }
    }

    // MARK: - Register Content

    /// 注册内容
    @ViewBuilder
    private var registerContent: some View {
        VStack(spacing: 16) {
            // 根据当前步骤显示不同内容
            switch registerStep {
            case .emailInput:
                registerEmailStep
            case .otpVerification:
                registerOTPStep
            case .passwordSetup:
                registerPasswordStep
            }
        }
    }

    /// 注册第一步：邮箱输入
    private var registerEmailStep: some View {
        VStack(spacing: 16) {
            // 提示
            StepIndicator(currentStep: 1, totalSteps: 3, title: "输入邮箱")

            // 邮箱输入
            CustomTextField(
                icon: "envelope.fill",
                placeholder: "邮箱",
                text: $registerEmail,
                keyboardType: .emailAddress
            )
            .onChange(of: registerEmail) { newValue in
                // 自动清理 mailto: 前缀
                if newValue.lowercased().hasPrefix("mailto:") {
                    registerEmail = String(newValue.dropFirst(7))
                }
            }

            // 邮箱格式验证提示
            if !registerEmail.isEmpty {
                HStack {
                    Image(systemName: authManager.isValidEmail(registerEmail) ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(authManager.isValidEmail(registerEmail) ? .green : .red)
                    Text(authManager.isValidEmail(registerEmail) ? "邮箱格式正确" : "请输入有效的邮箱地址")
                        .font(.caption)
                        .foregroundColor(authManager.isValidEmail(registerEmail) ? .green : .red)
                }
                .padding(.horizontal, 4)
            }

            // 发送验证码按钮
            PrimaryButton(title: "发送验证码", icon: "paperplane.fill") {
                Task {
                    await sendRegisterOTP()
                }
            }
            .disabled(registerEmail.isEmpty || !authManager.isValidEmail(registerEmail))
        }
    }

    /// 注册第二步：验证码验证
    private var registerOTPStep: some View {
        VStack(spacing: 16) {
            // 提示
            StepIndicator(currentStep: 2, totalSteps: 3, title: "验证邮箱")

            // 提示文字
            Text("验证码已发送至 \(registerEmail)")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            // 验证码输入
            CustomTextField(
                icon: "number",
                placeholder: "6位验证码",
                text: $registerOTP,
                keyboardType: .numberPad
            )
            .onChange(of: registerOTP) { newValue in
                // 限制为6位数字
                if newValue.count > 6 {
                    registerOTP = String(newValue.prefix(6))
                }
            }

            // 重发倒计时
            if countdown > 0 {
                Text("\(countdown)秒后可重发")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            } else {
                Button(action: {
                    Task {
                        await sendRegisterOTP()
                    }
                }) {
                    Text("重新发送")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }

            // 验证按钮
            PrimaryButton(title: "验证", icon: "checkmark.circle.fill") {
                Task {
                    await verifyRegisterOTP()
                }
            }
            .disabled(registerOTP.count != 6)

            // 返回修改邮箱
            Button(action: {
                withAnimation {
                    registerStep = .emailInput
                    registerOTP = ""
                    authManager.resetState()
                }
            }) {
                Text("修改邮箱")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
    }

    /// 注册第三步：密码设置
    private var registerPasswordStep: some View {
        VStack(spacing: 16) {
            // 提示
            StepIndicator(currentStep: 3, totalSteps: 3, title: "设置密码")

            // 重要提示
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(ApocalypseTheme.warning)
                Text("请设置密码以完成注册")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding()
            .background(ApocalypseTheme.warning.opacity(0.1))
            .cornerRadius(8)

            // 密码输入
            CustomSecureField(
                icon: "lock.fill",
                placeholder: "密码（至少6位）",
                text: $registerPassword
            )

            // 确认密码
            CustomSecureField(
                icon: "lock.fill",
                placeholder: "确认密码",
                text: $registerConfirmPassword
            )

            // 密码强度提示
            if !registerPassword.isEmpty {
                let (isValid, message) = authManager.validatePassword(registerPassword)
                if let message = message {
                    HStack {
                        Image(systemName: isValid ? "info.circle" : "exclamationmark.circle")
                        Text(message)
                            .font(.caption)
                    }
                    .foregroundColor(isValid ? ApocalypseTheme.info : ApocalypseTheme.warning)
                }
            }

            // 完成注册按钮
            PrimaryButton(title: "完成注册", icon: "checkmark.seal.fill") {
                Task {
                    await completeRegistration()
                }
            }
            .disabled(!canCompleteRegistration)
        }
    }

    // MARK: - Third Party Section

    /// 第三方登录区域
    private var thirdPartySection: some View {
        VStack(spacing: 20) {
            // 分隔线
            HStack {
                Rectangle()
                    .fill(ApocalypseTheme.textMuted.opacity(0.3))
                    .frame(height: 1)

                Text("或者使用以下方式登录")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .padding(.horizontal, 12)

                Rectangle()
                    .fill(ApocalypseTheme.textMuted.opacity(0.3))
                    .frame(height: 1)
            }

            // 第三方登录按钮
            VStack(spacing: 12) {
                // Google 登录
                ThirdPartyButton(
                    title: "使用 Google 登录",
                    icon: "g.circle.fill",
                    backgroundColor: .white,
                    foregroundColor: .black,
                    action: {
                        Task {
                            await authManager.signInWithGoogle()
                            if authManager.isAuthenticated {
                                showToastMessage("Google 登录成功！")
                            }
                        }
                    }
                )
            }
        }
    }

    // MARK: - Forgot Password Sheet

    /// 找回密码弹窗
    private var forgotPasswordSheet: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 标题
                        Text("找回密码")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .padding(.top)

                        // 根据步骤显示内容
                        switch resetStep {
                        case .emailInput:
                            resetEmailStep
                        case .otpVerification:
                            resetOTPStep
                        case .passwordSetup:
                            resetPasswordStep
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        showForgotPassword = false
                        resetStep = .emailInput
                        resetEmail = ""
                        resetOTP = ""
                        resetNewPassword = ""
                        resetConfirmPassword = ""
                        authManager.resetState()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    /// 重置密码第一步：邮箱输入
    private var resetEmailStep: some View {
        VStack(spacing: 16) {
            StepIndicator(currentStep: 1, totalSteps: 3, title: "输入邮箱")

            CustomTextField(
                icon: "envelope.fill",
                placeholder: "邮箱",
                text: $resetEmail,
                keyboardType: .emailAddress
            )
            .onChange(of: resetEmail) { newValue in
                // 自动清理 mailto: 前缀
                if newValue.lowercased().hasPrefix("mailto:") {
                    resetEmail = String(newValue.dropFirst(7))
                }
            }

            // 邮箱格式验证提示
            if !resetEmail.isEmpty {
                HStack {
                    Image(systemName: authManager.isValidEmail(resetEmail) ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(authManager.isValidEmail(resetEmail) ? .green : .red)
                    Text(authManager.isValidEmail(resetEmail) ? "邮箱格式正确" : "请输入有效的邮箱地址")
                        .font(.caption)
                        .foregroundColor(authManager.isValidEmail(resetEmail) ? .green : .red)
                }
                .padding(.horizontal, 4)
            }

            PrimaryButton(title: "发送验证码", icon: "paperplane.fill") {
                Task {
                    await sendResetOTP()
                }
            }
            .disabled(resetEmail.isEmpty || !authManager.isValidEmail(resetEmail))
        }
    }

    /// 重置密码第二步：验证码验证
    private var resetOTPStep: some View {
        VStack(spacing: 16) {
            StepIndicator(currentStep: 2, totalSteps: 3, title: "验证邮箱")

            Text("验证码已发送至 \(resetEmail)")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            CustomTextField(
                icon: "number",
                placeholder: "6位验证码",
                text: $resetOTP,
                keyboardType: .numberPad
            )
            .onChange(of: resetOTP) { newValue in
                if newValue.count > 6 {
                    resetOTP = String(newValue.prefix(6))
                }
            }

            if countdown > 0 {
                Text("\(countdown)秒后可重发")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            } else {
                Button(action: {
                    Task {
                        await sendResetOTP()
                    }
                }) {
                    Text("重新发送")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }

            PrimaryButton(title: "验证", icon: "checkmark.circle.fill") {
                Task {
                    await verifyResetOTP()
                }
            }
            .disabled(resetOTP.count != 6)

            Button(action: {
                withAnimation {
                    resetStep = .emailInput
                    resetOTP = ""
                    authManager.resetState()
                }
            }) {
                Text("修改邮箱")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
    }

    /// 重置密码第三步：密码设置
    private var resetPasswordStep: some View {
        VStack(spacing: 16) {
            StepIndicator(currentStep: 3, totalSteps: 3, title: "设置新密码")

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "新密码（至少6位）",
                text: $resetNewPassword
            )

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "确认新密码",
                text: $resetConfirmPassword
            )

            if !resetNewPassword.isEmpty {
                let (isValid, message) = authManager.validatePassword(resetNewPassword)
                if let message = message {
                    HStack {
                        Image(systemName: isValid ? "info.circle" : "exclamationmark.circle")
                        Text(message)
                            .font(.caption)
                    }
                    .foregroundColor(isValid ? ApocalypseTheme.info : ApocalypseTheme.warning)
                }
            }

            PrimaryButton(title: "重置密码", icon: "checkmark.seal.fill") {
                Task {
                    await performResetPassword()
                }
            }
            .disabled(!canResetPassword)
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
                Image(systemName: "exclamationmark.circle.fill")
                Text(toastMessage)
                    .font(.subheadline)
            }
            .foregroundColor(.white)
            .padding()
            .background(ApocalypseTheme.danger)
            .cornerRadius(12)
            .shadow(radius: 10)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Actions

    /// 执行登录
    private func performLogin() async {
        await authManager.signIn(email: loginEmail, password: loginPassword)

        if authManager.isAuthenticated {
            showToastMessage("登录成功")
        }
    }

    /// 发送注册验证码
    private func sendRegisterOTP() async {
        await authManager.sendRegisterOTP(email: registerEmail)

        if authManager.otpSent {
            withAnimation {
                registerStep = .otpVerification
            }
            startCountdown()
        }
    }

    /// 验证注册验证码
    private func verifyRegisterOTP() async {
        await authManager.verifyRegisterOTP(email: registerEmail, code: registerOTP)

        // 验证成功后会通过 onChange(of: authManager.otpVerified) 自动跳转到密码设置
        // 如果验证失败，错误信息会通过 authManager.errorMessage 显示
        if !authManager.otpVerified && authManager.errorMessage == nil {
            // 如果没有错误信息但验证失败，显示通用错误
            showToastMessage("验证码错误，请重试")
        }
    }

    /// 完成注册
    private func completeRegistration() async {
        guard registerPassword == registerConfirmPassword else {
            showToastMessage("两次密码输入不一致")
            return
        }

        await authManager.completeRegistration(password: registerPassword)

        if authManager.isAuthenticated {
            showToastMessage("注册成功！")
        }
    }

    /// 发送重置密码验证码
    private func sendResetOTP() async {
        await authManager.sendResetOTP(email: resetEmail)

        if authManager.otpSent {
            withAnimation {
                resetStep = .otpVerification
            }
            startCountdown()
        }
    }

    /// 验证重置密码验证码
    private func verifyResetOTP() async {
        await authManager.verifyResetOTP(email: resetEmail, code: resetOTP)

        // 验证成功后会通过 onChange 自动跳转
    }

    /// 执行密码重置
    private func performResetPassword() async {
        guard resetNewPassword == resetConfirmPassword else {
            showToastMessage("两次密码输入不一致")
            return
        }

        await authManager.resetPassword(newPassword: resetNewPassword)

        if authManager.isAuthenticated {
            showToastMessage("密码重置成功！")
            showForgotPassword = false
        }
    }

    /// 开始倒计时
    private func startCountdown() {
        countdown = 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer?.invalidate()
            }
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

    // MARK: - Computed Properties

    /// 是否可以完成注册
    private var canCompleteRegistration: Bool {
        !registerPassword.isEmpty &&
        !registerConfirmPassword.isEmpty &&
        registerPassword == registerConfirmPassword &&
        registerPassword.count >= 6
    }

    /// 是否可以重置密码
    private var canResetPassword: Bool {
        !resetNewPassword.isEmpty &&
        !resetConfirmPassword.isEmpty &&
        resetNewPassword == resetConfirmPassword &&
        resetNewPassword.count >= 6
    }
}

// MARK: - Supporting Types

/// Tab 枚举
enum AuthTab {
    case login
    case register
}

/// 注册步骤
enum RegisterStep {
    case emailInput
    case otpVerification
    case passwordSetup
}

/// 重置密码步骤
enum ResetStep {
    case emailInput
    case otpVerification
    case passwordSetup
}

// MARK: - Custom Components

/// Tab 按钮
struct TabButton: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    isSelected ?
                    LinearGradient(
                        colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// 步骤指示器
struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(1...totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? ApocalypseTheme.primary : ApocalypseTheme.textMuted.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            Text("第 \(currentStep)/\(totalSteps) 步：\(title)")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(.vertical, 8)
    }
}

/// 自定义文本输入框
struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 24)

            TextField(placeholder, text: $text)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ApocalypseTheme.primary.opacity(0.2), lineWidth: 1)
        )
    }
}

/// 自定义密码输入框
struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @State private var isSecure = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 24)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            } else {
                TextField(placeholder, text: $text)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Button(action: { isSecure.toggle() }) {
                Image(systemName: isSecure ? "eye.slash.fill" : "eye.fill")
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ApocalypseTheme.primary.opacity(0.2), lineWidth: 1)
        )
    }
}

/// 主要操作按钮
struct PrimaryButton: View {
    let title: LocalizedStringKey
    let icon: String
    let action: () -> Void
    @Environment(\.isEnabled) var isEnabled

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)

                Image(systemName: icon)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                isEnabled ?
                LinearGradient(
                    colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
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
            .shadow(color: isEnabled ? ApocalypseTheme.primary.opacity(0.3) : .clear, radius: 10)
        }
        .disabled(!isEnabled)
    }
}

/// 第三方登录按钮
struct ThirdPartyButton: View {
    let title: LocalizedStringKey
    let icon: String
    let backgroundColor: Color
    var foregroundColor: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)

                Text(title)
                    .font(.headline)
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding()
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ApocalypseTheme.textMuted.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    AuthView()
}
