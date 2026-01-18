//
//  ExplorationManager.swift
//  EarthLord
//
//  探索管理器：GPS追踪、距离计算、速度限制、POI搜刮系统
//

import Foundation
import CoreLocation
import Combine
import Supabase
import MapKit

/// 探索管理器
/// 负责探索流程控制、GPS追踪、速度监控、POI管理、奖励生成
@MainActor
class ExplorationManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = ExplorationManager()

    // MARK: - Published Properties

    /// 是否正在探索
    @Published var isExploring: Bool = false

    /// 当前累计距离（米）
    @Published var totalDistance: Double = 0

    /// 探索时长（秒）
    @Published var currentDuration: TimeInterval = 0

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 速度警告倒计时（秒）
    @Published var speedWarningCountdown: Int = 0

    /// 探索是否失败
    @Published var explorationFailed: Bool = false

    /// 失败原因
    @Published var failureReason: String?

    /// 当前速度（km/h）
    @Published var currentSpeed: Double = 0

    // MARK: - POI 相关属性

    /// 当前探索中的POI列表
    @Published var nearbyPOIs: [POIData] = []

    /// 是否正在搜索POI
    @Published var isSearchingPOIs: Bool = false

    // MARK: - 多人密度相关属性

    /// 附近幸存者数量
    @Published var nearbyPlayerCount: Int = 0

    /// 当前密度等级
    @Published var currentDensityLevel: PlayerDensityLevel = .alone

    /// 当前接近的POI（触发弹窗）
    @Published var currentProximityPOI: POIData?

    /// 是否显示POI接近弹窗
    @Published var showPOIProximityPopup: Bool = false

    /// 是否显示搜刮结果
    @Published var showScavengeResult: Bool = false

    /// 搜刮获得的物品
    @Published var scavengeRewards: [RewardItem] = []

    /// 已搜刮的POI ID集合
    @Published var scavengedPOIIds: Set<String> = []

    // MARK: - Private Properties

    /// LocationManager引用
    private let locationManager = LocationManager()

    /// 地理围栏管理器（用于POI接近检测）
    private let geofenceManager = CLLocationManager()

    /// 探索开始时间
    private var explorationStartTime: Date?

    /// 计时器（每1秒更新一次时长）
    private var durationTimer: Timer?

    /// 速度警告计时器
    private var speedWarningTimer: Timer?

    /// 上次记录的位置
    private var lastRecordedLocation: CLLocation?

    /// 上次记录时间
    private var lastRecordedTime: Date?

    /// 记录的位置点数（用于GPS预热）
    private var recordedPointsCount: Int = 0

    /// GPS预热点数（前5个点不检测速度，让GPS稳定）
    private let gpsWarmupPoints: Int = 5

    /// 速度限制（km/h）
    private let speedLimit: Double = 30.0

    /// 超速倒计时时长（秒）
    private let speedWarningDuration: Int = 10

    /// POI触发距离（米）
    private let poiTriggerRadius: CLLocationDistance = 50.0

    // 注意：使用全局的 supabase 实例（定义在 SupabaseTestView.swift）
    // 确保与 AuthManager 使用相同的认证会话

    /// Cancellables
    private var cancellables = Set<AnyCancellable>()

    /// 当前探索会话ID
    private var currentSessionId: UUID?

    // MARK: - Initialization

    private override init() {
        super.init()
        setupLocationObserver()
        setupGeofenceManager()
    }

    // MARK: - Setup

    /// 设置位置监听
    private func setupLocationObserver() {
        // 监听用户位置更新
        locationManager.$userLocation
            .sink { [weak self] coordinate in
                guard let self = self, self.isExploring, let coordinate = coordinate else { return }

                Task { @MainActor in
                    await self.handleLocationUpdate(coordinate: coordinate)
                }
            }
            .store(in: &cancellables)
    }

    /// 设置地理围栏管理器
    private func setupGeofenceManager() {
        geofenceManager.delegate = self
        geofenceManager.desiredAccuracy = kCLLocationAccuracyBest
        geofenceManager.allowsBackgroundLocationUpdates = false
    }

    // MARK: - Public Methods

    /// 开始探索
    func startExploration() async {
        log("========== 探索开始 ==========", type: .info)

        // 重置状态
        isExploring = true
        totalDistance = 0
        currentDuration = 0
        speedWarning = nil
        speedWarningCountdown = 0
        explorationFailed = false
        failureReason = nil
        currentSpeed = 0
        lastRecordedLocation = nil
        lastRecordedTime = nil
        recordedPointsCount = 0
        explorationStartTime = Date()

        // 重置POI状态
        nearbyPOIs = []
        scavengedPOIIds = []
        currentProximityPOI = nil
        showPOIProximityPopup = false
        showScavengeResult = false
        scavengeRewards = []

        // 重置密度状态
        nearbyPlayerCount = 0
        currentDensityLevel = .alone

        // 启动玩家位置上报
        PlayerLocationManager.shared.startReporting()

        // 启动计时器
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.isExploring {
                    self.currentDuration += 1
                }
            }
        }

        // 创建探索会话记录
        await createExplorationSession()

        // 搜索附近POI
        await searchAndSetupPOIs()

        log("计时器已启动", type: .info)
        log("GPS追踪已开始", type: .info)
        log("========== 探索准备就绪 ==========", type: .success)
    }

    /// 停止探索（正常结束）
    func stopExploration() async -> ExplorationResult {
        log("========== 探索结束 ==========", type: .info)
        log("总距离: \(String(format: "%.1f", totalDistance))米", type: .info)
        log("总时长: \(String(format: "%.0f", currentDuration))秒", type: .info)

        // 停止计时器
        durationTimer?.invalidate()
        durationTimer = nil
        speedWarningTimer?.invalidate()
        speedWarningTimer = nil

        // 生成奖励
        let rewardGenerator = RewardGenerator.shared
        let rewards = rewardGenerator.generateReward(distance: totalDistance)
        let tier = rewardGenerator.calculateTier(distance: totalDistance)

        log("奖励等级: \(tier.displayName)", type: .success)
        log("获得物品数量: \(rewards.count)个", type: .success)
        for reward in rewards {
            log("  - \(reward.itemId) x\(reward.quantity)", type: .info)
        }

        // 保存奖励到背包
        var rewardsAddedSuccessfully = false
        var rewardsErrorMessage: String? = nil

        do {
            log("========== 开始添加奖励到背包 ==========", type: .info)
            try await InventoryManager.shared.addItems(rewards)
            rewardsAddedSuccessfully = true
            log("========== 奖励添加成功 ==========", type: .success)
        } catch {
            rewardsAddedSuccessfully = false
            rewardsErrorMessage = error.localizedDescription
            log("========== 奖励添加失败 ==========", type: .error)
            log("错误详情: \(error)", type: .error)
        }

        // 计算经验值（每100米 = 10经验）
        let experienceGained = Int(totalDistance / 100.0) * 10

        // 查询累计距离
        let totalCumulativeDistance = await getTotalCumulativeDistance()

        // 更新数据库
        await updateExplorationSession(
            status: "completed",
            distance: totalDistance,
            tier: tier.rawValue,
            rewards: rewards
        )

        // 创建探索结果
        let result = ExplorationResult(
            id: UUID().uuidString,
            startTime: explorationStartTime ?? Date(),
            endTime: Date(),
            stats: ExplorationStats(
                walkDistanceThisTime: totalDistance,
                walkDistanceTotal: totalCumulativeDistance + totalDistance,
                explorationDuration: currentDuration
            ),
            obtainedItems: rewards.map { reward in
                ObtainedItem(
                    id: UUID().uuidString,
                    itemId: reward.itemId,
                    quantity: reward.quantity,
                    quality: nil,
                    source: "探索奖励"
                )
            },
            experienceGained: experienceGained,
            rewardsAddedSuccessfully: rewardsAddedSuccessfully,
            rewardsErrorMessage: rewardsErrorMessage
        )

        // 清除POI数据和围栏
        clearPOIs()

        // 停止玩家位置上报
        PlayerLocationManager.shared.stopReporting()

        // 重置状态
        isExploring = false

        log("========== 探索完成 ==========", type: .success)

        return result
    }

    /// 停止探索（失败）
    func stopExplorationWithFailure(reason: String) async {
        log("========== 探索失败 ==========", type: .error)
        log("失败原因: \(reason)", type: .error)

        // 清除POI数据和围栏
        clearPOIs()

        // 停止玩家位置上报
        PlayerLocationManager.shared.stopReporting()

        explorationFailed = true
        failureReason = reason

        // 停止计时器
        durationTimer?.invalidate()
        durationTimer = nil
        speedWarningTimer?.invalidate()
        speedWarningTimer = nil

        // 更新数据库
        await updateExplorationSession(
            status: "failed",
            distance: totalDistance,
            tier: nil,
            rewards: [],
            failureReason: reason
        )

        // 重置状态
        isExploring = false

        log("========== 探索已停止 ==========", type: .error)
    }

    // MARK: - Private Methods

    /// 处理位置更新
    private func handleLocationUpdate(coordinate: CLLocationCoordinate2D) async {
        let currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        // ⭐ 主动检测POI接近（每次位置更新都检查）
        checkPOIProximity(userLocation: currentLocation)

        // 第一个位置点
        if lastRecordedLocation == nil {
            lastRecordedLocation = currentLocation
            lastRecordedTime = Date()
            recordedPointsCount = 1
            log("GPS位置更新: (\(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude)))", type: .info)
            log("记录起始点", type: .info)
            return
        }

        guard let lastLocation = lastRecordedLocation, let lastTime = lastRecordedTime else {
            return
        }

        // 计算距离
        let distance = currentLocation.distance(from: lastLocation)

        // 过滤太近的点（< 5米）
        guard distance >= 5 else {
            return
        }

        // 计算速度
        let timeInterval = Date().timeIntervalSince(lastTime)
        guard timeInterval > 0 else { return }

        let speed = (distance / timeInterval) * 3.6  // 转换为 km/h
        currentSpeed = speed

        log("GPS位置更新: (\(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude)))", type: .info)
        log("距离: \(String(format: "%.1f", distance))米, 时间: \(String(format: "%.1f", timeInterval))秒, 速度: \(String(format: "%.1f", speed)) km/h", type: .info)

        // 速度检测
        let speedValid = await validateMovementSpeed(speed: speed, accuracy: currentLocation.horizontalAccuracy)

        if speedValid {
            // 速度正常，记录距离
            totalDistance += distance
            lastRecordedLocation = currentLocation
            lastRecordedTime = Date()
            recordedPointsCount += 1

            log("距离累加: +\(String(format: "%.1f", distance))米，总计: \(String(format: "%.1f", totalDistance))米", type: .success)
        }
    }

    /// 验证移动速度
    /// - Parameters:
    ///   - speed: 速度（km/h）
    ///   - accuracy: GPS精度（米）
    /// - Returns: true表示速度有效，false表示速度无效
    private func validateMovementSpeed(speed: Double, accuracy: Double) async -> Bool {
        // GPS预热期（前5个点）不检测速度
        if recordedPointsCount < gpsWarmupPoints {
            log("GPS预热中，跳过速度检测（\(recordedPointsCount)/\(gpsWarmupPoints)）", type: .info)
            return true
        }

        // 检查GPS精度（精度差时忽略速度检测）
        if accuracy < 0 || accuracy > 30 {
            log("GPS精度较差 (\(String(format: "%.1f", accuracy))米)，忽略速度检测", type: .warning)
            // 精度差时仍然记录距离，但不检测速度
            return true
        }

        // 过滤GPS跳变（> 50 km/h 视为GPS漂移）
        if speed > 50 {
            log("检测到GPS跳变/漂移 (\(String(format: "%.1f", speed)) km/h)，忽略本次更新", type: .warning)
            return false
        }

        // 检测超速（> 30 km/h 且精度良好时才警告）
        if speed > speedLimit && accuracy <= 20 {
            log("速度检测: \(String(format: "%.1f", speed)) km/h，超过限制(\(speedLimit) km/h)", type: .warning)

            if speedWarningTimer == nil {
                // 第一次超速，启动倒计时
                speedWarningCountdown = speedWarningDuration
                speedWarning = "速度过快: \(String(format: "%.0f", speed))km/h，请减速"

                log("超速警告启动，倒计时: \(speedWarningCountdown)秒", type: .warning)

                speedWarningTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                    Task { @MainActor in
                        guard let self = self else {
                            timer.invalidate()
                            return
                        }

                        self.speedWarningCountdown -= 1
                        self.log("倒计时: \(self.speedWarningCountdown)秒", type: .warning)

                        if self.speedWarningCountdown <= 0 {
                            // 倒计时结束，停止探索
                            self.log("倒计时结束，速度仍超过限制，停止探索", type: .error)
                            timer.invalidate()
                            self.speedWarningTimer = nil

                            await self.stopExplorationWithFailure(reason: "移动速度过快（持续超过\(self.speedLimit)km/h）")
                        } else {
                            // 更新警告文字
                            self.speedWarning = "速度过快，还有\(self.speedWarningCountdown)秒"
                        }
                    }
                }
            }

            return false  // 超速期间不记录距离
        } else {
            // 速度正常
            if speedWarningTimer != nil {
                // 取消倒计时
                log("速度恢复正常，警告取消", type: .success)
                speedWarningTimer?.invalidate()
                speedWarningTimer = nil
                speedWarningCountdown = 0
                speedWarning = nil
            }
            return true  // 正常记录距离
        }
    }

    // MARK: - Database Methods

    /// 创建探索会话
    private func createExplorationSession() async {
        do {
            guard let userId = try? await supabase.auth.session.user.id else {
                log("获取用户ID失败", type: .error)
                return
            }

            let sessionId = UUID()
            currentSessionId = sessionId

            struct SessionCreate: Encodable {
                let id: UUID
                let user_id: UUID
                let start_time: String
                let status: String
            }

            let session = SessionCreate(
                id: sessionId,
                user_id: userId,
                start_time: ISO8601DateFormatter().string(from: Date()),
                status: "active"
            )

            try await supabase
                .from("exploration_sessions")
                .insert(session)
                .execute()

            log("探索会话已创建: \(sessionId)", type: .success)
        } catch {
            log("创建探索会话失败: \(error.localizedDescription)", type: .error)
        }
    }

    /// 更新探索会话
    private func updateExplorationSession(
        status: String,
        distance: Double,
        tier: String?,
        rewards: [RewardItem],
        failureReason: String? = nil
    ) async {
        guard let sessionId = currentSessionId else {
            log("会话ID为空，无法更新", type: .error)
            return
        }

        do {
            struct SessionUpdate: Encodable {
                let end_time: String
                let duration: Int
                let total_distance: Double
                let reward_tier: String?
                let items_rewarded: [[String: Any]]?
                let status: String
                let failure_reason: String?

                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    try container.encode(end_time, forKey: .end_time)
                    try container.encode(duration, forKey: .duration)
                    try container.encode(total_distance, forKey: .total_distance)
                    try container.encodeIfPresent(reward_tier, forKey: .reward_tier)
                    try container.encode(status, forKey: .status)
                    try container.encodeIfPresent(failure_reason, forKey: .failure_reason)

                    // 手动编码 items_rewarded
                    if let items = items_rewarded {
                        var jsonString = "["
                        jsonString += items.map { item in
                            var parts: [String] = []
                            if let itemId = item["itemId"] as? String {
                                parts.append("\"itemId\":\"\(itemId)\"")
                            }
                            if let quantity = item["quantity"] as? Int {
                                parts.append("\"quantity\":\(quantity)")
                            }
                            return "{\(parts.joined(separator: ","))}"
                        }.joined(separator: ",")
                        jsonString += "]"

                        // Note: This is a workaround for JSONB encoding
                        // In a real implementation, you'd use PostgrestFilterBuilder's rpc or raw SQL
                    }
                }

                enum CodingKeys: String, CodingKey {
                    case end_time, duration, total_distance, reward_tier, items_rewarded, status, failure_reason
                }
            }

            let rewardsJSON = rewards.map { reward in
                ["itemId": reward.itemId, "quantity": reward.quantity] as [String: Any]
            }

            let update = SessionUpdate(
                end_time: ISO8601DateFormatter().string(from: Date()),
                duration: Int(currentDuration),
                total_distance: distance,
                reward_tier: tier,
                items_rewarded: rewardsJSON,
                status: status,
                failure_reason: failureReason
            )

            // 使用简化的更新（不包含JSONB，先用RPC或原始SQL）
            // 这里我们使用一个简化版本
            struct SimpleUpdate: Encodable {
                let end_time: String
                let duration: Int
                let total_distance: Double
                let reward_tier: String?
                let status: String
                let failure_reason: String?
            }

            let simpleUpdate = SimpleUpdate(
                end_time: ISO8601DateFormatter().string(from: Date()),
                duration: Int(currentDuration),
                total_distance: distance,
                reward_tier: tier,
                status: status,
                failure_reason: failureReason
            )

            try await supabase
                .from("exploration_sessions")
                .update(simpleUpdate)
                .eq("id", value: sessionId.uuidString)
                .execute()

            log("探索会话已更新: \(status)", type: .success)
        } catch {
            log("更新探索会话失败: \(error.localizedDescription)", type: .error)
        }
    }

    /// 获取累计总距离
    private func getTotalCumulativeDistance() async -> Double {
        do {
            guard let userId = try? await supabase.auth.session.user.id else {
                return 0
            }

            struct DistanceResult: Decodable {
                let total_distance: Double?
            }

            let result: [DistanceResult] = try await supabase
                .from("exploration_sessions")
                .select("total_distance")
                .eq("user_id", value: userId.uuidString)
                .eq("status", value: "completed")
                .execute()
                .value

            let total = result.compactMap { $0.total_distance }.reduce(0, +)
            log("查询累计距离: \(String(format: "%.1f", total))米", type: .info)
            return total
        } catch {
            log("查询累计距离失败: \(error.localizedDescription)", type: .error)
            return 0
        }
    }

    // MARK: - Logging

    /// 日志记录
    private func log(_ message: String, type: LogType) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let prefix = type.prefix
        print("\(prefix) [\(timestamp)] [ExplorationManager] \(message)")
    }

    /// 日志类型
    enum LogType {
        case info, warning, error, success

        var prefix: String {
            switch self {
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .success: return "✅"
            }
        }
    }

    // MARK: - POI 搜索与管理

    /// 搜索附近POI并设置地理围栏
    private func searchAndSetupPOIs() async {
        guard let userLocation = locationManager.userLocation else {
            log("无法获取用户位置，跳过POI搜索", type: .warning)
            return
        }

        isSearchingPOIs = true
        log("========== 开始搜索附近POI ==========", type: .info)

        // ⭐ 1. 先查询附近玩家密度，获取POI显示建议
        let suggestion = await PlayerLocationManager.shared.getPOISuggestion(
            latitude: userLocation.latitude,
            longitude: userLocation.longitude
        )

        // 更新密度状态
        nearbyPlayerCount = suggestion.nearbyCount
        currentDensityLevel = suggestion.densityLevel

        log("附近幸存者: \(suggestion.nearbyCount)人", type: .info)
        log("密度等级: \(suggestion.densityLevel.displayName)", type: .info)
        log("建议POI数: \(suggestion.suggestedPOICount)", type: .info)

        // ⭐ 2. 搜索POI
        var pois = await POISearchManager.shared.searchNearbyPOIs(center: userLocation)

        // ⭐ 添加虚拟测试POI（在用户位置附近20米处）
        let testPOI = createTestPOI(near: userLocation)
        pois.insert(testPOI, at: 0)  // 放在列表最前面
        log("已添加测试超市POI: \(testPOI.name)", type: .success)

        // ⭐ 3. 根据密度等级限制POI数量
        let maxPOICount = suggestion.suggestedPOICount
        if pois.count > maxPOICount {
            // 按距离排序，取最近的N个
            let sortedPOIs = pois.sorted { poi1, poi2 in
                let loc1 = CLLocation(latitude: poi1.coordinate.latitude, longitude: poi1.coordinate.longitude)
                let loc2 = CLLocation(latitude: poi2.coordinate.latitude, longitude: poi2.coordinate.longitude)
                let userLoc = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                return loc1.distance(from: userLoc) < loc2.distance(from: userLoc)
            }
            pois = Array(sortedPOIs.prefix(maxPOICount))
            log("根据密度限制POI数量: \(pois.count)个", type: .info)
        }

        nearbyPOIs = pois

        log("找到 \(pois.count) 个POI（含1个测试点）", type: .success)

        // 为每个POI创建地理围栏
        setupGeofences(for: pois)

        isSearchingPOIs = false
        log("========== POI搜索完成 ==========", type: .success)
    }

    /// 创建测试用虚拟POI（在用户当前位置，立即可触发）
    private func createTestPOI(near userLocation: CLLocationCoordinate2D) -> POIData {
        // ⭐ 直接放在用户当前位置（偏移约5米，确保立即触发）
        // 1度纬度约111公里，5米 ≈ 0.000045度
        let offsetLat = 0.00004  // 约4米北
        let offsetLng = 0.00004  // 约4米东

        let testCoordinate = CLLocationCoordinate2D(
            latitude: userLocation.latitude + offsetLat,
            longitude: userLocation.longitude + offsetLng
        )

        return POIData(
            id: "test_supermarket_\(UUID().uuidString.prefix(8))",
            name: "🧪 测试超市",
            type: .supermarket,
            coordinate: testCoordinate,
            discoveryStatus: .discovered,
            searchStatus: .hasLoot,
            dangerLevel: 1,
            description: "这是一个用于测试的虚拟超市，里面有丰富的物资等你来搜刮！"
        )
    }

    /// 为POI列表创建地理围栏
    private func setupGeofences(for pois: [POIData]) {
        log("开始创建地理围栏...", type: .info)

        // 先清除所有现有围栏
        clearAllGeofences()

        // 为每个POI创建围栏（最多20个）
        for poi in pois.prefix(20) {
            let region = CLCircularRegion(
                center: poi.coordinate,
                radius: poiTriggerRadius,
                identifier: poi.id
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false

            geofenceManager.startMonitoring(for: region)
            log("围栏已创建: \(poi.name) (ID: \(poi.id))", type: .info)
        }

        log("共创建 \(min(pois.count, 20)) 个地理围栏", type: .success)
    }

    /// 清除所有地理围栏
    private func clearAllGeofences() {
        for region in geofenceManager.monitoredRegions {
            geofenceManager.stopMonitoring(for: region)
        }
        log("已清除所有地理围栏", type: .info)
    }

    /// 清除POI数据（停止探索时调用）
    func clearPOIs() {
        clearAllGeofences()
        nearbyPOIs = []
        scavengedPOIIds = []
        currentProximityPOI = nil
        showPOIProximityPopup = false
        showScavengeResult = false
        scavengeRewards = []
        log("POI数据已清除", type: .info)
    }

    /// ⭐ 主动检测用户是否接近任何POI
    /// 每次位置更新时调用，补充地理围栏的不足
    private func checkPOIProximity(userLocation: CLLocation) {
        // 如果已有弹窗显示，跳过检测
        guard !showPOIProximityPopup && !showScavengeResult else { return }

        // 遍历所有POI，检查距离
        for poi in nearbyPOIs {
            // 跳过已搜刮的POI
            if scavengedPOIIds.contains(poi.id) { continue }

            let poiLocation = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
            let distance = userLocation.distance(from: poiLocation)

            // 如果在触发距离内（50米），显示弹窗
            if distance <= poiTriggerRadius {
                log("⭐ 主动检测到接近POI: \(poi.name)，距离: \(String(format: "%.1f", distance))米", type: .success)
                currentProximityPOI = poi
                showPOIProximityPopup = true
                return  // 一次只显示一个弹窗
            }
        }
    }

    // MARK: - POI 搜刮

    /// 执行POI搜刮
    /// - Parameter poi: 要搜刮的POI
    func scavengePOI(_ poi: POIData) async {
        log("========== 开始搜刮POI ==========", type: .info)
        log("POI: \(poi.name) (类型: \(poi.type.displayName))", type: .info)

        // 标记为已搜刮
        scavengedPOIIds.insert(poi.id)

        // 生成搜刮物品（复用RewardGenerator的物品池）
        let rewards = generateScavengeRewards(for: poi)
        scavengeRewards = rewards

        log("生成 \(rewards.count) 个物品:", type: .success)
        for reward in rewards {
            log("  - \(reward.itemId) x\(reward.quantity)", type: .info)
        }

        // 添加到背包
        do {
            try await InventoryManager.shared.addItems(rewards)
            log("物品已添加到背包", type: .success)
        } catch {
            log("添加物品到背包失败: \(error.localizedDescription)", type: .error)
        }

        // 关闭接近弹窗，显示结果
        showPOIProximityPopup = false
        showScavengeResult = true

        log("========== 搜刮完成 ==========", type: .success)
    }

    /// 生成搜刮奖励
    private func generateScavengeRewards(for poi: POIData) -> [RewardItem] {
        // 随机生成1-3个物品
        let itemCount = Int.random(in: 1...3)
        var rewards: [RewardItem] = []

        // 根据POI类型使用不同的物品池（Day22简化版：使用通用池）
        let itemPool = getItemPool(for: poi.type)

        for _ in 0..<itemCount {
            if let itemId = itemPool.randomElement() {
                let quantity = Int.random(in: 1...2)
                rewards.append(RewardItem(itemId: itemId, quantity: quantity))
            }
        }

        return rewards
    }

    /// 获取POI类型对应的物品池
    private func getItemPool(for poiType: POIType) -> [String] {
        // Day22简化版：所有类型使用相同的通用物品池
        // 后续可以根据类型返回不同物品池
        switch poiType {
        case .supermarket:
            return ["item_water_bottle", "item_canned_food", "item_bandage"]
        case .hospital, .pharmacy:
            return ["item_medicine", "item_bandage", "item_first_aid_kit"]
        case .gasStation:
            return ["item_flashlight", "item_rope", "item_scrap_metal"]
        default:
            return ["item_water_bottle", "item_canned_food", "item_bandage", "item_wood", "item_rope"]
        }
    }

    /// 关闭搜刮结果弹窗
    func dismissScavengeResult() {
        showScavengeResult = false
        scavengeRewards = []
        currentProximityPOI = nil
    }

    /// 关闭POI接近弹窗（稍后再说）
    func dismissPOIPopup() {
        showPOIProximityPopup = false
        currentProximityPOI = nil
    }

    /// 检查POI是否已被搜刮
    func isPOIScavenged(_ poi: POIData) -> Bool {
        return scavengedPOIIds.contains(poi.id)
    }
}

