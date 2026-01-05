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
                    hasLocatedUser: $hasLocatedUser,
                    pathCoordinates: $locationManager.pathCoordinates,
                    pathUpdateVersion: $locationManager.pathUpdateVersion
                )
                .ignoresSafeArea(.all, edges: [.top, .leading, .trailing])
            } else {
                // 未授权时显示占位图
                unauthorizedView
            }

            // 顶部信息栏
            VStack {
                topInfoBar
                Spacer()
            }

            // 右侧按钮组
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 16) {
                        // 圈地按钮
                        trackingButton

                        // 定位按钮
                        locationButton

                        // 停止圈地按钮（仅在追踪时显示）
                        if locationManager.isTracking {
                            stopTrackingButton
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 100) // 为 Tab Bar 留出空间
                }
            }

            // 追踪状态提示
            if locationManager.isTracking {
                VStack {
                    Spacer()
                    trackingStatusBar
                        .padding(.bottom, 90)
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

    /// 停止圈地按钮（大按钮样式）
    private var stopTrackingButton: some View {
        Button(action: {
            locationManager.stopPathTracking()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "stop.fill")
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("停止圈地")
                        .font(.headline)
                        .fontWeight(.bold)

                    Text("\(locationManager.pathCoordinates.count) 点")
                        .font(.caption)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [ApocalypseTheme.danger, ApocalypseTheme.danger.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(25)
            .shadow(color: ApocalypseTheme.danger.opacity(0.5), radius: 10, x: 0, y: 5)
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

    /// 追踪状态栏
    private var trackingStatusBar: some View {
        HStack(spacing: 12) {
            // 动画指示器
            Circle()
                .fill(ApocalypseTheme.danger)
                .frame(width: 12, height: 12)
                .opacity(locationManager.isTracking ? 1 : 0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: locationManager.isTracking)

            VStack(alignment: .leading, spacing: 4) {
                Text("正在圈地...")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("已记录 \(locationManager.pathCoordinates.count) 个点")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 清除按钮
            Button(action: {
                locationManager.clearPath()
            }) {
                Image(systemName: "trash.fill")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.danger)
                    .padding(8)
                    .background(ApocalypseTheme.cardBackground)
                    .clipShape(Circle())
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview {
    MapTabView()
}
