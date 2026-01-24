//
//  AIItemGenerator.swift
//  EarthLord
//
//  AI 物品生成器：调用 Edge Function 生成 AI 物品
//

import Foundation
import Supabase

// MARK: - AI 生成物品数据模型

/// AI 生成的物品（从服务端返回的原始数据）
struct AIGeneratedItem: Codable {
    let name: String        // 独特名称，如"老张的最后晚餐"
    let category: String    // 分类：医疗/食物/工具/武器/材料
    let rarity: String      // 稀有度：common/uncommon/rare/epic/legendary
    let story: String       // 背景故事
}

/// 搜刮奖励物品（用于 UI 显示和背包存储）
struct ScavengeRewardItem: Identifiable {
    let id: String          // UUID
    let name: String        // AI 生成的独特名称
    let category: String    // 物品分类
    let rarity: ItemRarity  // 稀有度枚举
    let story: String       // 背景故事
    let quantity: Int       // 数量（AI 物品默认为 1）
    let isAIGenerated: Bool // 标记是否为 AI 生成

    init(from aiItem: AIGeneratedItem) {
        self.id = UUID().uuidString
        self.name = aiItem.name
        self.category = aiItem.category
        self.rarity = ItemRarity(rawValue: aiItem.rarity) ?? .common
        self.story = aiItem.story
        self.quantity = 1
        self.isAIGenerated = true
    }

    /// 从预设物品创建（降级方案）
    init(presetItemId: String, name: String, category: String, rarity: ItemRarity) {
        self.id = UUID().uuidString
        self.name = name
        self.category = category
        self.rarity = rarity
        self.story = "这是一个普通的\(name)。"
        self.quantity = 1
        self.isAIGenerated = false
    }
}

// MARK: - Edge Function 请求/响应模型

/// 请求体中的 POI 信息
private struct POIRequestInfo: Encodable {
    let name: String
    let type: String
    let dangerLevel: Int
}

/// Edge Function 请求体
private struct GenerateItemRequest: Encodable {
    let poi: POIRequestInfo
    let itemCount: Int
}

/// Edge Function 响应体
private struct GenerateItemResponse: Decodable {
    let success: Bool
    let items: [AIGeneratedItem]?
    let error: String?
}

// MARK: - AI 物品生成器

/// AI 物品生成器
/// 负责调用 Edge Function 生成 AI 物品，以及降级方案
@MainActor
final class AIItemGenerator {

    // MARK: - Singleton

    static let shared = AIItemGenerator()

    private init() {}

    // MARK: - 预设物品库（降级方案）

    /// 预设物品库 - 按 POI 类型分类
    private let presetItemsByPOIType: [String: [(id: String, name: String, category: String, rarity: ItemRarity)]] = [
        "supermarket": [
            ("item_water_bottle", "矿泉水", "食物", .common),
            ("item_canned_food", "罐头食品", "食物", .common),
            ("item_bandage", "绷带", "医疗", .common),
            ("item_flashlight", "手电筒", "工具", .uncommon),
            ("item_snack", "过期零食", "食物", .common)
        ],
        "hospital": [
            ("item_medicine", "药品", "医疗", .uncommon),
            ("item_bandage", "绷带", "医疗", .common),
            ("item_first_aid_kit", "急救包", "医疗", .rare),
            ("item_antibiotics", "抗生素", "医疗", .epic),
            ("item_scalpel", "手术刀", "工具", .uncommon)
        ],
        "pharmacy": [
            ("item_medicine", "药品", "医疗", .uncommon),
            ("item_bandage", "绷带", "医疗", .common),
            ("item_antibiotics", "抗生素", "医疗", .rare),
            ("item_painkillers", "止痛片", "医疗", .common)
        ],
        "gas_station": [
            ("item_flashlight", "手电筒", "工具", .uncommon),
            ("item_rope", "绳子", "工具", .common),
            ("item_scrap_metal", "废金属", "材料", .common),
            ("item_fuel_can", "燃料罐", "材料", .uncommon)
        ],
        "police": [
            ("item_flashlight", "手电筒", "工具", .uncommon),
            ("item_rope", "绳子", "工具", .common),
            ("item_first_aid_kit", "急救包", "医疗", .rare),
            ("item_baton", "警棍", "武器", .uncommon)
        ],
        "factory": [
            ("item_scrap_metal", "废金属", "材料", .common),
            ("item_rope", "绳子", "工具", .common),
            ("item_wrench", "扳手", "工具", .uncommon),
            ("item_wire", "电线", "材料", .common)
        ],
        "warehouse": [
            ("item_canned_food", "罐头食品", "食物", .common),
            ("item_wood", "木材", "材料", .common),
            ("item_rope", "绳子", "工具", .common),
            ("item_tarp", "防水布", "材料", .uncommon)
        ],
        "residence": [
            ("item_water_bottle", "矿泉水", "食物", .common),
            ("item_canned_food", "罐头食品", "食物", .common),
            ("item_bandage", "绷带", "医疗", .common),
            ("item_kitchen_knife", "厨刀", "工具", .common)
        ]
    ]

