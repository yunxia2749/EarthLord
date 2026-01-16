//
//  MapViewRepresentable.swift
//  EarthLord
//
//  MKMapView的SwiftUI包装器：显示真实地图、应用末世滤镜、自动居中用户位置
//

import SwiftUI
import MapKit

// MARK: - MapViewRepresentable
/// 苹果地图的SwiftUI包装器
struct MapViewRepresentable: UIViewRepresentable {

    // MARK: - Bindings

    /// 用户当前位置（双向绑定）
    @Binding var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次居中
    @Binding var hasLocatedUser: Bool

    /// 路径坐标数组（圈地轨迹）
    @Binding var pathCoordinates: [CLLocationCoordinate2D]

    /// 路径更新版本号
    @Binding var pathUpdateVersion: Int

    /// 路径是否已闭环
    var isPathClosed: Bool

    /// 已上传的领地列表
    var uploadedTerritories: [TerritoryData] = []

    /// 当前用户ID（用于区分自己和他人的领地）
    var currentUserId: String?

    /// Day 20: 当前地图区域（双向绑定）
    @Binding var currentMapRegion: MKCoordinateRegion?

    /// Day 20: 地图区域变化回调
    var onRegionChanged: ((MKCoordinateRegion) -> Void)?

    /// Day 22: 附近的POI列表
    var nearbyPOIs: [POIData] = []

    /// Day 22: 已搜刮的POI ID集合
    var scavengedPOIIds: Set<String> = []

    // MARK: - UIViewRepresentable

    /// 创建MKMapView
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        // 基础配置
        mapView.mapType = .hybrid // 卫星图+道路标签（末世废土风格）
        mapView.pointOfInterestFilter = .excludingAll // 隐藏所有POI标签（商店、餐厅等）
        mapView.showsBuildings = false // 隐藏3D建筑
        mapView.showsUserLocation = true // ⚠️ 关键：显示用户位置蓝点
        mapView.isZoomEnabled = true // 允许双指缩放
        mapView.isScrollEnabled = true // 允许单指拖动
        mapView.isRotateEnabled = true // 允许双指旋转
        mapView.isPitchEnabled = false // 禁用倾斜视角

        // ⚠️ 关键：设置代理，否则didUpdate userLocation不会被调用
        mapView.delegate = context.coordinator

        // 应用末世滤镜
        applyApocalypseFilter(to: mapView)

