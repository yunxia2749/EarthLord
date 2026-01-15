//
//  TerritoryManager.swift
//  EarthLord
//
//  Created by Claude on 2026/01/10.
//

import Foundation
import CoreLocation
import Supabase
import Combine

/// 领地管理器
/// 负责领地的上传和拉取
@MainActor
class TerritoryManager: ObservableObject {

    // MARK: - Singleton

    static let shared = TerritoryManager()

    private init() {}

    // MARK: - Properties

    /// 已加载的领地列表（用于碰撞检测）
    @Published var territories: [TerritoryData] = []

    // MARK: - Upload Data Structure

    /// 上传领地的数据结构
    private struct TerritoryUploadData: Encodable {
        let user_id: String
        let path: [[String: Double]]
        let polygon: String
        let bbox_min_lat: Double
        let bbox_max_lat: Double
        let bbox_min_lon: Double
        let bbox_max_lon: Double
        let area: Double
        let point_count: Int
        let started_at: String
        let is_active: Bool
    }

    // MARK: - Private Methods

    /// 将坐标数组转换为 path JSON 格式
    /// - Parameter coordinates: 坐标数组
    /// - Returns: [{"lat": x, "lon": y}, ...]
    private func coordinatesToPathJSON(_ coordinates: [CLLocationCoordinate2D]) -> [[String: Double]] {
        return coordinates.map { coordinate in
            [
                "lat": coordinate.latitude,
                "lon": coordinate.longitude
            ]
        }
    }

    /// 将坐标数组转换为 WKT (Well-Known Text) 格式
    /// ⚠️ 注意：WKT 格式是「经度在前，纬度在后」
    /// ⚠️ 多边形必须闭合（首尾相同）
    /// - Parameter coordinates: 坐标数组
    /// - Returns: WKT 格式字符串，例如：SRID=4326;POLYGON((121.4 31.2, 121.5 31.2, 121.5 31.3, 121.4 31.2))
    private func coordinatesToWKT(_ coordinates: [CLLocationCoordinate2D]) -> String {
        var points = coordinates

        // 确保多边形闭合（首尾相同）
        if let first = points.first, let last = points.last {
            if first.latitude != last.latitude || first.longitude != last.longitude {
                points.append(first)
            }
        }

        // WKT 格式：经度在前，纬度在后
        let wktPoints = points.map { coordinate in
            "\(coordinate.longitude) \(coordinate.latitude)"
        }.joined(separator: ", ")

        return "SRID=4326;POLYGON((\(wktPoints)))"
    }

    /// 计算边界框
    /// - Parameter coordinates: 坐标数组
    /// - Returns: (minLat, maxLat, minLon, maxLon)
    private func calculateBoundingBox(_ coordinates: [CLLocationCoordinate2D]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        guard !coordinates.isEmpty else {
            return (0, 0, 0, 0)
        }

        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }

