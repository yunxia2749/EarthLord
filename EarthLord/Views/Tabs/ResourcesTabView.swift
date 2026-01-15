//
//  ResourcesTabView.swift
//  EarthLord
//
//  资源模块主入口页面
//  包含 POI、背包、已购、领地、交易五个分段
//

import SwiftUI

struct ResourcesTabView: View {

    // MARK: - State Properties

    /// 当前选中的分段
    @State private var selectedSegment: ResourceSegment = .poi

    /// 交易开关状态（假数据）
    @State private var isTradingEnabled: Bool = false

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 顶部工具栏（交易开关）
                    topToolbar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    // 分段选择器
                    segmentPicker
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)

                    // 内容区域
                    contentView
                }
            }
            .navigationTitle("资源")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Top Toolbar

    /// 顶部工具栏
    private var topToolbar: some View {
        HStack(spacing: 12) {
            // 交易状态图标
            Image(systemName: isTradingEnabled ? "arrow.left.arrow.right.circle.fill" : "arrow.left.arrow.right.circle")
                .font(.system(size: 20))
                .foregroundColor(isTradingEnabled ? ApocalypseTheme.success : ApocalypseTheme.textMuted)

            // 交易开关
            VStack(alignment: .leading, spacing: 2) {
                Text("交易模式")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(isTradingEnabled ? "已开启" : "已关闭")
                    .font(.system(size: 12))
                    .foregroundColor(isTradingEnabled ? ApocalypseTheme.success : ApocalypseTheme.textMuted)
            }

            Spacer()

            // Toggle 开关
            Toggle("", isOn: $isTradingEnabled)
                .labelsHidden()
                .tint(ApocalypseTheme.success)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isTradingEnabled ? ApocalypseTheme.success.opacity(0.3) : ApocalypseTheme.textMuted.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Segment Picker

    /// 分段选择器
    private var segmentPicker: some View {
        Picker("选择资源类型", selection: $selectedSegment) {
            ForEach(ResourceSegment.allCases) { segment in
                Text(segment.rawValue).tag(segment)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Content View

    /// 内容区域
    private var contentView: some View {
        Group {
            switch selectedSegment {
            case .poi:
                POIListView()

            case .backpack:
                BackpackView()

            case .purchased:
                placeholderView(
                    icon: "cart.fill",
                    title: "已购物品",
                    message: "功能开发中"
                )

            case .territory:
                placeholderView(
                    icon: "flag.fill",
                    title: "领地资源",
                    message: "功能开发中"
                )

            case .trading:
                placeholderView(
                    icon: "arrow.left.arrow.right",
                    title: "交易市场",
                    message: "功能开发中"
                )
            }
        }
    }

    /// 占位视图
    private func placeholderView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            // 图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: icon)
                    .font(.system(size: 50))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 标题
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 消息
            Text(message)
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Resource Segment

/// 资源分段枚举
enum ResourceSegment: String, CaseIterable, Identifiable {
    case poi = "POI"
    case backpack = "背包"
    case purchased = "已购"
    case territory = "领地"
    case trading = "交易"

    var id: String { rawValue }
}

// MARK: - Preview

#Preview {
    ResourcesTabView()
}
