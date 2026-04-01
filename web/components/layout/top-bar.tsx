"use client";

import { usePathname, useRouter } from "next/navigation";
import { Search, Bell, LogIn } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { useEffect, useState } from "react";
import type { User } from "@supabase/supabase-js";

const pageTitles: Record<string, string> = {
  "/":        "艺见心",
  "/explore": "探索院校",
  "/cases":   "案例灵感",
  "/forum":   "论坛社区",
  "/profile": "我的",
};

export function TopBar() {
  const pathname = usePathname();
  const router = useRouter();
  const title = pageTitles[pathname] ?? "艺见心";
  const isHome = pathname === "/";
  const [user, setUser] = useState<User | null>(null);

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(({ data }) => setUser(data.user));
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_, session) => {
      setUser(session?.user ?? null);
    });
    return () => subscription.unsubscribe();
  }, []);

  return (
    <header className="flex-shrink-0 bg-white border-b border-gray-100">
      <div className="flex items-center justify-between h-14 px-4">
        {isHome ? (
          <div className="flex items-center gap-1.5">
            <div className="w-7 h-7 rounded-lg bg-gradient-to-br from-[#1A4B8C] to-[#4A90D9] flex items-center justify-center">
              <span className="text-white text-xs font-bold">艺</span>
            </div>
            <span className="text-lg font-bold text-gray-900 font-[family-name:var(--font-poppins)]">
              艺见心
            </span>
            <span className="text-[10px] text-[#1A4B8C] font-medium border border-[#1A4B8C]/30 rounded px-1 ml-0.5">
              BETA
            </span>
          </div>
        ) : (
          <h1 className="text-base font-semibold text-gray-900">{title}</h1>
        )}

        <div className="flex items-center gap-2">
          <button className="w-8 h-8 flex items-center justify-center rounded-full hover:bg-gray-100 transition-colors">
            <Search size={18} className="text-gray-600" />
          </button>
          {user ? (
            <button className="w-8 h-8 flex items-center justify-center rounded-full hover:bg-gray-100 transition-colors relative">
              <Bell size={18} className="text-gray-600" />
              <span className="absolute top-1 right-1 w-2 h-2 bg-[#1A4B8C] rounded-full" />
            </button>
          ) : (
            <button
              onClick={() => router.push(`/auth/login?redirect=${encodeURIComponent(pathname)}`)}
              className="flex items-center gap-1 text-xs font-medium text-[#1A4B8C] bg-blue-50 px-2.5 py-1.5 rounded-full"
            >
              <LogIn size={13} />
              登录
            </button>
          )}
        </div>
      </div>
    </header>
  );
}
