# Google 登录 Xcode 配置指南

## 🎯 在 Xcode 中配置 URL Schemes（不使用 Info.plist）

由于项目配置为自动生成 Info.plist，我们需要通过 Xcode 项目设置来添加 URL Schemes。

### 步骤 1: 获取 Google Client ID

1. 在 `GoogleSignInManager.swift` 中填入您的 Google Client ID
2. 记录下完整的 Client ID，格式类似：`123456789-abc.apps.googleusercontent.com`

### 步骤 2: 在 Xcode 中配置 URL Schemes

1. **打开项目设置**
   - 在 Xcode 中，点击左侧导航栏的 `EarthLord` 项目（蓝色图标）
   - 确保选中 `TARGETS` 下的 `EarthLord`

2. **进入 Info 标签**
   - 点击顶部的 `Info` 标签页
   - 向下滚动找到 `URL Types` 部分

3. **添加 URL Type**
   - 点击 `URL Types` 左边的展开箭头（如果已折叠）
   - 点击 `+` 按钮添加新的 URL Type

4. **配置 URL Scheme**
   - **Identifier**: 填入 `com.googleusercontent.apps`
   - **URL Schemes**: 填入反向的 Client ID

   **重要**：URL Scheme 需要反转 Client ID！

   例如，如果您的 Client ID 是：
   ```
   123456789-abc.apps.googleusercontent.com
   ```

   则 URL Scheme 应该填入：
   ```
   com.googleusercontent.apps.123456789-abc
   ```

   **格式说明**：
   - 原格式：`[CLIENT_ID].apps.googleusercontent.com`
   - 反转后：`com.googleusercontent.apps.[CLIENT_ID]`

5. **保存**
   - 配置完成后，Xcode 会自动保存

### 步骤 3: 构建目标选择

**重要**：在 Mac 上开发时，请确保选择模拟器作为构建目标：

1. 点击 Xcode 顶部工具栏的设备选择器（显示 "iPhone" 的按钮）
2. 选择一个模拟器（如 "iPhone 15 Pro"）
3. **不要选择** "Any iOS Device" 或实体设备（除非您已配置了开发者证书）

### 步骤 4: 清理并重新构建

```bash
# 在终端中执行
cd /Users/zhaoyunxia/Desktop/EarthLord
xcodebuild clean -project EarthLord.xcodeproj -scheme EarthLord
```

然后在 Xcode 中：
1. `Product` → `Clean Build Folder` (⇧⌘K)
2. `Product` → `Build` (⌘B)

## 📝 配置检查清单

- [ ] 已在 `GoogleSignInManager.swift` 中填入 Google Client ID
- [ ] 已在 Xcode → Info → URL Types 中添加 URL Scheme
- [ ] URL Scheme 格式正确（反转的 Client ID）
- [ ] 已选择模拟器作为构建目标
- [ ] 已清理并重新构建项目
- [ ] 构建成功，无错误

## 🐛 故障排除

### 问题 1: 构建失败 - "Provisioning profile doesn't include device"

**原因**：选择了真机设备但没有配置开发者证书

**解决方案**：
1. 切换到模拟器构建
2. 或者在 Apple Developer 账户中配置开发者证书

### 问题 2: URL Schemes 不工作

**检查**：
1. 确认 URL Scheme 格式正确（反转的 Client ID）
2. 检查 `GoogleSignInManager.swift` 中的 Client ID 是否正确
3. 重新构建项目

### 问题 3: 找不到 URL Types

**解决方案**：
1. 确保在 `TARGETS` → `EarthLord` → `Info` 标签页
2. 如果没有 `URL Types`，可以点击任意 key 旁边的 `+` 添加
3. 在弹出的菜单中选择 `URL Types`

## 🎉 验证配置

构建成功后，在控制台查看启动日志：

```
🚀 [App] 应用启动，配置第三方登录
🔧 [Google登录] 开始配置 Google Sign-In
✅ [Google登录] Google Sign-In 配置完成
📝 [Google登录] Client ID: 您的ClientID
✅ [App] 第三方登录配置完成
```

如果看到这些日志，说明配置成功！
