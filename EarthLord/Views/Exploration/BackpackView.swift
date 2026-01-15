//
//  BackpackView.swift
//  EarthLord
//
//  背包管理页面
//  显示玩家的背包物品、容量状态、搜索筛选功能
//

import SwiftUI

struct BackpackView: View {

    // MARK: - State Properties

    /// 背包管理器
    @StateObject private var inventoryManager = InventoryManager.shared

    /// 搜索文本
    @State private var searchText: String = ""

    /// 当前选中的分类（nil 表示全部）
    @State private var selectedCategory: ItemCategory? = nil

    /// 动画用的容量值
    @State private var animatedCapacity: Double = 0

    /// 加载错误信息
    @State private var loadError: String? = nil

    /// 背包最大容量（按物品数量计算）
    private let maxCapacity: Int = 100

    // MARK: - Computed Properties

    /// 当前背包物品数量
    private var currentCapacity: Int {
        return inventoryManager.items.reduce(0) { $0 + $1.quantity }
    }

    /// 容量百分比
    private var capacityPercentage: Double {
        return Double(currentCapacity) / Double(maxCapacity)
    }

    /// 筛选后的物品列表
    private var filteredItems: [(item: InventoryItem, definition: ItemDefinition)] {
        // 先获取所有物品及其定义
        let itemsWithDefinitions = inventoryManager.items.compactMap { invItem -> (item: InventoryItem, definition: ItemDefinition)? in
            guard let definition = MockExplorationData.getItemDefinition(by: invItem.itemId) else { return nil }
            return (invItem, definition)
        }

        // 应用分类筛选
        var filtered = itemsWithDefinitions
        if let category = selectedCategory {
            filtered = filtered.filter { $0.definition.category == category }
        }

        // 应用搜索筛选
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.definition.name.localizedCaseInsensitiveContains(searchText) }
        }

        return filtered
    }

    /// 是否显示警告（容量 > 90%）
    private var shouldShowWarning: Bool {
        return capacityPercentage > 0.9
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 容量状态卡
                capacityCard
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // 搜索框
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // 分类筛选
                categoryFilter
                    .padding(.top, 16)

                // 物品列表
                itemListSection
                    .padding(.top, 12)
            }

            // 加载指示器
            if inventoryManager.isLoading {
                ZStack {
                    ApocalypseTheme.background.opacity(0.8)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(ApocalypseTheme.primary)
                            .scaleEffect(1.5)

                        Text("加载中...")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }

            // 错误提示
            if let error = loadError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(ApocalypseTheme.danger)

                    Text("加载失败")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Button("重试") {
                        Task {
                            loadError = nil
                            try? await inventoryManager.loadInventory()
                        }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(ApocalypseTheme.primary)
                    )
                }
                .padding(.horizontal, 16)
            }
        }
        .navigationTitle("背包")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // 加载背包数据
            do {
                try await inventoryManager.loadInventory()
                print("✅ [BackpackView] 背包数据加载成功，共\(inventoryManager.items.count)种物品")
            } catch {
                loadError = error.localizedDescription
                print("❌ [BackpackView] 背包数据加载失败: \(error.localizedDescription)")
            }
        }
        .onAppear {
            // 容量进度条动画
            withAnimation(.easeOut(duration: 0.8)) {
                animatedCapacity = Double(currentCapacity)
            }
        }
        .onChange(of: currentCapacity) { newValue in
            // 当容量变化时，更新动画
            withAnimation(.easeOut(duration: 0.5)) {
                animatedCapacity = Double(newValue)
            }
        }
    }

    // MARK: - Capacity Card

    /// 容量状态卡
    private var capacityCard: some View {
        VStack(spacing: 12) {
            // 容量数字
            HStack {
                Text("背包容量")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                Text("\(currentCapacity) / \(maxCapacity)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ApocalypseTheme.background)
                        .frame(height: 10)

                    // 进度
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [capacityColor, capacityColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * (animatedCapacity / Double(maxCapacity)), height: 10)
                }
            }
            .frame(height: 10)

            // 警告文字
            if shouldShowWarning {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.danger)

                    Text("背包快满了！")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ApocalypseTheme.danger)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(capacityColor.opacity(0.3), lineWidth: 1)
        )
    }

    /// 容量进度条颜色
    private var capacityColor: Color {
        if capacityPercentage > 0.9 {
            return ApocalypseTheme.danger
        } else if capacityPercentage > 0.7 {
            return ApocalypseTheme.warning
        } else {
            return ApocalypseTheme.success
        }
    }

    // MARK: - Search Bar

    /// 搜索框
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textMuted)

            TextField("搜索物品名称", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ApocalypseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Category Filter

    /// 分类筛选
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // "全部" 按钮
                CategoryFilterChip(
                    title: "全部",
                    icon: "square.grid.2x2.fill",
                    color: ApocalypseTheme.primary,
                    isSelected: selectedCategory == nil
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = nil
                    }
                }

                // 各分类按钮
                ForEach(filterCategories, id: \.category) { categoryInfo in
                    CategoryFilterChip(
                        title: categoryInfo.name,
                        icon: categoryInfo.icon,
                        color: categoryInfo.color,
                        isSelected: selectedCategory == categoryInfo.category
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = categoryInfo.category
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    /// 筛选分类配置
    private var filterCategories: [(category: ItemCategory, name: String, icon: String, color: Color)] {
        [
            (.food, "食物", "fork.knife", .green),
            (.water, "水", "drop.fill", .blue),
            (.material, "材料", "cube.fill", .gray),
            (.tool, "工具", "wrench.and.screwdriver.fill", .orange),
            (.medical, "医疗", "cross.case.fill", .red)
        ]
    }

    // MARK: - Item List Section

    /// 物品列表区域
    private var itemListSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if filteredItems.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    ForEach(filteredItems, id: \.item.id) { itemData in
                        ItemCard(
                            item: itemData.item,
                            definition: itemData.definition,
                            onUse: {
                                print("使用物品: \(itemData.definition.name)")
                            },
                            onStore: {
                                print("存储物品: \(itemData.definition.name)")
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: selectedCategory)
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // 图标
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)
                .padding(.bottom, 8)

            // 主文字
            Text(emptyStateTitle)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 副文字
            Text(emptyStateMessage)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    /// 空状态图标
    private var emptyStateIcon: String {
        if inventoryManager.items.isEmpty {
            return "backpack"
        } else {
            return "magnifyingglass"
        }
    }

    /// 空状态标题
    private var emptyStateTitle: String {
        if inventoryManager.items.isEmpty {
            return "背包空空如也"
        } else {
            return "没有找到相关物品"
        }
    }

    /// 空状态消息
    private var emptyStateMessage: String {
        if inventoryManager.items.isEmpty {
            return "去探索收集物资吧"
        } else {
            return "尝试调整搜索条件或选择其他分类"
        }
    }
}

// MARK: - Category Filter Chip

/// 分类筛选按钮
struct CategoryFilterChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))

                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? color : ApocalypseTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? color : ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Item Card

