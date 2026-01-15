//
//  ExplorationResultView.swift
//  EarthLord
//
//  探索结果页面
//  显示探索完成后的统计数据和获得的物品
//

import SwiftUI

struct ExplorationResultView: View {

    // MARK: - Properties

    /// 探索结果数据
    let result: ExplorationResult?

    /// 错误信息（可选，如果有则显示错误状态）
    let errorMessage: String?

    /// 关闭页面
    @Environment(\.dismiss) var dismiss

    /// 初始化（成功状态）
    init(result: ExplorationResult) {
        self.result = result
        self.errorMessage = nil
    }

    /// 初始化（错误状态）
    init(errorMessage: String) {
        self.result = nil
        self.errorMessage = errorMessage
    }

    // MARK: - Animation States

    /// 动画用的行走距离
    @State private var animatedWalkDistance: Double = 0

    /// 动画用的经验值
    @State private var animatedExperience: Int = 0

    /// 物品显示状态
    @State private var visibleItemsCount: Int = 0

    /// 对勾图标缩放
    @State private var checkmarkScale: CGFloat = 0

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            if let errorMessage = errorMessage {
                // 错误状态
                errorStateView(message: errorMessage)
            } else if let result = result {
                // 成功状态
                successStateView(result: result)
            }
        }
        .onAppear {
            if let result = result {
                startAnimations(result: result)
            }
        }
    }

    // MARK: - Success State View

    /// 成功状态视图
    private func successStateView(result: ExplorationResult) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // 成就标题
                achievementHeader
                    .padding(.top, 40)

                // 统计数据卡片
                statsSection(result: result)
                    .padding(.horizontal, 16)

                // 奖励物品卡片
                rewardsSection(result: result)
                    .padding(.horizontal, 16)

                // 经验值显示
                experienceSection(result: result)
                    .padding(.horizontal, 16)

                // 确认按钮
                confirmButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Error State View

    /// 错误状态视图
    private func errorStateView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // 错误图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.danger.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.danger)
            }

            // 错误标题
            Text("探索失败")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 错误信息
            Text(message)
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // 重试按钮
            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .semibold))

                    Text("返回重试")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(ApocalypseTheme.primary)
                )
                .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .padding(.top, 20)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Animation Methods

    /// 启动所有动画
    private func startAnimations(result: ExplorationResult) {
        // 统计数字动画
        withAnimation(.easeOut(duration: 1.0)) {
            animatedWalkDistance = result.stats.walkDistanceThisTime
        }

        // 经验值动画（稍晚启动）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedExperience = result.experienceGained
            }
        }

        // 物品逐个出现
        for index in 0..<result.obtainedItems.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.2) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    visibleItemsCount = index + 1
                }
            }
        }

        // 对勾图标弹跳动画
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(result.obtainedItems.count) * 0.2 + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                checkmarkScale = 1.0
            }
        }
    }

    // MARK: - Achievement Header

    /// 成就标题区域
    private var achievementHeader: some View {
        VStack(spacing: 20) {
            // 大图标（带动画效果）
            ZStack {
                // 外圈光晕
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                ApocalypseTheme.success.opacity(0.3),
                                ApocalypseTheme.success.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                // 图标背景
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                ApocalypseTheme.success,
                                ApocalypseTheme.success.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: ApocalypseTheme.success.opacity(0.4), radius: 20, x: 0, y: 10)

                // 地图图标
                Image(systemName: "map.fill")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(.white)
            }

            // 标题文字
            VStack(spacing: 8) {
                Text("探索完成！")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("你在末日世界中又前进了一步")
                    .font(.system(size: 15))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
    }

    // MARK: - Stats Section

    /// 统计数据卡片
    private func statsSection(result: ExplorationResult) -> some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 18))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("探索统计")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }

            // 行走距离
            StatRow(
                icon: "figure.walk",
                title: "行走距离",
                thisTime: MockExplorationData.formatDistance(animatedWalkDistance),
                total: MockExplorationData.formatDistance(result.stats.walkDistanceTotal),
                color: ApocalypseTheme.info
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 探索时长
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(ApocalypseTheme.warning.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: "clock.fill")
                        .font(.system(size: 18))
                        .foregroundColor(ApocalypseTheme.warning)
                }

                // 标题
                Text("探索时长")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                // 时长
                Text(MockExplorationData.formatDuration(result.stats.explorationDuration))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ApocalypseTheme.primary.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Rewards Section

    /// 奖励物品卡片
    private func rewardsSection(result: ExplorationResult) -> some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "gift.fill")
                    .font(.system(size: 18))
                    .foregroundColor(ApocalypseTheme.warning)

                Text("获得物品")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }

            // 物品列表
            if result.obtainedItems.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text("未获得任何物品")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(result.obtainedItems.enumerated()), id: \.element.id) { index, obtainedItem in
                        if let definition = MockExplorationData.getItemDefinition(by: obtainedItem.itemId) {
                            if index < visibleItemsCount {
                                RewardItemRow(
                                    obtainedItem: obtainedItem,
                                    definition: definition,
                                    checkmarkScale: index == visibleItemsCount - 1 ? checkmarkScale : 1.0
                                )
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .opacity
                                ))
                            }
                        }
                    }
                }

                // 底部提示（根据实际添加结果显示）
                if visibleItemsCount == result.obtainedItems.count && checkmarkScale > 0 {
                    HStack(spacing: 8) {
                        if result.rewardsAddedSuccessfully {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(ApocalypseTheme.success)

                            Text("已添加到背包")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(ApocalypseTheme.danger)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("添加到背包失败")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(ApocalypseTheme.danger)
                                if let errorMsg = result.rewardsErrorMessage {
                                    Text(errorMsg)
                                        .font(.system(size: 11))
                                        .foregroundColor(ApocalypseTheme.textSecondary)
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(.top, 8)
                    .transition(.opacity)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ApocalypseTheme.warning.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Experience Section

    /// 经验值区域
    private func experienceSection(result: ExplorationResult) -> some View {
        HStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.purple,
                                Color.purple.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Image(systemName: "star.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }

            // 文字
            VStack(alignment: .leading, spacing: 4) {
                Text("获得经验")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("+\(animatedExperience) EXP")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Spacer()

            // 装饰性光效
            Image(systemName: "sparkles")
                .font(.system(size: 30))
                .foregroundColor(Color.purple.opacity(0.6))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Confirm Button

    /// 确认按钮
    private var confirmButton: some View {
        Button(action: {
            dismiss()
        }) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))

                Text("确认")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                ApocalypseTheme.primary,
                                ApocalypseTheme.primaryDark
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 10, x: 0, y: 5)
        }
    }
}

// MARK: - Stat Row

/// 统计数据行（已移除排名）
struct StatRow: View {
    let icon: String
    let title: String
    let thisTime: String
    let total: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }

            // 标题
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            // 数据
            HStack(spacing: 12) {
                // 本次
                VStack(alignment: .trailing, spacing: 2) {
                    Text("本次")
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text(thisTime)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                // 累计
                VStack(alignment: .trailing, spacing: 2) {
                    Text("累计")
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text(total)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
            }
        }
    }
}

// MARK: - Reward Item Row

/// 奖励物品行
struct RewardItemRow: View {
    let obtainedItem: ObtainedItem
    let definition: ItemDefinition
    var checkmarkScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 14) {
            // 物品图标
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: definition.category.iconName)
                    .font(.system(size: 18))
                    .foregroundColor(categoryColor)
            }

            // 物品信息
            VStack(alignment: .leading, spacing: 4) {
                Text(definition.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 8) {
                    // 数量
                    Text("x\(obtainedItem.quantity)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    // 来源
                    Text("来自: \(obtainedItem.source)")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }

            Spacer()

            // 绿色对勾（带弹跳动画）
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(ApocalypseTheme.success)
                .scaleEffect(checkmarkScale)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ApocalypseTheme.background)
        )
    }

    /// 分类对应的颜色
    private var categoryColor: Color {
        switch definition.category {
        case .water:
            return .blue
        case .food:
            return .green
        case .medical:
            return .red
        case .material:
            return .gray
        case .tool:
            return .orange
        case .weapon:
            return .purple
        case .clothing:
            return .cyan
        case .misc:
            return .brown
        }
    }
}

// MARK: - Preview

#Preview {
    ExplorationResultView(result: MockExplorationData.mockExplorationResult)
}