        return mapView
    }

    /// 更新视图
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // ⚠️ 关键：更新 Coordinator 的 parent 引用（否则会用旧的 isPathClosed 值）
        context.coordinator.parent = self

        // ⭐ 关键：当路径坐标、版本号或闭环状态更新时，重新绘制轨迹
        context.coordinator.updateTrackingPath(on: uiView, coordinates: pathCoordinates, version: pathUpdateVersion)

        // ⭐ 绘制已上传的领地
        context.coordinator.updateUploadedTerritories(on: uiView, territories: uploadedTerritories)

        // ⭐ Day 22: 更新POI标记
        context.coordinator.updatePOIAnnotations(on: uiView, pois: nearbyPOIs, scavengedIds: scavengedPOIIds)
    }

    /// 创建协调器
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Apocalypse Filter

    /// 应用末世滤镜：降低饱和度、添加棕褐色调（废土泛黄效果）
    private func applyApocalypseFilter(to mapView: MKMapView) {
        // 色调控制：降低饱和度和亮度
        let colorControls = CIFilter(name: "CIColorControls")
        colorControls?.setValue(-0.15, forKey: kCIInputBrightnessKey) // 稍微变暗
        colorControls?.setValue(0.5, forKey: kCIInputSaturationKey) // 降低饱和度

        // 棕褐色调：废土的泛黄效果
        let sepiaFilter = CIFilter(name: "CISepiaTone")
        sepiaFilter?.setValue(0.65, forKey: kCIInputIntensityKey) // 中等强度的棕褐色

        // 应用滤镜到地图图层
        if let colorControls = colorControls, let sepiaFilter = sepiaFilter {
            mapView.layer.filters = [colorControls, sepiaFilter]
        }
    }

    // MARK: - Coordinator
    /// 地图代理协调器：处理地图事件、实现自动居中
    class Coordinator: NSObject, MKMapViewDelegate {

        // MARK: - Properties

        /// 父视图引用
        var parent: MapViewRepresentable

        // MARK: - Initialization

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        // MARK: - MKMapViewDelegate

        /// ⭐ 关键方法：用户位置更新时调用（地图自动居中的核心）
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // 获取位置坐标
            guard let location = userLocation.location else { return }

            // 更新绑定的用户位置
            DispatchQueue.main.async {
                self.parent.userLocation = location.coordinate
            }

            // 如果已经完成首次居中，不再自动居中（允许用户手动拖动地图）
            // ⚠️ 使用 parent.hasLocatedUser 而不是本地变量，这样点击定位按钮可以重新居中
            guard !parent.hasLocatedUser else { return }

            // 创建居中区域（显示约1公里范围）
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 1000, // 纬度方向1公里
                longitudinalMeters: 1000 // 经度方向1公里
            )

            // ⭐ 平滑居中地图到用户位置
            mapView.setRegion(region, animated: true)

            // 更新外部状态
            DispatchQueue.main.async {
                self.parent.hasLocatedUser = true
            }
        }

        /// Day 20: 地图区域改变时调用（处理拖动、缩放）
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let region = mapView.region

            // 更新绑定的地图区域
            DispatchQueue.main.async {
                self.parent.currentMapRegion = region
            }

            // 调用回调函数
            if let onRegionChanged = parent.onRegionChanged {
                DispatchQueue.main.async {
                    onRegionChanged(region)
                }
            }
        }

        /// 地图加载完成时调用
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            // 地图初次加载完成
        }

        // MARK: - Path Tracking

        /// 已绘制的领地 ID 集合（用于避免重复绘制）
        private var renderedTerritoryIds: Set<String> = []

        /// 更新追踪路径
        /// - Parameters:
        ///   - mapView: 地图视图
        ///   - coordinates: 路径坐标数组
        ///   - version: 路径版本号（用于强制更新）
        func updateTrackingPath(on mapView: MKMapView, coordinates: [CLLocationCoordinate2D], version: Int) {
            // 移除当前追踪路径的 overlays（但保留已上传领地的 overlays）
            mapView.overlays.forEach { overlay in
                // 只移除 MKPolyline 和没有 title 的 MKPolygon（当前追踪路径）
                if overlay is MKPolyline {
                    mapView.removeOverlay(overlay)
                } else if let polygon = overlay as? MKPolygon, polygon.title == nil {
                    mapView.removeOverlay(overlay)
                }
            }

            // 如果没有坐标点，直接返回
            guard coordinates.count >= 2 else {
                print("⚠️  [地图渲染] 坐标点不足2个（当前:\(coordinates.count)），跳过绘制")
                return
            }

            print("\n🎨 [地图渲染] ========== 绘制路径 (版本 \(version)) ==========")
            print("📍 [地图渲染] 原始坐标点数: \(coordinates.count)")
            print("🔒 [地图渲染] 闭环状态: \(parent.isPathClosed ? "已闭环" : "未闭环")")

            // ⭐ iOS MapKit 在中国已使用 GCJ-02 坐标系，无需转换
            // CoreLocation 返回的坐标已经是 GCJ-02，直接使用即可
            print("✅ [地图渲染] 直接使用原始坐标（iOS 已自动处理）")

            // 创建 MKPolyline（路径线）
            var mutableCoordinates = coordinates
            let polyline = MKPolyline(coordinates: &mutableCoordinates, count: coordinates.count)

            // 添加路径线到地图
            mapView.addOverlay(polyline)

            // 如果已闭环且点数≥3，添加多边形填充
            if parent.isPathClosed && coordinates.count >= 3 {
                var polygonCoordinates = coordinates
                let polygon = MKPolygon(coordinates: &polygonCoordinates, count: coordinates.count)
                mapView.addOverlay(polygon)
                print("✅ [地图渲染] 已添加多边形填充")
            }

            print("✅ [地图渲染] 路径已添加到地图")
            print("🎨 [地图渲染] ========== 绘制完成 ==========\n")
        }

        /// 更新已上传的领地
        /// - Parameters:
        ///   - mapView: 地图视图
        ///   - territories: 领地列表
        func updateUploadedTerritories(on mapView: MKMapView, territories: [TerritoryData]) {
            print("\n🏛️  [已上传领地] 开始更新，领地数: \(territories.count)")

            // 当前领地 ID 集合
            let currentTerritoryIds = Set(territories.map { $0.id })

            // 移除不在当前列表中的领地
            mapView.overlays.forEach { overlay in
                if let polygon = overlay as? MKPolygon,
                   let territoryId = polygon.title,
                   !currentTerritoryIds.contains(territoryId) {
                    mapView.removeOverlay(overlay)
                    renderedTerritoryIds.remove(territoryId)
                    print("🗑️  [已上传领地] 移除领地: \(territoryId)")
                }
            }

            // 添加新领地
            for territory in territories {
                // 跳过已绘制的领地
                guard !renderedTerritoryIds.contains(territory.id) else {
                    continue
                }

                let coordinates = territory.toCoordinates()
                guard coordinates.count >= 3 else {
                    print("⚠️  [已上传领地] 领地 \(territory.id) 坐标点不足3个，跳过")
                    continue
                }

                var coords = coordinates
                let polygon = MKPolygon(coordinates: &coords, count: coords.count)
                polygon.title = territory.id // 使用 title 存储领地 ID
                polygon.subtitle = territory.userId // 使用 subtitle 存储用户 ID
                mapView.addOverlay(polygon)
                renderedTerritoryIds.insert(territory.id)

                print("✅ [已上传领地] 添加领地: \(territory.id), 用户: \(territory.userId), 面积: \(territory.area)m²")
            }

            print("🏛️  [已上传领地] 更新完成，当前显示 \(renderedTerritoryIds.count) 个领地\n")
        }

        /// ⭐ 关键方法：渲染覆盖层（绘制路径线条和多边形）
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // 如果是路径线（当前追踪路径）
            if let polyline = overlay as? MKPolyline {
                print("🖌️  [地图渲染] 创建路径渲染器")

                let renderer = MKPolylineRenderer(polyline: polyline)

                // 根据闭环状态选择颜色
                let lineColor: UIColor
                let colorName: String

                if parent.isPathClosed {
                    lineColor = UIColor.systemGreen // 闭环后变绿色
                    colorName = "绿色"
                } else {
                    lineColor = UIColor.systemCyan // 未闭环是青蓝色
                    colorName = "青蓝色"
                }

                // 路径样式
                renderer.strokeColor = lineColor.withAlphaComponent(0.9) // 90% 不透明度
                renderer.lineWidth = 4.0 // 线宽 4 像素
                renderer.lineCap = .round // 圆角端点
                renderer.lineJoin = .round // 圆角连接

                print("✅ [地图渲染] 路径样式已配置")
                print("   - 颜色: \(colorName)")
                print("   - 宽度: 4.0 像素")

                return renderer
            }

            // 如果是多边形
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                // 判断是当前追踪路径还是已上传领地
                if let territoryId = polygon.title {
                    // 已上传的领地：根据用户ID决定颜色
                    // 注意：UUID 比较需要忽略大小写（Swift 返回大写，数据库存储小写）
                    let userId = polygon.subtitle?.lowercased()
                    let currentId = parent.currentUserId?.lowercased()
                    let isOwnTerritory = (userId != nil && userId == currentId)

                    if isOwnTerritory {
                        // 自己的领地：绿色
                        print("🖌️  [地图渲染] 创建自己的领地渲染器: \(territoryId), userId=\(userId ?? "nil"), currentId=\(currentId ?? "nil")")
                        renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25) // 半透明绿色填充
                        renderer.strokeColor = UIColor.systemGreen.withAlphaComponent(0.8) // 绿色边框
                        renderer.lineWidth = 2.0 // 边框宽度
                    } else {
                        // 他人的领地：黄色
                        print("🖌️  [地图渲染] 创建他人的领地渲染器: \(territoryId), userId=\(userId ?? "nil"), currentId=\(currentId ?? "nil")")
                        renderer.fillColor = UIColor.systemYellow.withAlphaComponent(0.25) // 半透明黄色填充
                        renderer.strokeColor = UIColor.systemYellow.withAlphaComponent(0.8) // 黄色边框
                        renderer.lineWidth = 2.0 // 边框宽度
                    }
                } else {
                    // 当前追踪路径：绿色
                    print("🖌️  [地图渲染] 创建当前追踪路径多边形渲染器")
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.3) // 稍微亮一些
                    renderer.strokeColor = UIColor.systemGreen // 绿色边框
                    renderer.lineWidth = 2.5 // 稍微粗一些
                }

                print("✅ [地图渲染] 多边形样式已配置")

                return renderer
            }

            // 默认渲染器
            return MKOverlayRenderer(overlay: overlay)
        }

        // MARK: - POI Annotations (Day 22)

        /// 已渲染的POI ID集合
        private var renderedPOIIds: Set<String> = []

        /// 更新POI标记
        func updatePOIAnnotations(on mapView: MKMapView, pois: [POIData], scavengedIds: Set<String>) {
            // 当前POI ID集合
            let currentPOIIds = Set(pois.map { $0.id })

            // 移除不在当前列表中的标记
            mapView.annotations.forEach { annotation in
                if let poiAnnotation = annotation as? POIAnnotation,
                   !currentPOIIds.contains(poiAnnotation.poiId) {
                    mapView.removeAnnotation(annotation)
                    renderedPOIIds.remove(poiAnnotation.poiId)
                }
            }

            // 添加新POI标记
            for poi in pois {
                // 如果已存在，检查是否需要更新搜刮状态
                if let existingAnnotation = mapView.annotations.compactMap({ $0 as? POIAnnotation }).first(where: { $0.poiId == poi.id }) {
                    let isScavenged = scavengedIds.contains(poi.id)
                    if existingAnnotation.isScavenged != isScavenged {
                        // 状态变化，移除旧标记并重新添加
                        mapView.removeAnnotation(existingAnnotation)
                        renderedPOIIds.remove(poi.id)
                    } else {
                        continue // 无需更新
                    }
                }

                // 跳过已绘制的POI
                guard !renderedPOIIds.contains(poi.id) else { continue }

                // 创建标记
                let annotation = POIAnnotation(poi: poi, isScavenged: scavengedIds.contains(poi.id))
                mapView.addAnnotation(annotation)
                renderedPOIIds.insert(poi.id)
            }
        }

        /// 自定义POI标记视图
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 忽略用户位置标记
            guard !(annotation is MKUserLocation) else { return nil }

            // 处理POI标记
            if let poiAnnotation = annotation as? POIAnnotation {
                let identifier = "POIAnnotation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: poiAnnotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = poiAnnotation
                }

                // 根据POI类型和搜刮状态设置样式
                if poiAnnotation.isScavenged {
                    // 已搜刮：灰色
                    annotationView?.markerTintColor = .gray
                    annotationView?.glyphImage = UIImage(systemName: "checkmark")
                } else {
                    // 未搜刮：根据类型设置颜色和图标
                    annotationView?.markerTintColor = markerColor(for: poiAnnotation.poiType)
                    annotationView?.glyphImage = UIImage(systemName: poiAnnotation.poiType.iconName)
                }

                return annotationView
            }

            return nil
        }

        /// 根据POI类型获取标记颜色
        private func markerColor(for type: POIType) -> UIColor {
            switch type {
            case .supermarket: return .systemOrange
            case .hospital: return .systemRed
            case .pharmacy: return .systemGreen
            case .gasStation: return .systemBlue
            case .warehouse: return .systemBrown
            case .factory: return .systemGray
            case .residence: return .systemTeal
            case .policeStation: return .systemIndigo
            }
        }
    }
}

// MARK: - POI Annotation

/// POI标记类
class POIAnnotation: NSObject, MKAnnotation {
    let poiId: String
    let poiType: POIType
    let poiName: String
    var isScavenged: Bool

    var coordinate: CLLocationCoordinate2D
    var title: String? { poiName }
    var subtitle: String? { poiType.displayName }

    init(poi: POIData, isScavenged: Bool) {
        self.poiId = poi.id
        self.poiType = poi.type
        self.poiName = poi.name
        self.coordinate = poi.coordinate
        self.isScavenged = isScavenged
        super.init()
    }
}

