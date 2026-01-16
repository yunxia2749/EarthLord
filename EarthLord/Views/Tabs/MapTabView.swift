//
//  MapTabView.swift
//  EarthLord
//
//  地图页面：显示真实地图、用户位置、定位权限管理
//

import SwiftUI
import MapKit
import Supabase

struct MapTabView: View {

    // MARK: - Environment Objects

    /// 定位管理器（从父视图注入）
    @EnvironmentObject var locationManager: LocationManager

    // MARK: - Managers

    /// 领地管理器
    @StateObject private var territoryManager = TerritoryManager.shared

    // MARK: - State Properties

    /// 是否已完成首次定位
    @State private var hasLocatedUser = false

    /// 是否显示权限提示
    @State private var showPermissionAlert = false

    /// 是否显示验证结果横幅
    @State private var showValidationBanner = false

    /// 是否正在上传
    @State private var isUploading = false

    /// 上传错误消息
    @State private var uploadError: String?

    /// 是否显示成功提示
    @State private var showSuccessMessage = false

    /// 已上传的领地列表（在地图上显示）
    @State private var uploadedTerritories: [TerritoryData] = []

    // MARK: - Day 19: 碰撞检测状态
    @State private var collisionCheckTimer: Timer?
    @State private var collisionWarning: String?
    @State private var showCollisionWarning = false
    @State private var collisionWarningLevel: WarningLevel = .safe
    @State private var trackingStartTime: Date?
    @State private var currentUserId: String? // 当前用户ID（用于碰撞检测）

    // MARK: - 探索功能状态
    @StateObject private var explorationManager = ExplorationManager.shared
    @State private var showExplorationResult: Bool = false
    @State private var explorationResult: ExplorationResult?
    @State private var showExplorationFailure: Bool = false

