import { FilterChips } from "@/components/explore/filter-chips";
import { UniversityCard } from "@/components/explore/university-card";
import { universities } from "@/lib/mock-data";
import { Search } from "lucide-react";

export default function ExplorePage() {
  return (
    <div className="pb-4">
      {/* 搜索框 */}
      <div className="px-4 pt-3 pb-2">
        <div className="flex items-center gap-2 bg-gray-100 rounded-xl px-3 py-2.5">
          <Search size={15} className="text-gray-400 flex-shrink-0" />
          <span className="text-sm text-gray-400">搜索院校、专业、城市...</span>
        </div>
      </div>

      {/* 筛选标签 */}
      <FilterChips />

      {/* 统计 */}
      <div className="flex items-center justify-between px-4 py-2">
        <span className="text-xs text-gray-500">共 {universities.length} 所院校</span>
        <button className="text-xs text-[#FF6A00] font-medium">对比模式</button>
      </div>

      {/* 院校列表 */}
      {universities.map((uni) => (
        <UniversityCard key={uni.id} uni={uni} />
      ))}

      {/* 底部提示 */}
      <p className="text-center text-xs text-gray-400 mt-2 mb-4">
        持续收录全球艺术院校中 ·
        <button className="text-[#FF6A00] ml-1">建议补充</button>
      </p>
    </div>
  );
}
