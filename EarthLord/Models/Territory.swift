//
//  Territory.swift
//  EarthLord
//
//  Created by Claude on 2026/01/10.
//

import Foundation
import CoreLocation

/// 领地数据模型
/// 用于解析从 Supabase 返回的领地数据
struct TerritoryData: Codable, Identifiable {
    /// 领地ID
    let id: String

    /// 用户ID
    let userId: String

    /// 领地名称（可选，数据库允许为空）
    let name: String?

    /// 路径点数组，格式：[{"lat": x, "lon": y}, ...]
    let path: [[String: Double]]

    /// 面积（平方米）
    let area: Double

    /// 路径点数（可选）
    let pointCount: Int?

    /// 是否激活（可选）
    let isActive: Bool?

    /// 编码键映射
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case path
        case area
        case pointCount = "point_count"
        case isActive = "is_active"
    }

    /// 将 path 转换为 CLLocationCoordinate2D 数组
    /// - Returns: 坐标数组
    func toCoordinates() -> [CLLocationCoordinate2D] {
        return path.compactMap { point in
            guard let lat = point["lat"], let lon = point["lon"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }
}