    // MARK: - Day 20: 地图区域状态
    @State private var currentMapRegion: MKCoordinateRegion?
    @State private var lastLoadedRegion: MKCoordinateRegion?

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
                    isPathClosed: locationManager.isPathClosed,
                    uploadedTerritories: uploadedTerritories,
                    currentUserId: currentUserId,
                    currentMapRegion: $currentMapRegion,
                    onRegionChanged: handleMapRegionChanged,
                    nearbyPOIs: explorationManager.nearbyPOIs,
                    scavengedPOIIds: explorationManager.scavengedPOIIds
                )
                .ignoresSafeArea(.all, edges: [.top, .leading, .trailing])
            } else {
                // 未授权时显示占位图
                unauthorizedView
            }

            // 主要UI层（确保在地图之上）
            // ⚠️ 仅在授权时显示，避免覆盖 unauthorizedView 的按钮
            if locationManager.isAuthorized {
                VStack(spacing: 0) {
                    // 顶部信息栏
                    topInfoBar

                    // 速度警告横幅
                    if locationManager.speedWarning != nil {
                        speedWarningBanner
                    }

                    // 验证结果横幅（闭环后显示）
                    if showValidationBanner {
                        validationResultBanner
                    }

                    // Day 19: 碰撞警告横幅（分级颜色）
                    if showCollisionWarning, let warning = collisionWarning {
                        collisionWarningBanner(message: warning, level: collisionWarningLevel)
                    }

                    Spacer()

                    // 底部按钮区域
                    if locationManager.territoryValidationPassed {
                        // 验证通过时显示「确认登记」和「取消」按钮
                        VStack(spacing: 12) {
                            confirmUploadButton
                            cancelButton
                        }
                        .padding(.bottom, 16)
                    } else if locationManager.isTracking {
                        // 追踪中但未验证通过时显示「停止圈地」按钮
                        stopTrackingButtonLarge
                            .padding(.bottom, 16)
                    }
                }
                .zIndex(1) // 确保在地图之上
            }

            // 底部按钮栏（不在追踪时显示）
            if !locationManager.isTracking && locationManager.isAuthorized {
                VStack {
                    Spacer()
                    bottomButtonBar
                        .padding(.bottom, 16)
                        .padding(.horizontal, 16)
                }
                .zIndex(2) // 确保按钮在最上层
            }

            // MARK: - POI 弹窗层

            // POI接近弹窗
            if explorationManager.showPOIProximityPopup, let poi = explorationManager.currentProximityPOI {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        explorationManager.dismissPOIPopup()
                    }
                    .zIndex(10)

                VStack {
                    Spacer()
                    POIProximityPopup(
                        poi: poi,
                        userLocation: locationManager.userLocation,
                        onScavenge: {
                            Task {
                                await explorationManager.scavengePOI(poi)
                            }
                        },
                        onDismiss: {
                            explorationManager.dismissPOIPopup()
                        }
                    )
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(11)
            }

            // 搜刮结果弹窗
            if explorationManager.showScavengeResult, let poi = explorationManager.currentProximityPOI {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .zIndex(12)

                ScavengeResultView(
                    poi: poi,
                    rewards: explorationManager.scavengeRewards,
                    onConfirm: {
                        explorationManager.dismissScavengeResult()
                    }
                )
                .transition(.scale.combined(with: .opacity))
                .zIndex(13)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: explorationManager.showPOIProximityPopup)
        .animation(.easeInOut(duration: 0.3), value: explorationManager.showScavengeResult)
        .onAppear {
            // 首次打开时请求定位权限
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestPermission()
            } else if locationManager.isAuthorized {
                locationManager.startUpdatingLocation()
            }

            // Day 20: 使用优化的初始化逻辑
            initAppData()
        }
        // ⭐ 监听闭环状态，闭环后根据验证结果显示横幅
        .onReceive(locationManager.$isPathClosed) { isClosed in
            if isClosed {
                // ⭐ 闭环时，清除碰撞警告横幅（避免和验证结果横幅重叠）
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe

                // 闭环后延迟0.2秒，确保验证结果已更新
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation {
                        showValidationBanner = true
                    }

                    // ⭐ 只有验证失败时才自动隐藏（验证通过时需要显示"确认登记"按钮）
                    if !locationManager.territoryValidationPassed {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                showValidationBanner = false
                            }
                        }
                    }
                }
            } else {
                // 路径被清空时，隐藏所有横幅
                showValidationBanner = false
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
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

    /// 验证结果横幅（根据验证结果显示成功或失败）
    private var validationResultBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: locationManager.territoryValidationPassed
                  ? "checkmark.circle.fill"
                  : "xmark.circle.fill")
                .font(.body)
            if locationManager.territoryValidationPassed {
                Text("圈地成功！领地面积: \(String(format: "%.0f", locationManager.calculatedArea))m²")
                    .font(.subheadline)
                    .fontWeight(.medium)
            } else {
                Text(locationManager.territoryValidationError ?? "验证失败")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(locationManager.territoryValidationPassed ? Color.green : Color.red)
        .cornerRadius(20)
        .padding(.horizontal)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut, value: showValidationBanner)
    }

    /// 底部按钮栏（三个按钮水平排列）
    private var bottomButtonBar: some View {
        HStack(spacing: 12) {
            // 左侧：开始圈地按钮
            claimButton

            // 中间：定位按钮
            locationButton

            // 右侧：探索按钮
            exploreButton
        }
    }

    /// 开始圈地按钮（橙色）
    private var claimButton: some View {
        Button(action: {
            if locationManager.isAuthorized {
                startClaimingWithCollisionCheck()
            } else {
                showPermissionAlert = true
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 18))
                    .foregroundColor(.white)

                Text("开始圈地")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Color.orange
            )
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
        }
    }

    /// 定位按钮（蓝色圆形）
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
            Image(systemName: "location.fill")
                .font(.system(size: 22))
                .foregroundColor(.white)
                .frame(width: 56, height: 48)
                .background(
                    Color.orange
                )
                .cornerRadius(24)
                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
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

    /// 探索按钮（绿色，匹配老师设计）
    private var exploreButton: some View {
        VStack(spacing: 12) {
            // 速度警告（如果有）
            if let warning = explorationManager.speedWarning, explorationManager.speedWarningCountdown > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.danger)

                    Text("速度过快，还有\(explorationManager.speedWarningCountdown)秒")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ApocalypseTheme.danger)

                    Spacer()

                    Text("\(String(format: "%.0f", explorationManager.currentSpeed))km/h")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(ApocalypseTheme.danger)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ApocalypseTheme.danger.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ApocalypseTheme.danger, lineWidth: 1)
                )
                .transition(.opacity)
            }

            // 探索按钮
            Button(action: {
                performExploration()
            }) {
                HStack(spacing: 8) {
                    if explorationManager.isExploring {
                        // 探索中：显示停止图标
                        Image(systemName: "stop.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    } else {
                        // 未探索：显示行走图标
                        Image(systemName: "figure.walk")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }

                    if explorationManager.isExploring {
                        VStack(spacing: 2) {
                            Text("停止探索")
                                .font(.system(size: 15, weight: .semibold))

                            HStack(spacing: 8) {
                                Text("\(String(format: "%.0f", explorationManager.totalDistance))米")
                                    .font(.system(size: 11))

                                Text(formatDuration(explorationManager.currentDuration))
                                    .font(.system(size: 11))
                            }
                        }
                        .foregroundColor(.white)
                    } else {
                        Text("开始探索")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    explorationManager.isExploring ?
                    Color.red :  // 探索中显示红色（停止按钮）
                    Color.green  // 未探索显示绿色
                )
                .cornerRadius(25)
                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: explorationManager.speedWarning)
        .animation(.easeInOut(duration: 0.3), value: explorationManager.isExploring)
        .sheet(isPresented: $showExplorationResult) {
            if let result = explorationResult {
                ExplorationResultView(result: result)
            }
        }
        .alert("探索失败", isPresented: $showExplorationFailure) {
            Button("确定", role: .cancel) {}
        } message: {
            if let reason = explorationManager.failureReason {
                Text(reason)
            }
        }
    }

    /// 格式化时长
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    /// 停止圈地按钮（老师样式）
    private var stopTrackingButtonLarge: some View {
        Button(action: {
            stopCollisionMonitoring()
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

    // MARK: - Confirm Upload Button

    /// 取消按钮（放弃当前圈地，重新开始）
    private var cancelButton: some View {
        Button(action: {
            // 停止碰撞监控
            stopCollisionMonitoring()

            // 隐藏验证横幅
            showValidationBanner = false

            // 清空路径并停止追踪
            locationManager.stopPathTracking()

            // 触发轻微震动反馈
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()

            print("✅ [MapTabView] 用户取消圈地，可以重新开始")
        }) {
            HStack(spacing: 10) {
                Image(systemName: "xmark.circle")
                    .font(.title3)
                    .foregroundColor(ApocalypseTheme.danger)

                Text("取消重新圈地")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.danger)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                ApocalypseTheme.cardBackground
            )
            .cornerRadius(30)
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(ApocalypseTheme.danger, lineWidth: 2)
            )
        }
        .padding(.horizontal, 20)
    }

    /// 确认登记领地按钮
    private var confirmUploadButton: some View {
        Button(action: {
            Task {
                await uploadCurrentTerritory()
            }
        }) {
            HStack(spacing: 10) {
                // 图标
                Image(systemName: isUploading ? "arrow.up.circle" : "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.white)

                // 文字
                Text(isUploading ? "正在上传..." : "确认登记领地")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: isUploading ? [Color.gray] : [Color.green, Color.green.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(30)
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .disabled(isUploading)
        .padding(.horizontal, 20)
        .alert("上传失败", isPresented: .constant(uploadError != nil)) {
            Button("确定") {
                uploadError = nil
            }
        } message: {
            Text(uploadError ?? "")
        }
        .alert("领地登记成功", isPresented: $showSuccessMessage) {
            Button("确定") {
                showSuccessMessage = false
            }
        } message: {
            Text("领地已成功登记到数据库！")
        }
    }

    // MARK: - Exploration Method

    /// 执行探索操作
    private func performExploration() {
        if explorationManager.isExploring {
            // 停止探索
            print("🔵 [MapTabView] 用户点击停止探索")
            Task {
                let result = await explorationManager.stopExploration()
                explorationResult = result
                showExplorationResult = true
                print("✅ [MapTabView] 探索结束，显示结果页面")
            }
        } else {
            // 开始探索
            print("🔵 [MapTabView] 用户点击开始探索")
            Task {
                await explorationManager.startExploration()
                print("✅ [MapTabView] 探索已启动")
            }
        }

        // 监听失败状态
        Task {
            // 等待一点时间让Manager初始化
            try? await Task.sleep(nanoseconds: 500_000_000)

            // 定期检查失败状态
            while explorationManager.isExploring {
                try? await Task.sleep(nanoseconds: 1_000_000_000)  // 每秒检查一次

                if explorationManager.explorationFailed {
                    showExplorationFailure = true
                    print("❌ [MapTabView] 探索失败: \(explorationManager.failureReason ?? "未知原因")")
                    break
                }
            }
        }
    }

    // MARK: - Upload Method

    /// 上传当前领地
    private func uploadCurrentTerritory() async {
        print("🔵 [MapTabView] 用户点击上传按钮")

        // ⚠️ 再次检查验证状态
        guard locationManager.territoryValidationPassed else {
            print("❌ [MapTabView] 验证未通过，禁止上传")
            uploadError = "领地验证未通过，无法上传"
            return
        }

        guard !locationManager.pathCoordinates.isEmpty else {
            print("❌ [MapTabView] 路径为空，禁止上传")
            uploadError = "路径数据为空，无法上传"
            return
        }

        isUploading = true

        do {
            print("📤 [MapTabView] 开始上传领地")
            print("   - 坐标点数: \(locationManager.pathCoordinates.count)")
            print("   - 面积: \(locationManager.calculatedArea) m²")

            try await territoryManager.uploadTerritory(
                coordinates: locationManager.pathCoordinates,
                area: locationManager.calculatedArea,
                startTime: Date() // 使用当前时间作为开始时间
            )

            print("✅ [MapTabView] 上传成功")

            // 显示成功提示
            await MainActor.run {
                showSuccessMessage = true
                showValidationBanner = false  // 隐藏验证横幅
            }

            // Day 19: 停止碰撞监控并清除警告
            stopCollisionMonitoring()

            // ⚠️ 关键：上传成功后必须停止追踪！
            locationManager.stopPathTracking()

            // ⭐ 重新加载领地列表，在地图上显示新上传的领地
            await loadUploadedTerritories()

        } catch {
            print("❌ [MapTabView] 上传失败: \(error.localizedDescription)")
            await MainActor.run {
                uploadError = "上传失败: \(error.localizedDescription)"
                isUploading = false
            }
        }

        await MainActor.run {
            isUploading = false
        }
    }

    // MARK: - Day 20: 优化后的初始化逻辑

    /// Day 20: 统一初始化入口（并行加载，不阻塞UI）
    private func initAppData() {
        Task {
            // 并行执行：同时获取用户ID 和 加载地图数据
            await withTaskGroup(of: Void.self) { group in

                // 任务1：获取用户ID
                group.addTask {
                    await self.loadCurrentUserId()
                }

                // 任务2：加载地图数据
                group.addTask {
                    await self.loadUploadedTerritories()
                }
            }
        }
    }

    /// Day 20: 优化版 - 加载领地数据（基于地图区域）
    private func loadUploadedTerritories() async {
        do {
            print("📥 [MapTabView] 开始智能加载领地...")

            // 1. 优先使用当前地图区域，否则等待定位
            let region: MKCoordinateRegion
            if let currentRegion = currentMapRegion {
                region = currentRegion
                print("✅ [MapTabView] 使用当前地图区域")
            } else {
                // 等待位置就绪（带重试机制，2秒超时）
                guard let location = try? await waitForLocation(timeout: 2.0) else {
                    print("⚠️ [MapTabView] 定位和地图区域都未就绪，暂停加载")
                    return
                }
                // 创建默认区域（约 5km 范围）
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    latitudinalMeters: 5000,
                    longitudinalMeters: 5000
                )
                print("✅ [MapTabView] 使用定位创建默认区域")
            }

            // 2. 计算加载范围（屏幕的 1.5 倍缓冲区）
            let bufferMultiplier = 1.5
            let latDelta = region.span.latitudeDelta
            let lngDelta = region.span.longitudeDelta

            let minLat = region.center.latitude - (latDelta * bufferMultiplier / 2)
            let maxLat = region.center.latitude + (latDelta * bufferMultiplier / 2)
            let minLng = region.center.longitude - (lngDelta * bufferMultiplier / 2)
            let maxLng = region.center.longitude + (lngDelta * bufferMultiplier / 2)

            print("📐 [MapTabView] 加载范围: (\(minLat), \(minLng)) → (\(maxLat), \(maxLng))")

            // 3. 计算缩放级别（用于多边形简化）
            let zoomLevel = calculateZoomLevel(from: region.span)

            // 4. 调用 PostGIS RPC（8秒超时）
            let territories = try await withTimeout(seconds: 8) {
                try await TerritoryManager.shared.loadVisibleTerritories(
                    minLat: minLat,
                    minLng: minLng,
                    maxLat: maxLat,
                    maxLng: maxLng,
                    zoomLevel: zoomLevel
                )
            }

            // 5. 更新 UI 和缓存
            await MainActor.run {
                self.uploadedTerritories = territories
                self.lastLoadedRegion = region
                print("✅ [MapTabView] PostGIS 成功加载 \(territories.count) 个领地（缩放级别: \(zoomLevel)）")
            }

        } catch {
            print("❌ [MapTabView] 加载失败: \(error.localizedDescription)")
            // 失败不阻塞页面
            await MainActor.run {
                self.uploadedTerritories = []
            }
        }
    }

    /// Day 20: 处理地图区域变化
    private func handleMapRegionChanged(_ region: MKCoordinateRegion) {
        // 检查是否需要重新加载（移动超过50%视野）
        if shouldReloadTerritories(newRegion: region) {
            print("🔄 [MapTabView] 地图区域变化显著，触发重新加载")
            Task {
                await loadUploadedTerritories()
            }
        }
    }

    /// Day 20: 判断是否需要重新加载
    private func shouldReloadTerritories(newRegion: MKCoordinateRegion) -> Bool {
        guard let lastRegion = lastLoadedRegion else {
            return true // 首次加载
        }

        // 计算中心点移动距离
        let latDiff = abs(newRegion.center.latitude - lastRegion.center.latitude)
        let lngDiff = abs(newRegion.center.longitude - lastRegion.center.longitude)

        // 计算缩放变化
        let spanChange = abs(newRegion.span.latitudeDelta - lastRegion.span.latitudeDelta) / lastRegion.span.latitudeDelta

        // 如果移动超过上次加载区域的 50%，或缩放变化超过 30%，则重新加载
        let moveThreshold = lastRegion.span.latitudeDelta * 0.5
        let needsReload = latDiff > moveThreshold || lngDiff > moveThreshold || spanChange > 0.3

        return needsReload
    }

    /// Day 20: 计算缩放级别（用于多边形简化）
    private func calculateZoomLevel(from span: MKCoordinateSpan) -> Double {
        // 根据 latitudeDelta 估算缩放级别
        // latitudeDelta 越小，缩放级别越高（更详细）
        let zoom = log2(360.0 / span.latitudeDelta)
        return max(1.0, min(20.0, zoom)) // 限制在 1-20 之间
    }

    /// Day 20: 优化版 - 获取用户ID
    private func loadCurrentUserId() async {
        do {
            // 5秒超时
            let session = try await withTimeout(seconds: 5) {
                try await supabase.auth.session
            }

            await MainActor.run {
                self.currentUserId = session.user.id.uuidString
                print("✅ [MapTabView] 用户ID已就绪: \(self.currentUserId ?? "未知")")
            }
        } catch {
            print("❌ [MapTabView] 用户未登录或网络错误: \(error.localizedDescription)")
            await MainActor.run {
                self.currentUserId = nil
            }
        }
    }

    /// Day 20: 辅助方法 - 等待定位就绪（轮询）
    private func waitForLocation(timeout: TimeInterval) async throws -> CLLocation {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if let coordinate = locationManager.userLocation {
                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                print("✅ [MapTabView] 定位就绪: (\(coordinate.latitude), \(coordinate.longitude))")
                return location
            }
            // 等待 200ms 后重试
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        throw NSError(
            domain: "LocationError",
            code: 408,
            userInfo: [NSLocalizedDescriptionKey: "定位超时"]
        )
    }

    // MARK: - Day 19: 碰撞检测方法

    /// Day 19: 带碰撞检测的开始圈地
    private func startClaimingWithCollisionCheck() {
        guard let location = locationManager.userLocation,
              let userId = currentUserId else {
            return
        }

        // 检测起始点是否在他人领地内
        let result = territoryManager.checkPointCollision(
            location: location,
            currentUserId: userId
        )

        if result.hasCollision {
            // 起点在他人领地内，显示错误并震动
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)

            TerritoryLogger.shared.log("起点碰撞：阻止圈地", type: .error)

            // 3秒后隐藏警告
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }

            return
        }

        // 起点安全，开始圈地
        TerritoryLogger.shared.log("起始点安全，开始圈地", type: .info)
        trackingStartTime = Date()
        locationManager.startPathTracking()
        startCollisionMonitoring()
    }

    /// Day 19: 启动碰撞检测监控
    private func startCollisionMonitoring() {
        // 先停止已有定时器
        stopCollisionCheckTimer()

        // 每 10 秒检测一次
        collisionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [self] _ in
            performCollisionCheck()
        }

        TerritoryLogger.shared.log("碰撞检测定时器已启动", type: .info)
    }

    /// Day 19: 仅停止定时器（不清除警告状态）
    private func stopCollisionCheckTimer() {
        collisionCheckTimer?.invalidate()
        collisionCheckTimer = nil
        TerritoryLogger.shared.log("碰撞检测定时器已停止", type: .info)
    }

    /// Day 19: 完全停止碰撞监控（停止定时器 + 清除警告）
    private func stopCollisionMonitoring() {
        stopCollisionCheckTimer()
        // 清除警告状态
        showCollisionWarning = false
        collisionWarning = nil
        collisionWarningLevel = .safe
    }

    /// Day 19: 执行碰撞检测
    private func performCollisionCheck() {
        guard locationManager.isTracking,
              let userId = currentUserId else {
            return
        }

        let path = locationManager.pathCoordinates
        guard path.count >= 2 else { return }

        let result = territoryManager.checkPathCollisionComprehensive(
            path: path,
            currentUserId: userId
        )

        // 根据预警级别处理
        switch result.warningLevel {
        case .safe:
            // 安全，隐藏警告横幅
            showCollisionWarning = false
            collisionWarning = nil
            collisionWarningLevel = .safe

        case .caution:
            // 注意（50-100m）- 黄色横幅 + 轻震 1 次
            collisionWarning = result.message
            collisionWarningLevel = .caution
            showCollisionWarning = true
            triggerHapticFeedback(level: .caution)

        case .warning:
            // 警告（25-50m）- 橙色横幅 + 中震 2 次
            collisionWarning = result.message
            collisionWarningLevel = .warning
            showCollisionWarning = true
            triggerHapticFeedback(level: .warning)

        case .danger:
            // 危险（<25m）- 红色横幅 + 强震 3 次
            collisionWarning = result.message
            collisionWarningLevel = .danger
            showCollisionWarning = true
            triggerHapticFeedback(level: .danger)

        case .violation:
            // 【关键修复】违规处理 - 必须先显示横幅，再停止！

            // 1. 先设置警告状态（让横幅显示出来）
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 2. 触发震动
            triggerHapticFeedback(level: .violation)

            // 3. 只停止定时器，不清除警告状态！
            stopCollisionCheckTimer()

            // 4. 停止圈地追踪
            locationManager.stopPathTracking()
            trackingStartTime = nil

            TerritoryLogger.shared.log("碰撞违规，自动停止圈地", type: .error)

            // 5. 5秒后再清除警告横幅
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }
        }
    }

    /// Day 19: 触发震动反馈
    private func triggerHapticFeedback(level: WarningLevel) {
        switch level {
        case .safe:
            // 安全：无震动
            break

        case .caution:
            // 注意：轻震 1 次
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)

        case .warning:
            // 警告：中震 2 次
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }

        case .danger:
            // 危险：强震 3 次
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                generator.impactOccurred()
            }

        case .violation:
            // 违规：错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
        }
    }

    /// Day 19: 碰撞警告横幅（分级颜色）
    private func collisionWarningBanner(message: String, level: WarningLevel) -> some View {
        // 根据级别确定颜色
        let backgroundColor: Color
        switch level {
        case .safe:
            backgroundColor = .green
        case .caution:
            backgroundColor = .yellow
        case .warning:
            backgroundColor = .orange
        case .danger, .violation:
            backgroundColor = .red
        }

        // 根据级别确定文字颜色（黄色背景用黑字）
        let textColor: Color = (level == .caution) ? .black : .white

        // 根据级别确定图标
        let iconName = (level == .violation) ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"

        return HStack {
            Image(systemName: iconName)
                .font(.system(size: 18))

            Text(message)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(textColor)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(backgroundColor.opacity(0.95))
        .cornerRadius(25)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: showCollisionWarning)
    }

}

// MARK: - Timeout Utility

/// 为异步操作添加超时支持
/// - Parameters:
///   - seconds: 超时秒数
///   - operation: 需要执行的异步操作
/// - Returns: 操作结果
/// - Throws: 超时错误或操作本身的错误
func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // 添加实际操作任务
        group.addTask {
            try await operation()
        }

        // 添加超时任务
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw NSError(
                domain: "TimeoutError",
                code: -1001,
                userInfo: [NSLocalizedDescriptionKey: "操作超时（\(Int(seconds))秒）"]
            )
        }

        // 返回第一个完成的任务结果
        let result = try await group.next()!

        // 取消其他任务
        group.cancelAll()

        return result
    }
}

// MARK: - Preview

#Preview {
    MapTabView()
        .environmentObject(LocationManager())
}
