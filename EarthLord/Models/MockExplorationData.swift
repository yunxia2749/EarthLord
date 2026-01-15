//
//  MockExplorationData.swift
//  EarthLord
//
//  探索模块测试假数据
//  用于开发和测试探索功能的 UI 和逻辑
//

import Foundation
import CoreLocation

// MARK: - POI 兴趣点数据

/// POI 发现状态
enum POIDiscoveryStatus: String, Codable {
    case undiscovered = "undiscovered"  // 未发现（地图上不显示或显示为问号）
    case discovered = "discovered"       // 已发现（可以看到详情）
}

/// POI 搜索状态
enum POISearchStatus: String, Codable {
    case hasLoot = "has_loot"           // 有物资可搜刮
    case empty = "empty"                 // 已被搜空
    case notSearched = "not_searched"   // 未搜索（未发现的 POI）
}

/// POI 类型
enum POIType: String, Codable, CaseIterable {
    case supermarket = "supermarket"    // 超市
    case hospital = "hospital"          // 医院
    case gasStation = "gas_station"     // 加油站
    case pharmacy = "pharmacy"          // 药店
    case factory = "factory"            // 工厂
    case warehouse = "warehouse"        // 仓库
    case residence = "residence"        // 民居
    case policeStation = "police"       // 警察局

    /// POI 类型的中文名称
    var displayName: String {
        switch self {
        case .supermarket: return "超市"
        case .hospital: return "医院"
        case .gasStation: return "加油站"
        case .pharmacy: return "药店"
        case .factory: return "工厂"
        case .warehouse: return "仓库"
        case .residence: return "民居"
        case .policeStation: return "警察局"
        }
    }

    /// POI 类型的图标名称
    var iconName: String {
        switch self {
        case .supermarket: return "cart.fill"
        case .hospital: return "cross.case.fill"
        case .gasStation: return "fuelpump.fill"
        case .pharmacy: return "pills.fill"
        case .factory: return "building.2.fill"
        case .warehouse: return "shippingbox.fill"
        case .residence: return "house.fill"
        case .policeStation: return "shield.fill"
        }
    }
}

/// 兴趣点（POI）数据模型
struct POIData: Identifiable, Codable {
    let id: String                          // 唯一标识
    let name: String                        // POI 名称
    let type: POIType                       // POI 类型
    let coordinate: CLLocationCoordinate2D  // 坐标位置
    let discoveryStatus: POIDiscoveryStatus // 发现状态
    let searchStatus: POISearchStatus       // 搜索状态
    let dangerLevel: Int                    // 危险等级 1-5
    let description: String                 // 描述文本

    // Codable 支持 CLLocationCoordinate2D
    enum CodingKeys: String, CodingKey {
        case id, name, type, latitude, longitude, discoveryStatus, searchStatus, dangerLevel, description
    }

    init(id: String, name: String, type: POIType, coordinate: CLLocationCoordinate2D,
         discoveryStatus: POIDiscoveryStatus, searchStatus: POISearchStatus,
         dangerLevel: Int, description: String) {
        self.id = id
        self.name = name
        self.type = type
        self.coordinate = coordinate
        self.discoveryStatus = discoveryStatus
        self.searchStatus = searchStatus
        self.dangerLevel = dangerLevel
        self.description = description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(POIType.self, forKey: .type)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        discoveryStatus = try container.decode(POIDiscoveryStatus.self, forKey: .discoveryStatus)
        searchStatus = try container.decode(POISearchStatus.self, forKey: .searchStatus)
        dangerLevel = try container.decode(Int.self, forKey: .dangerLevel)
        description = try container.decode(String.self, forKey: .description)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(discoveryStatus, forKey: .discoveryStatus)
        try container.encode(searchStatus, forKey: .searchStatus)
        try container.encode(dangerLevel, forKey: .dangerLevel)
        try container.encode(description, forKey: .description)
    }
}

// MARK: - 物品数据

/// 物品分类
enum ItemCategory: String, Codable, CaseIterable {
    case water = "water"        // 水类
    case food = "food"          // 食物
    case medical = "medical"    // 医疗用品
    case material = "material"  // 材料
    case tool = "tool"          // 工具
    case weapon = "weapon"      // 武器
    case clothing = "clothing"  // 服装
    case misc = "misc"          // 杂项

    /// 分类的中文名称
    var displayName: String {
        switch self {
        case .water: return "水类"
        case .food: return "食物"
        case .medical: return "医疗"
        case .material: return "材料"
        case .tool: return "工具"
        case .weapon: return "武器"
        case .clothing: return "服装"
        case .misc: return "杂项"
        }
    }

