"use client";

import { useState } from "react";
import { StatBar } from "@/components/profile/stat-bar";
import { TrackerCard } from "@/components/profile/tracker-card";
import { myTrackers } from "@/lib/mock-data";
import { Settings, BookOpen, Heart, FileText, Plus } from "lucide-react";

const profileTabs = ["申请追踪", "我的案例", "我的收藏"];

export default function ProfilePage() {
  const [activeTab, setActiveTab] = useState("申请追踪");

  return (
    <div className="pb-4">
      {/* 个人信息头部 */}
      <div className="relative">
        {/* 渐变背景 */}
        <div className="h-28 bg-gradient-to-br from-[#FF6A00] via-[#FF8C00] to-[#FFB347]" />

        {/* 设置按钮 */}
        <button className="absolute top-3 right-3 w-8 h-8 bg-white/20 backdrop-blur-sm rounded-full flex items-center justify-center">
          <Settings size={15} className="text-white" />
        </button>

        {/* 头像 */}
        <div className="absolute left-4 bottom-0 translate-y-1/2">
          <div className="w-16 h-16 rounded-full bg-white border-2 border-white shadow-md flex items-center justify-center text-2xl">
            🎨
          </div>
        </div>
      </div>

      {/* 用户名 & 简介 */}
      <div className="pt-10 px-4 pb-3">
        <div className="flex items-end justify-between">
          <div>
            <h2 className="text-base font-bold text-gray-900">小艺同学</h2>
            <p className="text-[11px] text-gray-500 mt-0.5">芝加哥大学 视觉艺术 | GPA 3.8</p>
            <p className="text-[11px] text-gray-400 mt-0.5">目标：英国 G5 纯艺硕士 · 2026 Fall</p>
          </div>
          <button className="text-xs border border-[#FF6A00] text-[#FF6A00] px-3 py-1 rounded-full font-medium">
            编辑资料
          </button>
        </div>
      </div>

      {/* 统计条 */}
      <StatBar />

      {/* 快捷工具 */}
      <div className="grid grid-cols-4 gap-2 px-4 py-3 border-b border-gray-100">
        {[
          { icon: BookOpen, label: "选校清单", color: "bg-blue-50 text-blue-500" },
          { icon: Heart, label: "我的收藏", color: "bg-rose-50 text-rose-500" },
          { icon: FileText, label: "文书草稿", color: "bg-purple-50 text-purple-500" },
          { icon: Plus, label: "预约导师", color: "bg-orange-50 text-[#FF6A00]" },
        ].map(({ icon: Icon, label, color }) => (
          <button key={label} className="flex flex-col items-center gap-1">
            <div className={`w-10 h-10 rounded-xl ${color} flex items-center justify-center`}>
              <Icon size={18} />
            </div>
            <span className="text-[9px] text-gray-500 text-center leading-tight">{label}</span>
          </button>
        ))}
      </div>

      {/* Tab 切换 */}
      <div className="flex border-b border-gray-100">
        {profileTabs.map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`flex-1 py-2.5 text-xs font-medium border-b-2 transition-colors ${
              activeTab === tab
                ? "border-[#FF6A00] text-[#FF6A00]"
                : "border-transparent text-gray-400"
            }`}
          >
            {tab}
          </button>
        ))}
      </div>

      {/* 内容区 */}
      <div className="px-4 pt-3">
        {activeTab === "申请追踪" && (
          <>
            <div className="flex items-center justify-between mb-3">
              <p className="text-xs text-gray-500">共 {myTrackers.length} 所学校</p>
              <button className="flex items-center gap-1 text-xs text-[#FF6A00] font-medium">
                <Plus size={12} />
                添加学校
              </button>
            </div>
            {myTrackers.map((t) => (
              <TrackerCard key={t.id} tracker={t} />
            ))}
          </>
        )}

        {activeTab === "我的案例" && (
          <div className="flex flex-col items-center justify-center py-12 text-gray-400">
            <span className="text-3xl mb-2">📝</span>
            <p className="text-sm mb-3">还没有分享过案例</p>
            <button className="bg-[#FF6A00] text-white text-xs px-4 py-2 rounded-full font-medium">
              分享我的申请经历
            </button>
          </div>
        )}

        {activeTab === "我的收藏" && (
          <div className="flex flex-col items-center justify-center py-12 text-gray-400">
            <span className="text-3xl mb-2">🔖</span>
            <p className="text-sm">还没有收藏内容</p>
          </div>
        )}
      </div>
    </div>
  );
}
