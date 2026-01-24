-- =============================================
-- 可见领地查询函数
-- 用于地图加载时获取可见区域内的领地
-- =============================================

-- 确保启用 PostGIS 扩展
CREATE EXTENSION IF NOT EXISTS postgis;

-- =============================================
-- 1. 创建 territories 表（如果不存在）
-- =============================================

CREATE TABLE IF NOT EXISTS territories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT,
    path JSONB NOT NULL,
    polygon TEXT,  -- WKT 格式的多边形
    geom GEOMETRY(POLYGON, 4326),  -- PostGIS 几何体
    bbox_min_lat DOUBLE PRECISION,
    bbox_max_lat DOUBLE PRECISION,
    bbox_min_lon DOUBLE PRECISION,
    bbox_max_lon DOUBLE PRECISION,
    area DOUBLE PRECISION,
    point_count INTEGER,
    started_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 创建空间索引
CREATE INDEX IF NOT EXISTS idx_territories_geom ON territories USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_territories_bbox ON territories (bbox_min_lat, bbox_max_lat, bbox_min_lon, bbox_max_lon);
CREATE INDEX IF NOT EXISTS idx_territories_user_id ON territories (user_id);
CREATE INDEX IF NOT EXISTS idx_territories_is_active ON territories (is_active);

-- =============================================
-- 2. 触发器：自动从 polygon WKT 生成 geom
-- =============================================

CREATE OR REPLACE FUNCTION update_territory_geom()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.polygon IS NOT NULL THEN
        BEGIN
            NEW.geom := ST_GeomFromText(NEW.polygon, 4326);
        EXCEPTION WHEN OTHERS THEN
            -- WKT 解析失败时忽略
            NEW.geom := NULL;
        END;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_update_territory_geom ON territories;
CREATE TRIGGER trigger_update_territory_geom
    BEFORE INSERT OR UPDATE ON territories
    FOR EACH ROW
    EXECUTE FUNCTION update_territory_geom();

-- =============================================
-- 3. RLS 策略
-- =============================================

ALTER TABLE territories ENABLE ROW LEVEL SECURITY;

-- 允许用户创建自己的领地
DROP POLICY IF EXISTS "Users can insert their own territories" ON territories;
CREATE POLICY "Users can insert their own territories"
ON territories FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- 允许用户更新自己的领地
DROP POLICY IF EXISTS "Users can update their own territories" ON territories;
CREATE POLICY "Users can update their own territories"
ON territories FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 允许用户删除自己的领地
DROP POLICY IF EXISTS "Users can delete their own territories" ON territories;
CREATE POLICY "Users can delete their own territories"
ON territories FOR DELETE
USING (auth.uid() = user_id);

-- 允许所有登录用户查看所有领地（用于地图显示）
DROP POLICY IF EXISTS "Users can view all territories" ON territories;
CREATE POLICY "Users can view all territories"
ON territories FOR SELECT
USING (true);

-- =============================================
-- 4. get_visible_territories 函数
-- =============================================

CREATE OR REPLACE FUNCTION get_visible_territories(
    min_lat DOUBLE PRECISION,
    min_lng DOUBLE PRECISION,
    max_lat DOUBLE PRECISION,
    max_lng DOUBLE PRECISION,
    zoom_level DOUBLE PRECISION DEFAULT 15.0
)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    name TEXT,
    path JSONB,
    area DOUBLE PRECISION,
    point_count INTEGER,
    is_active BOOLEAN,
    created_at TIMESTAMPTZ,
    geojson JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    simplify_tolerance DOUBLE PRECISION;
BEGIN
    -- 根据缩放级别计算简化容差
    -- 缩放级别越低（更远），简化程度越高
    IF zoom_level >= 17 THEN
        simplify_tolerance := 0.0;  -- 不简化
    ELSIF zoom_level >= 15 THEN
        simplify_tolerance := 0.00001;  -- 轻微简化
    ELSIF zoom_level >= 13 THEN
        simplify_tolerance := 0.0001;   -- 中等简化
    ELSE
        simplify_tolerance := 0.001;    -- 大幅简化
    END IF;

    RETURN QUERY
    SELECT
        t.id,
        t.user_id,
        t.name,
        t.path,
        t.area,
        t.point_count,
        t.is_active,
        t.created_at,
        -- 生成简化后的 GeoJSON
        CASE
            WHEN t.geom IS NOT NULL AND simplify_tolerance > 0 THEN
                ST_AsGeoJSON(ST_SimplifyPreserveTopology(t.geom, simplify_tolerance))::jsonb
            WHEN t.geom IS NOT NULL THEN
                ST_AsGeoJSON(t.geom)::jsonb
            ELSE
                NULL
        END AS geojson
    FROM territories t
    WHERE
        t.is_active = true
        AND (
            -- 使用边界框进行快速过滤
            (t.bbox_min_lat IS NOT NULL AND t.bbox_max_lat IS NOT NULL
             AND t.bbox_min_lon IS NOT NULL AND t.bbox_max_lon IS NOT NULL
             AND t.bbox_min_lat <= max_lat
             AND t.bbox_max_lat >= min_lat
             AND t.bbox_min_lon <= max_lng
             AND t.bbox_max_lon >= min_lng)
            -- 或者使用 PostGIS 空间查询
            OR (t.geom IS NOT NULL
                AND ST_Intersects(
                    t.geom,
                    ST_MakeEnvelope(min_lng, min_lat, max_lng, max_lat, 4326)
                ))
        )
    ORDER BY t.created_at DESC
    LIMIT 100;  -- 限制返回数量
END;
$$;

-- 授予执行权限
GRANT EXECUTE ON FUNCTION get_visible_territories(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;

-- =============================================
-- 5. find_overlapping_territories 函数（碰撞检测）
-- =============================================

CREATE OR REPLACE FUNCTION find_overlapping_territories(
    p_polygon TEXT,  -- WKT 格式的多边形
    p_user_id UUID DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    name TEXT,
    area DOUBLE PRECISION
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_geom GEOMETRY;
BEGIN
    -- 解析 WKT
    v_geom := ST_GeomFromText(p_polygon, 4326);

    RETURN QUERY
    SELECT
        t.id,
        t.user_id,
        t.name,
        t.area
    FROM territories t
    WHERE
        t.is_active = true
        AND t.geom IS NOT NULL
        AND ST_Intersects(t.geom, v_geom)
        AND (p_user_id IS NULL OR t.user_id != p_user_id);
END;
$$;

-- 授予执行权限
GRANT EXECUTE ON FUNCTION find_overlapping_territories(TEXT, UUID) TO authenticated;

-- =============================================
-- 完成
-- =============================================

COMMENT ON FUNCTION get_visible_territories IS '获取可见区域内的领地列表（支持几何简化）';
COMMENT ON FUNCTION find_overlapping_territories IS '查找与指定多边形重叠的领地（用于碰撞检测）';
