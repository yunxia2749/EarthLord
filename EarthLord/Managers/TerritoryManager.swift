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

        // 获取当前用户ID
        print("🔍 [TerritoryManager] 正在获取 Supabase session...")

        do {
            let session = try await supabase.auth.session
            let userId = session.user.id

            print("✅ [TerritoryManager] 成功获取用户信息")
            print("   - User ID: \(userId.uuidString)")
            print("   - Email: \(session.user.email ?? "未知")")

            // 继续上传流程
            try await performUpload(userId: userId, coordinates: coordinates, area: area, startTime: startTime)

        } catch {
            print("❌ [TerritoryManager] 获取 session 失败: \(error)")
            print("   - 错误类型: \(type(of: error))")
            print("   - 错误详情: \(error.localizedDescription)")
            throw NSError(domain: "TerritoryManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "用户未登录或 session 已过期"])
        }
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

        // 5. 上传到 Supabase
        do {
            let _: TerritoryData = try await supabase
                .from("territories")
                .insert(uploadData)
                .select()
                .single()
                .execute()
                .value

            print("✅ [TerritoryManager] 领地上传成功")
            TerritoryLogger.shared.log("领地上传成功！面积: \(Int(area))m²", type: .success)
        } catch {
            print("❌ [TerritoryManager] 领地上传失败: \(error)")
            TerritoryLogger.shared.log("领地上传失败: \(error.localizedDescription)", type: .error)
            throw error
        }
    }

    /// 加载所有活跃的领地
    /// - Returns: 领地数组
    /// - Throws: 加载错误
    func loadAllTerritories() async throws -> [TerritoryData] {
        print("📥 [TerritoryManager] 开始加载领地列表")

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
