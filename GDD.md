# EarthLord - 游戏设计文档 (GDD)
**Game Design Document**

---

## 文档信息
- **游戏名称**: EarthLord (地球领主)
- **游戏类型**: LBS生存建造游戏
- **平台**: iOS
- **目标年龄**: 16+
- **版本**: v1.0
- **更新日期**: 2025-12-24

---

# 第一章: 游戏概念

## 1.1 高概念 (High Concept)
**"用双脚丈量废土,重建你的文明王国"**

一款结合真实世界探索的末日生存游戏。玩家通过GPS圈地占领领土、探索真实地标获取资源、建造建筑发展家园、与其他玩家交易合作,在废墟之上重建新世界。

## 1.2 核心玩法柱 (Core Pillars)
1. **真实探索**: Walk to Earn机制,鼓励玩家走出家门
2. **领土扩张**: GPS圈地系统,用脚步画出自己的王国
3. **资源管理**: 搜刮-建造-交易的经济循环
4. **社交互动**: 基于地理位置的本地社区建设
5. **生存挑战**: 时间衰减机制带来的持续参与动力

## 1.3 独特卖点 (USP)
- **完全免费的全球地图**: 使用Apple MapKit,无调用次数限制
- **真实POI探索**: 现实世界的每个餐厅、医院、公园都是游戏资源点
- **希望朋克美学**: 区别于传统黑暗末日风格,传递积极向上的重建精神
- **本地社交**: 3km范围内的玩家实时互动,建立真实社区联系

---

# 第二章: 故事与世界观

## 2.1 背景故事

### 时间线
- **2048年**: "终末战争"爆发
  - 72小时内全球文明崩塌
  - 99%人口消失
  - 基础设施瘫痪,秩序瓦解

- **2048-2051年**: 黑暗三年
  - 幸存者躲藏在避难所
  - 地表成为废墟
  - 旧世界的法则失效

- **2051年**: 新纪元开始
  - 《新开拓者协议》颁布
  - 幸存者走出避难所
  - 重建文明的征程开始

### 核心设定: 《新开拓者协议》
> **"凡以双足丈量之无主土地,皆为开拓者所有"**

这是新世界唯一的法则:
- 旧世界的土地所有权失效
- 用GPS记录的脚步证明占有权
- 鼓励探索、建设、合作
- 惩罚占据不用、恶意圈地

## 2.2 世界设定

### 地理环境
- **城市废墟**: 破败的建筑,生锈的车辆,杂草丛生的街道
- **自然回归**: 植物突破水泥,动物重返都市
- **科技遗迹**: 仍在运作的卫星网络,残留的能源设施
- **气候变化**: 更极端的天气,资源分布不均

### 社会结构
- **独立开拓者**: 单人行动,自给自足
- **临时联盟**: 基于利益的短期合作
- **领主势力**: 占据大片领地的强者
- **游商旅者**: 往返于各领地间交易的中间人

## 2.3 视觉风格: 希望朋克 (Hopepunk)

