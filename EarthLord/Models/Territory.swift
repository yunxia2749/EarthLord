//
//  Territory.swift
//  EarthLord
//
//  Created by Claude on 2026/01/10.
//

import Foundation
import CoreLocation

// MARK: - GeoJSON Support

/// GeoJSON 几何体
/// 用于解析 PostGIS 返回的简化坐标
struct GeoJSONGeometry: Codable {
    let type: String
    let coordinates: [CLLocationCoordinate2D]

    enum CodingKeys: String, CodingKey {
        case type
        case coordinates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)

        // GeoJSON 的坐标格式：[[[lon, lat], [lon, lat], ...]]
        // Polygon 类型有三层数组：外层是多边形数组，中层是环数组，内层是坐标对
        let rawCoordinates = try container.decode([[[Double]]].self, forKey: .coordinates)

        // 取第一个环（外环）
        guard let firstRing = rawCoordinates.first else {
            throw DecodingError.dataCorruptedError(
                forKey: .coordinates,
                in: container,
                debugDescription: "GeoJSON Polygon 坐标为空"
            )
        }

        // 将 [lon, lat] 转换为 CLLocationCoordinate2D
        coordinates = firstRing.compactMap { pair in
            guard pair.count >= 2 else { return nil }
            let lon = pair[0]
            let lat = pair[1]
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)

        // 转换回 GeoJSON 格式
        let geoJSONCoords = coordinates.map { [$0.longitude, $0.latitude] }
        try container.encode([[geoJSONCoords]], forKey: .coordinates)
    }
}

// MARK: - Territory Data

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

    /// 面积（平方米，可选）
    let area: Double?

    /// 路径点数（可选）
    let pointCount: Int?

    /// 是否激活（可选）
    let isActive: Bool?

    /// 创建时间
    let createdAt: String?

    /// 简化后的路径（从 PostGIS 函数返回，可选）
    /// 字段名可以是 geojson 或 simplified_path
    let geojson: GeoJSONGeometry?

    /// 编码键映射
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case path
        case area
        case pointCount = "point_count"
        case isActive = "is_active"
        case createdAt = "created_at"
        case geojson
        case simplifiedPath = "simplified_path"
    }

    /// 自定义解码器（处理可选的 path 字段）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        area = try container.decodeIfPresent(Double.self, forKey: .area)
        pointCount = try container.decodeIfPresent(Int.self, forKey: .pointCount)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)

        // 优先尝试 geojson 字段，回退到 simplified_path
        if let geoJsonData = try? container.decodeIfPresent(GeoJSONGeometry.self, forKey: .geojson) {
            geojson = geoJsonData
        } else {
            geojson = try? container.decodeIfPresent(GeoJSONGeometry.self, forKey: .simplifiedPath)
        }

        // path 字段可能不存在（当使用 geojson 时）
        path = (try? container.decode([[String: Double]].self, forKey: .path)) ?? []
    }

    /// 自定义编码器
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encode(path, forKey: .path)
        try container.encodeIfPresent(area, forKey: .area)
        try container.encodeIfPresent(pointCount, forKey: .pointCount)
        try container.encodeIfPresent(isActive, forKey: .isActive)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(geojson, forKey: .geojson)
    }

    /// 将 path 转换为 CLLocationCoordinate2D 数组
    /// - Returns: 坐标数组
    /// - Note: 优先使用简化后的路径（来自 PostGIS），回退到原始 path
    func toCoordinates() -> [CLLocationCoordinate2D] {
        // 优先使用简化后的 GeoJSON 路径（性能优化）
        if let simplified = geojson, !simplified.coordinates.isEmpty {
            print("✅ [TerritoryData] 使用简化路径，坐标点数: \(simplified.coordinates.count)")
            return simplified.coordinates
        }

        // 回退到原始 path
        print("🔍 [TerritoryData] 使用原始路径，path 数组长度: \(path.count)")
        let coordinates = path.compactMap { point -> CLLocationCoordinate2D? in
            guard let lat = point["lat"], let lon = point["lon"] else {
                print("⚠️ [TerritoryData] 坐标点缺少 lat 或 lon: \(point)")
                return nil
            }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        print("✅ [TerritoryData] 成功转换 \(coordinates.count) 个坐标点")
        return coordinates
    }
}
