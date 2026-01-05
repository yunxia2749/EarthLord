//
//  ResourcesTabView.swift
//  EarthLord
//
//  资源页面：显示玩家拥有的各种资源
//

import SwiftUI

struct ResourcesTabView: View {

    // MARK: - State Properties

    /// 资源数据（示例数据）
    @State private var resources: [Resource] = [
        Resource(name: "食物", icon: "fork.knife", amount: 245, maxAmount: 500, category: .survival, color: ApocalypseTheme.success),
        Resource(name: "水", icon: "drop.fill", amount: 180, maxAmount: 300, category: .survival, color: ApocalypseTheme.info),
        Resource(name: "木材", icon: "tree.fill", amount: 520, maxAmount: 1000, category: .material, color: Color(red: 0.6, green: 0.4, blue: 0.2)),
        Resource(name: "石头", icon: "cube.fill", amount: 380, maxAmount: 1000, category: .material, color: Color(white: 0.5)),
        Resource(name: "金属", icon: "bolt.fill", amount: 95, maxAmount: 500, category: .material, color: Color(red: 0.7, green: 0.7, blue: 0.8)),
        Resource(name: "燃料", icon: "flame.fill", amount: 62, maxAmount: 200, category: .energy, color: ApocalypseTheme.warning),
        Resource(name: "电力", icon: "bolt.circle.fill", amount: 120, maxAmount: 300, category: .energy, color: Color(red: 0.3, green: 0.8, blue: 1.0)),
        Resource(name: "药品", icon: "cross.case.fill", amount: 28, maxAmount: 100, category: .medical, color: Color(red: 1.0, green: 0.2, blue: 0.4)),
    ]

    /// 当前选择的分类
    @State private var selectedCategory: ResourceCategory? = nil

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 顶部统计卡片
                        totalResourcesCard

                        // 分类筛选
                        categoryFilter

                        // 资源列表
                        resourcesList

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("资源")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Subviews

    /// 总资源统计卡片
    private var totalResourcesCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "cube.box.fill")
                    .font(.title)
                    .foregroundColor(ApocalypseTheme.primary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("资源总览")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("总共 \(resources.count) 种资源")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

                // 总容量百分比
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(totalPercentage))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("总容量")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ApocalypseTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(ApocalypseTheme.primary.opacity(0.3), lineWidth: 1)
            )
        }
    }

    /// 分类筛选器
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // 全部按钮
                CategoryChip(
                    title: "全部",
                    icon: "square.grid.2x2.fill",
                    isSelected: selectedCategory == nil,
                    color: ApocalypseTheme.primary
                ) {
                    selectedCategory = nil
                }

                // 各分类按钮
                ForEach(ResourceCategory.allCases) { category in
                    CategoryChip(
                        title: category.displayName,
                        icon: category.icon,
                        isSelected: selectedCategory == category,
                        color: category.color
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    /// 资源列表
    private var resourcesList: some View {
        VStack(spacing: 12) {
            ForEach(filteredResources) { resource in
                ResourceCard(resource: resource)
            }
        }
    }

    // MARK: - Computed Properties

    /// 过滤后的资源列表
    private var filteredResources: [Resource] {
        if let category = selectedCategory {
            return resources.filter { $0.category == category }
        }
        return resources
    }

    /// 总容量百分比
    private var totalPercentage: Double {
        let totalAmount = resources.reduce(0.0) { $0 + Double($1.amount) }
        let totalMax = resources.reduce(0.0) { $0 + Double($1.maxAmount) }
        return totalMax > 0 ? (totalAmount / totalMax) * 100 : 0
    }
}

// MARK: - Resource Card

/// 资源卡片
struct ResourceCard: View {
    let resource: Resource

    var body: some View {
        HStack(spacing: 16) {
            // 资源图标
            ZStack {
                Circle()
                    .fill(resource.color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: resource.icon)
                    .font(.title3)
                    .foregroundColor(resource.color)
            }

            // 资源信息
            VStack(alignment: .leading, spacing: 8) {
                // 资源名称和数量
                HStack {
                    Text(resource.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()

                    Text("\(resource.amount) / \(resource.maxAmount)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(resource.percentageFull > 80 ? ApocalypseTheme.success : ApocalypseTheme.textSecondary)
                }

                // 进度条
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ApocalypseTheme.background)
                            .frame(height: 6)

                        // 进度
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [resource.color, resource.color.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * (resource.percentageFull / 100), height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(resource.color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Category Chip

/// 分类筛选按钮
struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? color : ApocalypseTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(color.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Models

/// 资源数据模型
struct Resource: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let amount: Int
    let maxAmount: Int
    let category: ResourceCategory
    let color: Color

    /// 容量百分比
    var percentageFull: Double {
        return maxAmount > 0 ? (Double(amount) / Double(maxAmount)) * 100 : 0
    }
}

/// 资源分类
enum ResourceCategory: String, CaseIterable, Identifiable {
    case survival = "生存"
    case material = "材料"
    case energy = "能源"
    case medical = "医疗"

    var id: String { rawValue }

    var displayName: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .survival: return "heart.fill"
        case .material: return "hammer.fill"
        case .energy: return "bolt.fill"
        case .medical: return "cross.fill"
        }
    }

    var color: Color {
        switch self {
        case .survival: return ApocalypseTheme.success
        case .material: return Color(red: 0.6, green: 0.4, blue: 0.2)
        case .energy: return ApocalypseTheme.warning
        case .medical: return Color(red: 1.0, green: 0.2, blue: 0.4)
        }
    }
}

// MARK: - Preview

#Preview {
    ResourcesTabView()
}
