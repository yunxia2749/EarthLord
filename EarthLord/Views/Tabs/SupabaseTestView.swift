//
//  SupabaseTestView.swift
//  EarthLord
//
//  Created by 赵云霞 on 2025/12/24.
//

import SwiftUI
import Supabase

// 全局 Supabase 客户端实例
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://kmfuiegtfpqvcfkfzfzw.supabase.co")!,
    supabaseKey: "sb_publishable_8TcGR_ajCs6TwukKADIzcQ_1OUMhERM"
)

struct SupabaseTestView: View {
    // 连接状态
    @State private var isConnected: Bool? = nil

    // 调试日志
    @State private var debugLog: String = "点击按钮开始测试连接..."

    // 是否正在测试
    @State private var isTesting: Bool = false

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // 标题
                    Text("Supabase 连接测试")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .padding(.top, 20)

                    // 状态图标
                    ZStack {
                        Circle()
                            .fill(statusBackgroundColor)
                            .frame(width: 100, height: 100)
                            .shadow(color: statusBackgroundColor.opacity(0.5), radius: 20)

                        Image(systemName: statusIcon)
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 10)

                    // 调试日志文本框
                    VStack(alignment: .leading, spacing: 8) {
                        Text("调试日志")
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        ScrollView {
                            Text(debugLog)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(ApocalypseTheme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                        .frame(height: 200)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // 测试按钮
                    Button(action: {
                        testConnection()
                    }) {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isTesting ? "测试中..." : "测试连接")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 10)
                    }
                    .disabled(isTesting)
                    .padding(.horizontal)

                    // 连接信息
                    VStack(alignment: .leading, spacing: 8) {
                        Text("连接信息")
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("URL:")
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                                Text("https://kmfuiegtfpqvcfkfzfzw.supabase.co")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(ApocalypseTheme.info)
                            }

                            HStack {
                                Text("Key:")
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                                Text("sb_publishable_***")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(ApocalypseTheme.textMuted)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    Spacer()
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Supabase 测试")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 计算属性

    /// 状态图标
    private var statusIcon: String {
        if isTesting {
            return "ellipsis.circle.fill"
        }

        guard let isConnected = isConnected else {
            return "questionmark.circle.fill"
        }

        return isConnected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    /// 状态背景色
    private var statusBackgroundColor: Color {
        if isTesting {
            return ApocalypseTheme.info
        }

        guard let isConnected = isConnected else {
            return ApocalypseTheme.textMuted
        }

        return isConnected ? ApocalypseTheme.success : ApocalypseTheme.danger
    }

    // MARK: - 测试方法

    /// 测试 Supabase 连接
    private func testConnection() {
        isTesting = true
        isConnected = nil
        debugLog = "开始测试连接...\n\n"

        Task {
            do {
                debugLog += "正在连接到 Supabase...\n"
                debugLog += "URL: https://kmfuiegtfpqvcfkfzfzw.supabase.co\n\n"

                // 故意查询一个不存在的表来测试连接
                debugLog += "发送测试请求...\n"
                let _: [String: String] = try await supabase
                    .from("non_existent_table")
                    .select()
                    .execute()
                    .value

                // 如果没有抛出错误（理论上不应该到这里）
                updateResult(success: true, message: "✅ 连接成功（意外收到响应）")

            } catch {
                // 分析错误信息
                let errorMessage = error.localizedDescription
                debugLog += "收到响应错误：\n\(errorMessage)\n\n"

                // 判断连接是否成功（通过错误类型）
                if errorMessage.contains("PGRST") ||
                   errorMessage.contains("Could not find the table") ||
                   errorMessage.contains("relation") && errorMessage.contains("does not exist") {
                    // 这些错误说明已经连接到服务器，只是表不存在
                    updateResult(
                        success: true,
                        message: "✅ 连接成功（服务器已响应）\n\n说明：收到 PostgreSQL 错误响应，表示已成功连接到 Supabase 服务器。"
                    )
                } else if errorMessage.contains("hostname") ||
                          errorMessage.contains("URL") ||
                          errorMessage.contains("NSURLErrorDomain") {
                    // 网络或 URL 错误
                    updateResult(
                        success: false,
                        message: "❌ 连接失败：URL 错误或无网络\n\n错误详情：\n\(errorMessage)"
                    )
                } else {
                    // 其他错误
                    updateResult(
                        success: false,
                        message: "❌ 连接失败\n\n错误详情：\n\(errorMessage)"
                    )
                }
            }
        }
    }

    /// 更新测试结果
    @MainActor
    private func updateResult(success: Bool, message: String) {
        isConnected = success
        debugLog += "\n" + message
        isTesting = false
    }
}

#Preview {
    NavigationStack {
        SupabaseTestView()
    }
}
