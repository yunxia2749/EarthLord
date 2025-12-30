//
//  RootView.swift
//  EarthLord
//
//  Created by 赵云霞 on 2025/12/24.
//

import SwiftUI

/// 根视图：控制启动页、登录页与主界面的切换
struct RootView: View {
    /// 启动页是否完成
    @State private var splashFinished = false

    /// 认证管理器
    @StateObject private var authManager = AuthManager.shared

    var body: some View {
        ZStack {
            if !splashFinished {
                // 第一步：显示启动页
                SplashView(isFinished: $splashFinished)
                    .transition(.opacity)
            } else if !authManager.isAuthenticated {
                // 第二步：启动页完成后，如果未登录显示认证页
                AuthView()
                    .transition(.opacity)
            } else {
                // 第三步：已登录显示主界面
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: splashFinished)
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
    }
}

#Preview {
    RootView()
}