### 色彩方案
- **主色**: 废土灰 (#6B7280) - 破败的现实
- **辅色**: 新生绿 (#10B981) - 希望的象征
- **强调色**: 科技蓝 (#3B82F6) - 文明的火种
- **警告色**: 警戒橙 (#F59E0B) - 危险与机遇

### 设计语言
- **对比美学**: 破败与新生并存
- **图标风格**: 线性图标 + 霓虹发光效果
- **UI元素**: 电子终端风格,带扫描线和噪点
- **动画**: 流畅的过渡,微光粒子效果

### 情感基调
- ❌ **不是**: 绝望、恐怖、黑暗、压抑
- ✅ **而是**: 希望、重建、成长、连接

---

# 第三章: 游戏系统设计

## 3.1 核心循环

### 三层循环设计

#### 第一层: 实时循环 (Session Loop) - 15分钟
```
打开App → 查看附近POI → 走到POI位置 → 触发搜刮 → 获得资源 → 使用资源建造/交易 → 获得成就感 → 关闭App
```

#### 第二层: 日常循环 (Daily Loop) - 每天
```
早晨: 查看每日任务 → 规划探索路线
白天: 通勤/午休时探索POI → 积累资源
晚上: 建造建筑 → 交易物品 → 公共频道聊天 → 查看排行榜 → 准备明天
```

#### 第三层: 长期循环 (Long-term Loop) - 每周/每月
```
扩张领地 → 解锁新建筑 → 完成成就 → 提升排名 → 加入联盟 → 参与赛季活动 → 获得稀有奖励
```

## 3.2 系统详细设计

---

### 系统1: 登录注册系统

#### 功能目标
- 快速无障碍登录
- 安全的账号管理
- 跨设备数据同步

#### 登录方式
1. **Apple登录** (推荐)
   - 优势: 一键登录,隐私保护
   - 目标: 70%用户选择

2. **Google登录**
   - 优势: 全球通用,Android用户熟悉
   - 目标: 20%用户选择

3. **邮箱注册**
   - 优势: 传统可靠
   - 目标: 10%用户选择

#### 新手引导 (FTUE)
**目标**: 3分钟内让玩家理解核心玩法

```
步骤1: 观看30秒世界观CG (可跳过)
步骤2: 选择登录方式
步骤3: 自动圈一块教学领地 (系统引导走小圈)
步骤4: 教程POI探索 (虚拟地点,必得资源)
步骤5: 建造第一个篝火
步骤6: 解锁成就,获得奖励
步骤7: 进入游戏主界面
```

---

### 系统2: GPS圈地系统

#### 核心机制
玩家通过GPS追踪脚步,绘制闭合路径,占领土地。

#### 圈地规则

##### 合法判定
✅ **允许**:
- 最小面积: 500m² (约25m×20m)
- 最大面积: 100,000m² (约10公顷)
- 形状: 任意闭合多边形
- 闭合距离: 起点终点距离 <30米

❌ **禁止**:
- 与他人领地重叠
- 使用虚假GPS (检测速度异常)
- 24小时内重复圈同一块地
- 圈地时速度 >15km/h (防止开车作弊)

##### 防作弊机制
1. **速度检测**:
   - 正常步行: 3-6 km/h
   - 跑步: 7-12 km/h
   - 骑行: 12-15 km/h (允许)
   - 开车: >15 km/h (标记为可疑)

2. **轨迹连续性**:
   - GPS点间隔 <60秒
   - 无明显跳跃 (>100米瞬移)

3. **行为分析**:
   - 同一用户7天内圈地 >20块 → 人工审核
   - IP地址与GPS位置不匹配 → 警告

#### 领地管理

##### 领地属性
```swift
Territory {
    id: UUID
    owner_id: UUID
    name: String            // 用户命名
    geometry: Polygon       // PostGIS存储
    area: Double           // 平方米
    created_at: DateTime
    last_active: DateTime  // 最后一次建造/升级时间
    buildings: [Building]  // 建筑列表
    allow_trade: Bool      // 是否允许交易
    status: TerritoryStatus // active/inactive/abandoned
}

enum TerritoryStatus {
    case active      // 活跃使用中
    case inactive    // 30天未活动
    case abandoned   // 90天未活动,可被回收
}
```

##### 领地维护规则
- 30天内必须至少建造/升级1次建筑,否则变为inactive
- 90天未活动,系统回收领地
- 激励玩家持续参与,防止囤地

---

### 系统3: POI探索系统

#### POI分类与资源对应

| POI类型 | 真实地点示例 | 主要产出 | 稀有产出 | 刷新时间 |
|---------|-------------|----------|---------|---------|
| 餐厅/超市 | 肯德基、沃尔玛 | 罐头食品×20-30 | 稀有食材×1-2 | 4小时 |
| 医院/药店 | 人民医院、CVS | 急救包×10-15 | 抗生素×2-3 | 6小时 |
| 公园/林地 | 中央公园、森林 | 木材×15-25 | 优质木材×3-5 | 3小时 |
| 工厂/工地 | 制造厂、建筑工地 | 金属×10-20 | 电子元件×1-2 | 6小时 |
| 银行/珠宝店 | Chase、Tiffany | 货币×5-10 | 稀有矿石×1 | 12小时 |
| 加油站 | Shell、BP | 燃料×15-20 | 高级燃料×2-3 | 4小时 |
| 学校/图书馆 | 大学、公共图书馆 | 书籍×5-10 | 技能书×1 | 8小时 |

#### 地理围栏机制

##### 触发条件
1. 玩家GPS位置进入POI半径50米范围
2. 该POI资源已刷新 (距上次搜刮 >刷新时间)
3. 玩家当天探索次数未达上限 (免费用户10次/天,付费用户无限)

##### 触发流程
```
1. 检测到进入POI范围
2. 推送通知: "发现兴趣点: [POI名称]"
3. 玩家点击"搜刮"按钮
4. 播放搜刮动画 (3秒)
5. 根据POI类型随机生成资源
6. 显示获得物品列表
7. 记录探索成就数据
```

#### 探索成就统计
- 探索距离: GPS轨迹总长度 (km)
- 探索时长: 累计活跃时间
- POI数量: 搜刮过的不同POI总数
- 稀有发现: 获得稀有资源次数

---

### 系统4: 背包系统

#### 背包规格
- **默认容量**: 100格
- **扩容方式**:
  - 建造小仓库: +50格
  - 建造中仓库: +100格
  - 建造大仓库: +200格
  - 购买背包扩容: +50格 ($2.99一次性)

#### 物品分类

##### 消耗品 (Consumables)
- **食物**: 罐头食品、肉类、蔬菜、水果
- **饮料**: 饮用水、果汁、能量饮料
- **药品**: 急救包、抗生素、止痛药

##### 材料 (Materials)
- **基础材料**: 木材、石头、金属、布料
- **高级材料**: 电子元件、精密零件、稀有矿石
- **特殊材料**: 卫星模块、核心处理器

##### 工具 (Tools)
- **建造工具**: 锤子、扳手、电锯
- **探索工具**: 背包、登山杖、望远镜
- **通讯工具**: 收音机、对讲机、电台设备

#### 背包交互

##### 操作
- **查看**: 点击物品显示详情
- **使用**: 消耗品可直接使用
- **丢弃**: 长按物品选择丢弃 (不可撤销警告)
- **排序**: 按类型/稀有度/数量/最近获得
- **筛选**: 快速找到指定物品

##### 本地优先架构
```
用户操作 → 立即更新本地数据库 (Core Data)
         → 显示新UI (无延迟)
         → 后台同步到Supabase
         → 同步成功/失败反馈
```

优势:
- 离线可用
- 操作无延迟
- 网络恢复后自动同步

---

### 系统5: 建造系统

#### 建筑分类与数据

##### Tier 1: 生存基础 (解锁等级: 1级)

| 建筑 | 材料需求 | 功能 | 产出 | 升级路径 |
|------|---------|------|------|---------|
| 篝火 | 石头×20, 木材×30 | 提供温暖,+5生命/小时 | - | Lv1-3 |
| 简易庇护所 | 木材×50, 布料×20 | 休息恢复,+10生命/次 | - | Lv1-3 |
| 小仓库 | 木材×40, 金属×20 | 背包+50格 | - | 不可升级 |

##### Tier 2: 功能扩展 (解锁等级: 5级)

| 建筑 | 材料需求 | 功能 | 产出 | 升级路径 |
|------|---------|------|------|---------|
| 农田 | 木材×30, 种子×10 | 自动生产食物 | 5食物/小时 | Lv1-5 |
| 水井 | 石头×50, 金属×30 | 自动生产水 | 3水/小时 | Lv1-5 |
| 工作台 | 木材×60, 金属×40 | 解锁高级建筑 | - | Lv1-3 |
| 中仓库 | 木材×80, 金属×50 | 背包+100格 | - | 不可升级 |

##### Tier 3: 高级设施 (解锁等级: 10级)

| 建筑 | 材料需求 | 功能 | 产出 | 升级路径 |
|------|---------|------|------|---------|
| 太阳能板 | 金属×100, 电子元件×20 | 提供能源 | 10能源/小时 | Lv1-5 |
| 风力发电机 | 金属×120, 电子元件×30 | 提供能源 | 15能源/小时 | Lv1-5 |
| 营地电台 | 金属×80, 卫星模块×5 | 解锁10km通讯 | - | Lv1-3 |
| 大仓库 | 金属×150, 混凝土×100 | 背包+200格 | - | 不可升级 |
| 医疗站 | 金属×100, 药品×50 | 快速恢复生命 | +50生命/次 | Lv1-5 |

#### 建造流程

```
1. 玩家点击"建造"按钮
2. 选择建筑类型和具体建筑
3. 系统检查:
   - 资源是否足够?
   - 领地是否有空间?
   - 玩家等级是否满足?
4. 通过检查:
   - 扣除资源
   - 进入"拖动放置"模式
   - 玩家在领地上选择位置
   - 确认位置,建筑生成
5. 建筑进入"待激活"状态
6. 玩家点击建筑 → "激活" → 进入"运行中"状态
```

#### 建筑状态机

```
          建造完成
            ↓
        [待激活] ────激活───→ [运行中]
            ↓                    ↓
        (可删除)          (可升级/维修/关闭)
                                 ↓
                          耐久度=0
                                 ↓
                             [损坏]
                                 ↓
                          维修(消耗资源)
                                 ↓
                            [运行中]
```

状态转换规则:
- **待激活**: 刚建好,未使用,可免费删除
- **运行中**: 正常工作,产生效果
- **损坏**: 耐久度归零,停止工作,需维修
- 只有"运行中"状态可升级

---

### 系统6: 交易系统

#### 交易机制

##### 挂单流程
```
1. 玩家打开"交易"页面
2. 点击"发布挂单"
3. 选择"我提供"的物品 (从背包选择)
4. 选择"我需要"的物品 (从物品库选择)
5. 设置数量比例 (如: 罐头×10 换 药品×5)
6. 确认发布
7. 挂单进入"待交易"池
```

##### 发现机制
**关键**: 只有双方距离 <100米时才能看到对方挂单

实现逻辑:
```sql
-- 查询附近的挂单
SELECT * FROM trades
WHERE ST_DWithin(
  territory_location,           -- 挂单者领地位置
  ST_MakePoint($1, $2)::geography,  -- 当前玩家位置
  100                            -- 100米半径
)
AND status = 'active'
AND requester_id != $current_user_id;
```

##### 交易流程
```
1. 玩家A发布挂单: 罐头×10 → 药品×5
2. 玩家B走到A的领地100米范围内
3. B的App显示A的挂单
4. B点击"接受交易"
5. 系统检查:
   - B是否有药品×5?
   - A是否仍有罐头×10?
6. 通过检查:
   - A背包: -罐头×10, +药品×5
   - B背包: +罐头×10, -药品×5
   - 挂单状态 → "已完成"
7. 双方收到通知
```

#### 交易安全

##### 防欺诈机制
- **原子性**: 交易要么全部成功,要么全部失败,无中间态
- **库存锁定**: 挂单物品从可用背包中扣除,防止重复交易
- **超时取消**: 24小时无人接单自动取消,物品归还
- **交易记录**: 所有交易永久记录,可追溯

##### 交易限制
- 每日挂单上限: 10个 (防止刷屏)
- 同时挂单上限: 5个 (鼓励精准交易)
- 最小交易价值: 稀有度×数量 ≥ 10 (防止垃圾交易)

---

### 系统7: 通讯系统

#### 7.1 消息中心

##### 消息类型
1. **系统通知**
   - 账号相关: 登录、注销、安全提醒
   - 领地相关: 圈地成功、领地即将回收
   - 建筑相关: 建造完成、损坏警告

2. **游戏公告**
   - 版本更新
   - 活动通知
   - 维护预告

3. **社交通知**
   - 交易请求
   - 好友申请
   - 联盟邀请

#### 7.2 公共频道

##### 频道机制
- **范围**: 以玩家为中心,半径3km
- **实时性**: Supabase Realtime推送,延迟<3秒
- **消息保留**: 最近200条消息

##### 聊天规则
- 消息长度: 1-200字符
- 发送间隔: 最小3秒 (防刷屏)
- 敏感词过滤: 自动屏蔽违规内容
- 举报系统: 累计3次举报永久禁言

##### 数据结构
```swift
Message {
    id: UUID
    channel_id: UUID
    sender_id: UUID
    sender_name: String
    content: String
    location: Point        // 发送者位置
    created_at: DateTime
    is_reported: Bool
}
```

#### 7.3 频道管理

##### 频道类型
1. **公共频道** (系统默认)
   - 全球唯一
   - 自动加入
   - 无法退出

2. **私人频道** (用户创建)
   - 创建者命名
   - 邀请制/公开制
   - 最多100人

##### 频道创建
```
1. 点击"创建频道"
2. 输入频道名称 (2-20字符)
3. 选择类型:
   - 公开: 任何人可搜索加入
   - 私密: 仅邀请链接可加入
4. 设置频道描述 (可选)
5. 确认创建
6. 成为频道管理员
```

##### 管理员权限
- 踢出成员
- 禁言成员
- 编辑频道信息
- 解散频道

#### 7.4 PTT呼叫 (对讲机模式)

##### 交互设计
- **UI**: 大按钮占据屏幕下半部分
- **操作**: 长按说话,松开发送
- **视觉反馈**: 按下时按钮变红,波形动画
- **音频反馈**: 按下"嘀"一声,松开"嘀嘀"两声

##### 技术实现
```
1. 玩家长按PTT按钮
2. 开始录音 (最长60秒)
3. 实时显示音量波形
4. 松开按钮
5. 停止录音
6. 上传音频到Supabase Storage
7. 发送消息到当前频道,包含音频URL
8. 其他玩家收到消息,自动播放音频
```

#### 7.5 设备等级系统

##### 设备升级路径

| 设备 | 解锁方式 | 通讯能力 | 升级成本 |
|------|---------|---------|---------|
| 收音机 | 初始拥有 | 仅接收公共频道 | - |
| 对讲机 | 建造篝火×1 | 发送+接收,范围3km | 免费 |
| 营地电台 | 建造营地电台×1 | 范围10km,创建频道 | 免费 |
| 卫星通讯 | 付费购买 | 全球范围,优先推送 | $9.99 |

##### 设备切换
- 玩家可拥有多个设备
- 通讯页面顶部显示当前设备
- 点击设备图标切换
- 不同设备有不同能力

---

### 系统8: 排行榜系统

#### 排行榜类型

##### 1. 领地面积榜
```sql
SELECT
    user_id,
    username,
    SUM(ST_Area(geometry::geography)) as total_area,
    COUNT(*) as territory_count,
    RANK() OVER (ORDER BY SUM(ST_Area(geometry::geography)) DESC) as rank
FROM territories
WHERE status = 'active'
GROUP BY user_id, username
ORDER BY total_area DESC
LIMIT 100;
```

##### 2. 探索废墟榜
```sql
SELECT
    user_id,
    username,
    COUNT(DISTINCT poi_id) as unique_pois,
    SUM(distance) as total_distance,
    RANK() OVER (ORDER BY COUNT(DISTINCT poi_id) DESC) as rank
FROM explorations
GROUP BY user_id, username
ORDER BY unique_pois DESC
LIMIT 100;
```

##### 3. 建筑数量榜
```sql
SELECT
    user_id,
    username,
    COUNT(*) as building_count,
    SUM(CASE WHEN tier = 3 THEN 1 ELSE 0 END) as tier3_count,
    RANK() OVER (ORDER BY COUNT(*) DESC) as rank
FROM buildings
WHERE status = 'active'
GROUP BY user_id, username
ORDER BY building_count DESC
LIMIT 100;
```

#### 排行榜机制

##### 更新策略
- **实时榜**: 每5分钟更新 (使用缓存)
- **每日榜**: 每天00:00重置
- **每周榜**: 每周一00:00重置
- **赛季榜**: 赛季结束时结算

##### 奖励机制
| 排名 | 每日奖励 | 每周奖励 | 赛季奖励 |
|------|---------|---------|---------|
| 第1名 | 金币×200 | 金币×2000 | 传说徽章+金币×20000 |
| 第2-10名 | 金币×100 | 金币×1000 | 史诗徽章+金币×10000 |
| 第11-50名 | 金币×50 | 金币×500 | 稀有徽章+金币×5000 |
| 第51-100名 | 金币×20 | 金币×200 | 普通徽章+金币×2000 |

---

### 系统9: 成就系统

#### 成就分类

##### 新手成就 (引导性)
| 成就 | 触发条件 | 奖励 | 目的 |
|------|---------|------|------|
| 新手领主 | 圈第1块地 | 金币×100 | 学会圈地 |
| 末世拾荒者 | 搜刮第1个POI | 金币×100 | 学会探索 |
| 建设者 | 建造第1个建筑 | 金币×100 | 学会建造 |
| 交易先锋 | 完成第1笔交易 | 金币×150 | 学会交易 |
| 社交达人 | 发送第1条消息 | 金币×50 | 学会聊天 |

##### 进阶成就 (挑战性)
| 成就 | 触发条件 | 奖励 | 稀有度 |
|------|---------|------|--------|
| 领土扩张 | 拥有5块领地 | 金币×500 | 稀有 |
| 探索大师 | 搜刮100个不同POI | 金币×1000 | 稀有 |
| 建筑师 | 建造50个建筑 | 金币×800 | 稀有 |
| 贸易大亨 | 完成100笔交易 | 金币×1200 | 史诗 |
| 社区领袖 | 创建频道并达到50人 | 金币×1500 | 史诗 |

##### 稀有成就 (炫耀性)
| 成就 | 触发条件 | 奖励 | 稀有度 |
|------|---------|------|--------|
| 土地大亨 | 领地总面积>100000m² | 金币×5000+专属头像框 | 传说 |
| 全球探索家 | 搜刮1000个POI | 金币×10000+专属称号 | 传说 |
| 建造狂魔 | 建造500个建筑 | 金币×8000+专属特效 | 传说 |

#### EventBus架构

##### 事件发布
```swift
// 圈地成功后
EventBus.shared.publish(.territoryCreated(territoryId: newTerritory.id))

// 建造完成后
EventBus.shared.publish(.buildingConstructed(buildingId: newBuilding.id))
```

##### 成就监听
```swift
class AchievementManager {
    init() {
        // 订阅圈地事件
        EventBus.shared.subscribe(.territoryCreated) { territoryId in
            self.checkAchievement("新手领主")
        }

        // 订阅建造事件
        EventBus.shared.subscribe(.buildingConstructed) { buildingId in
            self.checkAchievement("建设者")
        }
    }
}
```

优势:
- 解耦: 圈地系统无需知道成就系统存在
- 扩展性: 新增成就无需修改其他代码
- 维护性: 成就逻辑集中管理

---

### 系统10: 生存体征系统

#### 三大体征

##### 1. 核心生命 (Health)
- **初始值**: 100
- **最大值**: 100 (可通过建筑提升到150)
- **衰减**: 不会自然衰减
- **消耗**: 饱食度/水分过低时才掉血
- **恢复**: 使用急救包 (+20), 医疗站 (+50)

##### 2. 饱食度 (Hunger)
- **初始值**: 100%
- **衰减速率**: -5% / 小时
- **衰减加速**: 探索POI时 -10% / 次
- **危险阈值**: <30% 时开始掉血 (-5生命/小时)
- **恢复**: 食用食物 (+20%-50%)

##### 3. 水分 (Thirst)
- **初始值**: 100%
- **衰减速率**: -10% / 小时 (比饿得快)
- **衰减加速**: 探索POI时 -15% / 次
- **危险阈值**: <30% 时开始掉血 (-10生命/小时)
- **恢复**: 饮用水 (+30%-60%)

#### Buff机制

##### 良好状态 (饱食度+水分 >80%)
✅ **激活Buff**:
- 探索奖励 +20%
- 建造速度 +10%
- 移动速度显示提升 (视觉反馈)

##### 不良状态
❌ **饱食度 <30%**:
- 探索奖励 -20%
- 开始掉血

❌ **水分 <30%**:
- 移动速度 -20% (视觉反馈)
- 开始掉血

❌ **生命值 <20**:
- 无法探索POI
- 无法建造
- 必须恢复才能继续游戏

#### 定时器实现

```swift
class VitalSignsManager {
    private var timer: Timer?

    func startMonitoring() {
        // 每10分钟检查一次
        timer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { _ in
            self.updateVitalSigns()
        }
    }

    private func updateVitalSigns() {
        let timePassed = Date().timeIntervalSince(lastUpdate)
        let hoursPassed = timePassed / 3600

        // 更新饱食度
        hunger -= 5 * hoursPassed

        // 更新水分
        thirst -= 10 * hoursPassed

        // 检查是否需要扣血
        if hunger < 30 {
            health -= 5 * hoursPassed
        }
        if thirst < 30 {
            health -= 10 * hoursPassed
        }

        // 同步到服务器
        syncToServer()
    }
}
```

---

### 系统11: 付费系统

#### 订阅制

##### 开拓者月卡 ($9.99/月)
**权益**:
- 探索次数无限 (免费用户10次/天)
- 探索范围 +50% (免费100米 → 150米)
- 资源产出 +20%
- 专属月卡徽章
- 去除广告 (未来功能)

##### 领主通行证 ($19.99/月)
**权益** (包含月卡所有 +):
- 领地数量无限 (免费用户最多5块)
- 建筑数量无限 (免费用户每块地最多10个)
- 专属皮肤 (领地边界特效)
- 优先客服响应
- 赛季奖励翻倍

#### 内购

##### 资源包
| 商品 | 价格 | 内容 | 价值 |
|------|------|------|------|
| 初级物资包 | $0.99 | 食物×50, 水×50 | 节省2小时探索 |
| 中级物资包 | $2.99 | 药品×20, 工具×10, 木材×100 | 节省5小时探索 |
| 高级物资包 | $4.99 | 稀有材料×10, 金属×200 | 节省10小时探索 |
| 稀有资源包 | $9.99 | 卫星模块×3, 核心处理器×2 | 稀有,无法探索获得 |

##### 功能解锁
| 商品 | 价格 | 内容 | 是否永久 |
|------|------|------|---------|
| 背包扩容 | $2.99 | +50格 | 是 |
| 设备升级 (卫星通讯) | $9.99 | 全球通讯 | 是 |
| 领地皮肤包 | $4.99 | 5种特效 | 是 |

#### StoreKit 2集成

```swift
// 商品ID定义
enum ProductID: String {
    case monthlyPass = "com.earthlord.monthly"
    case lordPass = "com.earthlord.lord"
    case basicPack = "com.earthlord.pack.basic"
    case premiumPack = "com.earthlord.pack.premium"
}

// 购买流程
class StoreKitManager {
    func purchase(_ productId: ProductID) async throws {
        // 1. 获取产品信息
        let products = try await Product.products(for: [productId.rawValue])
        guard let product = products.first else { return }

        // 2. 发起购买
        let result = try await product.purchase()

        // 3. 处理结果
        switch result {
        case .success(let verification):
            // 验证交易
            let transaction = try checkVerified(verification)
            // 发放商品
            await deliverProduct(transaction)
            // 完成交易
            await transaction.finish()

        case .userCancelled:
            // 用户取消
            break

        case .pending:
            // 等待批准 (家长控制)
            break
        }
    }
}
```

---

# 第四章: 游戏平衡性设计

## 4.1 资源经济

### 资源获取速度
| 资源类型 | 获取方式 | 获取速率 (小时) | 存储上限 |
|---------|---------|----------------|---------|
| 食物 | 探索餐厅/超市 | 20-30/次 | 500 |
| 水 | 探索餐厅/超市 | 15-25/次 | 300 |
| 木材 | 探索公园/林地 | 15-25/次 | 1000 |
| 金属 | 探索工厂/工地 | 10-20/次 | 500 |
| 药品 | 探索医院/药店 | 10-15/次 | 200 |
| 稀有材料 | 探索银行/珠宝店 | 1-2/次 | 50 |

### 资源消耗速度
| 消耗类型 | 速率 | 强制性 |
|---------|------|--------|
| 饱食度 | -5%/小时 | 是 (生存) |
| 水分 | -10%/小时 | 是 (生存) |
| 建造篝火 | 石头×20, 木材×30 | 否 (发展) |
| 建造农田 | 木材×30, 种子×10 | 否 (发展) |

### 经济循环设计
```
探索 (获取) → 背包 (存储) → 建造 (消耗) → 生产建筑 (产出) → 再投资

或

探索 (获取) → 背包 (存储) → 交易 (流通) → 获得所需资源 → 建造
```

**关键平衡点**:
- 免费玩家: 每天探索10次,获得约200资源,足够建造2-3个基础建筑
- 付费玩家: 探索无限,或直接购买资源包,加速发展3-5倍

## 4.2 等级进度

### 经验值系统
| 行为 | 经验值 | 每日上限 |
|------|-------|---------|
| 圈地 | 100 XP | 500 XP (5次) |
| 探索POI | 50 XP | 500 XP (10次免费) |
| 建造建筑 | 80 XP | 无上限 |
| 完成交易 | 30 XP | 300 XP (10次) |
| 完成成就 | 200-1000 XP | 无上限 |

### 等级解锁
| 等级 | 所需XP | 解锁内容 |
|------|--------|---------|
| 1 | 0 | 初始等级,Tier 1建筑 |
| 5 | 5000 | Tier 2建筑,创建频道 |
| 10 | 15000 | Tier 3建筑,联盟功能 |
| 20 | 50000 | 赛季排行榜,稀有皮肤 |
| 50 | 200000 | 传说称号,全服公告 |

## 4.3 付费平衡

### 免费玩家体验
✅ **可以做的**:
- 圈地 (最多5块,总面积无限)
- 探索 (10次/天)
- 建造 (每块地最多10个建筑)
- 交易 (无限)
- 聊天 (无限)
- 参与排行榜

❌ **受限的**:
- 探索次数 (10次/天 vs 无限)
- 探索范围 (100米 vs 150米)
- 资源产出 (100% vs 120%)

### 付费玩家优势
- **时间优势**: 探索无限,发展速度快3-5倍
- **空间优势**: 领地/建筑无限,更大规模
- **社交优势**: 专属徽章,彰显身份
- **便利优势**: 资源包直接购买,省时间

### Pay-to-Win风险控制
❌ **我们不做**:
- 付费玩家独占的强力建筑
- 付费才能参与的核心玩法
- 付费玩家碾压免费玩家的PVP

✅ **我们的原则**:
- 付费 = 节省时间,不是获得力量
- 免费玩家花时间也能达到付费玩家的水平
- 核心社交功能对所有人开放

---

# 第五章: UI/UX设计

## 5.1 信息架构

### 主导航 (底部Tab Bar)
```
[地图] [探索] [背包] [通讯] [个人]
```

#### 地图Tab
- 卫星地图视图
- 当前GPS位置
- 附近POI标记
- 自己的领地 (绿色多边形)
- 其他玩家领地 (灰色多边形)
- 圈地按钮 (悬浮大按钮)

#### 探索Tab
- 附近POI列表
- 距离排序
- 资源类型筛选
- 搜刮历史记录
- 探索统计数据

#### 背包Tab
- 物品网格视图
- 分类筛选 (全部/消耗品/材料/工具)
- 容量显示 (41/100)
- 快速使用按钮

#### 通讯Tab
- 消息中心
- 公共频道
- 我的频道
- PTT呼叫
- 设备切换

#### 个人Tab
- 用户头像和昵称
- 等级和经验条
- 领地统计
- 成就徽章
- 排行榜快捷入口
- 设置按钮

## 5.2 关键页面设计

### 圈地界面
```
┌────────────────────────────┐
│  ← EarthLord               │  顶部导航
├────────────────────────────┤
│                            │
│                            │
│      [卫星地图视图]          │  主内容区
│      🔵 玩家位置             │
│      ━━━ GPS轨迹            │
│      🟢 已有领地             │
│                            │
│                            │
├────────────────────────────┤
│  距离: 1.2km  时长: 15min   │  数据显示
│  ┌──────────────────────┐ │
│  │  [开始圈地] 🚀        │ │  主操作按钮
│  └──────────────────────┘ │
└────────────────────────────┘
```

### POI搜刮界面
```
┌────────────────────────────┐
│  × 惠州白鹭湖喜来登酒店       │  POI名称
├────────────────────────────┤
│                            │
│      [POI图标]              │  视觉元素
│       🏨                   │
│                            │
│  类型: 餐厅                 │  POI信息
│  距离: 23米                 │
│  状态: ✅ 可搜刮            │
│                            │
│  预计获得:                  │  奖励预览
│  • 罐头食品 ×20-30         │
│  • 饮用水 ×15-25           │
│  • 稀有食材 ×1-2 (随机)     │
│                            │
│  ┌──────────────────────┐ │
│  │  [搜刮] 🔍           │ │  操作按钮
│  └──────────────────────┘ │
└────────────────────────────┘
```

### 建造界面
```
┌────────────────────────────┐
│  ← 建造                     │
├────────────────────────────┤
│ [全部] [生存] [储存] [生产]  │  分类Tab
├────────────────────────────┤
│ ┌──────┐ ┌──────┐ ┌──────┐│
│ │ 🔥   │ │ 🏠   │ │ 📦   ││  建筑卡片
│ │篝火  │ │庇护所 │ │仓库  ││
│ │Tier1 │ │Tier1 │ │Tier1 ││
│ └──────┘ └──────┘ └──────┘│
│                            │
│ ┌────────────────────────┐│
│ │ 篝火 - Tier 1           ││  选中建筑详情
│ │                         ││
│ │ 需要材料:                ││
│ │ • 石头 ×20 ✅           ││
│ │ • 木材 ×30 ✅           ││
│ │                         ││
│ │ 功能: 提供温暖,+5生命/小时││
│ │                         ││
│ │ [开始建造] 🔨           ││
│ └────────────────────────┘│
└────────────────────────────┘
```

## 5.3 动画与反馈

### 微交互
- **按钮点击**: 缩放0.95x + 震动反馈
- **加载**: 旋转加载器 + "正在加载..."文字
- **成功**: ✅图标 + 绿色闪烁 + 成功音效
- **失败**: ❌图标 + 红色抖动 + 错误音效

### 转场动画
- **页面切换**: Push/Pop动画,300ms
- **Tab切换**: 淡入淡出,200ms
- **弹窗**: 从底部弹出,400ms弹簧动画

### 粒子效果
- **圈地成功**: 绿色粒子从边界向中心聚集
- **搜刮POI**: 金色光芒爆发效果
- **升级**: 蓝色光环扩散

---

# 第六章: 技术实现

## 6.1 技术栈详细

### 前端 (iOS App)
```
SwiftUI (UI框架)
├── MapKit (地图)
├── CoreLocation (GPS)
├── CoreData (本地数据库)
├── Combine (响应式编程)
└── StoreKit 2 (内购)
```

### 后端 (Supabase)
```
Supabase
├── PostgreSQL + PostGIS (数据库)
├── Supabase Auth (认证)
├── Supabase Storage (文件存储)
├── Supabase Realtime (实时推送)
└── Supabase Functions (Edge Functions)
```

## 6.2 数据库设计

### 核心表结构

#### users 表
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE,
    username TEXT UNIQUE NOT NULL,
    avatar_url TEXT,
    level INTEGER DEFAULT 1,
    experience INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_login TIMESTAMPTZ,
    subscription_tier TEXT, -- 'free', 'monthly', 'lord'
    subscription_expires_at TIMESTAMPTZ
);
```

#### territories 表
```sql
CREATE TABLE territories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id UUID REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    geometry GEOMETRY(Polygon, 4326) NOT NULL,  -- PostGIS类型
    area DOUBLE PRECISION,  -- 平方米
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_active TIMESTAMPTZ DEFAULT NOW(),
    allow_trade BOOLEAN DEFAULT false,
    status TEXT DEFAULT 'active'  -- 'active', 'inactive', 'abandoned'
);

-- 地理索引,加速附近查询
CREATE INDEX idx_territories_geometry ON territories USING GIST(geometry);
```

#### buildings 表
```sql
CREATE TABLE buildings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    territory_id UUID REFERENCES territories(id) ON DELETE CASCADE,
    building_type TEXT NOT NULL,  -- 'campfire', 'shelter', etc.
    tier INTEGER NOT NULL,
    level INTEGER DEFAULT 1,
    status TEXT DEFAULT 'inactive',  -- 'inactive', 'active', 'damaged'
    durability INTEGER DEFAULT 100,
    location GEOMETRY(Point, 4326),
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### items 表 (用户背包)
```sql
CREATE TABLE user_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    item_type TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 复合唯一索引,一个用户的同一物品只有一条记录
CREATE UNIQUE INDEX idx_user_items_unique ON user_items(user_id, item_type);
```

#### trades 表
```sql
CREATE TABLE trades (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    requester_id UUID REFERENCES users(id) ON DELETE CASCADE,
    territory_id UUID REFERENCES territories(id),
    offer_items JSONB NOT NULL,  -- [{"type": "canned_food", "quantity": 10}]
    request_items JSONB NOT NULL,
    status TEXT DEFAULT 'active',  -- 'active', 'completed', 'cancelled'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    accepter_id UUID REFERENCES users(id)
);
```

#### messages 表
```sql
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    channel_id UUID REFERENCES channels(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES users(id),
    content TEXT NOT NULL,
    message_type TEXT DEFAULT 'text',  -- 'text', 'audio'
    location GEOMETRY(Point, 4326),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 实时订阅索引
CREATE INDEX idx_messages_channel_time ON messages(channel_id, created_at DESC);
```

## 6.3 关键算法

### GPS防作弊算法
```swift
func validateGPSPath(_ path: [CLLocation]) -> Bool {
    guard path.count >= 10 else { return false }  // 至少10个点

    for i in 1..<path.count {
        let prev = path[i-1]
        let curr = path[i]

        // 计算速度
        let distance = curr.distance(from: prev)  // 米
        let time = curr.timestamp.timeIntervalSince(prev.timestamp)  // 秒
        let speed = distance / time * 3.6  // km/h

        // 速度检测
        if speed > 15 {
            return false  // 超速,可能是开车
        }

        // 跳跃检测
        if distance > 100 && time < 5 {
            return false  // 瞬移,可能是作弊
        }
    }

    return true
}
```

### 多边形面积计算 (Shoelace算法)
```swift
func calculatePolygonArea(_ coordinates: [CLLocationCoordinate2D]) -> Double {
    guard coordinates.count >= 3 else { return 0 }

    var area = 0.0
    for i in 0..<coordinates.count {
        let j = (i + 1) % coordinates.count
        area += coordinates[i].longitude * coordinates[j].latitude
        area -= coordinates[j].longitude * coordinates[i].latitude
    }
    area = abs(area) / 2.0

    // 转换为平方米 (近似,在小范围内有效)
    let metersPerDegree = 111320.0  // 1纬度约111km
    return area * metersPerDegree * metersPerDegree
}
```

### 附近POI查询 (PostGIS)
```sql
-- 查询玩家周围100米内的POI
SELECT
    id,
    name,
    poi_type,
    ST_Distance(
        location::geography,
        ST_MakePoint($longitude, $latitude)::geography
    ) as distance
FROM pois
WHERE ST_DWithin(
    location::geography,
    ST_MakePoint($longitude, $latitude)::geography,
    100  -- 100米
)
ORDER BY distance
LIMIT 10;
```

---

# 第七章: 运营与更新计划

## 7.1 赛季系统 (未来功能)

### 赛季机制
- **赛季周期**: 3个月
- **赛季主题**: 每季不同故事线和任务
- **赛季通行证**:
  - 免费版: 基础奖励
  - 付费版 ($9.99): 双倍奖励+专属皮肤

### 赛季任务示例
| 任务 | 要求 | 奖励 |
|------|------|------|
| 领土扩张 | 圈地总面积达到50000m² | 金币×1000 |
| 探索狂热 | 搜刮100个不同POI | 稀有资源包 |
| 建设大师 | 建造20个Tier 3建筑 | 专属皮肤 |
| 社交达人 | 完成50笔交易 | 称号"贸易大师" |

## 7.2 活动运营

### 每日活动
- **双倍资源日**: 每周末,所有POI产出翻倍
- **建造折扣日**: 每周三,建造材料消耗-20%
- **交易市集**: 每周五,交易完成+额外金币

### 节日活动
- **春节**: 特殊红包POI,随机出现高价值资源
- **万圣节**: 夜间探索获得"幽灵货币",兑换限定皮肤
- **圣诞节**: 雪景地图皮肤,圣诞树建筑限时解锁

## 7.3 内容更新路线图

### 第一年计划

#### Q1 (Month 1-3): 核心玩法稳定
- ✅ MVP上线
- 修复bug,优化性能
- 收集用户反馈
- 新增5种建筑

#### Q2 (Month 4-6): 社交深化
- 联盟系统上线
- 联盟领地 (多人协作圈地)
- 联盟战争 (PVE,攻打NPC据点)
- 好友系统

#### Q3 (Month 7-9): 赛季机制
- 第一赛季"重建之春"
- 赛季通行证
- 排行榜奖励升级
- AR模式Beta测试

#### Q4 (Month 10-12): 全球化
- 日语、韩语、西班牙语上线
- 全球联赛
- 跨服交易市场
- 年度盛典活动

---

# 第八章: 监控与分析

## 8.1 关键指标

### 用户指标
- DAU / MAU
- 留存率 (D1, D7, D30)
- 平均游戏时长
- 新增用户数

### 行为指标
- 圈地次数
- POI搜刮次数
- 建造次数
- 交易次数
- 聊天消息数

### 商业指标
- 付费转化率
- ARPU / ARPPU
- LTV
- 订阅续费率

## 8.2 A/B测试计划

### 测试项目
1. **新手教程长度**: 3分钟 vs 5分钟
2. **圈地最小面积**: 500m² vs 1000m²
3. **探索免费次数**: 10次 vs 15次
4. **首充礼包价格**: $0.99 vs $1.99

---

# 附录: 参考资料

## 竞品研究
- 宝可梦GO: LBS玩法鼻祖
- Ingress: 团队协作机制
- Zombies, Run!: 故事驱动的运动游戏
- Geocaching: 真实世界寻宝

## 技术文档
- Apple MapKit: https://developer.apple.com/maps/
- Supabase Docs: https://supabase.com/docs
- PostGIS Manual: https://postgis.net/docs/
- StoreKit 2: https://developer.apple.com/storekit/

---

**文档状态**: ✅ 已完成
**版本**: v1.0
**最后更新**: 2025-12-24
**维护者**: Game Design Team
