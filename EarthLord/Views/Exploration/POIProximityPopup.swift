//
//  POIProximityPopup.swift
//  EarthLord
//
//  POI接近弹窗：玩家进入POI范围时显示的搜刮提示
//

import SwiftUI
import CoreLocation

/// POI接近弹窗视图
struct POIProximityPopup: View {

    /// POI数据
    let poi: POIData

    /// 用户当前位置（用于计算距离）
    let userLocation: CLLocationCoordinate2D?

    /// 立即搜刮回调
    let onScavenge: () -> Void

    /// 稍后再说回调
    let onDismiss: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 顶部装饰条
            Rectangle()
                .fill(ApocalypseTheme.warning)
                .frame(height: 4)

            VStack(spacing: 16) {
                // 标题区域
                HStack(spacing: 12) {
                    // POI图标
                    ZStack {
                        Circle()
                            .fill(ApocalypseTheme.warning.opacity(0.2))
                            .frame(width: 50, height: 50)

                        Image(systemName: poi.type.iconName)
                            .font(.system(size: 24))
                            .foregroundColor(ApocalypseTheme.warning)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("发现废墟")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Text(poi.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .lineLimit(1)

                        // 距离信息
                        if let distance = calculateDistance() {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 10))
                                Text("距离: \(Int(distance))米")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }

                    Spacer()
                }

                // 分隔线
                Rectangle()
                    .fill(ApocalypseTheme.textSecondary.opacity(0.2))
                    .frame(height: 1)

                // POI类型标签
                HStack {
                    Label(poi.type.displayName, systemImage: poi.type.iconName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.warning)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(ApocalypseTheme.warning.opacity(0.15))
                        )

                    Spacer()

                    // 危险等级
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < poi.dangerLevel ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                                .font(.system(size: 10))
                                .foregroundColor(index < poi.dangerLevel ? dangerColor : ApocalypseTheme.textSecondary.opacity(0.3))
                        }
                    }
                }

                // 按钮区域
                HStack(spacing: 12) {
                    // 稍后再说
                    Button(action: onDismiss) {
                        Text("稍后再说")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(ApocalypseTheme.textSecondary.opacity(0.3), lineWidth: 1)
                            )
                    }

                    // 立即搜刮
                    Button(action: onScavenge) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                            Text("立即搜刮")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(ApocalypseTheme.warning)
                        )
                    }
                }
            }
            .padding(20)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ApocalypseTheme.warning.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 20)
    }

    // MARK: - Computed Properties

    /// 计算到POI的距离
    private func calculateDistance() -> Double? {
        guard let userLoc = userLocation else { return nil }

        let userCLLocation = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        let poiCLLocation = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)

        return userCLLocation.distance(from: poiCLLocation)
    }

    /// 危险等级颜色
    private var dangerColor: Color {
        switch poi.dangerLevel {
        case 1: return .green
        case 2: return .yellow
        case 3: return .orange
        case 4, 5: return .red
        default: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        POIProximityPopup(
            poi: POIData(
                id: "test_poi",
                name: "废弃超市",
                type: .supermarket,
                coordinate: CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
                discoveryStatus: .discovered,
                searchStatus: .hasLoot,
                dangerLevel: 2,
                description: "这是一个废弃的超市"
            ),
            userLocation: CLLocationCoordinate2D(latitude: 31.2305, longitude: 121.4738),
            onScavenge: { print("搜刮") },
            onDismiss: { print("稍后") }
        )
    }
}