    /// 分类的图标名称
    var iconName: String {
        switch self {
        case .water: return "drop.fill"
        case .food: return "fork.knife"
        case .medical: return "cross.case.fill"
        case .material: return "cube.fill"
        case .tool: return "wrench.and.screwdriver.fill"
        case .weapon: return "bolt.fill"
        case .clothing: return "tshirt.fill"
        case .misc: return "shippingbox.fill"
        }
    }
}

/// 物品稀有度
enum ItemRarity: String, Codable, CaseIterable {
    case common = "common"          // 普通（白色）
    case uncommon = "uncommon"      // 优良（绿色）
    case rare = "rare"              // 稀有（蓝色）
    case epic = "epic"              // 史诗（紫色）
    case legendary = "legendary"    // 传说（橙色）

    /// 稀有度的中文名称
    var displayName: String {
        switch self {
        case .common: return "普通"
        case .uncommon: return "优良"
        case .rare: return "稀有"
        case .epic: return "史诗"
        case .legendary: return "传说"
        }
    }
}

/// 物品品质（百分比，影响物品效果）
enum ItemQuality: String, Codable {
    case pristine = "pristine"      // 完好 100%
    case good = "good"              // 良好 75%
    case worn = "worn"              // 磨损 50%
    case damaged = "damaged"        // 损坏 25%
    case broken = "broken"          // 破损 10%

    /// 品质的中文名称
    var displayName: String {
        switch self {
        case .pristine: return "完好"
        case .good: return "良好"
        case .worn: return "磨损"
        case .damaged: return "损坏"
        case .broken: return "破损"
        }
    }

    /// 品质对应的效果百分比
    var effectPercent: Double {
        switch self {
        case .pristine: return 1.0
        case .good: return 0.75
        case .worn: return 0.50
        case .damaged: return 0.25
        case .broken: return 0.10
        }
    }
}

/// 物品定义（静态数据，定义物品的基本属性）
struct ItemDefinition: Identifiable, Codable {
    let id: String              // 物品唯一ID（如 "item_water_bottle"）
    let name: String            // 中文名称
    let category: ItemCategory  // 分类
    let weight: Double          // 单个重量（kg）
    let volume: Double          // 单个体积（升）
    let rarity: ItemRarity      // 稀有度
    let description: String     // 物品描述
    let stackable: Bool         // 是否可堆叠
    let maxStack: Int           // 最大堆叠数量
    let hasQuality: Bool        // 是否有品质属性（工具类有，消耗品无）
}

/// 背包物品（玩家持有的物品实例）
struct InventoryItem: Identifiable, Codable {
    let id: String              // 实例唯一ID
    let itemId: String          // 对应的物品定义ID
    var quantity: Int           // 数量
    let quality: ItemQuality?   // 品质（可选，消耗品无品质）
    let obtainedAt: Date        // 获得时间

    /// 计算总重量
    func totalWeight(definition: ItemDefinition) -> Double {
        return definition.weight * Double(quantity)
    }
}

// MARK: - 探索结果数据

/// 探索统计数据
struct ExplorationStats: Codable {
    // 行走距离
    let walkDistanceThisTime: Double    // 本次行走距离（米）
    let walkDistanceTotal: Double       // 累计行走距离（米）

    // 探索时长
    let explorationDuration: TimeInterval   // 探索时长（秒）
}

/// 探索结果（一次探索活动的结果）
struct ExplorationResult: Identifiable, Codable {
    let id: String                      // 结果ID
    let startTime: Date                 // 开始时间
    let endTime: Date                   // 结束时间
    let stats: ExplorationStats         // 统计数据
    let obtainedItems: [ObtainedItem]   // 获得的物品列表
    let experienceGained: Int           // 获得的经验值
    let rewardsAddedSuccessfully: Bool  // 奖励是否成功添加到背包
    let rewardsErrorMessage: String?    // 奖励添加失败的错误信息

    /// 便捷初始化（向后兼容）
    init(id: String, startTime: Date, endTime: Date, stats: ExplorationStats,
         obtainedItems: [ObtainedItem], experienceGained: Int,
         rewardsAddedSuccessfully: Bool = true, rewardsErrorMessage: String? = nil) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.stats = stats
        self.obtainedItems = obtainedItems
        self.experienceGained = experienceGained
        self.rewardsAddedSuccessfully = rewardsAddedSuccessfully
        self.rewardsErrorMessage = rewardsErrorMessage
    }
}

/// 获得的物品（探索结果中的物品）
struct ObtainedItem: Identifiable, Codable {
    let id: String          // 唯一ID
    let itemId: String      // 物品定义ID
    let quantity: Int       // 数量
    let quality: ItemQuality?   // 品质（可选）
    let source: String      // 来源（如 POI 名称）
}

// MARK: - Mock 数据

/// 探索模块假数据
struct MockExplorationData {

