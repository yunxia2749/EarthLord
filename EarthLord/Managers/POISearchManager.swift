//
//  POISearchManager.swift
//  EarthLord
//
//  POI搜索管理器：使用MapKit搜索附近真实地点
//

import Foundation
import MapKit
import CoreLocation
import Combine

/// POI搜索管理器
/// 负责调用MapKit搜索附近1公里内的真实POI
@MainActor
class POISearchManager: ObservableObject {

    // MARK: - Singleton

    static let shared = POISearchManager()

    private init() {}

    // MARK: - Published Properties

    /// 是否正在搜索
    @Published var isSearching: Bool = false

    /// 搜索错误信息
    @Published var searchError: String?

    // MARK: - Constants

    /// 搜索半径（米）
    private let searchRadius: CLLocationDistance = 1000

    /// 每种类型最多返回的POI数量
    private let maxResultsPerCategory: Int = 5

    /// 要搜索的POI类型列表
    private let searchCategories: [MKPointOfInterestCategory] = [
        .store,           // 商店
        .foodMarket,      // 超市/食品市场
        .hospital,        // 医院
        .pharmacy,        // 药店
        .gasStation,      // 加油站
        .restaurant,      // 餐厅
        .cafe             // 咖啡店
    ]

    // MARK: - Public Methods

    /// 搜索附近的POI
    /// - Parameter center: 搜索中心点（用户当前位置）
    /// - Returns: POI数据列表
    func searchNearbyPOIs(center: CLLocationCoordinate2D) async -> [POIData] {
        log("========== 开始搜索附近POI ==========", type: .info)
        log("搜索中心: (\(String(format: "%.6f", center.latitude)), \(String(format: "%.6f", center.longitude)))", type: .info)
        log("搜索半径: \(searchRadius)米", type: .info)

        isSearching = true
        searchError = nil

        var allPOIs: [POIData] = []

        // 搜索多种类型的POI
        for category in searchCategories {
            do {
                let pois = try await searchPOIs(center: center, category: category)
                allPOIs.append(contentsOf: pois)
                log("[\(categoryDisplayName(category))] 找到 \(pois.count) 个POI", type: .success)
            } catch {
                log("[\(categoryDisplayName(category))] 搜索失败: \(error.localizedDescription)", type: .error)
            }
        }

        // 去重（按ID）
        var uniquePOIs: [POIData] = []
        var seenIds: Set<String> = []
        for poi in allPOIs {
            if !seenIds.contains(poi.id) {
                seenIds.insert(poi.id)
                uniquePOIs.append(poi)
            }
        }

        // 限制总数量（最多20个，因为地理围栏有数量限制）
        let limitedPOIs = Array(uniquePOIs.prefix(20))

        isSearching = false

        log("========== 搜索完成 ==========", type: .success)
        log("总计找到 \(limitedPOIs.count) 个POI", type: .success)

        return limitedPOIs
    }

    // MARK: - Private Methods

    /// 搜索特定类型的POI
    private func searchPOIs(center: CLLocationCoordinate2D, category: MKPointOfInterestCategory) async throws -> [POIData] {
        // 创建搜索请求
        let request = MKLocalPointsOfInterestRequest(center: center, radius: searchRadius)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [category])

        // 执行搜索
        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        // 转换结果
        let pois = response.mapItems.prefix(maxResultsPerCategory).map { mapItem -> POIData in
            let coordinate = mapItem.placemark.coordinate
            let name = mapItem.name ?? "未知地点"
            let poiType = mapCategoryToType(category)

            return POIData(
                id: UUID().uuidString,
                name: name,
                type: poiType,
                coordinate: coordinate,
                discoveryStatus: .discovered,
                searchStatus: .hasLoot,
                dangerLevel: Int.random(in: 1...3),
                description: generateDescription(for: poiType, name: name)
            )
        }

        return Array(pois)
    }

    /// 将MapKit类型映射到游戏POI类型
    private func mapCategoryToType(_ category: MKPointOfInterestCategory) -> POIType {
        switch category {
        case .store, .foodMarket:
            return .supermarket
        case .hospital:
            return .hospital
        case .pharmacy:
            return .pharmacy
        case .gasStation:
            return .gasStation
        case .restaurant, .cafe:
            return .residence  // 餐厅/咖啡店映射为民居
        default:
            return .warehouse
        }
    }

    /// 获取类型显示名称
    private func categoryDisplayName(_ category: MKPointOfInterestCategory) -> String {
        switch category {
        case .store: return "商店"
        case .foodMarket: return "超市"
        case .hospital: return "医院"
        case .pharmacy: return "药店"
        case .gasStation: return "加油站"
        case .restaurant: return "餐厅"
        case .cafe: return "咖啡店"
        default: return "其他"
        }
    }

    /// 生成POI描述
    private func generateDescription(for type: POIType, name: String) -> String {
        let descriptions: [POIType: [String]] = [
            .supermarket: ["废弃的\(name)，货架上可能还有物资", "看起来已经被搜刮过，但角落里可能有遗漏"],
            .hospital: ["医疗设施，可能有急需的药品", "医院废墟，小心潜伏的危险"],
            .pharmacy: ["药店遗址，或许能找到有用的药物", "门窗破损的药房"],
            .gasStation: ["加油站，燃料和工具的好去处", "废弃的加油站，小心易燃物"],
            .residence: ["普通建筑，可能有日用品", "看起来有人居住过的痕迹"],
            .warehouse: ["仓库废墟，物资储备地", "大型仓库，值得探索"],
            .factory: ["工厂遗址，可能有工具和材料", "废弃工厂"],
            .policeStation: ["警察局，可能有特殊物资", "警局废墟"]
        ]

        return descriptions[type]?.randomElement() ?? "一个值得探索的地点"
    }

    // MARK: - Logging

    private func log(_ message: String, type: LogType) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let prefix = type.prefix
        print("\(prefix) [\(timestamp)] [POISearchManager] \(message)")
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
