"use client";

import { useState } from "react";
import { WaterfallGrid } from "@/components/cases/waterfall-grid";
import { cases } from "@/lib/mock-data";

const tabs = ["全部案例", "录取", "等候", "灵感库"];

export default function CasesPage() {
  const [activeTab, setActiveTab] = useState("全部案例");

  const filtered =
    activeTab === "录取"
      ? cases.filter((c) => c.result === "admitted")
      : activeTab === "等候"
      ? cases.filter((c) => c.result === "waitlisted")
      : cases;

  return (
    <div className="pb-4">
      {/* Tab 切换 */}
      <div className="flex gap-1 px-4 pt-3 pb-2 border-b border-gray-100">
        {tabs.map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`flex-1 py-1.5 rounded-lg text-xs font-medium transition-colors ${
              activeTab === tab
                ? "bg-[#FF6A00] text-white"
                : "text-gray-500 hover:bg-gray-50"
            }`}
          >
            {tab}
          </button>
        ))}
      </div>

      {/* 筛选标签 */}
      <div className="flex gap-2 px-4 py-2 overflow-x-auto scrollbar-hide">
        {["全部", "纯艺", "建筑", "设计", "插画", "摄影"].map((tag) => (
          <button
            key={tag}
            className="flex-shrink-0 text-[10px] px-2.5 py-1 rounded-full bg-gray-100 text-gray-500 font-medium"
          >
            {tag}
          </button>
        ))}
      </div>

      {/* 发布按钮 */}
      <div className="flex items-center justify-between px-4 mb-3">
        <span className="text-xs text-gray-500">{filtered.length} 条案例</span>
        <button className="flex items-center gap-1 bg-[#FF6A00] text-white text-xs font-medium px-3 py-1.5 rounded-full">
          <span>+</span>
          <span>分享案例</span>
        </button>
      </div>

      {/* 瀑布流 */}
      <WaterfallGrid items={filtered} />
    </div>
  );
}
