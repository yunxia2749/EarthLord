# Day 24 AI 物品生成系统 - 部署指南

## 📋 已完成的功能

### 1. ✅ 代码实现
- **AIItemGenerator.swift** - AI 物品生成器
- **AIScavengeResultView.swift** - 搜刮结果界面（带展开/收起故事功能）
- **InventoryManager.swift** - 背包管理器（支持 AI 物品）
- **ExplorationManager.swift** - 探索管理器（集成 AI 物品生成）
- **Edge Function** - generate-ai-item（调用阿里云百炼 API）

### 2. ✅ UI 功能
- 每个物品显示独特名称
- 每个物品都有背景故事
- **点击展开/收起完整故事**（新增）
- 不同稀有度有不同颜色标识
- 展开时边框加粗（视觉反馈）

### 3. ✅ 降级处理
- AI 调用失败时自动使用预设物品库
- 不影响正常游戏流程
- 日志记录失败原因

---

## 🚀 需要手动完成的部署步骤

### 步骤 1：应用数据库迁移

**方式一：使用 Supabase Dashboard（推荐）**

1. 打开 [Supabase Dashboard](https://supabase.com/dashboard)
2. 选择你的项目
3. 点击左侧菜单 **SQL Editor**
4. 点击 **New query**
5. 复制粘贴以下文件内容到编辑器：
   ```
   supabase/migrations/20260124_ai_items_support.sql
   ```
6. 点击 **Run** 执行

**方式二：使用 Supabase CLI**

```bash
cd /Users/zhaoyunxia/Desktop/EarthLord

# 1. 登录 Supabase
npx supabase login

# 2. 链接到项目（替换 YOUR_PROJECT_REF 为你的项目ID）
npx supabase link --project-ref YOUR_PROJECT_REF

# 3. 应用迁移
npx supabase db push
```

---

### 步骤 2：部署 Edge Function

**前置条件：**
- 你需要有**阿里云百炼 API Key**（国际版）
- 获取方式：访问 [阿里云百炼](https://dashscope.aliyun.com/) → 申请 API Key

**部署步骤：**

```bash
cd /Users/zhaoyunxia/Desktop/EarthLord

# 1. 设置阿里云 API Key（替换为你的真实 Key）
npx supabase secrets set DASHSCOPE_API_KEY=sk-xxxxxxxxxxxxxxxx

# 2. 部署 Edge Function
npx supabase functions deploy generate-ai-item --no-verify-jwt

# 3. 验证部署成功
npx supabase functions list
```

**重要提示：**
- `--no-verify-jwt` 参数表示此函数不需要 JWT 验证（因为我们在代码中已处理认证）
- 如果你的阿里云 API Key 是国内版，需要修改 `supabase/functions/generate-ai-item/index.ts` 第 25 行的 `baseURL`

---

### 步骤 3：测试功能

1. **重新运行 App**（确保代码更新生效）
   - 在 Xcode 中停止应用
   - 清理构建（Command + Shift + K）
   - 重新运行（Command + R）

2. **测试流程**
   ```
   点击"开始探索" → 走动接近POI → 点击"搜刮" → 查看AI生成物品
   ```

3. **测试展开/收起功能**
   - 在搜刮结果页面，**点击任意物品**
   - 故事会展开显示完整内容
   - 再次点击可收起

4. **查看日志**（在 Xcode Console 中）
   ```
   ✅ [AIItemGenerator] AI 生成成功，获得 3 个物品
   ✅ [InventoryManager] AI物品已添加: xxx
   ```

---

## 🔧 常见问题排查

### 问题 1: AI 调用失败，总是使用预设物品

**可能原因：**
- Edge Function 未部署
- DASHSCOPE_API_KEY 未设置或无效
- API 余额不足

**解决方法：**
1. 检查 Edge Function 是否部署成功
   ```bash
   npx supabase functions list
   ```
2. 检查 Supabase Logs
   - Dashboard → Functions → generate-ai-item → Logs
3. 检查阿里云控制台余额

---

### 问题 2: 物品无法添加到背包

**可能原因：**
- 数据库迁移未应用
- inventory_items 表缺少必要字段

**解决方法：**
1. 检查表结构
   - Dashboard → Table Editor → inventory_items
   - 确保有以下列：`item_name`, `category`, `rarity`, `story`, `is_ai_generated`
2. 重新应用迁移文件

---

### 问题 3: 点击物品无法展开故事

**可能原因：**
- 代码未重新编译
- 缓存问题

**解决方法：**
1. 清理构建（Command + Shift + K）
2. 删除 App 重新安装
3. 重启 Xcode

---

## ✅ 功能验收清单

部署完成后，请逐一验证：

- [ ] 数据库迁移已应用（inventory_items 表有新字段）
- [ ] Edge Function 已部署并设置了 API Key
- [ ] 搜刮 POI 能看到 AI 生成物品
- [ ] 物品名称独特且有创意
- [ ] 点击物品可展开/收起完整故事
- [ ] 不同稀有度有不同颜色
- [ ] 物品已添加到背包
- [ ] AI 失败时有降级方案（预设物品）

---

## 📝 测试建议

1. **低危 POI 测试**（危险等级 1-2）
   - 期待：主要是普通(白色)和优秀(绿色)物品

2. **中危 POI 测试**（危险等级 3）
   - 期待：开始出现稀有(蓝色)和少量史诗(紫色)物品

3. **高危 POI 测试**（危险等级 4-5）
   - 期待：高概率史诗(紫色)和传奇(橙色)物品

4. **故事展开测试**
   - 点击每个物品，查看完整背景故事
   - 确认故事有画面感，符合末日氛围

---

## 🎉 完成标志

当你看到：
- ✅ AI 生成的物品有独特名称（不是"普通罐头"而是"老张的最后晚餐"）
- ✅ 点击物品能展开完整故事
- ✅ 故事内容丰富，有末日感
- ✅ 稀有度分布合理

**恭喜！Day 24 的所有功能已完成！** 🎊

---

## 📞 需要帮助？

如果遇到问题，请检查：
1. Xcode Console 中的日志
2. Supabase Dashboard → Functions → Logs
3. Supabase Dashboard → Database → Logs

提供这些日志信息可以帮助快速定位问题。
