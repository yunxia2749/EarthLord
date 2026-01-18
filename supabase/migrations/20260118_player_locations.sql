-- =============================================
-- 附近玩家检测系统 - 数据库表和 RPC 函数
-- Day 22: 多人密度检测系统
-- =============================================

-- 确保启用 PostGIS 扩展（用于空间查询）
CREATE EXTENSION IF NOT EXISTS postgis;

-- =============================================
-- 1. 玩家位置表
-- =============================================

CREATE TABLE IF NOT EXISTS player_locations (
    -- 玩家ID（关联 auth.users）
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

    -- 位置坐标（使用 PostGIS geography 类型，支持精确的地球距离计算）
    location GEOGRAPHY(POINT, 4326) NOT NULL,

    -- 经纬度（冗余字段，方便客户端直接读取）
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,

    -- 最后更新时间（用于判断是否在线：5分钟内有更新则视为在线）
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 创建空间索引（加速范围查询）
CREATE INDEX IF NOT EXISTS idx_player_locations_geography
ON player_locations USING GIST (location);

-- 创建时间索引（加速在线状态过滤）
CREATE INDEX IF NOT EXISTS idx_player_locations_updated_at
ON player_locations (updated_at);

-- =============================================
-- 2. RLS 策略（行级安全）
-- =============================================

-- 启用 RLS
ALTER TABLE player_locations ENABLE ROW LEVEL SECURITY;

-- 允许用户插入/更新自己的位置
CREATE POLICY "Users can upsert their own location"
ON player_locations
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 允许读取所有在线玩家的位置（仅用于统计数量，不暴露具体坐标）
-- 注意：实际查询通过 RPC 函数进行，不直接暴露位置数据
CREATE POLICY "Users can read online player count"
ON player_locations
FOR SELECT
USING (true);

-- =============================================
-- 3. RPC 函数：上报玩家位置
-- =============================================

CREATE OR REPLACE FUNCTION report_player_location(
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    -- 获取当前用户ID
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;

    -- 插入或更新位置（UPSERT）
    INSERT INTO player_locations (user_id, location, latitude, longitude, updated_at)
    VALUES (
        v_user_id,
        ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography,
        p_latitude,
        p_longitude,
        NOW()
    )
    ON CONFLICT (user_id)
    DO UPDATE SET
        location = ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography,
        latitude = p_latitude,
        longitude = p_longitude,
        updated_at = NOW();
END;
$$;

-- =============================================
-- 4. RPC 函数：查询附近玩家数量
-- =============================================

CREATE OR REPLACE FUNCTION get_nearby_player_count(
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION,
    p_radius_meters INTEGER DEFAULT 1000
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_count INTEGER;
    v_point GEOGRAPHY;
BEGIN
    -- 获取当前用户ID
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;

    -- 创建查询点
    v_point := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography;

    -- 统计范围内的在线玩家数量（排除自己）
    SELECT COUNT(*)
    INTO v_count
    FROM player_locations
    WHERE
        -- 在指定半径内
        ST_DWithin(location, v_point, p_radius_meters)
        -- 5分钟内活跃（在线）
        AND updated_at > NOW() - INTERVAL '5 minutes'
        -- 排除当前用户
        AND user_id != v_user_id;

    RETURN COALESCE(v_count, 0);
END;
$$;

-- =============================================
-- 5. RPC 函数：获取 POI 显示建议
-- =============================================

CREATE OR REPLACE FUNCTION get_poi_suggestion(
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION,
    p_radius_meters INTEGER DEFAULT 1000
)
RETURNS TABLE (
    nearby_count INTEGER,
    density_level TEXT,
    suggested_poi_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_count INTEGER;
    v_level TEXT;
    v_poi_count INTEGER;
BEGIN
    -- 获取附近玩家数量
    v_count := get_nearby_player_count(p_latitude, p_longitude, p_radius_meters);

    -- 根据数量判断密度等级和建议POI数量
    IF v_count = 0 THEN
        v_level := 'alone';      -- 独行者
        v_poi_count := 1;        -- 保底1个
    ELSIF v_count <= 5 THEN
        v_level := 'low';        -- 低密度
        v_poi_count := 3;        -- 2-3个
    ELSIF v_count <= 20 THEN
        v_level := 'medium';     -- 中密度
        v_poi_count := 6;        -- 4-6个
    ELSE
        v_level := 'high';       -- 高密度
        v_poi_count := 99;       -- 显示所有
    END IF;

    RETURN QUERY SELECT v_count, v_level, v_poi_count;
END;
$$;

-- =============================================
-- 6. RPC 函数：标记玩家离线（App进入后台时调用）
-- =============================================

CREATE OR REPLACE FUNCTION mark_player_offline()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    -- 获取当前用户ID
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;

    -- 将更新时间设置为10分钟前，使 is_online 变为 false
    UPDATE player_locations
    SET updated_at = NOW() - INTERVAL '10 minutes'
    WHERE user_id = v_user_id;
END;
$$;

-- =============================================
-- 7. 授予执行权限
-- =============================================

GRANT EXECUTE ON FUNCTION report_player_location(DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;
GRANT EXECUTE ON FUNCTION get_nearby_player_count(DOUBLE PRECISION, DOUBLE PRECISION, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_poi_suggestion(DOUBLE PRECISION, DOUBLE PRECISION, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION mark_player_offline() TO authenticated;

-- =============================================
-- 完成
-- =============================================

COMMENT ON TABLE player_locations IS '玩家位置表 - 用于多人密度检测系统';
COMMENT ON FUNCTION report_player_location IS '上报玩家位置（每30秒或移动50米时调用）';
COMMENT ON FUNCTION get_nearby_player_count IS '查询附近1公里内的在线玩家数量';
COMMENT ON FUNCTION get_poi_suggestion IS '根据附近玩家密度获取POI显示建议';
COMMENT ON FUNCTION mark_player_offline IS '标记玩家离线（App进入后台时调用）';
