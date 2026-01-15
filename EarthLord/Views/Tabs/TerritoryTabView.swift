//
//  TerritoryTabView.swift
//  EarthLord
//
//  Day 18: 领地列表页面
//  显示和管理用户实际圈占的领地
//

import SwiftUI
import MapKit
import Supabase

@MainActor
struct TerritoryTabView: View {

    // MARK: - State Properties

    /// 领地列表（从Supabase加载）
    @State private var territories: [TerritoryData] = []

    /// 是否正在加载
    @State private var isLoading = false

    /// 错误消息
    @State private var errorMessage: String?

    /// 当前选择的领地
    @State private var selectedTerritory: TerritoryData?

    /// 显示领地详情
    @State private var showTerritoryDetail = false

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                // 蓝紫色渐变背景
                LinearGradient(
                    colors: [
                        Color(red: 0.15, green: 0.18, blue: 0.35),
                        Color(red: 0.1, green: 0.12, blue: 0.25)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if isLoading {
                    // 加载指示器
                    loadingView
                } else if let error = errorMessage {
                    // 错误视图
                    errorView(message: error)
                } else if territories.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    // 领地列表
                    ScrollView {
                        VStack(spacing: 24) {
                            // 顶部统计卡片
                            territoryStatsCard

                            // 领地列表
                            territoriesSection

                            Spacer(minLength: 20)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("我的领地")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: loadTerritories) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                }
            }
            .sheet(isPresented: $showTerritoryDetail) {
                if let territory = selectedTerritory {
                    TerritoryDetailSheetView(territory: territory) {
                        // 删除后刷新列表
                        loadTerritories()
                    }
                }
            }
            .onAppear {
                if territories.isEmpty {
                    loadTerritories()
                }
            }
        }
    }

    // MARK: - Subviews

    /// 加载视图
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(ApocalypseTheme.primary)

            Text("加载领地中...")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    /// 错误视图
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.danger)

            Text("加载失败")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(message)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: loadTerritories) {
                Text("重试")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(8)
            }
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "map")
                .font(.system(size: 80))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("还没有领地")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("前往地图页面圈占你的第一块领地吧！")
                .font(.body)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    /// 领地统计卡片（毛玻璃风格）
    private var territoryStatsCard: some View {
        HStack(spacing: 0) {
            // 领地数量
            VStack(spacing: 4) {
                Text("\(territories.count)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(ApocalypseTheme.primary)
                Text("领地数")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)

            // 总面积
            VStack(spacing: 4) {
                Text(formatArea(totalArea))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(ApocalypseTheme.primary)
                Text("总面积")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    /// 领地列表区域
    private var territoriesSection: some View {
        VStack(spacing: 12) {
            // 领地卡片列表（无标题，简洁风格）
            ForEach(territories) { territory in
                TerritoryListCard(territory: territory) {
                    selectedTerritory = territory
                    showTerritoryDetail = true
                }
            }
        }
    }

    // MARK: - Computed Properties

    /// 总面积
    private var totalArea: Double {
        territories.reduce(0) { $0 + ($1.area ?? 0) }
    }

    /// 总路径点
    private var totalPoints: Int {
        territories.reduce(0) { $0 + ($1.pointCount ?? 0) }
    }

    // MARK: - Methods

    /// 加载领地列表
    private func loadTerritories() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                print("📥 [TerritoryTabView] 开始加载领地列表...")
                territories = try await TerritoryManager.shared.loadAllTerritories()
                print("✅ [TerritoryTabView] 加载成功，共 \(territories.count) 个领地")
            } catch {
                print("❌ [TerritoryTabView] 加载失败: \(error)")
                errorMessage = "加载领地失败: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    /// 格式化面积显示
    private func formatArea(_ area: Double) -> String {
        if area >= 1_000_000 {
            return String(format: "%.1f km²", area / 1_000_000)
        } else if area >= 1000 {
            return String(format: "%.0f m²", area)
        } else {
            return String(format: "%.1f m²", area)
        }
    }
}

// MARK: - Territory List Card

/// 领地列表卡片（简洁毛玻璃风格）
struct TerritoryListCard: View {
    let territory: TerritoryData
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 左侧信息
                VStack(alignment: .leading, spacing: 4) {
                    // 名称
                    Text(territory.name ?? "未命名领地")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)

                    // 面积和路径点
                    HStack(spacing: 16) {
                        // 面积图标 + 数值
                        HStack(spacing: 4) {
                            Image(systemName: "map")
                                .font(.system(size: 12))
                            Text(formatArea(territory.area ?? 0))
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.white.opacity(0.6))

                        // 路径点图标 + 数值
                        if let pointCount = territory.pointCount {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 12))
                                Text("\(pointCount) 点")
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }

                Spacer()

                // 右侧箭头
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// 格式化面积显示
    private func formatArea(_ area: Double) -> String {
        if area >= 1_000_000 {
            return String(format: "%.1f km²", area / 1_000_000)
        } else {
            return String(format: "%.0f m²", area)
        }
    }
}

// MARK: - Territory Detail Sheet View

/// 领地详情底部弹窗
struct TerritoryDetailSheetView: View {
    let territory: TerritoryData
    let onDelete: () -> Void

    @Environment(\.dismiss) var dismiss
    @State private var showDeleteAlert = false
    @State private var isDeleting = false

    var body: some View {
        ZStack {
            // 深蓝色背景
            Color(red: 0.1, green: 0.12, blue: 0.18)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // 顶部栏：关闭按钮 + 标题
                    ZStack {
                        // 左侧关闭按钮
                        HStack {
                            Button(action: {
                                dismiss()
                            }) {
                                Text("关闭")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(ApocalypseTheme.primary)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color(red: 0.15, green: 0.17, blue: 0.23))
                                    )
                            }
                            .padding(.leading, 16)

                            Spacer()
                        }

                        // 中间标题
                        Text(territory.name ?? "未命名领地")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 16)

                    // 地图预览
                    TerritoryMapPreview(territory: territory)
                        .frame(height: 280)
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                        .onAppear {
                            print("📱 [TerritoryDetailSheetView] 地图预览出现")
                            print("   - 领地ID: \(territory.id)")
                            print("   - 面积: \(territory.area)")
                            print("   - 路径点数: \(territory.pointCount ?? 0)")
                        }

                    // 领地信息标题
                    HStack {
                        Text("领地信息")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // 领地信息卡片
                    VStack(spacing: 16) {
                        // 面积
                        TerritoryInfoRow(
                            icon: "map.fill",
                            title: "面积",
                            value: formatArea(territory.area ?? 0)
                        )

                        // 路径点数
                        if let pointCount = territory.pointCount {
                            TerritoryInfoRow(
                                icon: "location.circle.fill",
                                title: "路径点",
                                value: "\(pointCount) 个"
                            )
                        }

                        // 创建时间
                        if let createdAt = territory.createdAt {
                            TerritoryInfoRow(
                                icon: "clock.fill",
                                title: "创建时间",
                                value: formatDate(createdAt)
                            )
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(red: 0.15, green: 0.17, blue: 0.23))
                    )
                    .padding(.horizontal, 16)

                    // 删除按钮
                    Button(action: {
                        showDeleteAlert = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 16))
                            Text("删除领地")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .disabled(isDeleting)

                    // 更多功能区域
                    VStack(alignment: .leading, spacing: 12) {
                        Text("更多功能")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)

                        VStack(spacing: 12) {
                            // 重命名领地
                            FeatureButton(
                                icon: "pencil",
                                title: "重命名领地",
                                badge: "敬请期待"
                            )

                            // 建筑系统
                            FeatureButton(
                                icon: "building.2.fill",
                                title: "建筑系统",
                                badge: "敬请期待"
                            )

                            // 领地交易
                            FeatureButton(
                                icon: "arrow.left.arrow.right",
                                title: "领地交易",
                                badge: "敬请期待"
                            )
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 8)

                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
            }
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deleteTerritory()
            }
        } message: {
            Text("确定要删除这个领地吗？此操作无法撤销。")
        }
    }

    /// 删除领地
    private func deleteTerritory() {
        isDeleting = true

        Task {
            do {
                // TODO: 实现删除领地的API调用
                try await supabase
                    .from("territories")
                    .delete()
                    .eq("id", value: territory.id)
                    .execute()

                print("✅ [TerritoryDetailSheetView] 领地删除成功")

                await MainActor.run {
                    dismiss()
                    onDelete()
                }
            } catch {
                print("❌ [TerritoryDetailSheetView] 领地删除失败: \(error)")
                // TODO: 显示错误提示
            }
            isDeleting = false
        }
    }

    /// 格式化面积显示
    private func formatArea(_ area: Double) -> String {
        if area >= 1_000_000 {
            return String(format: "%.2f km²", area / 1_000_000)
        } else {
            return String(format: "%.0f m²", area)
        }
    }

    /// 格式化日期显示
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
}

