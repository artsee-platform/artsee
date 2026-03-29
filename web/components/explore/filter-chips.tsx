"use client";

import { useState } from "react";

const filters = {
  country: ["全部", "英国", "美国", "德国", "荷兰"],
  major: ["全部", "纯艺", "建筑", "设计工程", "插画", "摄影", "雕塑"],
  ielts: ["全部", "6.0+", "6.5+", "7.0+", "7.5+"],
};

export function FilterChips() {
  const [activeCountry, setActiveCountry] = useState("英国");
  const [activeMajor, setActiveMajor] = useState("全部");

  return (
    <div className="space-y-2 px-4 py-3 border-b border-gray-100">
      {/* 国家 */}
      <div className="flex gap-2 overflow-x-auto scrollbar-hide">
        {filters.country.map((c) => (
          <button
            key={c}
            onClick={() => setActiveCountry(c)}
            className={`flex-shrink-0 px-3 py-1 rounded-full text-xs font-medium transition-colors ${
              activeCountry === c
                ? "bg-[#FF6A00] text-white"
                : "bg-gray-100 text-gray-600"
            }`}
          >
            {c}
          </button>
        ))}
      </div>
      {/* 专业 */}
      <div className="flex gap-2 overflow-x-auto scrollbar-hide">
        {filters.major.map((m) => (
          <button
            key={m}
            onClick={() => setActiveMajor(m)}
            className={`flex-shrink-0 px-3 py-1 rounded-full text-xs font-medium transition-colors ${
              activeMajor === m
                ? "bg-[#FF6A00]/10 text-[#FF6A00] border border-[#FF6A00]/30"
                : "bg-gray-50 text-gray-500 border border-gray-200"
            }`}
          >
            {m}
          </button>
        ))}
      </div>
    </div>
  );
}
