//
//  TestMenuView.swift
//  EarthLord
//
//  开发测试菜单：提供各个测试模块的入口
//

import SwiftUI

struct TestMenuView: View {

    /// 定位管理器（从父视图注入，传递给子视图）
    @EnvironmentObject var locationManager: LocationManager

    var body: some View {
        List {
            // Supabase 连接测试
            NavigationLink(destination: SupabaseTestView()) {
                HStack(spacing: 16) {
                    Image(systemName: "server.rack")
                        .font(.title2)
                        .foregroundColor(ApocalypseTheme.primary)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Supabase 连接测试")
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("测试数据库连接和认证功能")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
                .padding(.vertical, 8)
            }

            // 圈地功能测试
            NavigationLink(destination: TerritoryTestView().environmentObject(locationManager)) {
                HStack(spacing: 16) {
                    Image(systemName: "map.circle.fill")
                        .font(.title2)
                        .foregroundColor(ApocalypseTheme.success)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("圈地功能测试")
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("实时查看圈地模块运行日志")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("开发测试")
        .background(ApocalypseTheme.background)
    }
}

#Preview {
    NavigationView {
        TestMenuView()
    }
}
