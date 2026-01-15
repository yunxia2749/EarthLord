//
//  POIDetailView.swift
//  EarthLord
//
//  POI 详情页面
//  显示 POI 的详细信息、状态和操作按钮
//

import SwiftUI
import CoreLocation

struct POIDetailView: View {

    // MARK: - Properties

    /// POI 数据
    let poi: POIData

    /// 显示探索结果页面的状态
    @State private var showExplorationResult = false

    /// 模拟的距离（米）
    private let mockDistance: Double = 350

    /// 模拟的来源
    private let source: String = "地图数据"

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // 顶部大图区域
                    headerSection

                    // 信息区域和操作按钮
                    VStack(spacing: 20) {
                        // 信息卡片
                        infoSection
                            .padding(.horizontal, 16)
                            .padding(.top, 24)

                        // 描述区域
                        descriptionSection
                            .padding(.horizontal, 16)

                        // 操作按钮区域
                        actionButtonsSection
                            .padding(.horizontal, 16)
                            .padding(.bottom, 30)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showExplorationResult) {
            // 探索结果页面
            ExplorationResultView(result: MockExplorationData.mockExplorationResult)
        }
    }

    // MARK: - Header Section

    /// 顶部大图区域
    private var headerSection: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 渐变背景
                LinearGradient(
                    colors: [poiGradientColors.0, poiGradientColors.1],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: geometry.size.height)

                // 中间大图标
                VStack {
                    Spacer()

                    Image(systemName: poi.type.iconName)
                        .font(.system(size: 80, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

                    Spacer()
                    Spacer()
                }

                // 底部半透明遮罩
                VStack(spacing: 0) {
                    Spacer()

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                    .overlay(
                        VStack(alignment: .leading, spacing: 6) {
                            Spacer()

                            // POI 名称
                            Text(poi.name)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)

                            // POI 类型
                            HStack(spacing: 8) {
                                Image(systemName: poi.type.iconName)
                                    .font(.system(size: 14))

                                Text(poi.type.displayName)
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    )
                }
            }
        }
        .frame(height: UIScreen.main.bounds.height * 0.35)
    }

    /// POI 类型对应的渐变颜色
    private var poiGradientColors: (Color, Color) {
        switch poi.type {
        case .supermarket:
            return (Color.green, Color.green.opacity(0.6))
        case .hospital:
            return (Color.red, Color.red.opacity(0.6))
        case .gasStation:
            return (Color.orange, Color.orange.opacity(0.6))
        case .pharmacy:
            return (Color.purple, Color.purple.opacity(0.6))
        case .factory:
            return (Color.gray, Color.gray.opacity(0.6))
        case .warehouse:
            return (Color.brown, Color.brown.opacity(0.6))
        case .residence:
            return (Color.cyan, Color.cyan.opacity(0.6))
        case .policeStation:
            return (Color.blue, Color.blue.opacity(0.6))
        }
    }

    // MARK: - Info Section

    /// 信息卡片区域
    private var infoSection: some View {
        VStack(spacing: 16) {
            // 距离和物资状态（第一行）
            HStack(spacing: 16) {
                // 距离信息
                InfoCard(
                    icon: "location.fill",
                    title: "距离",
                    value: formatDistance(mockDistance),
                    color: ApocalypseTheme.info
                )

                // 物资状态
                InfoCard(
                    icon: lootStatusIcon,
                    title: "物资状态",
                    value: lootStatusText,
                    color: lootStatusColor
                )
            }

            // 危险等级和来源（第二行）
            HStack(spacing: 16) {
                // 危险等级
                InfoCard(
                    icon: "exclamationmark.triangle.fill",
                    title: "危险等级",
                    value: dangerLevelText,
                    color: dangerLevelColor
                )

                // 来源
                InfoCard(
                    icon: "map.fill",
                    title: "来源",
                    value: source,
                    color: ApocalypseTheme.textMuted
                )
            }
        }
    }

    /// 格式化距离
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    /// 物资状态图标
    private var lootStatusIcon: String {
        switch poi.searchStatus {
        case .hasLoot:
            return "shippingbox.fill"
        case .empty:
            return "shippingbox"
        case .notSearched:
            return "questionmark.square.fill"
        }
    }

    /// 物资状态文字
    private var lootStatusText: String {
        switch poi.searchStatus {
        case .hasLoot:
            return "有物资"
        case .empty:
            return "已清空"
        case .notSearched:
            return "未搜索"
        }
    }

    /// 物资状态颜色
    private var lootStatusColor: Color {
        switch poi.searchStatus {
        case .hasLoot:
            return ApocalypseTheme.success
        case .empty:
            return ApocalypseTheme.textMuted
        case .notSearched:
            return ApocalypseTheme.warning
        }
    }

    /// 危险等级文字
    private var dangerLevelText: String {
        switch poi.dangerLevel {
        case 1:
            return "安全"
        case 2:
            return "低危"
        case 3:
            return "中危"
        case 4:
            return "高危"
        case 5:
            return "极危"
        default:
            return "未知"
        }
    }

    /// 危险等级颜色
    private var dangerLevelColor: Color {
        switch poi.dangerLevel {
        case 1:
            return ApocalypseTheme.success
        case 2:
            return ApocalypseTheme.info
        case 3:
            return ApocalypseTheme.warning
        case 4, 5:
            return ApocalypseTheme.danger
        default:
            return ApocalypseTheme.textMuted
        }
    }

    // MARK: - Description Section

    /// 描述区域
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("地点描述")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(poi.description)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - Action Buttons Section

    /// 操作按钮区域
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // 主按钮：搜寻此POI
            Button(action: {
                if poi.searchStatus != .empty {
                    showExplorationResult = true
                    print("开始搜寻 POI: \(poi.name)")
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: poi.searchStatus == .empty ? "xmark.circle.fill" : "magnifyingglass.circle.fill")
                        .font(.system(size: 20, weight: .semibold))

                    Text(poi.searchStatus == .empty ? "此地点已被搜空" : "搜寻此 POI")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Group {
                        if poi.searchStatus == .empty {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(ApocalypseTheme.textMuted)
                        } else {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.6, blue: 0.2),
                                            Color(red: 1.0, green: 0.4, blue: 0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }
                )
                .shadow(color: poi.searchStatus == .empty ? .clear : Color.orange.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(poi.searchStatus == .empty)

            // 两个小按钮并排
            HStack(spacing: 12) {
                // 标记已发现
                SecondaryActionButton(
                    icon: "eye.fill",
                    title: "标记已发现",
                    color: ApocalypseTheme.info
                ) {
                    print("标记 \(poi.name) 为已发现")
                }

                // 标记无物资
                SecondaryActionButton(
                    icon: "shippingbox",
                    title: "标记无物资",
                    color: ApocalypseTheme.textMuted
                ) {
                    print("标记 \(poi.name) 为无物资")
                }
            }
        }
    }
}

// MARK: - Info Card

/// 信息卡片
struct InfoCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            // 图标
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }

            // 标题
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ApocalypseTheme.textMuted)

            // 数值
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Secondary Action Button

/// 次要操作按钮
struct SecondaryActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(ApocalypseTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.5), lineWidth: 1.5)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        POIDetailView(poi: MockExplorationData.mockPOIs[0])
    }
}
