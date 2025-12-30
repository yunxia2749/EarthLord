//
//  EarthLordApp.swift
//  EarthLord
//
//  Created by 赵云霞 on 2025/12/24.
//

import SwiftUI

@main
struct EarthLordApp: App {

    init() {
        // 配置 Google Sign-In
        print("🚀 [App] 应用启动，配置第三方登录")
        GoogleSignInManager.shared.configure()
        print("✅ [App] 第三方登录配置完成")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    // 处理 Google Sign-In 的 URL 回调
                    print("🔗 [App] 收到URL回调: \(url.absoluteString)")
                    let handled = GoogleSignInManager.shared.handleURL(url)
                    if handled {
                        print("✅ [App] Google Sign-In URL处理成功")
                    } else {
                        print("⚠️ [App] URL未被处理: \(url.absoluteString)")
                    }
                }
        }
    }
}
