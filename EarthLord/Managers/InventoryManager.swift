//
//  InventoryManager.swift
//  EarthLord
//
//  背包管理器：管理用户背包物品、与数据库同步
//

import Foundation
import Combine
import Supabase

/// 背包管理器
@MainActor
class InventoryManager: ObservableObject {

    // MARK: - Singleton

    static let shared = InventoryManager()

    private init() {}

    // MARK: - Published Properties

    /// 背包物品列表
    @Published var items: [InventoryItem] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    // MARK: - Private Properties

    // 注意：使用全局的 supabase 实例（定义在 SupabaseTestView.swift）
    // 确保与 AuthManager 使用相同的认证会话

    // MARK: - Public Methods

    /// 加载背包物品
    func loadInventory() async throws {
        log("开始加载背包物品", type: .info)
        isLoading = true

        defer {
            isLoading = false
        }

        do {
            guard let userId = try? await supabase.auth.session.user.id else {
                log("获取用户ID失败", type: .error)
                throw InventoryError.userNotFound
            }

            // 查询背包物品
            struct InventoryItemDB: Decodable {
                let id: String
                let user_id: String
                let item_id: String
                let quantity: Int
                let obtained_at: String
            }

            let dbItems: [InventoryItemDB] = try await supabase
                .from("inventory_items")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            // 转换为UI模型
            items = dbItems.map { dbItem in
                InventoryItem(
                    id: dbItem.id,
                    itemId: dbItem.item_id,
                    quantity: dbItem.quantity,
                    quality: nil,
                    obtainedAt: ISO8601DateFormatter().date(from: dbItem.obtained_at) ?? Date()
                )
            }

            log("背包加载完成，共\(items.count)种物品", type: .success)
        } catch {
            log("加载背包失败: \(error.localizedDescription)", type: .error)
            throw error
        }
    }

    /// 添加物品到背包
    /// - Parameter rewards: 奖励物品列表
    func addItems(_ rewards: [RewardItem]) async throws {
        guard !rewards.isEmpty else {
            log("奖励列表为空，跳过添加", type: .info)
            return
        }

        log("========== 开始添加物品到背包 ==========", type: .info)
        log("待添加物品数量: \(rewards.count)", type: .info)
        for (index, reward) in rewards.enumerated() {
            log("  [\(index + 1)] \(reward.itemId) x\(reward.quantity)", type: .info)
        }

        do {
            // 获取用户ID
            log("正在获取用户ID...", type: .info)
            guard let userId = try? await supabase.auth.session.user.id else {
                log("获取用户ID失败 - 用户可能未登录或会话已过期", type: .error)
                throw InventoryError.userNotFound
            }
            log("用户ID: \(userId.uuidString)", type: .success)

            for reward in rewards {
                // 检查物品是否已存在
                struct ExistingItem: Decodable {
                    let id: String
                    let quantity: Int
                }

                let existingItems: [ExistingItem] = try await supabase
                    .from("inventory_items")
                    .select("id, quantity")
                    .eq("user_id", value: userId.uuidString)
                    .eq("item_id", value: reward.itemId)
                    .execute()
                    .value

                if let existing = existingItems.first {
                    // 物品已存在，更新数量
                    let newQuantity = existing.quantity + reward.quantity
                    log("物品已存在，准备更新数量: \(existing.quantity) + \(reward.quantity) = \(newQuantity)", type: .info)

                    struct QuantityUpdate: Encodable {
                        let quantity: Int
                    }

                    try await supabase
                        .from("inventory_items")
                        .update(QuantityUpdate(quantity: newQuantity))
                        .eq("id", value: existing.id)
                        .execute()

                    log("物品\(reward.itemId)数量已更新: +\(reward.quantity) (总计: \(newQuantity))", type: .success)
                } else {
                    // 物品不存在，创建新记录
                    log("物品不存在，准备创建新记录", type: .info)

                    struct NewItem: Encodable {
                        let user_id: String
                        let item_id: String
                        let quantity: Int
                        let obtained_at: String
                    }

                    let newItem = NewItem(
                        user_id: userId.uuidString,
                        item_id: reward.itemId,
                        quantity: reward.quantity,
                        obtained_at: ISO8601DateFormatter().string(from: Date())
                    )

                    log("插入数据: user_id=\(userId.uuidString), item_id=\(reward.itemId), quantity=\(reward.quantity)", type: .info)

                    try await supabase
                        .from("inventory_items")
                        .insert(newItem)
                        .execute()

                    log("新物品\(reward.itemId)已添加: x\(reward.quantity)", type: .success)
                }
            }

            // 重新加载背包
            log("正在重新加载背包数据...", type: .info)
            try await loadInventory()

            log("========== 所有物品添加完成 ==========", type: .success)
        } catch {
            log("========== 添加物品失败 ==========", type: .error)
            log("错误类型: \(type(of: error))", type: .error)
            log("错误详情: \(error)", type: .error)
            throw error
        }
    }

    /// 移除物品
    /// - Parameters:
    ///   - itemId: 物品ID
    ///   - quantity: 数量
    func removeItem(itemId: String, quantity: Int) async throws {
        log("移除物品: \(itemId), 数量: \(quantity)", type: .info)

        do {
            guard let userId = try? await supabase.auth.session.user.id else {
                log("获取用户ID失败", type: .error)
                throw InventoryError.userNotFound
            }

            // 查询现有物品
            struct ExistingItem: Decodable {
                let id: String
                let quantity: Int
            }

            let existingItems: [ExistingItem] = try await supabase
                .from("inventory_items")
                .select("id, quantity")
                .eq("user_id", value: userId.uuidString)
                .eq("item_id", value: itemId)
                .execute()
                .value

            guard let existing = existingItems.first else {
                log("物品不存在", type: .error)
                throw InventoryError.itemNotFound
            }

            let newQuantity = existing.quantity - quantity

            if newQuantity <= 0 {
                // 删除物品
                try await supabase
                    .from("inventory_items")
                    .delete()
                    .eq("id", value: existing.id)
                    .execute()

                log("物品已删除", type: .success)
            } else {
                // 更新数量
                struct QuantityUpdate: Encodable {
                    let quantity: Int
                }

                try await supabase
                    .from("inventory_items")
                    .update(QuantityUpdate(quantity: newQuantity))
                    .eq("id", value: existing.id)
                    .execute()

                log("物品数量已更新: -\(quantity) (剩余: \(newQuantity))", type: .success)
            }

            // 重新加载背包
            try await loadInventory()
        } catch {
            log("移除物品失败: \(error.localizedDescription)", type: .error)
            throw error
        }
    }

    // MARK: - Logging

    private func log(_ message: String, type: LogType) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let prefix = type.prefix
        print("\(prefix) [\(timestamp)] [InventoryManager] \(message)")
    }

    enum LogType {
        case info, error, success

        var prefix: String {
            switch self {
            case .info: return "ℹ️"
            case .error: return "❌"
            case .success: return "✅"
            }
        }
    }
}

// MARK: - Errors

enum InventoryError: Error {
    case userNotFound
    case itemNotFound

    var localizedDescription: String {
        switch self {
        case .userNotFound:
            return "用户未登录"
        case .itemNotFound:
            return "物品不存在"
        }
    }
}
