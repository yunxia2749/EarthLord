//
//  PlayerLocationManager.swift
//  EarthLord
//
//  多人密度检测系统 - 玩家位置管理器
//  Day 22: 位置上报、密度查询、POI显示建议
//

import Foundation
import CoreLocation
import Combine
import Supabase
import UIKit

/// 玩家密度等级
enum PlayerDensityLevel: String {
    case alone = "alone"      // 独行者（0人）
    case low = "low"          // 低密度（1-5人）
    case medium = "medium"    // 中密度（6-20人）
    case high = "high"        // 高密度（20+人）

    /// 显示名称
    var displayName: String {
        switch self {
        case .alone: return "独行者"
        case .low: return "低密度"
        case .medium: return "中密度"
        case .high: return "高密度"
        }
    }

    /// 描述文字
    var description: String {
        switch self {
        case .alone: return "附近没有其他幸存者"
        case .low: return "附近有少量幸存者"
        case .medium: return "附近有一些幸存者"
        case .high: return "附近有大量幸存者"
        }
    }

    /// 建议的 POI 数量
    var suggestedPOICount: Int {
        switch self {
        case .alone: return 1
        case .low: return 3
        case .medium: return 6
        case .high: return 99  // 显示所有
        }
    }
}

/// POI 建议结果
struct POISuggestion {
    let nearbyCount: Int           // 附近玩家数量
    let densityLevel: PlayerDensityLevel  // 密度等级
    let suggestedPOICount: Int     // 建议显示的 POI 数量
}

