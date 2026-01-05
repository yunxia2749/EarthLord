//
//  TerritoryTabView.swift
//  EarthLord
//
//  领地页面：显示和管理玩家的领地
//

import SwiftUI
import MapKit

struct TerritoryTabView: View {

    // MARK: - State Properties

    /// 领地列表（示例数据）
    @State private var territories: [Territory] = [
        Territory(
            name: "中央堡垒",
            coordinate: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
            level: 5,
            population: 120,
            maxPopulation: 150,
            status: .thriving,
            resources: [
                TerritoryResource(type: "食物", productionRate: 45),
                TerritoryResource(type: "水", productionRate: 30)
            ]
        ),
        Territory(
            name: "东方前哨",
            coordinate: CLLocationCoordinate2D(latitude: 39.9142, longitude: 116.4174),
            level: 3,
            population: 45,
            maxPopulation: 80,
            status: .growing,
            resources: [
                TerritoryResource(type: "木材", productionRate: 20),
                TerritoryResource(type: "石头", productionRate: 15)
            ]
        ),
        Territory(
            name: "西部矿场",
            coordinate: CLLocationCoordinate2D(latitude: 39.8942, longitude: 116.3974),
            level: 2,
            population: 28,
            maxPopulation: 50,
            status: .developing,
            resources: [
                TerritoryResource(type: "金属", productionRate: 12),
                TerritoryResource(type: "燃料", productionRate: 8)
            ]
        ),
    ]

    /// 当前选择的领地
    @State private var selectedTerritory: Territory?

    /// 显示领地详情
    @State private var showTerritoryDetail = false

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 顶部统计卡片
                        territoryStatsCard

                        // 领地列表
                        territoriesSection