/// 物品卡片
struct ItemCard: View {
    let item: InventoryItem
    let definition: ItemDefinition
    let onUse: () -> Void
    let onStore: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // 左边：圆形图标
            itemIcon

            // 中间：物品信息
            VStack(alignment: .leading, spacing: 6) {
                // 物品名称和稀有度标签
                HStack(spacing: 8) {
                    Text(definition.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 稀有度标签
                    rarityBadge
                }

                // 数量、重量、品质
                HStack(spacing: 12) {
                    // 数量
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .font(.system(size: 10))
                            .foregroundColor(ApocalypseTheme.textMuted)

                        Text("x\(item.quantity)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }

                    // 重量
                    HStack(spacing: 4) {
                        Image(systemName: "scalemass")
                            .font(.system(size: 10))
                            .foregroundColor(ApocalypseTheme.textMuted)

                        Text(String(format: "%.1fkg", definition.weight))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }

                    // 品质（如果有）
                    if let quality = item.quality {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(ApocalypseTheme.warning)

                            Text(quality.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }
                }
            }

            Spacer()

            // 右边：使用和存储按钮
            VStack(spacing: 8) {
                // 使用按钮
                Button(action: onUse) {
                    Text("使用")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(ApocalypseTheme.primary)
                        )
                }

                // 存储按钮
                Button(action: onStore) {
                    Text("存储")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(ApocalypseTheme.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(categoryColor.opacity(0.3), lineWidth: 1)
        )
    }

    /// 物品图标
    private var itemIcon: some View {
        ZStack {
            Circle()
                .fill(categoryColor.opacity(0.15))
                .frame(width: 48, height: 48)

            Image(systemName: definition.category.iconName)
                .font(.system(size: 20))
                .foregroundColor(categoryColor)
        }
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

    /// 稀有度标签
    private var rarityBadge: some View {
        Text(definition.rarity.displayName)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(rarityColor)
            )
    }

    /// 稀有度对应的颜色
    private var rarityColor: Color {
        switch definition.rarity {
        case .common:
            return .gray
        case .uncommon:
            return .green
        case .rare:
            return .blue
        case .epic:
            return .purple
        case .legendary:
            return .orange
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        BackpackView()
    }
}
