//
//  MapTabView.swift
//  EarthLord
//
//  地图页面：显示真实地图、用户位置、定位权限管理
//

import SwiftUI
import MapKit

struct MapTabView: View {

    // MARK: - State Objects

    /// 定位管理器
    @StateObject private var locationManager = LocationManager()

    // MARK: - State Properties

    /// 是否已完成首次定位
    @State private var hasLocatedUser = false

    /// 是否显示权限提示
    @State private var showPermissionAlert = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // 地图视图
            if locationManager.isAuthorized {
                MapViewRepresentable(
                    userLocation: $locationManager.userLocation,
                    hasLocatedUser: $hasLocatedUser
                )
                .edgesIgnoringSafeArea(.all)
            } else {
                // 未授权时显示占位图
                unauthorizedView
            }

            // 顶部信息栏
            VStack {
                topInfoBar
                Spacer()
            }

            // 右下角定位按钮
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    locationButton
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                }
            }
        }
        .onAppear {
            // 首次打开时请求定位权限
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestPermission()
            } else if locationManager.isAuthorized {
                locationManager.startUpdatingLocation()
            }
        }
    }

    // MARK: - Subviews

    /// 顶部信息栏
    private var topInfoBar: some View {
        HStack {
            // 地图图标
            Image(systemName: "map.fill")
                .font(.title2)
                .foregroundColor(ApocalypseTheme.primary)

            VStack(alignment: .leading, spacing: 4) {
                Text("末日地图")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if let location = locationManager.userLocation {
                    // 显示经纬度坐标
                    Text(String(format: "坐标: %.4f, %.4f", location.latitude, location.longitude))
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                } else {
                    Text("正在定位中...")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.warning)
                }
            }

            Spacer()
        }
        .padding()
        .background(
            ApocalypseTheme.cardBackground
                .opacity(0.9)
                .blur(radius: 10)
        )
    }

    /// 定位按钮
    private var locationButton: some View {
        Button(action: {
            if locationManager.isAuthorized {
                // 已授权，重新居中地图
                hasLocatedUser = false
            } else if locationManager.isDenied {
                // 被拒绝，提示去设置
                showPermissionAlert = true
            } else {
                // 未请求，请求权限
                locationManager.requestPermission()
            }
        }) {
            Image(systemName: locationManager.isAuthorized ? "location.fill" : "location.slash.fill")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(
                    locationManager.isAuthorized ?
                    ApocalypseTheme.primary :
                    ApocalypseTheme.danger
                )
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
        }
        .alert("定位权限未开启", isPresented: $showPermissionAlert) {
            Button("前往设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("《地球新主》需要定位权限来显示您在末日世界中的位置。请在设置中开启定位权限。")
        }
    }

    /// 未授权时的占位视图
    private var unauthorizedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.slash")
                .font(.system(size: 80))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("无法获取位置")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("需要定位权限才能在地图上显示您的位置")
                .font(.body)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if locationManager.isDenied {
                // 被拒绝，显示前往设置按钮
                Button(action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("前往设置")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(8)
                }
            } else {
                // 未请求，显示请求权限按钮
                Button(action: {
                    locationManager.requestPermission()
                }) {
                    Text("允许定位")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ApocalypseTheme.background)
    }
}

// MARK: - Preview

#Preview {
    MapTabView()
}