/// 玩家位置管理器
/// 负责位置上报、附近玩家数量查询、POI 显示建议
@MainActor
class PlayerLocationManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = PlayerLocationManager()

    // MARK: - Published Properties

    /// 附近玩家数量
    @Published var nearbyPlayerCount: Int = 0

    /// 当前密度等级
    @Published var densityLevel: PlayerDensityLevel = .alone

    /// 是否正在上报位置
    @Published var isReporting: Bool = false

    /// 最后上报时间
    @Published var lastReportTime: Date?

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Private Properties

    /// 位置管理器
    private let locationManager = CLLocationManager()

    /// 上报定时器
    private var reportTimer: Timer?

    /// 上次上报的位置
    private var lastReportedLocation: CLLocation?

    /// 上报间隔（秒）
    private let reportInterval: TimeInterval = 30.0

    /// 移动阈值（米）- 超过此距离立即上报
    private let movementThreshold: CLLocationDistance = 50.0

    /// 查询半径（米）
    private let queryRadius: Double = 1000.0

    /// 是否已启动
    private var isStarted: Bool = false

    /// Cancellables
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private override init() {
        super.init()
        setupLocationManager()
        setupAppLifecycleObservers()
    }

    // MARK: - Setup

    /// 设置位置管理器
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10  // 每移动10米更新一次
    }

    /// 设置 App 生命周期监听
    private func setupAppLifecycleObservers() {
        // 监听 App 进入前台
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleAppWillEnterForeground()
                }
            }
            .store(in: &cancellables)

        // 监听 App 进入后台
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleAppDidEnterBackground()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// 开始位置上报
    func startReporting() {
        guard !isStarted else {
            log("已在运行中，跳过启动", type: .info)
            return
        }

        log("========== 启动位置上报 ==========", type: .info)
        isStarted = true

        // 开始位置更新
        locationManager.startUpdatingLocation()

        // 立即上报一次
        Task {
            await reportCurrentLocation()
        }

        // 启动定时上报
        startReportTimer()

        log("位置上报已启动", type: .success)
    }

    /// 停止位置上报
    func stopReporting() {
        guard isStarted else { return }

        log("========== 停止位置上报 ==========", type: .info)
        isStarted = false

        // 停止定时器
        reportTimer?.invalidate()
        reportTimer = nil

        // 停止位置更新
        locationManager.stopUpdatingLocation()

        log("位置上报已停止", type: .info)
    }

    /// 查询附近玩家数量
    /// - Parameters:
    ///   - latitude: 纬度
    ///   - longitude: 经度
    /// - Returns: 附近玩家数量
    func queryNearbyPlayerCount(latitude: Double, longitude: Double) async -> Int {
        do {
            let count: Int = try await supabase
                .rpc("get_nearby_player_count", params: [
                    "p_latitude": latitude,
                    "p_longitude": longitude,
                    "p_radius_meters": queryRadius
                ])
                .execute()
                .value

            log("附近玩家数量: \(count)", type: .success)
            return count
        } catch {
            log("查询附近玩家失败: \(error.localizedDescription)", type: .error)
            return 0
        }
    }

    /// 获取 POI 显示建议
    /// - Parameters:
    ///   - latitude: 纬度
    ///   - longitude: 经度
    /// - Returns: POI 建议
    func getPOISuggestion(latitude: Double, longitude: Double) async -> POISuggestion {
        log("========== 获取POI显示建议 ==========", type: .info)
        log("位置: (\(String(format: "%.6f", latitude)), \(String(format: "%.6f", longitude)))", type: .info)

        do {
            // 定义返回结构
            struct POISuggestionResponse: Decodable {
                let nearby_count: Int
                let density_level: String
                let suggested_poi_count: Int
            }

            let response: [POISuggestionResponse] = try await supabase
                .rpc("get_poi_suggestion", params: [
                    "p_latitude": latitude,
                    "p_longitude": longitude,
                    "p_radius_meters": queryRadius
                ])
                .execute()
                .value

            guard let result = response.first else {
                log("RPC返回为空", type: .warning)
                return POISuggestion(nearbyCount: 0, densityLevel: .alone, suggestedPOICount: 1)
            }

            let densityLevel = PlayerDensityLevel(rawValue: result.density_level) ?? .alone

            // 更新本地状态
            nearbyPlayerCount = result.nearby_count
            self.densityLevel = densityLevel

            log("附近玩家: \(result.nearby_count)人", type: .success)
            log("密度等级: \(densityLevel.displayName)", type: .success)
            log("建议POI数: \(result.suggested_poi_count)", type: .success)

            return POISuggestion(
                nearbyCount: result.nearby_count,
                densityLevel: densityLevel,
                suggestedPOICount: result.suggested_poi_count
            )
        } catch {
            log("获取POI建议失败: \(error.localizedDescription)", type: .error)
            errorMessage = error.localizedDescription
            return POISuggestion(nearbyCount: 0, densityLevel: .alone, suggestedPOICount: 1)
        }
    }

    // MARK: - Private Methods

    /// 启动定时上报
    private func startReportTimer() {
        reportTimer?.invalidate()
        reportTimer = Timer.scheduledTimer(withTimeInterval: reportInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.reportCurrentLocation()
            }
        }
        log("定时上报已启动（每\(Int(reportInterval))秒）", type: .info)
    }

    /// 上报当前位置
    private func reportCurrentLocation() async {
        guard let location = locationManager.location else {
            log("无法获取当前位置", type: .warning)
            return
        }

        await reportLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }

    /// 上报位置到服务器
    private func reportLocation(latitude: Double, longitude: Double) async {
        isReporting = true
        errorMessage = nil

        do {
            try await supabase
                .rpc("report_player_location", params: [
                    "p_latitude": latitude,
                    "p_longitude": longitude
                ])
                .execute()

            lastReportTime = Date()
            lastReportedLocation = CLLocation(latitude: latitude, longitude: longitude)
            log("位置上报成功: (\(String(format: "%.6f", latitude)), \(String(format: "%.6f", longitude)))", type: .success)
        } catch {
            log("位置上报失败: \(error.localizedDescription)", type: .error)
            errorMessage = error.localizedDescription
        }

        isReporting = false
    }

    /// 标记玩家离线
    private func markOffline() async {
        do {
            try await supabase
                .rpc("mark_player_offline")
                .execute()

            log("已标记为离线", type: .info)
        } catch {
            log("标记离线失败: \(error.localizedDescription)", type: .error)
        }
    }

    /// 处理 App 进入前台
    private func handleAppWillEnterForeground() {
        log("App 进入前台", type: .info)
        if isStarted {
            // 立即上报位置
            Task {
                await reportCurrentLocation()
            }
            // 重新启动定时器
            startReportTimer()
        }
    }

    /// 处理 App 进入后台
    private func handleAppDidEnterBackground() async {
        log("App 进入后台", type: .info)
        // 标记玩家离线
        await markOffline()
        // 停止定时器（省电）
        reportTimer?.invalidate()
        reportTimer = nil
    }

    /// 检查是否需要因移动而上报
    private func checkMovementAndReport(newLocation: CLLocation) {
        guard let lastLocation = lastReportedLocation else {
            // 没有上次位置，立即上报
            Task {
                await reportLocation(latitude: newLocation.coordinate.latitude, longitude: newLocation.coordinate.longitude)
            }
            return
        }

        let distance = newLocation.distance(from: lastLocation)

        if distance >= movementThreshold {
            log("移动超过\(Int(movementThreshold))米，立即上报", type: .info)
            Task {
                await reportLocation(latitude: newLocation.coordinate.latitude, longitude: newLocation.coordinate.longitude)
            }
        }
    }

    // MARK: - Logging

    private func log(_ message: String, type: LogType) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let prefix = type.prefix
        print("\(prefix) [\(timestamp)] [PlayerLocationManager] \(message)")
    }

    enum LogType {
        case info, warning, error, success

        var prefix: String {
            switch self {
            case .info: return "i"
            case .warning: return "!"
            case .error: return "x"
            case .success: return "v"
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension PlayerLocationManager: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            // 检查是否需要因移动而上报
            checkMovementAndReport(newLocation: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            log("位置更新失败: \(error.localizedDescription)", type: .error)
            errorMessage = error.localizedDescription
        }
    }
}
