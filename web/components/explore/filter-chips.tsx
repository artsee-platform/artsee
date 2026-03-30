"use client";

import { useState } from "react";

const filters = {
  degree: ["全部", "Master", "Bachelor", "PhD"],
  major: ["全部", "Fine Art", "Design", "Architecture", "Animation", "Photography", "Illustration"],
  ielts: ["全部", "6.0+", "6.5+", "7.0+", "7.5+"],
};

interface FilterChipsProps {
  onFilter: (degree: string, major: string, ielts: string) => void;
}

export function FilterChips({ onFilter }: FilterChipsProps) {
  const [activeDegree, setActiveDegree] = useState("全部");
  const [activeMajor, setActiveMajor] = useState("全部");
  const [activeIelts, setActiveIelts] = useState("全部");

  function update(degree: string, major: string, ielts: string) {
    onFilter(degree, major, ielts);
  }

  return (
    <div className="space-y-2 px-4 py-3 border-b border-gray-100">
      <div className="flex gap-2 overflow-x-auto scrollbar-hide">
        {filters.degree.map((d) => (
          <button key={d} onClick={() => { setActiveDegree(d); update(d, activeMajor, activeIelts); }}
            className={`flex-shrink-0 px-3 py-1 rounded-full text-xs font-medium transition-colors ${
              activeDegree === d ? "bg-[#FF6A00] text-white" : "bg-gray-100 text-gray-600"
            }`}>{d}</button>
        ))}
      </div>
      <div className="flex gap-2 overflow-x-auto scrollbar-hide">
        {filters.major.map((m) => (
          <button key={m} onClick={() => { setActiveMajor(m); update(activeDegree, m, activeIelts); }}
            className={`flex-shrink-0 px-3 py-1 rounded-full text-xs font-medium transition-colors ${
              activeMajor === m
                ? "bg-[#FF6A00]/10 text-[#FF6A00] border border-[#FF6A00]/30"
                : "bg-gray-50 text-gray-500 border border-gray-200"
            }`}>{m}</button>
        ))}
      </div>
      <div className="flex gap-2 overflow-x-auto scrollbar-hide">
        {filters.ielts.map((i) => (
          <button key={i} onClick={() => { setActiveIelts(i); update(activeDegree, activeMajor, i); }}
            className={`flex-shrink-0 px-3 py-1 rounded-full text-xs font-medium transition-colors ${
              activeIelts === i ? "bg-blue-100 text-blue-700" : "bg-gray-50 text-gray-500 border border-gray-200"
            }`}>{i === "全部" ? "IELTS 全部" : `IELTS ${i}`}</button>
        ))}
      </div>
    </div>
  );
}
