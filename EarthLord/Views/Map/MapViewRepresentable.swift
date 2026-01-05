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

    /// 更新视图（不需要实现）
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 空实现即可，Coordinator会处理位置更新
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

        /// 地图区域改变时调用
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 可以在这里处理地图拖动、缩放事件
        }

        /// 地图加载完成时调用
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            // 地图初次加载完成
        }
    }
}
