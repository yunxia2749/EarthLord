-- Day 24: 为 inventory_items 表添加 AI 物品支持
-- 2026-01-24

-- 1. 创建 inventory_items 表（如果不存在）
CREATE TABLE IF NOT EXISTS inventory_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    item_id TEXT NOT NULL,
    item_name TEXT,                  -- AI 生成的独特名称
    category TEXT,                   -- 物品分类（医疗/食物/工具/武器/材料）
    rarity TEXT,                     -- 稀有度（common/uncommon/rare/epic/legendary）
    story TEXT,                      -- 背景故事
    quantity INTEGER NOT NULL DEFAULT 1,
    is_ai_generated BOOLEAN DEFAULT FALSE,
    obtained_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. 如果表已存在，添加缺失的列（安全升级）
DO $$
BEGIN
    -- 添加 item_name 列（如果不存在）
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'inventory_items' AND column_name = 'item_name'
    ) THEN
        ALTER TABLE inventory_items ADD COLUMN item_name TEXT;
    END IF;

    -- 添加 category 列（如果不存在）
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'inventory_items' AND column_name = 'category'
    ) THEN
        ALTER TABLE inventory_items ADD COLUMN category TEXT;
    END IF;

    -- 添加 rarity 列（如果不存在）
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'inventory_items' AND column_name = 'rarity'
    ) THEN
        ALTER TABLE inventory_items ADD COLUMN rarity TEXT;
    END IF;

    -- 添加 story 列（如果不存在）
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'inventory_items' AND column_name = 'story'
    ) THEN
        ALTER TABLE inventory_items ADD COLUMN story TEXT;
    END IF;

    -- 添加 is_ai_generated 列（如果不存在）
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'inventory_items' AND column_name = 'is_ai_generated'
    ) THEN
        ALTER TABLE inventory_items ADD COLUMN is_ai_generated BOOLEAN DEFAULT FALSE;
    END IF;
END $$;

-- 3. 创建索引（优化查询性能）
CREATE INDEX IF NOT EXISTS idx_inventory_user_item
    ON inventory_items(user_id, item_id);

CREATE INDEX IF NOT EXISTS idx_inventory_user_ai
    ON inventory_items(user_id, is_ai_generated);

-- 4. 启用 RLS（行级安全）
ALTER TABLE inventory_items ENABLE ROW LEVEL SECURITY;

-- 5. 删除旧策略（如果存在）
DROP POLICY IF EXISTS "用户只能查看自己的背包" ON inventory_items;
DROP POLICY IF EXISTS "用户只能修改自己的背包" ON inventory_items;

-- 6. 创建新的 RLS 策略
CREATE POLICY "用户只能查看自己的背包"
    ON inventory_items
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "用户只能修改自己的背包"
    ON inventory_items
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 7. 添加注释
COMMENT ON TABLE inventory_items IS 'Day 24: 用户背包物品表，支持预设物品和AI生成物品';
COMMENT ON COLUMN inventory_items.item_name IS 'AI生成的独特名称，如"老张的最后晚餐"';
COMMENT ON COLUMN inventory_items.story IS 'AI生成的背景故事';
COMMENT ON COLUMN inventory_items.is_ai_generated IS '是否为AI生成物品（true=AI，false=预设）';
