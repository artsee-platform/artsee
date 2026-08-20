import { NextResponse } from "next/server";

const CREATE_TABLES_SQL = `-- 创建更新触发器函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 1. schools - 学校表
CREATE TABLE IF NOT EXISTS schools (
    id SERIAL PRIMARY KEY,
    name_zh VARCHAR(200) NOT NULL,
    name_en TEXT,
    country VARCHAR(100),
    city VARCHAR(100),
    school_type VARCHAR(50),
    qs_art_rank INTEGER,
    official_website VARCHAR(500),
    logo_url TEXT,
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. art_categories - 艺术分类表
CREATE TABLE IF NOT EXISTS art_categories (
    id SERIAL PRIMARY KEY,
    name_zh VARCHAR(100) NOT NULL,
    name_en VARCHAR(100),
    parent_id INTEGER REFERENCES art_categories(id) ON DELETE SET NULL,
    level INTEGER DEFAULT 1,
    is_popular BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. programs - 项目表
CREATE TABLE IF NOT EXISTS programs (
    id SERIAL PRIMARY KEY,
    school_id INTEGER NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    program_name VARCHAR(200) NOT NULL,
    degree_type VARCHAR(50),
    duration_months INTEGER,
    requires_portfolio BOOLEAN DEFAULT false,
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. user_profiles - 用户资料扩展表
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    nickname VARCHAR(100),
    avatar_url TEXT,
    phone VARCHAR(20),
    wechat_open_id VARCHAR(100) UNIQUE,
    language VARCHAR(10) DEFAULT 'zh-CN',
    theme VARCHAR(20) DEFAULT 'light',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 短信验证码表不得在这里以明文方式创建。
-- 请另行执行 supabase/migrations/20260808195110_harden_sms_auth.sql，
-- 该迁移会启用 RLS、撤销匿名权限，并创建哈希验证码与原子消费函数。

-- 创建新用户时自动创建 profile
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (id, phone)
    VALUES (NEW.id, NEW.phone);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();`;

export async function POST() {
  return NextResponse.json({
    success: true,
    message: "请在 Supabase Dashboard SQL Editor 中执行以下 SQL",
    sql: CREATE_TABLES_SQL,
    instructions: [
      "1. 打开 https://app.supabase.com/project/nufrgmlhlfmhxsqbybfd",
      "2. 进入 SQL Editor",
      "3. 复制上面的基础 SQL 并执行",
      "4. 必须继续执行 supabase/migrations/20260808195110_harden_sms_auth.sql"
    ]
  });
}

export async function GET() {
  return NextResponse.json({
    message: "使用 POST 请求获取建表 SQL",
    tables: ["schools", "art_categories", "programs", "user_profiles"],
    requiredMigration: "supabase/migrations/20260808195110_harden_sms_auth.sql"
  });
}
