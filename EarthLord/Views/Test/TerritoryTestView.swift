//
//  TerritoryTestView.swift
//  EarthLord
//
//  圈地测试界面：实时显示圈地模块的调试日志
//

import SwiftUI

struct TerritoryTestView: View {

    // MARK: - Dependencies

    /// 定位管理器（监听追踪状态）
    @EnvironmentObject var locationManager: LocationManager

    /// 日志管理器（监听日志更新）
    @ObservedObject var logger = TerritoryLogger.shared

    // MARK: - Body

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // 顶部标题
                    Text("圈地功能测试")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 20)

                    // 状态指示器（大图标）
                    statusIndicator

                    // 调试日志区域
                    VStack(alignment: .leading, spacing: 12) {
                        Text("调试日志")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        logContentView
                    }

                    // 操作按钮
                    actionButtons

                    // 追踪信息
                    trackingInfoCard

                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("圈地测试")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Subviews

    /// 状态指示器（大图标）
    private var statusIndicator: some View {
        ZStack {
            // 背景光晕
            Circle()
                .fill(
                    locationManager.isTracking ?
                    ApocalypseTheme.success.opacity(0.3) :
                    Color.gray.opacity(0.3)
                )
                .frame(width: 120, height: 120)
                .blur(radius: 20)

            // 主圆圈
            Circle()
                .fill(
                    locationManager.isTracking ?
                    ApocalypseTheme.success :
                    Color.gray
                )
                .frame(width: 100, height: 100)

            // 图标
            Image(systemName: locationManager.isTracking ? "figure.walk.circle.fill" : "pause.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.white)
        }
        .padding(.vertical, 20)
    }

    /// 日志内容视图
    private var logContentView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if logger.logs.isEmpty {
                        // 空状态
                        Text("暂无日志数据...")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(ApocalypseTheme.textMuted)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else {
                        // 显示每条日志（带颜色）
                        ForEach(logger.logs) { log in
                            LogEntryRow(entry: log)
                        }
                        .id("logBottom")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 300)
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
            .onChange(of: logger.logs.count) { _ in
                withAnimation {
                    proxy.scrollTo("logBottom", anchor: .bottom)
                }
            }
        }
    }

    /// 操作按钮
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 导出日志按钮
            if #available(iOS 16.0, *) {
                ShareLink(item: logger.export()) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("导出日志")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            } else {
                Button(action: shareLog) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("导出日志")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }

            // 清空日志按钮
            Button(action: {
                logger.clear()
            }) {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("清空日志")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(ApocalypseTheme.danger.opacity(0.2))
                .foregroundColor(ApocalypseTheme.danger)
                .cornerRadius(12)
            }
        }
    }

    /// iOS 15 的分享方法
    private func shareLog() {
        let activityVC = UIActivityViewController(
            activityItems: [logger.export()],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    /// 追踪信息卡片
    private var trackingInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("追踪信息")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            VStack(spacing: 12) {
                InfoRow(label: "状态", value: locationManager.isTracking ? "追踪中" : "未追踪")
                InfoRow(label: "记录点数", value: "\(locationManager.pathCoordinates.count) 个")
                InfoRow(label: "闭环状态", value: locationManager.isPathClosed ? "已闭环" : "未闭环")
            }
            .padding()
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
        }
    }
}

// MARK: - Supporting Views

/// 日志条目行
struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 时间戳
            Text(timeString)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)

            // 类型标签
            Text("[\(entry.type.rawValue)]")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(entry.type.color)
                .fontWeight(.bold)

            // 消息内容
            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: entry.timestamp)
    }
}

/// 信息行
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }
}

#Preview {
    NavigationView {
        TerritoryTestView()
            .environmentObject(LocationManager())
    }
}
