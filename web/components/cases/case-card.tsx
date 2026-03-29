import { Heart, MessageCircle, Bookmark } from "lucide-react";
import type { Case } from "@/lib/mock-data";
import { resultLabel, resultColor } from "@/lib/mock-data";

export function CaseCard({ c, tall = false }: { c: Case; tall?: boolean }) {
  return (
    <article className="bg-white rounded-2xl overflow-hidden border border-gray-100 shadow-sm">
      {/* 封面 */}
      <div
        className={`w-full bg-gradient-to-br ${c.coverGradient} relative ${
          tall ? "h-48" : "h-36"
        }`}
      >
        {/* 结果 badge */}
        <span
          className={`absolute top-2 right-2 text-[9px] font-semibold px-1.5 py-0.5 rounded-full ${resultColor[c.result]}`}
        >
          {resultLabel[c.result]}
        </span>
        {/* 学校 badge */}
        <div className="absolute bottom-2 left-2 right-2">
          <span className="text-[9px] text-white font-medium bg-black/40 backdrop-blur-sm px-1.5 py-0.5 rounded-md">
            {c.targetSchool}
          </span>
        </div>
      </div>

      {/* 内容 */}
      <div className="p-2">
        <p className="text-[11px] font-semibold text-gray-900 leading-snug line-clamp-2 mb-1.5">
          {c.excerpt}
        </p>

        {/* 申请人信息 */}
        <div className="flex items-center gap-1 mb-2">
          <span className="text-[9px]">{c.authorAvatar}</span>
          <span className="text-[9px] text-gray-500 truncate">{c.undergrad} · {c.gpa}</span>
        </div>

        {/* 互动 */}
        <div className="flex items-center gap-2">
          <button className="flex items-center gap-0.5 text-gray-400">
            <Heart size={11} />
            <span className="text-[9px]">{c.likeCount}</span>
          </button>
          <button className="flex items-center gap-0.5 text-gray-400">
            <MessageCircle size={11} />
            <span className="text-[9px]">{c.commentCount}</span>
          </button>
          <button className="ml-auto text-gray-400">
            <Bookmark size={11} />
          </button>
        </div>
      </div>
    </article>
  );
}
