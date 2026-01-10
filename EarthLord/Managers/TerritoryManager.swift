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
        guard let userId = try? await supabase.auth.session.user.id else {
            print("❌ [TerritoryManager] 未登录，无法上传领地")
            throw NSError(domain: "TerritoryManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
        }

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
            let territories: [TerritoryData] = try await supabase
                .from("territories")
                .select()
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value

            print("✅ [TerritoryManager] 加载成功，共 \(territories.count) 个领地")
            return territories
        } catch {
            print("❌ [TerritoryManager] 加载领地失败: \(error)")
            throw error
        }
    }
}
