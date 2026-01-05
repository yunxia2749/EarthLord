//
//  CoordinateConverter.swift
//  EarthLord
//
//  坐标转换工具：WGS-84（GPS标准）→ GCJ-02（火星坐标系，中国地图标准）
//  在中国使用 MapKit 必须转换坐标，否则会有偏移
//

import Foundation
import CoreLocation

// MARK: - CoordinateConverter

/// 坐标转换器：将 WGS-84（GPS）坐标转换为 GCJ-02（火星坐标）
struct CoordinateConverter {

    // MARK: - Constants

    /// 长半轴
    private static let a: Double = 6378245.0

    /// 扁率
    private static let ee: Double = 0.00669342162296594323

    /// 判断是否在中国范围内
    /// - Parameter coordinate: WGS-84 坐标
    /// - Returns: 是否在中国
    private static func isInChina(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let lat = coordinate.latitude
        let lon = coordinate.longitude

        // 中国大致经纬度范围
        return lon >= 72.004 && lon <= 137.8347 &&
               lat >= 0.8293 && lat <= 55.8271
    }

    /// 转换纬度
    private static func transformLatitude(x: Double, y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * .pi) + 40.0 * sin(y / 3.0 * .pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * .pi) + 320 * sin(y * .pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    /// 转换经度
    private static func transformLongitude(x: Double, y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * .pi) + 40.0 * sin(x / 3.0 * .pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * .pi) + 300.0 * sin(x / 30.0 * .pi)) * 2.0 / 3.0
        return ret
    }

    // MARK: - Public Methods

    /// 将 WGS-84 坐标转换为 GCJ-02 坐标
    /// - Parameter wgsCoordinate: WGS-84 坐标（GPS原始坐标）
    /// - Returns: GCJ-02 坐标（火星坐标，用于中国地图）
    static func wgs84ToGcj02(_ wgsCoordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 如果不在中国范围内，不需要转换
        guard isInChina(wgsCoordinate) else {
            return wgsCoordinate
        }

        let lat = wgsCoordinate.latitude
        let lon = wgsCoordinate.longitude

        var dLat = transformLatitude(x: lon - 105.0, y: lat - 35.0)
        var dLon = transformLongitude(x: lon - 105.0, y: lat - 35.0)

        let radLat = lat / 180.0 * .pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)

        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * .pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * .pi)

        let mgLat = lat + dLat
        let mgLon = lon + dLon

        return CLLocationCoordinate2D(latitude: mgLat, longitude: mgLon)
    }

    /// 批量转换坐标数组
    /// - Parameter wgsCoordinates: WGS-84 坐标数组
    /// - Returns: GCJ-02 坐标数组
    static func convertCoordinates(_ wgsCoordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        return wgsCoordinates.map { wgs84ToGcj02($0) }
    }
}