    /// 默认物品池
    private let defaultItemPool: [(id: String, name: String, category: String, rarity: ItemRarity)] = [
        ("item_water_bottle", "矿泉水", "食物", .common),
        ("item_canned_food", "罐头食品", "食物", .common),
        ("item_bandage", "绷带", "医疗", .common),
        ("item_wood", "木材", "材料", .common),
        ("item_rope", "绳子", "工具", .common)
    ]

    // MARK: - 公开方法

    /// 为 POI 生成物品
    /// - Parameters:
    ///   - poi: POI 数据
    ///   - count: 物品数量（默认 3 个）
    /// - Returns: 搜刮奖励物品列表
    func generateItems(for poi: POIData, count: Int = 3) async -> [ScavengeRewardItem] {
        log("开始为 POI 生成物品: \(poi.name), 危险等级: \(poi.dangerLevel)", type: .info)

        // 尝试调用 AI 生成
        if let aiItems = await fetchAIItems(for: poi, count: count) {
            log("AI 生成成功，获得 \(aiItems.count) 个物品", type: .success)
            return aiItems.map { ScavengeRewardItem(from: $0) }
        }

        // AI 失败，使用降级方案
        log("AI 生成失败，使用预设物品库", type: .warning)
        return generateFallbackItems(for: poi, count: count)
    }

    // MARK: - 私有方法

    /// 调用 Edge Function 获取 AI 物品
    private func fetchAIItems(for poi: POIData, count: Int) async -> [AIGeneratedItem]? {
        do {
            // 构建请求
            let request = GenerateItemRequest(
                poi: POIRequestInfo(
                    name: poi.name,
                    type: poi.type.rawValue,
                    dangerLevel: poi.dangerLevel
                ),
                itemCount: count
            )

            log("调用 Edge Function: generate-ai-item", type: .info)

            // 调用 Edge Function
            let response: GenerateItemResponse = try await supabase.functions
                .invoke(
                    "generate-ai-item",
                    options: .init(body: request)
                )

            // 检查响应
            if response.success, let items = response.items {
                return items
            } else {
                log("Edge Function 返回失败: \(response.error ?? "未知错误")", type: .error)
                return nil
            }

        } catch {
            log("调用 Edge Function 失败: \(error.localizedDescription)", type: .error)
            return nil
        }
    }

    /// 生成降级物品（预设物品库）
    private func generateFallbackItems(for poi: POIData, count: Int) -> [ScavengeRewardItem] {
        let poiTypeKey = poi.type.rawValue
        let itemPool = presetItemsByPOIType[poiTypeKey] ?? defaultItemPool

        var results: [ScavengeRewardItem] = []

        for _ in 0..<count {
            if let item = itemPool.randomElement() {
                let rewardItem = ScavengeRewardItem(
                    presetItemId: item.id,
                    name: item.name,
                    category: item.category,
                    rarity: item.rarity
                )
                results.append(rewardItem)
            }
        }

        return results
    }

    // MARK: - 日志

    private func log(_ message: String, type: LogType) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let prefix = type.prefix
        print("\(prefix) [\(timestamp)] [AIItemGenerator] \(message)")
    }

    private enum LogType {
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
