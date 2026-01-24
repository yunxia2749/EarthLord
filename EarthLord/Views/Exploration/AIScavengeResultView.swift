//
//  AIScavengeResultView.swift
//  EarthLord
//
//  AI 物品搜刮结果视图：显示 AI 生成的物品名称、稀有度和故事
//

import SwiftUI
import CoreLocation

/// AI 搜刮结果视图
struct AIScavengeResultView: View {

    /// POI 信息
    let poi: POIData

    /// 获得的 AI 物品
    let rewards: [ScavengeRewardItem]

    /// 确认回调
    let onConfirm: () -> Void

    // MARK: - Animation States

    @State private var showContent = false
    @State private var visibleItemsCount = 0
    @State private var expandedItemIds: Set<String> = []  // 记录展开的物品ID

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 顶部装饰条
            Rectangle()
                .fill(ApocalypseTheme.success)
                .frame(height: 4)

            VStack(spacing: 20) {
                // 成功图标和标题
                headerView

                // 分隔线
                Rectangle()
                    .fill(ApocalypseTheme.textSecondary.opacity(0.2))
                    .frame(height: 1)

                // 物品列表
                itemsListView

                // 确认按钮
                confirmButton
            }
            .padding(24)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ApocalypseTheme.success.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 20)
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.success.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: "suitcase.fill")
                    .font(.system(size: 40))
                    .foregroundColor(ApocalypseTheme.success)
                    .scaleEffect(showContent ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showContent)
            }

            HStack(spacing: 6) {
                Text("🎉")
                Text("搜刮成功！")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }
            .opacity(showContent ? 1 : 0)
            .animation(.easeOut(duration: 0.3).delay(0.2), value: showContent)

            // POI 名称
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 12))
                Text(poi.name)
                    .font(.system(size: 14))
            }
            .foregroundColor(ApocalypseTheme.textSecondary)
            .opacity(showContent ? 1 : 0)
            .animation(.easeOut(duration: 0.3).delay(0.3), value: showContent)
        }
    }

    // MARK: - Items List View

    private var itemsListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🎁 获得物品")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Spacer()
                Text("\(rewards.count) 件")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(rewards.enumerated()), id: \.element.id) { index, reward in
                        if index < visibleItemsCount {
                            aiItemRow(reward: reward)
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                }
            }
            .frame(maxHeight: 300)  // 限制最大高度，支持滚动
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - AI Item Row

    private func aiItemRow(reward: ScavengeRewardItem) -> some View {
        let isExpanded = expandedItemIds.contains(reward.id)

        return VStack(spacing: 0) {
            // 主行（可点击）
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if isExpanded {
                        expandedItemIds.remove(reward.id)
                    } else {
                        expandedItemIds.insert(reward.id)
                    }
                }
            }) {
                HStack(spacing: 12) {
                    // 物品图标（根据分类）
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(rarityColor(reward.rarity).opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: categoryIcon(reward.category))
                            .font(.system(size: 20))
                            .foregroundColor(rarityColor(reward.rarity))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        // 物品名称和稀有度标签
                        HStack(spacing: 6) {
                            Text(reward.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(rarityColor(reward.rarity))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Text(rarityDisplayName(reward.rarity))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(rarityColor(reward.rarity))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(rarityColor(reward.rarity).opacity(0.2))
                                )
                        }

                        // 故事描述（支持展开/收起）
                        HStack(spacing: 4) {
                            Image(systemName: "text.quote")
                                .font(.system(size: 10))
                                .foregroundColor(ApocalypseTheme.textMuted)
                            Text(reward.story)
                                .font(.system(size: 12))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                                .lineLimit(isExpanded ? nil : 1)
                                .multilineTextAlignment(.leading)

                            if !isExpanded {
                                Text("...")
                                    .font(.system(size: 12))
                                    .foregroundColor(ApocalypseTheme.textMuted)
                            }
                        }

                        // 展开/收起提示
                        if reward.story.count > 30 {
                            HStack(spacing: 4) {
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10))
                                Text(isExpanded ? "收起" : "展开故事")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(rarityColor(reward.rarity).opacity(0.7))
                            .padding(.top, 2)
                        }
                    }

                    Spacer()

                    VStack(spacing: 4) {
                        // 数量
                        Text("x\(reward.quantity)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        // 绿色勾选
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(ApocalypseTheme.success)
                    }
                }
                .padding(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ApocalypseTheme.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(rarityColor(reward.rarity).opacity(0.3), lineWidth: isExpanded ? 2 : 1)
        )
    }

    // MARK: - Confirm Button

    private var confirmButton: some View {
        VStack(spacing: 12) {
            // 已添加到背包提示
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.success)
                Text("已添加到背包")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .opacity(visibleItemsCount == rewards.count ? 1 : 0)
            .animation(.easeOut(duration: 0.3), value: visibleItemsCount)

            // 确认按钮
            Button(action: onConfirm) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                    Text("确认收下")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ApocalypseTheme.success)
                )
            }
            .opacity(visibleItemsCount == rewards.count ? 1 : 0.5)
            .disabled(visibleItemsCount < rewards.count)
            .animation(.easeOut(duration: 0.3), value: visibleItemsCount)
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        // 显示主内容
        withAnimation {
            showContent = true
        }

        // 依次显示物品
        for index in 0..<rewards.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(index) * 0.2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    visibleItemsCount = index + 1
                }
            }
        }
    }

    // MARK: - Helper Methods

    /// 稀有度对应颜色
    private func rarityColor(_ rarity: ItemRarity) -> Color {
        switch rarity {
        case .common:
            return Color.white
        case .uncommon:
            return Color.green
        case .rare:
            return Color.blue
        case .epic:
            return Color.purple
        case .legendary:
            return Color.orange
        }
    }

    /// 稀有度中文名称
    private func rarityDisplayName(_ rarity: ItemRarity) -> String {
        switch rarity {
        case .common:
            return "普通"
        case .uncommon:
            return "优秀"
        case .rare:
            return "稀有"
        case .epic:
            return "史诗"
        case .legendary:
            return "传说"
        }
    }

    /// 分类对应图标
    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "医疗": return "cross.case.fill"
        case "食物": return "fork.knife"
        case "工具": return "wrench.and.screwdriver.fill"
        case "武器": return "bolt.fill"
        case "材料": return "cube.fill"
        default: return "shippingbox.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        AIScavengeResultView(
            poi: POIData(
                id: "test",
                name: "协和医院急诊室",
                type: .hospital,
                coordinate: .init(latitude: 0, longitude: 0),
                discoveryStatus: .discovered,
                searchStatus: .hasLoot,
                dangerLevel: 4,
                description: "测试"
            ),
            rewards: [
                ScavengeRewardItem(from: AIGeneratedItem(
                    name: "「最后的希望」应急包",
                    category: "医疗",
                    rarity: "epic",
                    story: "这个急救包上贴着一张便签：'给值夜班的自己准备的'。便签已经褪色，主人再也没能用上它..."
                )),
                ScavengeRewardItem(from: AIGeneratedItem(
                    name: "护士站的咖啡罐头",
                    category: "食物",
                    rarity: "rare",
                    story: "罐头上写着'夜班续命神器'。末日来临时，护士们大概正在喝着咖啡讨论患者病情。"
                )),
                ScavengeRewardItem(from: AIGeneratedItem(
                    name: "急诊科常备止痛片",
                    category: "医疗",
                    rarity: "uncommon",
                    story: "瓶身上还贴着患者的名字，只是这位'李先生'恐怕再也不需要止痛药了。"
                ))
            ],
            onConfirm: { print("确认") }
        )
    }
}