// MARK: - Territory Map Preview

/// 领地地图预览
struct TerritoryMapPreview: View {
    let territory: TerritoryData

    var body: some View {
        let coordinates = territory.toCoordinates()

        if coordinates.count >= 3 {
            // 有效的坐标数据，显示地图
            TerritoryMapKitView(territory: territory)
                .cornerRadius(16)
        } else {
            // 坐标数据不足，显示错误提示
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.2))

                VStack(spacing: 12) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)

                    Text("地图数据加载失败")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("坐标点数: \(coordinates.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

/// MapKit 地图视图（用于绘制多边形）
struct TerritoryMapKitView: UIViewRepresentable {
    let territory: TerritoryData

    func makeUIView(context: Context) -> MKMapView {
        print("🗺️ [TerritoryMapKitView] 创建地图视图，领地ID: \(territory.id)")
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        print("🔄 [TerritoryMapKitView] 更新地图视图")

        // 移除旧的 overlays
        mapView.removeOverlays(mapView.overlays)

        // 添加多边形
        let coordinates = territory.toCoordinates()
        print("📍 [TerritoryMapKitView] 坐标点数: \(coordinates.count)")

        guard coordinates.count >= 3 else {
            print("⚠️ [TerritoryMapKitView] 坐标点少于3个，无法绘制多边形")
            // 设置一个默认区域
            mapView.setRegion(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ), animated: false)
            return
        }

        var coords = coordinates
        let polygon = MKPolygon(coordinates: &coords, count: coords.count)
        mapView.addOverlay(polygon)
        print("✅ [TerritoryMapKitView] 已添加多边形 overlay")

        // 设置地图区域
        let centerLat = coordinates.reduce(0) { $0 + $1.latitude } / Double(coordinates.count)
        let centerLon = coordinates.reduce(0) { $0 + $1.longitude } / Double(coordinates.count)

        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }
        let latDelta = (lats.max() ?? 0) - (lats.min() ?? 0)
        let lonDelta = (lons.max() ?? 0) - (lons.min() ?? 0)

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(
                latitudeDelta: max(latDelta * 1.5, 0.005),
                longitudeDelta: max(lonDelta * 1.5, 0.005)
            )
        )

        print("🎯 [TerritoryMapKitView] 设置地图区域: 中心(\(centerLat), \(centerLon)), 跨度(\(region.span.latitudeDelta), \(region.span.longitudeDelta))")
        mapView.setRegion(region, animated: false)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            print("🎨 [TerritoryMapKitView] 渲染 overlay")
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                // 使用固定的 UIColor 而不是从 SwiftUI Color 转换
                renderer.fillColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 0.3) // 蓝色
                renderer.strokeColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
                renderer.lineWidth = 2
                print("✅ [TerritoryMapKitView] Polygon renderer 创建成功")
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Info Row

/// 信息行
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(title)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .fontWeight(.medium)
        }
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

// MARK: - Territory Info Row

/// 领地信息行（橙色图标+白色文字）
struct TerritoryInfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            // 橙色图标
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 24)

            // 标题
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.white)

            Spacer()

            // 值
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Feature Button

/// 功能按钮（灰色背景+白色文字+右侧标注）
struct FeatureButton: View {
    let icon: String
    let title: String
    let badge: String

    var body: some View {
        Button(action: {
            // 暂无功能
        }) {
            HStack(spacing: 12) {
                // 图标
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 24)

                // 标题
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(.white)

                Spacer()

                // 标注
                Text(badge)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.15, green: 0.17, blue: 0.23))
            )
        }
        .disabled(true)
    }
}

// MARK: - Preview

#Preview {
    TerritoryTabView()
}
