//
//  ExplorationManager.swift
//  EarthLord
//
//  探索管理器：GPS追踪、距离计算、速度限制（30km/h + 10秒倒计时）
//

import Foundation
import CoreLocation
import Combine
import Supabase

/// 探索管理器
/// 负责探索流程控制、GPS追踪、速度监控、奖励生成
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

    // MARK: - Private Properties

    /// LocationManager引用
    private let locationManager = LocationManager()

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

    /// GPS预热点数（前3个点不检测速度）
    private let gpsWarmupPoints: Int = 3

    /// 速度限制（km/h）
    private let speedLimit: Double = 30.0

    /// 超速倒计时时长（秒）
    private let speedWarningDuration: Int = 10

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

        // 重置状态
        isExploring = false

        log("========== 探索完成 ==========", type: .success)

        return result
    }

    /// 停止探索（失败）
    func stopExplorationWithFailure(reason: String) async {
        log("========== 探索失败 ==========", type: .error)
        log("失败原因: \(reason)", type: .error)

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
        // GPS预热期（前3个点）不检测速度
        if recordedPointsCount < gpsWarmupPoints {
            log("GPS预热中，跳过速度检测（\(recordedPointsCount)/\(gpsWarmupPoints)）", type: .info)
            return true
        }

        // 检查GPS精度
        if accuracy < 0 || accuracy > 65 {
            log("GPS精度太差 (\(String(format: "%.1f", accuracy))米)，忽略本次更新", type: .warning)
            return false
        }

        // 过滤GPS跳变（> 100 km/h）
        if speed > 100 {
            log("检测到GPS跳变 (\(String(format: "%.1f", speed)) km/h)，忽略本次更新", type: .warning)
            return false
        }

        // 检测超速（> 30 km/h）
        if speed > speedLimit {
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
}
