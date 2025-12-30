// Edge Function: delete-account
// 用途: 安全地删除用户账户及其所有相关数据
//
// 使用方法:
// POST /functions/v1/delete-account
// Headers: Authorization: Bearer <user_access_token>
//
// 响应:
// 成功: { success: true, message: "账户已成功删除" }
// 失败: { success: false, error: "错误信息" }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // 处理 CORS 预检请求
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('🚀 [删除账户] 开始处理账户删除请求')

    // 1. 验证请求方法
    if (req.method !== 'POST') {
      console.log('❌ [删除账户] 错误的请求方法:', req.method)
      return new Response(
        JSON.stringify({
          success: false,
          error: '仅支持 POST 请求'
        }),
        {
          status: 405,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 2. 获取环境变量
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    if (!supabaseUrl || !serviceRoleKey) {
      console.log('❌ [删除账户] 环境变量未配置')
      return new Response(
        JSON.stringify({
          success: false,
          error: '服务器配置错误'
        }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 3. 从请求头获取用户的 access token
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      console.log('❌ [删除账户] 缺少 Authorization header')
      return new Response(
        JSON.stringify({
          success: false,
          error: '未授权：缺少认证令牌'
        }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const token = authHeader.replace('Bearer ', '')
    console.log('📝 [删除账户] 收到认证令牌')

    // 4. 使用用户的 token 创建客户端，验证用户身份
    const supabaseClient = createClient(supabaseUrl, serviceRoleKey, {
      global: {
        headers: { Authorization: authHeader }
      }
    })

    // 验证用户身份
    const { data: { user }, error: authError } = await supabaseClient.auth.getUser(token)

    if (authError || !user) {
      console.log('❌ [删除账户] 用户身份验证失败:', authError?.message)
      return new Response(
        JSON.stringify({
          success: false,
          error: '未授权：无效的认证令牌'
        }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    console.log('✅ [删除账户] 用户身份验证成功')
    console.log('📝 [删除账户] 用户ID:', user.id)
    console.log('📝 [删除账户] 用户邮箱:', user.email)

    // 5. 使用 service role key 创建管理员客户端
    const adminClient = createClient(supabaseUrl, serviceRoleKey)

    // 6. 删除用户账户（会自动触发级联删除相关数据）
    console.log('🗑️ [删除账户] 开始删除用户账户...')

    const { error: deleteError } = await adminClient.auth.admin.deleteUser(user.id)

    if (deleteError) {
      console.log('❌ [删除账户] 删除失败:', deleteError.message)
      return new Response(
        JSON.stringify({
          success: false,
          error: `删除账户失败: ${deleteError.message}`
        }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    console.log('✅ [删除账户] 用户账户删除成功')
    console.log('📝 [删除账户] 已删除用户ID:', user.id)

    // 7. 返回成功响应
    return new Response(
      JSON.stringify({
        success: true,
        message: '账户已成功删除'
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.log('❌ [删除账户] 发生异常:', error.message)
    return new Response(
      JSON.stringify({
        success: false,
        error: `服务器错误: ${error.message}`
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})

/*
 * 数据库级联删除配置说明：
 *
 * 如果你有其他表引用了 auth.users 表，需要设置级联删除。
 *
 * 示例 SQL（在 Supabase SQL Editor 中执行）：
 *
 * -- 假设你有一个 user_profiles 表
 * ALTER TABLE user_profiles
 * DROP CONSTRAINT IF EXISTS user_profiles_user_id_fkey,
 * ADD CONSTRAINT user_profiles_user_id_fkey
 * FOREIGN KEY (user_id)
 * REFERENCES auth.users(id)
 * ON DELETE CASCADE;
 *
 * -- 假设你有一个 user_data 表
 * ALTER TABLE user_data
 * DROP CONSTRAINT IF EXISTS user_data_user_id_fkey,
 * ADD CONSTRAINT user_data_user_id_fkey
 * FOREIGN KEY (user_id)
 * REFERENCES auth.users(id)
 * ON DELETE CASCADE;
 *
 * 这样当用户被删除时，相关的数据也会自动删除。
 */
