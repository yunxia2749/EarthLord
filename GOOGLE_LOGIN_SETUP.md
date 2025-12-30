# Google 登录配置指南

## 🎯 配置步骤

### 1. 在 Google Cloud Console 创建 OAuth 2.0 凭据

1. 访问 [Google Cloud Console](https://console.cloud.google.com/)
2. 选择或创建项目
3. 进入「API 和服务」→「凭据」
4. 点击「创建凭据」→「OAuth 2.0 客户端 ID」
5. 应用类型选择「iOS」
6. 填写应用信息：
   - 名称：EarthLord
   - Bundle ID：从 Xcode 项目获取（在 TARGETS → EarthLord → General → Bundle Identifier）
7. 创建完成后，记录下 **Client ID**（格式类似：`123456789-abc.apps.googleusercontent.com`）

### 2. 配置项目文件

#### 2.1 更新 `GoogleSignInManager.swift`

打开文件：`EarthLord/Managers/GoogleSignInManager.swift`

找到第 22 行，将 `YOUR_GOOGLE_CLIENT_ID` 替换为您的 Client ID：

```swift
private let googleClientID = "您的Client_ID.apps.googleusercontent.com"
```

#### 2.2 更新 `Info.plist`

打开文件：`EarthLord/Info.plist`

找到第 16 行，将 `com.googleusercontent.apps.YOUR_CLIENT_ID` 替换为反向的 Client ID。

**重要**：需要将 Client ID 反转格式！

例如，如果您的 Client ID 是：
```
123456789-abc.apps.googleusercontent.com
```

则在 Info.plist 中填入：
```
com.googleusercontent.apps.123456789-abc
```

完整示例：
```xml
<string>com.googleusercontent.apps.123456789-abc</string>
```

#### 2.3 在 Xcode 中添加 Info.plist

1. 打开 Xcode 项目
2. 选择项目根目录 `EarthLord`
3. 选择 TARGETS → EarthLord
4. 选择 「Info」 标签页
5. 找到「Custom iOS Target Properties」
6. 点击右下角的 「+」 添加新属性
7. 选择或输入：`URL types`
8. 展开 URL types，添加 URL Schemes：
   - 在 `URL Schemes` 中填入反向的 Client ID（如上面的格式）

**或者直接在 Build Settings 中设置 Info.plist 路径：**
1. 在 TARGETS → EarthLord → Build Settings
2. 搜索 `Info.plist`
3. 将 `Info.plist File` 设置为：`EarthLord/Info.plist`

### 3. 在 Supabase 配置 Google Provider

您已经完成了这一步，确认以下配置：

1. 在 Supabase Dashboard 中，进入项目设置
2. 「Authentication」→「Providers」
3. 启用 Google Provider
4. 填入 **Authorized Client IDs**（就是您的 Client ID）
5. 开启 **Skip nonce check**（因为 Google Sign-In SDK 不使用 nonce）

### 4. 测试流程

#### 4.1 在模拟器或真机运行

1. 在 Xcode 中选择目标设备（建议使用真机测试）
2. 点击运行（⌘ + R）
3. 应用启动后，控制台应该会显示：
   ```
   🚀 [App] 应用启动，配置第三方登录
   🔧 [Google登录] 开始配置 Google Sign-In
   ✅ [Google登录] Google Sign-In 配置完成
   📝 [Google登录] Client ID: 您的ClientID
   ✅ [App] 第三方登录配置完成
   ```

#### 4.2 测试登录

1. 在登录页面，点击「使用 Google 登录」按钮
2. 控制台会显示详细的登录流程日志：
   ```
   🚀 [认证] 开始Google登录流程
   📱 [认证] 获取当前视图控制器
   🔑 [认证] 调用Google登录SDK
   🚀 [Google登录] 开始Google登录流程
   📱 [Google登录] 正在展示Google登录界面...
   ```

3. 选择 Google 账号并授权
4. 登录成功后，控制台会显示：
   ```
   ✅ [Google登录] 用户成功登录Google账号
   📝 [Google登录] 用户信息: user@gmail.com
   ✅ [Google登录] 成功获取ID Token
   🔐 [认证] 使用ID Token登录Supabase
   ✅ [认证] Google登录成功！
   📝 [认证] 用户ID: xxxx-xxxx-xxxx-xxxx
   📝 [认证] 邮箱: user@gmail.com
   🏁 [认证] Google登录流程结束
   ```

5. 页面会自动跳转到主界面

## 📝 关键代码说明

### 已实现的功能

1. **GoogleSignInManager.swift**
   - Google Sign-In SDK 的封装
   - 处理登录、登出、URL 回调
   - 包含详细的中文日志

2. **AuthManager.swift**
   - `signInWithGoogle()` 方法实现完整的 Google 登录流程
   - 与 Supabase 集成认证
   - 包含详细的中文日志

3. **EarthLordApp.swift**
   - 应用启动时配置 Google Sign-In
   - 处理 URL 回调（用于 OAuth 重定向）

4. **AuthView.swift**
   - 更新 Google 登录按钮，调用 AuthManager

5. **Info.plist**
   - 配置 URL Schemes（需要填入您的 Client ID）

## ⚠️ 常见问题

### 问题 1：Client ID 未配置

**错误信息**：
```
❌ [Google登录] 配置失败：Client ID未设置
```

**解决方案**：
检查 `GoogleSignInManager.swift` 中的 `googleClientID` 是否已正确填写。

### 问题 2：URL Scheme 未配置

**错误信息**：
```
⚠️ [App] URL未被处理
```

**解决方案**：
1. 检查 `Info.plist` 中的 URL Schemes 是否正确
2. 确认 Xcode 项目设置中是否正确引用了 Info.plist
3. URL Schemes 必须是反向的 Client ID 格式

### 问题 3：Supabase 认证失败

**错误信息**：
```
❌ [认证] Google登录失败: Invalid credentials
```

**解决方案**：
1. 确认 Supabase 中已启用 Google Provider
2. 确认 Authorized Client IDs 中填入了正确的 Client ID
3. 确认开启了 Skip nonce check

### 问题 4：无法获取视图控制器

**错误信息**：
```
❌ [认证] 无法获取视图控制器
```

**解决方案**：
这通常在应用刚启动时发生。等待应用完全加载后再尝试登录。

## 📱 测试清单

- [ ] Google Client ID 已正确配置在 `GoogleSignInManager.swift`
- [ ] Info.plist 中的 URL Schemes 已正确配置（反向 Client ID）
- [ ] Xcode 项目中已正确引用 Info.plist
- [ ] Supabase Google Provider 已启用并配置
- [ ] 应用启动时控制台显示 Google Sign-In 配置成功
- [ ] 点击 Google 登录按钮能弹出 Google 登录界面
- [ ] 能成功选择账号并授权
- [ ] 登录成功后能正常跳转到主界面
- [ ] 用户信息正确显示（邮箱、头像等）

## 🎉 完成

配置完成后，您的应用就支持 Google 登录了！所有关键步骤都包含详细的中文日志，方便您调试和排查问题。