                        // 扩张提示
                        expansionHint

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("领地")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showTerritoryDetail) {
                if let territory = selectedTerritory {
                    TerritoryDetailView(territory: territory)
                }
            }
        }
    }

    // MARK: - Subviews

    /// 领地统计卡片
    private var territoryStatsCard: some View {
        HStack(spacing: 20) {
            // 领地数量
            StatItem(
                icon: "flag.fill",
                title: "领地数量",
                value: "\(territories.count)",
                color: ApocalypseTheme.primary
            )

            Divider()
                .frame(height: 60)
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 总人口
            StatItem(
                icon: "person.3.fill",
                title: "总人口",
                value: "\(totalPopulation)",
                color: ApocalypseTheme.info
            )

            Divider()
                .frame(height: 60)
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 平均等级
            StatItem(
                icon: "star.fill",
                title: "平均等级",
                value: String(format: "%.1f", averageLevel),
                color: ApocalypseTheme.warning
            )
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

    /// 领地列表区域
    private var territoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Text("我的领地")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("\(territories.count) 个")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 领地卡片列表
            VStack(spacing: 12) {
                ForEach(territories) { territory in
                    TerritoryCard(territory: territory) {
                        selectedTerritory = territory
                        showTerritoryDetail = true
                    }
                }
            }
        }
    }

    /// 扩张提示
    private var expansionHint: some View {
        VStack(spacing: 16) {
            Image(systemName: "map.fill")
                .font(.system(size: 40))
                .foregroundColor(ApocalypseTheme.primary)

            Text("探索地图发现新领地")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("前往地图页面，圈占更多领地来扩张你的势力")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: {
                // 跳转到地图页面的逻辑
            }) {
                Text("前往地图")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ApocalypseTheme.primary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Computed Properties

    /// 总人口
    private var totalPopulation: Int {
        territories.reduce(0) { $0 + $1.population }
    }

    /// 平均等级
    private var averageLevel: Double {
        let totalLevel = territories.reduce(0) { $0 + $1.level }
        return territories.isEmpty ? 0 : Double(totalLevel) / Double(territories.count)
    }
}

// MARK: - Territory Card

/// 领地卡片
struct TerritoryCard: View {
    let territory: Territory
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                // 顶部：名称和等级
                HStack {
                    HStack(spacing: 12) {
                        // 状态图标
                        ZStack {
                            Circle()
                                .fill(territory.status.color.opacity(0.2))
                                .frame(width: 44, height: 44)

                            Image(systemName: "flag.fill")
                                .foregroundColor(territory.status.color)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(territory.name)
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Text(territory.status.displayName)
                                .font(.caption)
                                .foregroundColor(territory.status.color)
                        }
                    }

                    Spacer()

                    // 等级徽章
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                        Text("Lv.\(territory.level)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(ApocalypseTheme.warning)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ApocalypseTheme.warning.opacity(0.2))
                    .cornerRadius(12)
                }

                // 人口信息
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "person.3.fill")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.info)

                        Text("人口: \(territory.population) / \(territory.maxPopulation)")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Spacer()
                    }

                    // 人口进度条
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(ApocalypseTheme.background)
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [ApocalypseTheme.info, ApocalypseTheme.info.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * territory.populationPercentage, height: 6)
                        }
                    }
                    .frame(height: 6)
                }

                // 资源产出
                if !territory.resources.isEmpty {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.success)

                            Text("资源产出")
                                .font(.subheadline)
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            Spacer()
                        }

                        // 资源列表
                        HStack(spacing: 12) {
                            ForEach(territory.resources) { resource in
                                HStack(spacing: 4) {
                                    Text(resource.type)
                                        .font(.caption)
                                        .foregroundColor(ApocalypseTheme.textSecondary)

                                    Text("+\(resource.productionRate)/h")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(ApocalypseTheme.success)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(ApocalypseTheme.success.opacity(0.1))
                                .cornerRadius(8)
                            }

                            Spacer()
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ApocalypseTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(territory.status.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Stat Item

/// 统计项
struct StatItem: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(title)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Territory Detail View

/// 领地详情页面
struct TerritoryDetailView: View {
    let territory: Territory
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 领地信息
                        VStack(spacing: 20) {
                            // 图标
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [territory.status.color, territory.status.color.opacity(0.7)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 100, height: 100)

                                Image(systemName: "flag.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            }
                            .shadow(color: territory.status.color.opacity(0.5), radius: 20)

                            // 名称和状态
                            VStack(spacing: 8) {
                                Text(territory.name)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(ApocalypseTheme.textPrimary)

                                HStack(spacing: 8) {
                                    Image(systemName: "star.fill")
                                    Text("等级 \(territory.level)")
                                }
                                .font(.subheadline)
                                .foregroundColor(ApocalypseTheme.warning)

                                Text(territory.status.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(territory.status.color)
                            }
                        }
                        .padding(.top, 20)

                        // 详细信息卡片
                        VStack(spacing: 0) {
                            DetailRow(icon: "person.3.fill", title: "人口", value: "\(territory.population) / \(territory.maxPopulation)", showDivider: true)
                            DetailRow(icon: "location.fill", title: "坐标", value: String(format: "%.4f, %.4f", territory.coordinate.latitude, territory.coordinate.longitude), showDivider: false)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(ApocalypseTheme.cardBackground)
                        )

                        // 资源产出
                        if !territory.resources.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("资源产出")
                                    .font(.headline)
                                    .foregroundColor(ApocalypseTheme.textPrimary)

                                VStack(spacing: 0) {
                                    ForEach(Array(territory.resources.enumerated()), id: \.element.id) { index, resource in
                                        DetailRow(
                                            icon: "arrow.up.circle.fill",
                                            title: resource.type,
                                            value: "+\(resource.productionRate)/小时",
                                            showDivider: index < territory.resources.count - 1
                                        )
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(ApocalypseTheme.cardBackground)
                                )
                            }
                        }

                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }
}

/// 详情行
struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    let showDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .foregroundColor(ApocalypseTheme.primary)
                    .frame(width: 24)

                Text(title)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                Text(value)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .fontWeight(.medium)
            }
            .padding()

            if showDivider {
                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.2))
                    .padding(.leading, 56)
            }
        }
    }
}

// MARK: - Models

/// 领地数据模型
struct Territory: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let level: Int
    let population: Int
    let maxPopulation: Int
    let status: TerritoryStatus
    let resources: [TerritoryResource]

    /// 人口百分比
    var populationPercentage: Double {
        return maxPopulation > 0 ? Double(population) / Double(maxPopulation) : 0
    }
}

/// 领地资源
struct TerritoryResource: Identifiable {
    let id = UUID()
    let type: String
    let productionRate: Int
}

/// 领地状态
enum TerritoryStatus: String {
    case thriving = "繁荣发展"
    case growing = "成长中"
    case developing = "开发中"
    case struggling = "艰难维持"

    var displayName: String {
        rawValue
    }

    var color: Color {
        switch self {
        case .thriving: return ApocalypseTheme.success
        case .growing: return ApocalypseTheme.info
        case .developing: return ApocalypseTheme.warning
        case .struggling: return ApocalypseTheme.danger
        }
    }
}

// MARK: - Preview

#Preview {
    TerritoryTabView()
}
