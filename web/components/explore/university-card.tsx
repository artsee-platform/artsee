import { MapPin, Clock, BookOpen, GraduationCap, ChevronRight } from "lucide-react";
import type { University } from "@/lib/mock-data";

export function UniversityCard({ uni }: { uni: University }) {
  return (
    <article className="mx-4 mb-3 bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
      {/* 顶部彩色条 + 院校信息 */}
      <div className="flex items-center gap-3 p-3">
        {/* 院校 Logo（彩色圆圈） */}
        <div
          className={`w-12 h-12 rounded-xl bg-gradient-to-br ${uni.color} flex items-center justify-center flex-shrink-0`}
        >
          <span className="text-white text-[10px] font-bold text-center leading-tight">
            {uni.initial}
          </span>
        </div>

        {/* 院校名称 + 专业 */}
        <div className="flex-1 min-w-0">
          <h3 className="text-sm font-semibold text-gray-900 truncate">{uni.nameCn}</h3>
          <p className="text-xs text-gray-500 truncate">{uni.program}</p>
          <div className="flex items-center gap-1 mt-0.5">
            <MapPin size={10} className="text-gray-400" />
            <span className="text-[10px] text-gray-400">{uni.city}，{uni.country}</span>
          </div>
        </div>

        <ChevronRight size={16} className="text-gray-300 flex-shrink-0" />
      </div>

      {/* 关键数据条 */}
      <div className="flex items-center border-t border-gray-50 divide-x divide-gray-100">
        <div className="flex-1 flex flex-col items-center py-2">
          <div className="flex items-center gap-1">
            <GraduationCap size={11} className="text-[#FF6A00]" />
            <span className="text-[10px] font-semibold text-gray-700">{uni.gpaMin}</span>
          </div>
          <span className="text-[9px] text-gray-400 mt-0.5">GPA 要求</span>
        </div>
        <div className="flex-1 flex flex-col items-center py-2">
          <div className="flex items-center gap-1">
            <BookOpen size={11} className="text-blue-500" />
            <span className="text-[10px] font-semibold text-gray-700">{uni.ielts}</span>
          </div>
          <span className="text-[9px] text-gray-400 mt-0.5">IELTS</span>
        </div>
        <div className="flex-1 flex flex-col items-center py-2">
          <div className="flex items-center gap-1">
            <Clock size={11} className="text-green-500" />
            <span className="text-[10px] font-semibold text-gray-700">{uni.duration}</span>
          </div>
          <span className="text-[9px] text-gray-400 mt-0.5">学制</span>
        </div>
        <div className="flex-1 flex flex-col items-center py-2">
          <span className="text-[10px] font-semibold text-gray-700">
            {uni.rolling ? (
              <span className="text-green-600">滚动</span>
            ) : (
              <span className="text-orange-600">{uni.deadline.slice(5)}</span>
            )}
          </span>
          <span className="text-[9px] text-gray-400 mt-0.5">截止日期</span>
        </div>
      </div>

      {/* 底部标签 */}
      <div className="flex items-center gap-2 px-3 pb-3 pt-1">
        {uni.hasInterview && (
          <span className="text-[9px] bg-amber-50 text-amber-600 border border-amber-200 px-2 py-0.5 rounded-full">
            需要面试
          </span>
        )}
        <span className="text-[9px] bg-gray-50 text-gray-500 border border-gray-200 px-2 py-0.5 rounded-full">
          推荐信 ×{uni.recommenders}
        </span>
        <span className="text-[9px] bg-blue-50 text-blue-600 border border-blue-200 px-2 py-0.5 rounded-full">
          {uni.programEn.split(" ").slice(-1)[0]}
        </span>
      </div>
    </article>
  );
}
