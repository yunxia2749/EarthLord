//
//  RewardGenerator.swift
//  EarthLord
//
//  奖励生成器：根据行走距离生成奖励物品
//

import Foundation

/// 奖励等级
enum RewardTier: String {
    case none = "none"          // 无奖励
    case bronze = "bronze"      // 铜级
    case silver = "silver"      // 银级
    case gold = "gold"          // 金级
    case diamond = "diamond"    // 钻石级

    var displayName: String {
        switch self {
        case .none: return "无奖励"
        case .bronze: return "🥉 铜级"
        case .silver: return "🥈 银级"
        case .gold: return "🥇 金级"
        case .diamond: return "💎 钻石级"
        }
    }
}

/// 奖励物品
struct RewardItem {
    let itemId: String
    let quantity: Int
}

/// 奖励生成器
class RewardGenerator {

    // MARK: - Singleton

    static let shared = RewardGenerator()

    private init() {}

    // MARK: - Constants

    /// 物品池定义
    private let itemPools: [ItemRarity: [String]] = [
        .common: [
            "item_water_bottle",    // 矿泉水
            "item_canned_food",     // 罐头食品
            "item_bandage",         // 绷带
            "item_wood",            // 木材
            "item_scrap_metal",     // 废金属
            "item_rope"             // 绳子
        ],
        .rare: [
            "item_medicine",        // 药品
            "item_flashlight",      // 手电筒
            "item_first_aid_kit"    // 急救包
        ],
        .epic: [
            "item_antibiotics"      // 抗生素
        ]
    ]

    // MARK: - Public Methods

    /// 根据距离计算奖励等级
    /// - Parameter distance: 行走距离（米）
    /// - Returns: 奖励等级
    func calculateTier(distance: Double) -> RewardTier {
        if distance < 200 {
            return .none
        } else if distance < 500 {
            return .bronze
        } else if distance < 1000 {
            return .silver
        } else if distance < 2000 {
            return .gold
        } else {
            return .diamond
        }
    }

    /// 生成奖励
    /// - Parameter distance: 行走距离（米）
    /// - Returns: 奖励物品列表
    func generateReward(distance: Double) -> [RewardItem] {
        let tier = calculateTier(distance: distance)

        log("距离: \(String(format: "%.1f", distance))米, 等级: \(tier.displayName)", type: .info)

        // 根据等级获取奖励配置
        guard let config = getRewardConfig(for: tier) else {
            log("无奖励", type: .info)
            return []
        }

        log("物品数量: \(config.itemCount)个", type: .info)

        // 生成物品
        var rewards: [RewardItem] = []

        for index in 1...config.itemCount {
            // 根据概率决定稀有度
            let rarity = rollRarity(probabilities: config.rarityProbabilities)
            log("第\(index)个物品: \(rarity.displayName)稀有度", type: .info)

            // 从对应物品池随机抽取
            if let itemId = randomItem(from: rarity) {
                rewards.append(RewardItem(itemId: itemId, quantity: 1))
                log("抽取物品: \(itemId)", type: .success)
            }
        }

        log("生成完成，共\(rewards.count)个物品", type: .success)
        return rewards
    }

    // MARK: - Private Methods

    /// 获取奖励配置
    private func getRewardConfig(for tier: RewardTier) -> RewardConfig? {
        switch tier {
        case .none:
            return nil

        case .bronze:
            return RewardConfig(
                itemCount: 1,
                rarityProbabilities: [
                    .common: 0.90,   // 90%
                    .rare: 0.10,     // 10%
                    .epic: 0.00      // 0%
                ]
            )

        case .silver:
            return RewardConfig(
                itemCount: 2,
                rarityProbabilities: [
                    .common: 0.70,   // 70%
                    .rare: 0.25,     // 25%
                    .epic: 0.05      // 5%
                ]
            )

        case .gold:
            return RewardConfig(
                itemCount: 3,
                rarityProbabilities: [
                    .common: 0.50,   // 50%
                    .rare: 0.35,     // 35%
                    .epic: 0.15      // 15%
                ]
            )

        case .diamond:
            return RewardConfig(
                itemCount: 5,
                rarityProbabilities: [
                    .common: 0.30,   // 30%
                    .rare: 0.40,     // 40%
                    .epic: 0.30      // 30%
                ]
            )
        }
    }

    /// 根据概率掷骰子决定稀有度
    private func rollRarity(probabilities: [ItemRarity: Double]) -> ItemRarity {
        let roll = Double.random(in: 0..<1)
        var accumulated: Double = 0

        // 按顺序累加概率
        for rarity in [ItemRarity.common, .rare, .epic] {
            accumulated += probabilities[rarity] ?? 0
            if roll < accumulated {
                return rarity
            }
        }

        // 默认返回普通
        return .common
    }

    /// 从物品池随机抽取一个物品
    private func randomItem(from rarity: ItemRarity) -> String? {
        guard let pool = itemPools[rarity], !pool.isEmpty else {
            return nil
        }
        return pool.randomElement()
    }

    // MARK: - Logging

    private func log(_ message: String, type: LogType) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let prefix = type.prefix
        print("\(prefix) [\(timestamp)] [RewardGenerator] \(message)")
    }

    enum LogType {
        case info, success

        var prefix: String {
            switch self {
            case .info: return "ℹ️"
            case .success: return "✅"
            }
        }
    }
}

// MARK: - Supporting Types

/// 奖励配置
private struct RewardConfig {
    let itemCount: Int
    let rarityProbabilities: [ItemRarity: Double]
}