    // MARK: - POI 假数据

    /// 5个不同状态的兴趣点
    /// 用于测试地图上的 POI 显示和交互
    static let mockPOIs: [POIData] = [
        // 废弃超市：已发现，有物资
        POIData(
            id: "poi_001",
            name: "废弃超市",
            type: .supermarket,
            coordinate: CLLocationCoordinate2D(latitude: 22.2480, longitude: 112.8095),
            discoveryStatus: .discovered,
            searchStatus: .hasLoot,
            dangerLevel: 2,
            description: "一家废弃的小型超市，货架上还残留着一些物资。门窗破损，需要小心玻璃碎片。"
        ),

        // 医院废墟：已发现，已被搜空
        POIData(
            id: "poi_002",
            name: "医院废墟",
            type: .hospital,
            coordinate: CLLocationCoordinate2D(latitude: 22.2465, longitude: 112.8110),
            discoveryStatus: .discovered,
            searchStatus: .empty,
            dangerLevel: 4,
            description: "曾经的区级医院，已被多次搜刮，几乎没有剩余物资。建筑结构不稳定，危险等级较高。"
        ),

        // 加油站：未发现
        POIData(
            id: "poi_003",
            name: "加油站",
            type: .gasStation,
            coordinate: CLLocationCoordinate2D(latitude: 22.2490, longitude: 112.8080),
            discoveryStatus: .undiscovered,
            searchStatus: .notSearched,
            dangerLevel: 3,
            description: "位置未知，需要靠近才能发现。"
        ),

        // 药店废墟：已发现，有物资
        POIData(
            id: "poi_004",
            name: "药店废墟",
            type: .pharmacy,
            coordinate: CLLocationCoordinate2D(latitude: 22.2475, longitude: 112.8100),
            discoveryStatus: .discovered,
            searchStatus: .hasLoot,
            dangerLevel: 2,
            description: "街角的小药店，部分药品还在有效期内。货架倒塌严重，搜索需要花费较长时间。"
        ),

        // 工厂废墟：未发现
        POIData(
            id: "poi_005",
            name: "工厂废墟",
            type: .factory,
            coordinate: CLLocationCoordinate2D(latitude: 22.2455, longitude: 112.8120),
            discoveryStatus: .undiscovered,
            searchStatus: .notSearched,
            dangerLevel: 5,
            description: "位置未知，需要靠近才能发现。"
        )
    ]

    // MARK: - 物品定义表

    /// 物品定义表
    /// 记录每种物品的基本属性，用于生成物品实例
    static let itemDefinitions: [ItemDefinition] = [
        // 水类
        ItemDefinition(
            id: "item_water_bottle",
            name: "矿泉水",
            category: .water,
            weight: 0.5,
            volume: 0.5,
            rarity: .common,
            description: "普通的瓶装矿泉水，可以补充水分。",
            stackable: true,
            maxStack: 10,
            hasQuality: false
        ),

        // 食物
        ItemDefinition(
            id: "item_canned_food",
            name: "罐头食品",
            category: .food,
            weight: 0.4,
            volume: 0.3,
            rarity: .common,
            description: "密封保存的罐头食品，保质期较长。",
            stackable: true,
            maxStack: 10,
            hasQuality: false
        ),

        // 医疗 - 绷带
        ItemDefinition(
            id: "item_bandage",
            name: "绷带",
            category: .medical,
            weight: 0.1,
            volume: 0.1,
            rarity: .common,
            description: "基础的医疗绷带，可以处理轻微伤口。",
            stackable: true,
            maxStack: 20,
            hasQuality: false
        ),

        // 医疗 - 药品
        ItemDefinition(
            id: "item_medicine",
            name: "药品",
            category: .medical,
            weight: 0.05,
            volume: 0.05,
            rarity: .uncommon,
            description: "各类常用药品，可以治疗疾病。",
            stackable: true,
            maxStack: 10,
            hasQuality: false
        ),

        // 材料 - 木材
        ItemDefinition(
            id: "item_wood",
            name: "木材",
            category: .material,
            weight: 2.0,
            volume: 3.0,
            rarity: .common,
            description: "基础建筑材料，用于建造和修复。",
            stackable: true,
            maxStack: 50,
            hasQuality: false
        ),

        // 材料 - 废金属
        ItemDefinition(
            id: "item_scrap_metal",
            name: "废金属",
            category: .material,
            weight: 1.5,
            volume: 1.0,
            rarity: .common,
            description: "回收的金属碎片，可以用于制造和修理。",
            stackable: true,
            maxStack: 50,
            hasQuality: false
        ),

        // 工具 - 手电筒
        ItemDefinition(
            id: "item_flashlight",
            name: "手电筒",
            category: .tool,
            weight: 0.3,
            volume: 0.2,
            rarity: .uncommon,
            description: "便携式手电筒，夜间探索必备。需要电池供电。",
            stackable: false,
            maxStack: 1,
            hasQuality: true  // 工具有品质
        ),

        // 工具 - 绳子
        ItemDefinition(
            id: "item_rope",
            name: "绳子",
            category: .tool,
            weight: 0.5,
            volume: 0.3,
            rarity: .common,
            description: "结实的尼龙绳，用途广泛。",
            stackable: true,
            maxStack: 5,
            hasQuality: true  // 工具有品质
        )
    ]

