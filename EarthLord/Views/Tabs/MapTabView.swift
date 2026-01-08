//
//  MapTabView.swift
//  EarthLord
//
//  地图页面：显示真实地图、用户位置、定位权限管理
//

import SwiftUI
import MapKit

struct MapTabView: View {

    // MARK: - Environment Objects

    /// 定位管理器（从父视图注入）
    @EnvironmentObject var locationManager: LocationManager

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
                    hasLocatedUser: $hasLocatedUser,
                    pathCoordinates: $locationManager.pathCoordinates,
                    pathUpdateVersion: $locationManager.pathUpdateVersion,
                    isPathClosed: locationManager.isPathClosed
                )
                .ignoresSafeArea(.all, edges: [.top, .leading, .trailing])
            } else {
                // 未授权时显示占位图
                unauthorizedView
            }

            // 主要UI层（确保在地图之上）
            VStack(spacing: 0) {
                // 顶部信息栏
                topInfoBar

                // 速度警告横幅
                if locationManager.speedWarning != nil {
                    speedWarningBanner
                }

                Spacer()

                // 底部停止圈地按钮（追踪时显示）
                if locationManager.isTracking {
                    stopTrackingButtonLarge
                        .padding(.bottom, 16)
                }
            }
            .zIndex(1) // 确保在地图之上

            // 右侧按钮组
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 16) {
                        // 圈地按钮（不在追踪时显示）
                        if !locationManager.isTracking {
                            trackingButton
                        }

                        // 定位按钮
                        locationButton
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, locationManager.isTracking ? 100 : 100) // 为停止按钮和Tab Bar留出空间
                }
            }
            .zIndex(2) // 确保按钮在最上层
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

    /// 速度警告横幅（小型样式）
    private var speedWarningBanner: some View {
        HStack(spacing: 8) {
            // 警告图标
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.body)
                .foregroundColor(.white)

            // 警告文字（单行）
            Text(locationManager.speedWarning ?? "")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Color.orange // 橙色背景
        )
        .cornerRadius(20)
        .padding(.horizontal)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut, value: locationManager.speedWarning)
    }

    /// 圈地追踪按钮
    private var trackingButton: some View {
        Button(action: {
            if locationManager.isTracking {
                // 停止圈地
                locationManager.stopPathTracking()
            } else {
                // 开始圈地
                if locationManager.isAuthorized {
                    locationManager.startPathTracking()
                } else {
                    showPermissionAlert = true
                }
            }
        }) {
            Image(systemName: locationManager.isTracking ? "stop.circle.fill" : "figure.walk.circle.fill")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(
                    locationManager.isTracking ?
                    ApocalypseTheme.danger :
                    ApocalypseTheme.success
                )
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
        }
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

    /// 停止圈地按钮（老师样式）
    private var stopTrackingButtonLarge: some View {
        Button(action: {
            locationManager.stopPathTracking()
        }) {
            HStack(spacing: 10) {
                // 停止图标（方形）
                Image(systemName: "stop.fill")
                    .font(.title3)
                    .foregroundColor(.white)

                // 文字
                Text("停止圈地 \(locationManager.pathCoordinates.count)点")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                Color.red // 纯红色背景
            )
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal)
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
        .environmentObject(LocationManager())
}
