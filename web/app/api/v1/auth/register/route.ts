import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

export async function POST(req: NextRequest) {
  try {
    const { email, password, username } = await req.json();

    if (!email || !password || !username) {
      return NextResponse.json(
        { message: "邮箱、密码和用户名不能为空" },
        { status: 400 }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    const { data: authData, error: signUpError } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        username,
      },
    });

    if (signUpError) {
      if (signUpError.message.includes("already registered")) {
        return NextResponse.json(
          { message: "邮箱已被注册" },
          { status: 409 }
        );
      }
      console.error("注册失败:", signUpError);
      return NextResponse.json(
        { message: signUpError.message || "注册失败" },
        { status: 400 }
      );
    }

    if (!authData.user) {
      return NextResponse.json(
        { message: "创建用户失败" },
        { status: 500 }
      );
    }

    const userId = authData.user.id;

    await supabase
      .from("user_profiles")
      .upsert({
        id: userId,
        nickname: username,
        last_login_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }, { onConflict: "id" });

    const { data: sessionData, error: sessionError } = await supabase.auth.admin.generateLink({
      type: 'magiclink',
      email,
    });

    let token = "";
    if (!sessionError && sessionData) {
      const { data: signInData } = await supabase.auth.signInWithPassword({
        email,
        password,
      });
      token = signInData?.session?.access_token || "";
    }

    return NextResponse.json({
      token,
      user: {
        id: userId,
        email: authData.user.email,
        username,
      },
    });
  } catch (error: unknown) {
    console.error("注册错误:", error);
    const message = error instanceof Error ? error.message : "服务器错误";
    return NextResponse.json(
      { message },
      { status: 500 }
    );
  }
}
