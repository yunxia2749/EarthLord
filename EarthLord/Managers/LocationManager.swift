//
//  LocationManager.swift
//  EarthLord
//
//  GPS定位管理器：处理定位权限、获取用户位置
//

import Foundation
import CoreLocation
import Combine

// MARK: - LocationManager
/// 定位管理器：负责请求定位权限、获取GPS坐标
class LocationManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// 用户当前位置坐标
    @Published var userLocation: CLLocationCoordinate2D?

    /// 定位权限状态
    @Published var authorizationStatus: CLAuthorizationStatus

    /// 定位错误信息
    @Published var locationError: String?

    /// 是否正在追踪路径
    @Published var isTracking = false

    /// 路径坐标数组
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []

    /// 路径更新版本号（用于强制 SwiftUI 更新）
    @Published var pathUpdateVersion = 0

    // MARK: - Private Properties

    /// CoreLocation定位管理器
    private let locationManager = CLLocationManager()

    /// 定时器（每1秒记录一次位置）
    private var trackingTimer: Timer?

    /// 最小距离间隔（米）- 降低到5米以获得更细腻的轨迹
    private let minimumDistance: CLLocationDistance = 5.0

    // MARK: - Initialization

    override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation // 导航级最高精度
        locationManager.distanceFilter = 3 // 移动3米才更新位置（更细腻的轨迹）
    }

    // MARK: - Public Methods

    /// 请求定位权限（使用App期间）
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// 开始更新位置
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }

    /// 停止更新位置
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - Path Tracking Methods

    /// 开始追踪路径（圈地）
    func startPathTracking() {
        print("\n🎯 [路径追踪] ========== 开始圈地 ==========")
        print("📍 [路径追踪] 清空之前的路径数据")

        // 重置状态
        isTracking = true
        pathCoordinates.removeAll()
        pathUpdateVersion = 0

        print("✅ [路径追踪] 状态已重置")
        print("⏱️  [路径追踪] 启动定时器（每1秒记录一次）")

        // 启动定时器，每1秒记录一次位置（提高记录频率）
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.recordPathPoint()
        }

        print("🎯 [路径追踪] ========== 圈地已启动 ==========\n")
    }

    /// 停止追踪路径
    func stopPathTracking() {
        print("\n🛑 [路径追踪] ========== 停止圈地 ==========")
        print("📊 [路径追踪] 总记录点数: \(pathCoordinates.count)")

        isTracking = false
        trackingTimer?.invalidate()
        trackingTimer = nil

        print("⏱️  [路径追踪] 定时器已停止")
        print("🛑 [路径追踪] ========== 圈地已停止 ==========\n")
    }

    /// 清除路径
    func clearPath() {
        print("\n🗑️  [路径追踪] 清除路径数据")
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        print("✅ [路径追踪] 路径已清除\n")
    }

    // MARK: - Private Methods

    /// 记录路径点
    private func recordPathPoint() {
        // 检查当前位置
        guard let currentLocation = userLocation else {
            print("⚠️  [路径追踪] 当前位置为 nil，跳过本次记录")
            return
        }

        // 如果是第一个点，直接添加
        if pathCoordinates.isEmpty {
            pathCoordinates.append(currentLocation)
            pathUpdateVersion += 1
            print("📍 [路径追踪] 记录起始点: (\(String(format: "%.6f", currentLocation.latitude)), \(String(format: "%.6f", currentLocation.longitude)))")
            print("✅ [路径追踪] 当前路径点数: \(pathCoordinates.count)")
            return
        }

        // 检查距离上一个点是否 > 5米（降低阈值以获得更细腻的轨迹）
        let lastCoordinate = pathCoordinates.last!
        let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
        let currentCLLocation = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
        let distance = currentCLLocation.distance(from: lastLocation)

        if distance > minimumDistance {
            pathCoordinates.append(currentLocation)
            pathUpdateVersion += 1
            print("📍 [路径追踪] 记录新点: (\(String(format: "%.6f", currentLocation.latitude)), \(String(format: "%.6f", currentLocation.longitude)))")
            print("📏 [路径追踪] 距离上一点: \(String(format: "%.1f", distance)) 米")
            print("✅ [路径追踪] 当前路径点数: \(pathCoordinates.count)")
        } else {
            print("⏭️  [路径追踪] 距离不足 5 米（\(String(format: "%.1f", distance))m），跳过")
        }
    }

    // MARK: - Computed Properties

    /// 是否已授权定位
    var isAuthorized: Bool {
        return authorizationStatus == .authorizedWhenInUse ||
               authorizationStatus == .authorizedAlways
    }

    /// 是否被拒绝授权
    var isDenied: Bool {
        return authorizationStatus == .denied || authorizationStatus == .restricted
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    /// 定位权限状态改变时调用
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        // 如果已授权，开始定位
        if isAuthorized {
            startUpdatingLocation()
        }
    }

    /// 成功获取位置时调用
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // 更新用户位置
        DispatchQueue.main.async {
            self.userLocation = location.coordinate
            self.locationError = nil
        }
    }

    /// 定位失败时调用
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = "定位失败：\(error.localizedDescription)"
        }
    }
}