// MARK: - CLLocationManagerDelegate

extension ExplorationManager: CLLocationManagerDelegate {

    /// 进入地理围栏时调用
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }

        Task { @MainActor in
            handleDidEnterRegion(identifier: circularRegion.identifier)
        }
    }

    /// 处理进入围栏事件
    private func handleDidEnterRegion(identifier: String) {
        log("========== 进入POI范围 ==========", type: .info)
        log("围栏ID: \(identifier)", type: .info)

        // 查找对应的POI
        guard let poi = nearbyPOIs.first(where: { $0.id == identifier }) else {
            log("未找到对应的POI", type: .warning)
            return
        }

        // 检查是否已搜刮
        if scavengedPOIIds.contains(poi.id) {
            log("POI已被搜刮，跳过弹窗", type: .info)
            return
        }

        // 检查是否已有弹窗显示
        if showPOIProximityPopup || showScavengeResult {
            log("已有弹窗显示，跳过", type: .info)
            return
        }

        // 设置当前POI并显示弹窗
        currentProximityPOI = poi
        showPOIProximityPopup = true

        log("显示搜刮提示: \(poi.name)", type: .success)
        log("========== ==========", type: .info)
    }

    /// 地理围栏监控失败
    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        Task { @MainActor in
            log("围栏监控失败: \(error.localizedDescription)", type: .error)
        }
    }
}