    // MARK: - 背包物品假数据

    /// 背包物品列表
    /// 模拟玩家当前持有的物品
    static let mockInventory: [InventoryItem] = [
        // 矿泉水 x3
        InventoryItem(
            id: "inv_001",
            itemId: "item_water_bottle",
            quantity: 3,
            quality: nil,  // 消耗品无品质
            obtainedAt: Date().addingTimeInterval(-3600)
        ),

        // 罐头食品 x5
        InventoryItem(
            id: "inv_002",
            itemId: "item_canned_food",
            quantity: 5,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-7200)
        ),

        // 绷带 x8
        InventoryItem(
            id: "inv_003",
            itemId: "item_bandage",
            quantity: 8,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-1800)
        ),

        // 药品 x2
        InventoryItem(
            id: "inv_004",
            itemId: "item_medicine",
            quantity: 2,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-5400)
        ),

        // 木材 x12
        InventoryItem(
            id: "inv_005",
            itemId: "item_wood",
            quantity: 12,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-10800)
        ),

        // 废金属 x7
        InventoryItem(
            id: "inv_006",
            itemId: "item_scrap_metal",
            quantity: 7,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-9000)
        ),

        // 手电筒 x1（良好品质）
        InventoryItem(
            id: "inv_007",
            itemId: "item_flashlight",
            quantity: 1,
            quality: .good,  // 工具有品质
            obtainedAt: Date().addingTimeInterval(-14400)
        ),

        // 绳子 x2（磨损品质）
        InventoryItem(
            id: "inv_008",
            itemId: "item_rope",
            quantity: 2,
            quality: .worn,  // 工具有品质
            obtainedAt: Date().addingTimeInterval(-12000)
        )
    ]

    // MARK: - 探索结果假数据

    /// 探索结果示例
    /// 模拟一次完整的探索活动结果
    static let mockExplorationResult = ExplorationResult(
        id: "explore_001",
        startTime: Date().addingTimeInterval(-1800),  // 30分钟前开始
        endTime: Date(),                               // 现在结束
        stats: ExplorationStats(
            walkDistanceThisTime: 2500,     // 本次 2500 米
            walkDistanceTotal: 15000,       // 累计 15000 米
            explorationDuration: 1800       // 30 分钟（1800 秒）
        ),
        obtainedItems: [
            // 木材 x5
            ObtainedItem(
                id: "obtained_001",
                itemId: "item_wood",
                quantity: 5,
                quality: nil,
                source: "废弃超市"
            ),
            // 矿泉水 x3
            ObtainedItem(
                id: "obtained_002",
                itemId: "item_water_bottle",
                quantity: 3,
                quality: nil,
                source: "废弃超市"
            ),
            // 罐头 x2
            ObtainedItem(
                id: "obtained_003",
                itemId: "item_canned_food",
                quantity: 2,
                quality: nil,
                source: "废弃超市"
            )
        ],
        experienceGained: 150  // 获得 150 经验
    )

    // MARK: - 辅助方法

    /// 根据物品ID获取物品定义
    static func getItemDefinition(by id: String) -> ItemDefinition? {
        return itemDefinitions.first { $0.id == id }
    }

    /// 计算背包总重量
    static func calculateTotalWeight() -> Double {
        return mockInventory.reduce(0) { total, item in
            guard let definition = getItemDefinition(by: item.itemId) else { return total }
            return total + item.totalWeight(definition: definition)
        }
    }

    /// 计算背包物品总数
    static func calculateTotalItemCount() -> Int {
        return mockInventory.reduce(0) { $0 + $1.quantity }
    }

    /// 格式化距离显示
    static func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    /// 格式化面积显示
    static func formatArea(_ squareMeters: Double) -> String {
        if squareMeters >= 1_000_000 {
            return String(format: "%.2f km²", squareMeters / 1_000_000)
        } else if squareMeters >= 10000 {
            return String(format: "%.1f 万m²", squareMeters / 10000)
        } else {
            return String(format: "%.0f m²", squareMeters)
        }
    }

    /// 格式化时长显示
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return "\(hours)小时\(remainingMinutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}
