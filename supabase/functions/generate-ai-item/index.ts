// Edge Function: generate-ai-item
// 用途: 调用阿里云百炼 API 生成 AI 物品
//
// 使用方法:
// POST /functions/v1/generate-ai-item
// Headers: Authorization: Bearer <user_access_token>
// Body: { poi: { name, type, dangerLevel }, itemCount: 3 }
//
// 响应:
// 成功: { success: true, items: [...] }
// 失败: { success: false, error: "错误信息" }

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import OpenAI from "npm:openai";

// CORS 头
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// 阿里云百炼配置（国际版端点）
const openai = new OpenAI({
    apiKey: Deno.env.get("DASHSCOPE_API_KEY"),
    baseURL: "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
});

// 系统提示词
const SYSTEM_PROMPT = `你是一个末日生存游戏的物品生成器。游戏背景是丧尸末日后的世界。

根据玩家搜刮的地点，生成符合场景的物品列表。每个物品需要：
- name: 独特有创意的名称（15字以内），可以暗示前主人身份或物品来历
- category: 分类，只能是以下之一：医疗、食物、工具、武器、材料
- rarity: 稀有度，只能是以下之一：common、uncommon、rare、epic、legendary
- story: 背景故事（50-100字），要有画面感，营造末日氛围

规则：
1. 物品类型要与搜刮地点相关（医院出医疗物品，超市出食物等）
2. 名称要有创意，不要用"普通"、"损坏"等无聊的形容词
3. 故事要有画面感，可以有黑色幽默，但不要太血腥
4. 严格按照要求的稀有度分布生成

只返回 JSON 数组格式，不要包含任何其他文字或 markdown 标记。`;

// 根据危险值生成稀有度分布描述
function getRarityDescription(dangerLevel: number): string {
    switch (dangerLevel) {
        case 1:
        case 2:
            return "普通(common) 70%, 优秀(uncommon) 25%, 稀有(rare) 5%";
        case 3:
            return "普通(common) 50%, 优秀(uncommon) 30%, 稀有(rare) 15%, 史诗(epic) 5%";
        case 4:
            return "优秀(uncommon) 40%, 稀有(rare) 35%, 史诗(epic) 20%, 传奇(legendary) 5%";
        case 5:
            return "稀有(rare) 30%, 史诗(epic) 40%, 传奇(legendary) 30%";
        default:
            return "普通(common) 60%, 优秀(uncommon) 30%, 稀有(rare) 10%";
    }
}

// POI类型映射到中文
const poiTypeNames: Record<string, string> = {
    'supermarket': '超市',
    'hospital': '医院',
    'gas_station': '加油站',
    'pharmacy': '药店',
    'factory': '工厂',
    'warehouse': '仓库',
    'residence': '民居',
    'police': '警察局'
};

Deno.serve(async (req: Request) => {
    // 处理 CORS 预检请求
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        console.log('[generate-ai-item] 开始处理请求');

        // 验证请求方法
        if (req.method !== 'POST') {
            return new Response(
                JSON.stringify({ success: false, error: '仅支持 POST 请求' }),
                { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            );
        }

        // 检查 API Key 配置
        const apiKey = Deno.env.get("DASHSCOPE_API_KEY");
        if (!apiKey) {
            console.error('[generate-ai-item] DASHSCOPE_API_KEY 未配置');
            return new Response(
                JSON.stringify({ success: false, error: '服务器配置错误：API Key 未设置' }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            );
        }

        // 解析请求体
        const { poi, itemCount = 3 } = await req.json();

        if (!poi || !poi.name || !poi.type || poi.dangerLevel === undefined) {
            return new Response(
                JSON.stringify({ success: false, error: '缺少必要参数：poi (name, type, dangerLevel)' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            );
        }

        console.log(`[generate-ai-item] POI: ${poi.name}, 类型: ${poi.type}, 危险等级: ${poi.dangerLevel}, 物品数: ${itemCount}`);

        // 构建用户提示词
        const poiTypeName = poiTypeNames[poi.type] || poi.type;
        const rarityDescription = getRarityDescription(poi.dangerLevel);

        const userPrompt = `搜刮地点：${poi.name}（${poiTypeName}类型，危险等级 ${poi.dangerLevel}/5）

请生成 ${itemCount} 个物品。

稀有度分布参考（请大致遵守这个比例）：
${rarityDescription}

返回格式示例：
[
  {
    "name": "物品名称",
    "category": "医疗",
    "rarity": "rare",
    "story": "背景故事..."
  }
]

只返回 JSON 数组，不要其他内容。`;

        console.log('[generate-ai-item] 调用 AI API...');

        // 调用阿里云百炼 API
        const completion = await openai.chat.completions.create({
            model: "qwen-plus",
            messages: [
                { role: "system", content: SYSTEM_PROMPT },
                { role: "user", content: userPrompt }
            ],
            max_tokens: 1000,
            temperature: 0.8
        });

        const content = completion.choices[0]?.message?.content;
        console.log('[generate-ai-item] AI 原始响应:', content);

        if (!content) {
            throw new Error('AI 返回内容为空');
        }

        // 清理响应（移除可能的 markdown 标记）
        let cleanContent = content.trim();
        if (cleanContent.startsWith('```json')) {
            cleanContent = cleanContent.slice(7);
        }
        if (cleanContent.startsWith('```')) {
            cleanContent = cleanContent.slice(3);
        }
        if (cleanContent.endsWith('```')) {
            cleanContent = cleanContent.slice(0, -3);
        }
        cleanContent = cleanContent.trim();

        // 解析 JSON
        const items = JSON.parse(cleanContent);

        // 验证返回的物品格式
        if (!Array.isArray(items)) {
            throw new Error('AI 返回格式错误：不是数组');
        }

        // 验证每个物品的字段
        const validItems = items.map((item: any, index: number) => {
            if (!item.name || !item.category || !item.rarity || !item.story) {
                console.warn(`[generate-ai-item] 物品 ${index} 字段不完整:`, item);
            }
            return {
                name: item.name || `未命名物品${index + 1}`,
                category: item.category || '杂项',
                rarity: item.rarity || 'common',
                story: item.story || '这个物品的来历已经无从考证...'
            };
        });

        console.log(`[generate-ai-item] 成功生成 ${validItems.length} 个物品`);

        return new Response(
            JSON.stringify({ success: true, items: validItems }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );

    } catch (error) {
        console.error('[generate-ai-item] 错误:', error.message);
        return new Response(
            JSON.stringify({ success: false, error: error.message }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
    }
});
