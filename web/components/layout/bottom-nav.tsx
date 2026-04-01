"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Home, Compass, Grid3x3, MessageSquare, User } from "lucide-react";

const tabs = [
  { href: "/",        label: "首页", icon: Home },
  { href: "/explore", label: "探索", icon: Compass },
  { href: "/cases",   label: "案例", icon: Grid3x3 },
  { href: "/forum",   label: "论坛", icon: MessageSquare },
  { href: "/profile", label: "我的", icon: User },
];

export function BottomNav() {
  const pathname = usePathname();

  return (
    <nav className="flex-shrink-0 border-t border-gray-100 bg-white">
      <div className="flex items-center justify-around h-16 px-2">
        {tabs.map(({ href, label, icon: Icon }) => {
          const active = pathname === href;
          return (
            <Link
              key={href}
              href={href}
              className="flex flex-col items-center gap-0.5 min-w-[52px] py-1"
            >
              <Icon
                size={22}
                className={active ? "text-[#1A4B8C]" : "text-gray-400"}
                strokeWidth={active ? 2.5 : 1.8}
              />
              <span
                className={`text-[10px] font-medium ${
                  active ? "text-[#1A4B8C]" : "text-gray-400"
                }`}
              >
                {label}
              </span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
