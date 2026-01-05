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

    /// 路径是否已闭环
    @Published var isPathClosed = false

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 是否超速
    @Published var isOverSpeed = false

    // MARK: - Private Properties

    /// CoreLocation定位管理器
    private let locationManager = CLLocationManager()

    /// 定时器（每1秒记录一次位置）
    private var trackingTimer: Timer?

    /// 最小距离间隔（米）- 降低到5米以获得更细腻的轨迹
    private let minimumDistance: CLLocationDistance = 5.0

    /// 闭环距离阈值（米）- 距离起点30米内视为闭环
    private let closureDistanceThreshold: Double = 30.0

    /// 最少路径点数 - 至少10个点才能判断闭环
    private let minimumPathPoints: Int = 10

    /// 上次位置的时间戳（用于计算速度）
    private var lastLocationTimestamp: Date?

    /// 上次位置（用于计算速度）
    private var lastLocation: CLLocation?

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
        isPathClosed = false
        speedWarning = nil
        isOverSpeed = false
        lastLocationTimestamp = nil
        lastLocation = nil

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

        // 创建 CLLocation 对象
        let currentCLLocation = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)

        // 速度检测（第2个点开始检测）
        if !pathCoordinates.isEmpty {
            if !validateMovementSpeed(newLocation: currentCLLocation) {
                print("⚠️  [路径追踪] 超速，跳过本次记录")
                return
            }
        }

        // 如果是第一个点，直接添加
        if pathCoordinates.isEmpty {
            pathCoordinates.append(currentLocation)
            pathUpdateVersion += 1
            lastLocation = currentCLLocation
            lastLocationTimestamp = Date()
            print("📍 [路径追踪] 记录起始点: (\(String(format: "%.6f", currentLocation.latitude)), \(String(format: "%.6f", currentLocation.longitude)))")
            print("✅ [路径追踪] 当前路径点数: \(pathCoordinates.count)")
            return
        }

        // 检查距离上一个点是否 > 5米（降低阈值以获得更细腻的轨迹）
        let lastCoordinate = pathCoordinates.last!
        let lastLocationPoint = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
        let distance = currentCLLocation.distance(from: lastLocationPoint)

        if distance > minimumDistance {
            pathCoordinates.append(currentLocation)
            pathUpdateVersion += 1
            lastLocation = currentCLLocation
            lastLocationTimestamp = Date()
            print("📍 [路径追踪] 记录新点: (\(String(format: "%.6f", currentLocation.latitude)), \(String(format: "%.6f", currentLocation.longitude)))")
            print("📏 [路径追踪] 距离上一点: \(String(format: "%.1f", distance)) 米")
            print("✅ [路径追踪] 当前路径点数: \(pathCoordinates.count)")

            // 检查是否闭环
            checkPathClosure()
        } else {
            print("⏭️  [路径追踪] 距离不足 5 米（\(String(format: "%.1f", distance))m），跳过")
        }
    }

    /// 检查路径是否闭环
    private func checkPathClosure() {
        // 已经闭环则不再检查
        guard !isPathClosed else { return }

        // 检查点数是否足够
        guard pathCoordinates.count >= minimumPathPoints else {
            print("⏭️  [闭环检测] 点数不足 \(minimumPathPoints) 个，当前：\(pathCoordinates.count)")
            return
        }

        // 获取起点和当前位置
        let startPoint = pathCoordinates[0]
        let currentPoint = pathCoordinates.last!

        // 计算距离
        let startLocation = CLLocation(latitude: startPoint.latitude, longitude: startPoint.longitude)
        let currentLocation = CLLocation(latitude: currentPoint.latitude, longitude: currentPoint.longitude)
        let distance = currentLocation.distance(from: startLocation)

        print("🔍 [闭环检测] 距离起点: \(String(format: "%.1f", distance)) 米 (阈值: \(closureDistanceThreshold) 米)")

        // 判断是否在阈值内
        if distance <= closureDistanceThreshold {
            isPathClosed = true
            pathUpdateVersion += 1
            print("🎉 [闭环检测] ========== 闭环成功！==========")
            print("✅ [闭环检测] 距离起点: \(String(format: "%.1f", distance)) 米")
            print("✅ [闭环检测] 总路径点数: \(pathCoordinates.count)")
        } else {
            print("⏭️  [闭环检测] 距离过远，继续追踪")
        }
    }

    /// 验证移动速度（防止作弊）
    /// - Parameter newLocation: 新位置
    /// - Returns: true 表示速度正常，false 表示超速
    private func validateMovementSpeed(newLocation: CLLocation) -> Bool {
        // 检查是否有上次位置记录
        guard let lastLoc = lastLocation, let lastTime = lastLocationTimestamp else {
            return true // 第一个点，无法计算速度
        }

        // 计算时间差（秒）
        let timeInterval = Date().timeIntervalSince(lastTime)
        guard timeInterval > 0 else { return true }

        // 计算距离（米）
        let distance = newLocation.distance(from: lastLoc)

        // 计算速度（km/h）
        let speed = (distance / timeInterval) * 3.6

        print("🚗 [速度检测] 当前速度: \(String(format: "%.1f", speed)) km/h")

        // 速度超过 30 km/h，暂停追踪
        if speed > 30 {
            speedWarning = "速度过快（\(String(format: "%.1f", speed)) km/h），已暂停圈地"
            isOverSpeed = true
            print("⚠️  [速度检测] 速度过快，暂停追踪")
            stopPathTracking()
            return false
        }

        // 速度超过 15 km/h，显示警告
        if speed > 15 {
            speedWarning = "速度过快（\(String(format: "%.1f", speed)) km/h），请减速"
            isOverSpeed = true
            print("⚠️  [速度检测] 速度过快，警告")
            return true // 仍然记录，但显示警告
        }

        // 速度正常，清除警告
        speedWarning = nil
        isOverSpeed = false
        return true
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