        return (
            minLat: lats.min() ?? 0,
            maxLat: lats.max() ?? 0,
            minLon: lons.min() ?? 0,
            maxLon: lons.max() ?? 0
        )
    }

    // MARK: - Public Methods

    /// 确保 session 有效（必要时刷新）
    /// - Returns: 有效的用户 ID
    /// - Throws: 认证错误
    private func ensureValidSession() async throws -> UUID {
        print("🔍 [TerritoryManager] 检查 session 状态...")

        do {
            // 第一次尝试：直接获取 session（会自动刷新 access token）
            // 添加 8 秒超时
            let session = try await withTimeout(seconds: 8) {
                try await supabase.auth.session
            }
            let userId = session.user.id

            print("✅ [TerritoryManager] Session 有效")
            print("   - User ID: \(userId.uuidString)")
            print("   - Email: \(session.user.email ?? "未知")")

            return userId

        } catch {
            print("⚠️  [TerritoryManager] 第一次获取 session 失败: \(error.localizedDescription)")

            // 如果是超时错误，直接抛出，不再尝试刷新
            if (error as NSError).domain == "TimeoutError" {
                throw NSError(
                    domain: "TerritoryManager",
                    code: -1001,
                    userInfo: [NSLocalizedDescriptionKey: "网络连接超时，请检查网络后重试"]
                )
            }

            // 第二次尝试：显式刷新 session（5秒超时）
            do {
                let refreshedSession = try await withTimeout(seconds: 5) {
                    try await supabase.auth.refreshSession()
                }
                let userId = refreshedSession.user.id

                print("✅ [TerritoryManager] Session 刷新成功")
                print("   - User ID: \(userId.uuidString)")
                print("   - Email: \(refreshedSession.user.email ?? "未知")")

                return userId

            } catch let refreshError {
                print("❌ [TerritoryManager] Session 刷新失败")
                print("   - 刷新错误: \(refreshError.localizedDescription)")
                print("   - 原始错误: \(error.localizedDescription)")
                print("   - 建议：用户需要重新登录")

                throw NSError(
                    domain: "TerritoryManager",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "登录已过期，请退出后重新登录"]
                )
            }
        }
    }

    // MARK: - Timeout Utility

    /// 为异步操作添加超时支持
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(
                    domain: "TimeoutError",
                    code: -1001,
                    userInfo: [NSLocalizedDescriptionKey: "操作超时（\(Int(seconds))秒）"]
                )
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    /// 上传领地到 Supabase
    /// - Parameters:
    ///   - coordinates: 坐标数组
    ///   - area: 面积（平方米）
    ///   - startTime: 开始圈地时间
    /// - Throws: 上传错误
    func uploadTerritory(
        coordinates: [CLLocationCoordinate2D],
        area: Double,
        startTime: Date
    ) async throws {
        print("🚀 [TerritoryManager] 开始上传领地")
        print("   - 坐标点数: \(coordinates.count)")
        print("   - 面积: \(area) m²")

        // 确保 session 有效
        let userId = try await ensureValidSession()

        // 继续上传流程
        try await performUpload(userId: userId, coordinates: coordinates, area: area, startTime: startTime)
    }

    /// 执行实际的上传操作
    private func performUpload(
        userId: UUID,
        coordinates: [CLLocationCoordinate2D],
        area: Double,
        startTime: Date
    ) async throws {

        // 1. 转换坐标为 path JSON
        let pathJSON = coordinatesToPathJSON(coordinates)

        // 2. 转换坐标为 WKT 格式
        let wktPolygon = coordinatesToWKT(coordinates)

        // 3. 计算边界框
        let bbox = calculateBoundingBox(coordinates)

        // 4. 准备上传数据
        let uploadData = TerritoryUploadData(
            user_id: userId.uuidString,
            path: pathJSON,
            polygon: wktPolygon,
            bbox_min_lat: bbox.minLat,
            bbox_max_lat: bbox.maxLat,
            bbox_min_lon: bbox.minLon,
            bbox_max_lon: bbox.maxLon,
            area: area,
            point_count: coordinates.count,
            started_at: startTime.ISO8601Format(),
            is_active: true
        )

        print("📤 [TerritoryManager] 上传数据:")
        print("   - user_id: \(userId.uuidString)")
        print("   - point_count: \(coordinates.count)")
        print("   - area: \(area)")
        print("   - bbox: (\(bbox.minLat), \(bbox.maxLat), \(bbox.minLon), \(bbox.maxLon))")

        // 5. 上传到 Supabase（优化：移除 select 减少往返时间）
        do {
            try await supabase
                .from("territories")
                .insert(uploadData)
                .execute()

            print("✅ [TerritoryManager] 领地上传成功")
            TerritoryLogger.shared.log("领地上传成功！面积: \(Int(area))m²", type: .success)
        } catch {
            print("❌ [TerritoryManager] 领地上传失败: \(error)")
            TerritoryLogger.shared.log("领地上传失败: \(error.localizedDescription)", type: .error)
            throw error
        }
    }

    /// 加载可见范围内的领地（PostGIS 优化版 - 边界框版本）
    /// - Parameters:
    ///   - minLat: 最小纬度
    ///   - minLng: 最小经度
    ///   - maxLat: 最大纬度
    ///   - maxLng: 最大经度
    ///   - zoomLevel: 地图缩放级别（用于控制坐标简化）
    /// - Returns: 简化后的领地数组
    /// - Throws: 加载错误
    func loadVisibleTerritories(
        minLat: Double,
        minLng: Double,
        maxLat: Double,
        maxLng: Double,
        zoomLevel: Double = 15.0
    ) async throws -> [TerritoryData] {
        print("📥 [TerritoryManager] 开始加载可见领地（PostGIS优化）")
        print("   - 边界框: (\(minLat), \(minLng)) → (\(maxLat), \(maxLng))")
        print("   - 缩放级别: \(zoomLevel)")

        do {
            // 调用 PostGIS 函数获取简化的领地数据
            let loadedTerritories: [TerritoryData] = try await supabase
                .rpc("get_visible_territories", params: [
                    "min_lat": minLat,
                    "min_lng": minLng,
                    "max_lat": maxLat,
                    "max_lng": maxLng,
                    "zoom_level": zoomLevel
                ])
                .execute()
                .value

            // 更新本地缓存（用于碰撞检测）
            self.territories = loadedTerritories

            print("✅ [TerritoryManager] 加载成功，共 \(loadedTerritories.count) 个领地")
            return loadedTerritories
        } catch {
            print("❌ [TerritoryManager] 加载领地失败: \(error)")
            throw error
        }
    }

    /// 加载可见范围内的领地（PostGIS 优化版 - 位置+半径版本）
    /// - Parameters:
    ///   - userLocation: 用户当前位置
    ///   - radiusKm: 查询半径（公里），默认5公里
    ///   - zoomLevel: 地图缩放级别，默认15（用于控制坐标简化）
    /// - Returns: 简化后的领地数组
    /// - Throws: 加载错误
    func loadVisibleTerritories(
        userLocation: CLLocationCoordinate2D,
        radiusKm: Double = 5.0,
        zoomLevel: Double = 15.0
    ) async throws -> [TerritoryData] {
        // 计算边界框
        let latDelta = radiusKm / 111.0  // 1度纬度约111km
        let lonDelta = radiusKm / (111.0 * cos(userLocation.latitude * .pi / 180))

        let minLat = userLocation.latitude - latDelta
        let maxLat = userLocation.latitude + latDelta
        let minLng = userLocation.longitude - lonDelta
        let maxLng = userLocation.longitude + lonDelta

        // 调用边界框版本
        return try await loadVisibleTerritories(
            minLat: minLat,
            minLng: minLng,
            maxLat: maxLat,
            maxLng: maxLng,
            zoomLevel: zoomLevel
        )
    }

    /// 加载所有活跃的领地（旧方法，保留向后兼容）
    /// - Returns: 领地数组
    /// - Throws: 加载错误
    /// - Warning: 此方法性能较差，建议使用 loadVisibleTerritories
    func loadAllTerritories() async throws -> [TerritoryData] {
        print("📥 [TerritoryManager] 开始加载领地列表（旧方法）")

        do {
            let loadedTerritories: [TerritoryData] = try await supabase
                .from("territories")
                .select()
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value

            // 更新本地缓存（用于碰撞检测）
            self.territories = loadedTerritories

            print("✅ [TerritoryManager] 加载成功，共 \(loadedTerritories.count) 个领地")
            return loadedTerritories
        } catch {
            print("❌ [TerritoryManager] 加载领地失败: \(error)")
            throw error
        }
    }

    // MARK: - 碰撞检测算法

    /// 射线法判断点是否在多边形内
    func isPointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }

        var inside = false
        let x = point.longitude
        let y = point.latitude

        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude

            let intersect = ((yi > y) != (yj > y)) &&
                           (x < (xj - xi) * (y - yi) / (yj - yi) + xi)

            if intersect {
                inside.toggle()
            }
            j = i
        }

        return inside
    }

    /// 检查起始点是否在他人领地内
    func checkPointCollision(location: CLLocationCoordinate2D, currentUserId: String) -> CollisionResult {
        let otherTerritories = territories.filter { territory in
            territory.userId.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else {
            return .safe
        }

        for territory in otherTerritories {
            let polygon = territory.toCoordinates()
            guard polygon.count >= 3 else { continue }

            if isPointInPolygon(point: location, polygon: polygon) {
                TerritoryLogger.shared.log("起点碰撞：位于他人领地内", type: .error)
                return CollisionResult(
                    hasCollision: true,
                    collisionType: .pointInTerritory,
                    message: "不能在他人领地内开始圈地！",
                    closestDistance: 0,
                    warningLevel: .violation
                )
            }
        }

        return .safe
    }

    /// 判断两条线段是否相交（CCW 算法）
    private func segmentsIntersect(
        p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
        p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D
    ) -> Bool {
        func ccw(_ A: CLLocationCoordinate2D, _ B: CLLocationCoordinate2D, _ C: CLLocationCoordinate2D) -> Bool {
            return (C.latitude - A.latitude) * (B.longitude - A.longitude) >
                   (B.latitude - A.latitude) * (C.longitude - A.longitude)
        }

        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 检查路径是否穿越他人领地边界
    func checkPathCrossTerritory(path: [CLLocationCoordinate2D], currentUserId: String) -> CollisionResult {
        guard path.count >= 2 else { return .safe }

        let otherTerritories = territories.filter { territory in
            territory.userId.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else { return .safe }

        for i in 0..<(path.count - 1) {
            let pathStart = path[i]
            let pathEnd = path[i + 1]

            for territory in otherTerritories {
                let polygon = territory.toCoordinates()
                guard polygon.count >= 3 else { continue }

                // 检查与领地每条边的相交
                for j in 0..<polygon.count {
                    let boundaryStart = polygon[j]
                    let boundaryEnd = polygon[(j + 1) % polygon.count]

                    if segmentsIntersect(p1: pathStart, p2: pathEnd, p3: boundaryStart, p4: boundaryEnd) {
                        TerritoryLogger.shared.log("路径碰撞：轨迹穿越他人领地边界", type: .error)
                        return CollisionResult(
                            hasCollision: true,
                            collisionType: .pathCrossTerritory,
                            message: "轨迹不能穿越他人领地！",
                            closestDistance: 0,
                            warningLevel: .violation
                        )
                    }
                }

                // 检查路径点是否在领地内
                if isPointInPolygon(point: pathEnd, polygon: polygon) {
                    TerritoryLogger.shared.log("路径碰撞：轨迹点进入他人领地", type: .error)
                    return CollisionResult(
                        hasCollision: true,
                        collisionType: .pointInTerritory,
                        message: "轨迹不能进入他人领地！",
                        closestDistance: 0,
                        warningLevel: .violation
                    )
                }
            }
        }

        return .safe
    }

    /// 计算当前位置到他人领地的最近距离
    func calculateMinDistanceToTerritories(location: CLLocationCoordinate2D, currentUserId: String) -> Double {
        let otherTerritories = territories.filter { territory in
            territory.userId.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else { return Double.infinity }

        var minDistance = Double.infinity
        let currentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)

        for territory in otherTerritories {
            let polygon = territory.toCoordinates()

            for vertex in polygon {
                let vertexLocation = CLLocation(latitude: vertex.latitude, longitude: vertex.longitude)
                let distance = currentLocation.distance(from: vertexLocation)
                minDistance = min(minDistance, distance)
            }
        }

        return minDistance
    }

    /// 综合碰撞检测（主方法）
    func checkPathCollisionComprehensive(path: [CLLocationCoordinate2D], currentUserId: String) -> CollisionResult {
        guard path.count >= 2 else { return .safe }

        // 1. 检查路径是否穿越他人领地
        let crossResult = checkPathCrossTerritory(path: path, currentUserId: currentUserId)
        if crossResult.hasCollision {
            return crossResult
        }

        // 2. 计算到最近领地的距离
        guard let lastPoint = path.last else { return .safe }
        let minDistance = calculateMinDistanceToTerritories(location: lastPoint, currentUserId: currentUserId)

        // 3. 根据距离确定预警级别和消息
        let warningLevel: WarningLevel
        let message: String?

        if minDistance > 100 {
            warningLevel = .safe
            message = nil
        } else if minDistance > 50 {
            warningLevel = .caution
            message = "注意：距离他人领地 \(Int(minDistance))m"
        } else if minDistance > 25 {
            warningLevel = .warning
            message = "警告：正在靠近他人领地（\(Int(minDistance))m）"
        } else {
            warningLevel = .danger
            message = "危险：即将进入他人领地！（\(Int(minDistance))m）"
        }

        if warningLevel != .safe {
            TerritoryLogger.shared.log("距离预警：\(warningLevel.description)，距离 \(Int(minDistance))m", type: .warning)
        }

        return CollisionResult(
            hasCollision: false,
            collisionType: nil,
            message: message,
            closestDistance: minDistance,
            warningLevel: warningLevel
        )
    }
}
