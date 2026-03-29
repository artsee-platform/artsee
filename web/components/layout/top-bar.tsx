"use client";

import { usePathname } from "next/navigation";
import { Search, Bell } from "lucide-react";

const pageTitles: Record<string, string> = {
  "/":        "艺见心",
  "/explore": "探索院校",
  "/cases":   "案例灵感",
  "/forum":   "论坛社区",
  "/profile": "我的",
};

export function TopBar() {
  const pathname = usePathname();
  const title = pageTitles[pathname] ?? "艺见心";
  const isHome = pathname === "/";

  return (
    <header className="flex-shrink-0 bg-white border-b border-gray-100">
      <div className="flex items-center justify-between h-14 px-4">
        {/* Logo / 页面标题 */}
        {isHome ? (
          <div className="flex items-center gap-1.5">
            <div className="w-7 h-7 rounded-lg bg-gradient-to-br from-[#FF6A00] to-[#FF9A3C] flex items-center justify-center">
              <span className="text-white text-xs font-bold">艺</span>
            </div>
            <span className="text-lg font-bold text-gray-900 font-[family-name:var(--font-poppins)]">
              艺见心
            </span>
            <span className="text-[10px] text-[#FF6A00] font-medium border border-[#FF6A00]/30 rounded px-1 ml-0.5">
              BETA
            </span>
          </div>
        ) : (
          <h1 className="text-base font-semibold text-gray-900">{title}</h1>
        )}

        {/* 右侧图标 */}
        <div className="flex items-center gap-3">
          <button className="w-8 h-8 flex items-center justify-center rounded-full hover:bg-gray-100 transition-colors">
            <Search size={18} className="text-gray-600" />
          </button>
          <button className="w-8 h-8 flex items-center justify-center rounded-full hover:bg-gray-100 transition-colors relative">
            <Bell size={18} className="text-gray-600" />
            <span className="absolute top-1 right-1 w-2 h-2 bg-[#FF6A00] rounded-full" />
          </button>
        </div>
      </div>
    </header>
  );
}
