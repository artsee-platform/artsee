import type { Metadata } from "next";
import { Poppins, Noto_Sans_SC } from "next/font/google";
import "./globals.css";
import { BottomNav } from "@/components/layout/bottom-nav";
import { TopBar } from "@/components/layout/top-bar";
import { CiyanChat } from "@/components/agent/ciyan-chat";

const poppins = Poppins({
  variable: "--font-poppins",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
  display: "swap",
});

const notoSansSC = Noto_Sans_SC({
  variable: "--font-noto-sc",
  subsets: ["latin"],
  weight: ["400", "500", "700"],
  display: "swap",
});

export const metadata: Metadata = {
  title: "艺见心 — 艺术留学一站式平台",
  description: "发现、收藏和分享艺术留学资讯，找到你的理想院校",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="zh-CN" className={`${poppins.variable} ${notoSansSC.variable} h-full antialiased`}>
      <body className="min-h-full bg-neutral-100 flex items-center justify-center">
        {/* 桌面端：手机壳容器 */}
        <div className="relative w-full max-w-[390px] h-screen max-h-[844px] bg-white overflow-hidden flex flex-col shadow-2xl">
          <TopBar />
          <main className="flex-1 overflow-y-auto scrollbar-hide">
            {children}
          </main>
          <CiyanChat />
          <BottomNav />
        </div>
      </body>
    </html>
  );
}
