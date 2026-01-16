//
//  ScavengeResultView.swift
//  EarthLord
//
//  搜刮结果视图：显示POI搜刮获得的物品
//

import SwiftUI
import CoreLocation

/// 搜刮结果视图
struct ScavengeResultView: View {

    /// POI信息
    let poi: POIData

    /// 获得的物品
    let rewards: [RewardItem]

    /// 确认回调
    let onConfirm: () -> Void

    // MARK: - Animation States

    @State private var showContent = false
    @State private var visibleItemsCount = 0

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 顶部装饰条
            Rectangle()
                .fill(ApocalypseTheme.success)
                .frame(height: 4)

            VStack(spacing: 20) {
                // 成功图标和标题
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(ApocalypseTheme.success.opacity(0.2))
                            .frame(width: 60, height: 60)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(ApocalypseTheme.success)
                            .scaleEffect(showContent ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showContent)
                    }

                    Text("搜刮成功！")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.3).delay(0.2), value: showContent)

                    // POI名称
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

                // 分隔线
                Rectangle()
                    .fill(ApocalypseTheme.textSecondary.opacity(0.2))
                    .frame(height: 1)

                // 物品列表
                VStack(alignment: .leading, spacing: 12) {
                    Text("获得物品")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    VStack(spacing: 8) {
                        ForEach(Array(rewards.enumerated()), id: \.element.itemId) { index, reward in
                            if index < visibleItemsCount {
                                itemRow(reward: reward)
                                    .transition(.asymmetric(
                                        insertion: .scale.combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 确认按钮
                Button(action: onConfirm) {
                    Text("确认")
                        .font(.system(size: 16, weight: .bold))
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

    // MARK: - Item Row

    private func itemRow(reward: RewardItem) -> some View {
        HStack(spacing: 12) {
            // 物品图标
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(ApocalypseTheme.warning.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: itemIcon(for: reward.itemId))
                    .font(.system(size: 20))
                    .foregroundColor(ApocalypseTheme.warning)
            }

            // 物品名称
            Text(itemName(for: reward.itemId))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 数量
            Text("x\(reward.quantity)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ApocalypseTheme.success)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ApocalypseTheme.background)
        )
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

    // MARK: - Item Helpers

    private func itemIcon(for itemId: String) -> String {
        switch itemId {
        case "item_water_bottle": return "drop.fill"
        case "item_canned_food": return "takeoutbag.and.cup.and.straw.fill"
        case "item_bandage": return "bandage.fill"
        case "item_medicine": return "pills.fill"
        case "item_flashlight": return "flashlight.on.fill"
        case "item_first_aid_kit": return "cross.case.fill"
        case "item_wood": return "tree.fill"
        case "item_rope": return "lasso"
        case "item_scrap_metal": return "wrench.and.screwdriver.fill"
        case "item_antibiotics": return "pill.fill"
        default: return "cube.fill"
        }
    }

    private func itemName(for itemId: String) -> String {
        switch itemId {
        case "item_water_bottle": return "矿泉水"
        case "item_canned_food": return "罐头食品"
        case "item_bandage": return "绷带"
        case "item_medicine": return "药品"
        case "item_flashlight": return "手电筒"
        case "item_first_aid_kit": return "急救包"
        case "item_wood": return "木材"
        case "item_rope": return "绳子"
        case "item_scrap_metal": return "废金属"
        case "item_antibiotics": return "抗生素"
        default: return "未知物品"
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        ScavengeResultView(
            poi: POIData(
                id: "test",
                name: "废弃超市",
                type: .supermarket,
                coordinate: .init(latitude: 0, longitude: 0),
                discoveryStatus: .discovered,
                searchStatus: .hasLoot,
                dangerLevel: 2,
                description: "测试"
            ),
            rewards: [
                RewardItem(itemId: "item_water_bottle", quantity: 2),
                RewardItem(itemId: "item_canned_food", quantity: 1),
                RewardItem(itemId: "item_bandage", quantity: 1)
            ],
            onConfirm: { print("确认") }
        )
    }
}
