//
//  POIListView.swift
//  EarthLord
//
//  显示附近兴趣点（POI）的列表页面
//  包含 GPS 状态栏、搜索按钮、分类筛选、POI 列表
//

import SwiftUI
import CoreLocation

struct POIListView: View {

    // MARK: - State Properties

    /// POI 列表数据
    @State private var pois: [POIData] = MockExplorationData.mockPOIs

    /// 当前选中的筛选分类（nil 表示全部）
    @State private var selectedCategory: POIType? = nil

    /// 是否正在搜索
    @State private var isSearching = false

    /// 搜索按钮按下状态
    @State private var isButtonPressed = false

    /// 列表项动画状态
    @State private var isListVisible = false

    /// 模拟 GPS 坐标
    private let mockCoordinate = CLLocationCoordinate2D(latitude: 22.54, longitude: 114.06)

    // MARK: - Computed Properties

    /// 筛选后的 POI 列表
    private var filteredPOIs: [POIData] {
        if let category = selectedCategory {
            return pois.filter { $0.type == category }
        }
        return pois
    }

    /// 已发现的 POI 数量
    private var discoveredCount: Int {
        pois.filter { $0.discoveryStatus == .discovered }.count
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 状态栏
                statusBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // 搜索按钮
                searchButton
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // 筛选工具栏
                filterToolbar
                    .padding(.top, 16)

                // POI 列表
                poiListSection
                    .padding(.top, 12)
            }
        }
        .navigationTitle("附近地点")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Status Bar

    /// GPS 状态栏
    private var statusBar: some View {
        HStack(spacing: 16) {
            // GPS 坐标
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.success)

                Text(String(format: "%.2f, %.2f", mockCoordinate.latitude, mockCoordinate.longitude))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 发现数量
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("附近发现 \(discoveredCount) 个地点")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - Search Button

    /// 搜索按钮
    private var searchButton: some View {
        Button(action: performSearch) {
            HStack(spacing: 12) {
                if isSearching {
                    // 搜索中状态
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)

                    Text("搜索中...")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    // 正常状态
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)

                    Text("搜索附近POI")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSearching ? ApocalypseTheme.textMuted : ApocalypseTheme.primary)
            )
        }
        .scaleEffect(isButtonPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isButtonPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isSearching {
                        isButtonPressed = true
                    }
                }
                .onEnded { _ in
                    isButtonPressed = false
                }
        )
        .disabled(isSearching)
    }

    // MARK: - Filter Toolbar

    /// 筛选工具栏
    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // "全部" 按钮
                FilterChip(
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
                ForEach(filterCategories, id: \.type) { category in
                    FilterChip(
                        title: category.name,
                        icon: category.icon,
                        color: category.color,
                        isSelected: selectedCategory == category.type
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category.type
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    /// 筛选分类配置
    private var filterCategories: [(type: POIType, name: String, icon: String, color: Color)] {
        [
            (.hospital, "医院", "cross.case.fill", .red),
            (.supermarket, "超市", "cart.fill", .green),
            (.factory, "工厂", "building.2.fill", .gray),
            (.pharmacy, "药店", "pills.fill", .purple),
            (.gasStation, "加油站", "fuelpump.fill", .orange)
        ]
    }

    // MARK: - POI List Section

    /// POI 列表区域
    private var poiListSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if filteredPOIs.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    ForEach(Array(filteredPOIs.enumerated()), id: \.element.id) { index, poi in
                        NavigationLink(destination: POIDetailView(poi: poi)) {
                            POIListCard(poi: poi)
                        }
                        .opacity(isListVisible ? 1 : 0)
                        .offset(y: isListVisible ? 0 : 20)
                        .animation(
                            .easeOut(duration: 0.4)
                                .delay(Double(index) * 0.1),
                            value: isListVisible
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .onAppear {
            isListVisible = true
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
        if pois.isEmpty {
            return "map"
        } else {
            return "mappin.slash"
        }
    }

    /// 空状态标题
    private var emptyStateTitle: String {
        if pois.isEmpty {
            return "附近暂无兴趣点"
        } else {
            return "没有找到该类型的地点"
        }
    }

    /// 空状态消息
    private var emptyStateMessage: String {
        if pois.isEmpty {
            return "点击搜索按钮发现周围的废墟"
        } else {
            return "尝试搜索附近或选择其他分类"
        }
    }

    // MARK: - Methods

    /// 执行搜索（模拟网络请求）
    private func performSearch() {
        isSearching = true

        // 模拟 1.5 秒的网络请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // 模拟刷新数据（这里用相同数据，实际应该请求服务器）
            pois = MockExplorationData.mockPOIs
            isSearching = false
        }
    }
}

// MARK: - Filter Chip

/// 筛选分类按钮
struct FilterChip: View {
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

// MARK: - POI List Card

/// POI 列表卡片
struct POIListCard: View {
    let poi: POIData

    var body: some View {
        HStack(spacing: 14) {
            // 左侧：类型图标
            poiIcon

            // 中间：名称和信息
            VStack(alignment: .leading, spacing: 6) {
                // 名称
                Text(poi.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 类型和状态
                HStack(spacing: 12) {
                    // 类型标签
                    Text(poi.type.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(poiColor)

                    // 发现状态
                    discoveryStatusBadge

                    // 物资状态
                    if poi.discoveryStatus == .discovered {
                        lootStatusBadge
                    }
                }
            }

            Spacer()

            // 右侧：箭头
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(poiColor.opacity(0.3), lineWidth: 1)
        )
    }

    /// POI 类型图标
    private var poiIcon: some View {
        ZStack {
            Circle()
                .fill(poiColor.opacity(0.15))
                .frame(width: 48, height: 48)

            Image(systemName: poi.type.iconName)
                .font(.system(size: 20))
                .foregroundColor(poiColor)
        }
    }

    /// POI 类型对应的颜色
    private var poiColor: Color {
        switch poi.type {
        case .hospital:
            return .red
        case .supermarket:
            return .green
        case .factory:
            return .gray
        case .pharmacy:
            return .purple
        case .gasStation:
            return .orange
        case .warehouse:
            return .brown
        case .residence:
            return .cyan
        case .policeStation:
            return .blue
        }
    }

    /// 发现状态标签
    private var discoveryStatusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: poi.discoveryStatus == .discovered ? "eye.fill" : "eye.slash.fill")
                .font(.system(size: 10))

            Text(poi.discoveryStatus == .discovered ? "已发现" : "未发现")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(poi.discoveryStatus == .discovered ? ApocalypseTheme.success : ApocalypseTheme.textMuted)
    }

    /// 物资状态标签
    private var lootStatusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: poi.searchStatus == .hasLoot ? "shippingbox.fill" : "shippingbox")
                .font(.system(size: 10))

            Text(poi.searchStatus == .hasLoot ? "有物资" : "已搜空")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(poi.searchStatus == .hasLoot ? ApocalypseTheme.warning : ApocalypseTheme.textMuted)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        POIListView()
    }
}
