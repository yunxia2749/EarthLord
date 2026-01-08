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

    // MARK: - 验证状态属性

    /// 领地验证是否通过
    @Published var territoryValidationPassed: Bool = false

    /// 验证失败的错误信息
    @Published var territoryValidationError: String? = nil

    /// 计算出的领地面积（平方米）
    @Published var calculatedArea: Double = 0

    // MARK: - Private Properties

    /// CoreLocation定位管理器
    private let locationManager = CLLocationManager()

    /// 定时器（每1秒记录一次位置）
    private var trackingTimer: Timer?

    /// 最小距离间隔（米）- 用于过滤GPS漂移
    private let minimumDistance: CLLocationDistance = 10.0

    /// 闭环距离阈值（米）- 距离起点30米内视为闭环
    private let closureDistanceThreshold: Double = 30.0

    /// 最少路径点数 - 至少10个点才能判断闭环
    private let minimumPathPoints: Int = 10

    /// GPS预热点数 - 前3个点不检测超速（GPS刚启动时不稳定）
    private let gpsWarmupPoints: Int = 3

    // MARK: - 验证常量

    /// 最小行走距离（米）- 总路径长度需≥50米
    private let minimumTotalDistance: Double = 50.0

    /// 最小领地面积（平方米）- 圈地面积需≥100m²
    private let minimumEnclosedArea: Double = 100.0

    /// 上次记录位置的时间戳（用于计算速度）
    private var lastLocationTimestamp: Date?

    /// 上次记录的位置（用于计算速度）
    private var lastRecordedLocation: CLLocation?

    // MARK: - Initialization

    override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation // 导航级最高精度
        locationManager.distanceFilter = 5 // 移动5米才更新位置（平衡精度和电量）
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
        lastRecordedLocation = nil

        print("✅ [路径追踪] 状态已重置")
        print("⏱️  [路径追踪] 启动定时器（每1秒记录一次）")

        // 添加日志
        TerritoryLogger.shared.log("开始圈地追踪", type: .info)

        // 启动定时器，每1秒记录一次位置（提高记录频率）
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            print("\n⏰ [定时器] 触发 recordPathPoint")
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

        // 添加日志
        TerritoryLogger.shared.log("停止追踪，共 \(pathCoordinates.count) 个点", type: .info)
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
    /// ⚠️ 关键：先检查距离，再检查速度！顺序不能反！
    private func recordPathPoint() {
        // 检查当前位置
        guard let location = userLocation else {
            print("⚠️  [路径追踪] 当前位置为 nil，跳过本次记录")
            return
        }

        let currentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)

        // === 第一个点：直接添加 ===
        if pathCoordinates.isEmpty {
            pathCoordinates.append(location)
            pathUpdateVersion += 1
            lastRecordedLocation = currentLocation
            lastLocationTimestamp = Date()
            print("📍 [路径追踪] 记录起始点: (\(String(format: "%.6f", location.latitude)), \(String(format: "%.6f", location.longitude)))")
            print("✅ [路径追踪] 当前路径点数: \(pathCoordinates.count)")
            return
        }

        // === 第二个点及以后：先距离，再速度 ===

        // 步骤1：先检查距离（过滤GPS漂移，距离不够直接返回）
        let lastCoordinate = pathCoordinates.last!
        let lastLocationPoint = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
        let distance = currentLocation.distance(from: lastLocationPoint)

        guard distance >= minimumDistance else {
            print("⏭️  [路径追踪] 距离不足 \(minimumDistance) 米（当前:\(String(format: "%.1f", distance))m），跳过")
            return  // 距离不够，不进行速度检测，直接返回
        }

        print("📏 [路径追踪] 距离检查通过: \(String(format: "%.1f", distance)) 米")

        // 步骤2：再检查速度（只对真实移动进行检测）
        guard validateMovementSpeed(newLocation: currentLocation) else {
            print("⚠️  [路径追踪] 速度检测未通过，跳过本次记录")
            return  // 严重超速，不记录
        }

        // 步骤3：记录新点
        pathCoordinates.append(location)
        pathUpdateVersion += 1
        lastRecordedLocation = currentLocation
        lastLocationTimestamp = Date()

        print("📍 [路径追踪] 记录新点: (\(String(format: "%.6f", location.latitude)), \(String(format: "%.6f", location.longitude)))")
        print("✅ [路径追踪] 当前路径点数: \(pathCoordinates.count)")

        // 添加日志
        TerritoryLogger.shared.log("记录第 \(pathCoordinates.count) 个点，距上点 \(String(format: "%.1f", distance))m", type: .info)

        // 步骤4：检测闭环
        checkPathClosure()
    }

    /// 检查路径是否闭环
    private func checkPathClosure() {
        // 已经闭环则不再检查
        guard !isPathClosed else {
            return  // 静默返回，不打印日志
        }

        // 检查点数是否足够
        guard pathCoordinates.count >= minimumPathPoints else {
            return  // 点数不够，静默返回
        }

        // 获取起点和当前位置
        let startPoint = pathCoordinates[0]
        let currentPoint = pathCoordinates.last!

        // 计算距离
        let startLocation = CLLocation(latitude: startPoint.latitude, longitude: startPoint.longitude)
        let currentLocation = CLLocation(latitude: currentPoint.latitude, longitude: currentPoint.longitude)
        let distance = currentLocation.distance(from: startLocation)

        print("🔍 [闭环检测] 距离起点: \(String(format: "%.1f", distance)) 米 (阈值: \(closureDistanceThreshold) 米)")
        print("🔍 [闭环检测] 当前点数: \(pathCoordinates.count) 个 (最少: \(minimumPathPoints) 个)")

        // 添加日志（只在点数≥10时显示距离信息）
        TerritoryLogger.shared.log("距起点 \(String(format: "%.1f", distance))m (需≤30m)", type: .info)

        // 判断是否在阈值内
        if distance <= closureDistanceThreshold {
            isPathClosed = true
            pathUpdateVersion += 1

            print("🎉 [闭环检测] ========== 闭环成功！==========")
            print("✅ [闭环检测] 距离起点: \(String(format: "%.1f", distance)) 米")
            print("✅ [闭环检测] 总路径点数: \(pathCoordinates.count)")
            print("🎉 [闭环检测] ========================================")

            // 添加成功日志
            TerritoryLogger.shared.log("闭环成功！距起点 \(String(format: "%.1f", distance))m", type: .success)

            // ⭐ 闭环成功后立即进行领地验证
            let validationResult = validateTerritory()

            // 更新验证状态
            territoryValidationPassed = validationResult.isValid
            territoryValidationError = validationResult.errorMessage

            // 如果验证通过，保存面积
            if validationResult.isValid {
                calculatedArea = calculatePolygonArea()
            } else {
                calculatedArea = 0
            }

            // 闭环成功后自动停止追踪
            DispatchQueue.main.async { [weak self] in
                self?.stopPathTracking()
            }
        }
    }

    /// 验证移动速度（防止作弊）
    /// - Parameter newLocation: 新位置
    /// - Returns: true 表示速度正常，false 表示严重超速
    private func validateMovementSpeed(newLocation: CLLocation) -> Bool {
        // 检查是否有上次记录的位置
        guard let lastLoc = lastRecordedLocation, let lastTime = lastLocationTimestamp else {
            return true // 第一个点，无法计算速度
        }

        // 步骤0：GPS预热期（前3个点不检测超速）
        if pathCoordinates.count < gpsWarmupPoints {
            print("🌡️ [速度检测] GPS预热中，跳过速度检测（\(pathCoordinates.count)/\(gpsWarmupPoints)）")
            return true // 预热期，不检测速度
        }

        // 步骤1：检查位置精度（过滤GPS信号差的情况）
        let accuracy = newLocation.horizontalAccuracy
        if accuracy < 0 || accuracy > 65 {
            print("⚠️  [速度检测] GPS精度太差 (\(String(format: "%.1f", accuracy))米)，忽略本次更新")
            TerritoryLogger.shared.log("GPS精度差 (\(String(format: "%.1f", accuracy))m)，已忽略", type: .warning)
            return false // 忽略这次更新，不记录
        }

        // 计算时间差（秒）
        let timeInterval = Date().timeIntervalSince(lastTime)
        guard timeInterval > 0 else { return true }

        // 计算距离（米）
        let distance = newLocation.distance(from: lastLoc)

        // 计算速度（km/h）
        let speed = (distance / timeInterval) * 3.6

        print("🚗 [速度检测] 距离: \(String(format: "%.1f", distance))米, 时间: \(String(format: "%.1f", timeInterval))秒, 速度: \(String(format: "%.1f", speed)) km/h, 精度: \(String(format: "%.1f", accuracy))米")

        // 步骤2：过滤明显的GPS跳变（速度 > 100 km/h）
        if speed > 100 {
            print("⚠️  [速度检测] 检测到GPS跳变 (\(String(format: "%.1f", speed)) km/h)，忽略本次更新")
            TerritoryLogger.shared.log("GPS跳变 (\(String(format: "%.1f", speed)) km/h)，已忽略", type: .warning)
            return false // 忽略这次更新，不停止追踪
        }

        // 步骤3：检测真实超速（30-100 km/h，可能是开车）
        if speed > 30 {
            speedWarning = "移动速度较快: \(String(format: "%.0f", speed))km/h"
            isOverSpeed = true
            print("⚠️  [速度检测] 速度超过30km/h，暂停追踪")

            // 添加错误日志
            TerritoryLogger.shared.log("超速 \(String(format: "%.1f", speed)) km/h，已停止追踪", type: .error)

            // 主线程停止追踪
            DispatchQueue.main.async { [weak self] in
                self?.stopPathTracking()
            }
            return false
        }

        // 步骤4：速度超过 15 km/h，显示警告但继续记录
        if speed > 15 {
            speedWarning = "移动速度较快: \(String(format: "%.0f", speed))km/h"
            isOverSpeed = true
            print("⚠️  [速度检测] 速度超过15km/h，显示警告但继续记录")

            // 添加警告日志
            TerritoryLogger.shared.log("速度较快 \(String(format: "%.1f", speed)) km/h", type: .warning)

            // 3秒后自动清除警告（只在追踪中的警告才自动消失）
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self = self else { return }
                // 只有当前仍在追踪且警告还在时才清除
                if self.isTracking && self.speedWarning != nil {
                    self.speedWarning = nil
                    self.isOverSpeed = false
                    print("⏱️  [速度检测] 警告已自动清除（3秒后）")
                }
            }

            return true // 仍然记录，但显示警告
        }

        // 速度正常，清除警告
        if speedWarning != nil {
            speedWarning = nil
            isOverSpeed = false
            print("✅ [速度检测] 速度恢复正常")
        }
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

    // MARK: - 距离与面积计算

    /// 计算路径总距离（米）
    /// - Returns: 总距离（米）
    private func calculateTotalPathDistance() -> Double {
        guard pathCoordinates.count >= 2 else { return 0 }

        var totalDistance: Double = 0

        for i in 0..<pathCoordinates.count - 1 {
            let current = CLLocation(
                latitude: pathCoordinates[i].latitude,
                longitude: pathCoordinates[i].longitude
            )
            let next = CLLocation(
                latitude: pathCoordinates[i + 1].latitude,
                longitude: pathCoordinates[i + 1].longitude
            )
            totalDistance += current.distance(from: next)
        }

        return totalDistance
    }

    /// 使用鞋带公式计算多边形面积（考虑地球曲率）
    /// - Returns: 面积（平方米）
    private func calculatePolygonArea() -> Double {
        guard pathCoordinates.count >= 3 else { return 0 }

        let earthRadius: Double = 6371000 // 地球半径（米）
        var area: Double = 0

        for i in 0..<pathCoordinates.count {
            let current = pathCoordinates[i]
            let next = pathCoordinates[(i + 1) % pathCoordinates.count] // 循环取点

            // 经纬度转弧度
            let lat1 = current.latitude * .pi / 180
            let lon1 = current.longitude * .pi / 180
            let lat2 = next.latitude * .pi / 180
            let lon2 = next.longitude * .pi / 180

            // 鞋带公式（球面修正）
            area += (lon2 - lon1) * (2 + sin(lat1) + sin(lat2))
        }

        area = abs(area * earthRadius * earthRadius / 2.0)
        return area
    }

    // MARK: - 自相交检测

    /// CCW 辅助函数（判断三点的旋转方向）
    /// - Parameters:
    ///   - A: 第一个点
    ///   - B: 第二个点
    ///   - C: 第三个点
    /// - Returns: true 表示逆时针，false 表示顺时针或共线
    /// - Note: 坐标映射：longitude = X轴，latitude = Y轴
    private func ccw(A: CLLocationCoordinate2D, B: CLLocationCoordinate2D, C: CLLocationCoordinate2D) -> Bool {
        // 叉积计算：(Cy - Ay) × (Bx - Ax) - (By - Ay) × (Cx - Ax)
        let crossProduct = (C.latitude - A.latitude) * (B.longitude - A.longitude) -
                          (B.latitude - A.latitude) * (C.longitude - A.longitude)
        return crossProduct > 0
    }

    /// 判断两条线段是否相交
    /// - Parameters:
    ///   - p1: 第一条线段的起点
    ///   - p2: 第一条线段的终点
    ///   - p3: 第二条线段的起点
    ///   - p4: 第二条线段的终点
    /// - Returns: true 表示相交，false 表示不相交
    private func segmentsIntersect(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
                                   p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D) -> Bool {
        // CCW 算法判断：
        // 两条线段相交的充要条件是：
        // ccw(p1, p3, p4) ≠ ccw(p2, p3, p4) 且 ccw(p1, p2, p3) ≠ ccw(p1, p2, p4)
        return ccw(A: p1, B: p3, C: p4) != ccw(A: p2, B: p3, C: p4) &&
               ccw(A: p1, B: p2, C: p3) != ccw(A: p1, B: p2, C: p4)
    }

    /// 检测路径是否自相交（画"8"字形则返回 true）
    /// - Returns: true 表示有自交，false 表示无自交
    func hasPathSelfIntersection() -> Bool {
        // ✅ 防御性检查：至少需要4个点才可能自交
        guard pathCoordinates.count >= 4 else { return false }

        // ✅ 创建路径快照的深拷贝，避免并发修改问题
        let pathSnapshot = Array(pathCoordinates)

        // ✅ 再次检查快照是否有效
        guard pathSnapshot.count >= 4 else { return false }

        let segmentCount = pathSnapshot.count - 1

        // ✅ 防御性检查：确保有足够的线段
        guard segmentCount >= 2 else { return false }

        // ✅ 闭环时需要跳过的首尾线段数量
        let skipHeadCount = 2
        let skipTailCount = 2

        for i in 0..<segmentCount {
            guard i < pathSnapshot.count - 1 else { break }

            let p1 = pathSnapshot[i]
            let p2 = pathSnapshot[i + 1]

            let startJ = i + 2
            guard startJ < segmentCount else { continue }

            for j in startJ..<segmentCount {
                guard j < pathSnapshot.count - 1 else { break }

                // ✅ 跳过首尾附近线段的比较（防止正常闭环被误判为自交）
                let isHeadSegment = i < skipHeadCount
                let isTailSegment = j >= segmentCount - skipTailCount
                if isHeadSegment && isTailSegment {
                    continue
                }

                let p3 = pathSnapshot[j]
                let p4 = pathSnapshot[j + 1]

                if segmentsIntersect(p1: p1, p2: p2, p3: p3, p4: p4) {
                    TerritoryLogger.shared.log("自交检测: 线段\(i)-\(i+1) 与 线段\(j)-\(j+1) 相交", type: .error)
                    return true
                }
            }
        }

        TerritoryLogger.shared.log("自交检测: 无交叉 ✓", type: .info)
        return false
    }

    // MARK: - 综合验证

    /// 验证领地是否合法
    /// - Returns: (isValid: 验证是否通过, errorMessage: 错误信息)
    func validateTerritory() -> (isValid: Bool, errorMessage: String?) {
        TerritoryLogger.shared.log("开始领地验证", type: .info)

        // 1. 点数检查
        let pointCount = pathCoordinates.count
        if pointCount < minimumPathPoints {
            let error = "点数不足: \(pointCount)个 (需≥\(minimumPathPoints)个)"
            TerritoryLogger.shared.log("点数检查: \(error) ✗", type: .error)
            TerritoryLogger.shared.log("领地验证失败", type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("点数检查: \(pointCount)个点 ✓", type: .info)

        // 2. 距离检查
        let totalDistance = calculateTotalPathDistance()
        if totalDistance < minimumTotalDistance {
            let error = "距离不足: \(String(format: "%.0f", totalDistance))m (需≥\(String(format: "%.0f", minimumTotalDistance))m)"
            TerritoryLogger.shared.log("距离检查: \(error) ✗", type: .error)
            TerritoryLogger.shared.log("领地验证失败", type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("距离检查: \(String(format: "%.0f", totalDistance))m ✓", type: .info)

        // 3. 自交检测
        if hasPathSelfIntersection() {
            let error = "轨迹自相交，请勿画8字形"
            TerritoryLogger.shared.log("领地验证失败", type: .error)
            return (false, error)
        }

        // 4. 面积检查
        let area = calculatePolygonArea()
        if area < minimumEnclosedArea {
            let error = "面积不足: \(String(format: "%.0f", area))m² (需≥\(String(format: "%.0f", minimumEnclosedArea))m²)"
            TerritoryLogger.shared.log("面积检查: \(error) ✗", type: .error)
            TerritoryLogger.shared.log("领地验证失败", type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("面积检查: \(String(format: "%.0f", area))m² ✓", type: .info)

        // ✅ 验证通过
        TerritoryLogger.shared.log("领地验证通过！面积: \(String(format: "%.0f", area))m²", type: .success)
        return (true, nil)
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
