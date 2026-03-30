import Link from "next/link";
import { Heart, MessageCircle, Bookmark } from "lucide-react";
import { resultLabel, resultColor } from "@/lib/utils";
import type { Case } from "@/lib/supabase/types";

export function CaseCard({ c, tall = false }: { c: Case; tall?: boolean }) {
  const gradient = c.cover_gradient ?? 'from-blue-500 to-purple-600'
  const result = c.result as keyof typeof resultLabel

  return (
    <Link href={`/cases/${c.id}`}>
      <article className="bg-white rounded-2xl overflow-hidden border border-gray-100 shadow-sm active:scale-[0.98] transition-transform">
        <div className={`w-full bg-gradient-to-br ${gradient} relative ${tall ? "h-48" : "h-36"}`}>
          <span className={`absolute top-2 right-2 text-[9px] font-semibold px-1.5 py-0.5 rounded-full ${resultColor[result]}`}>
            {resultLabel[result]}
          </span>
          <div className="absolute bottom-2 left-2 right-2">
            <span className="text-[9px] text-white font-medium bg-black/40 backdrop-blur-sm px-1.5 py-0.5 rounded-md">
              {c.target_school}
            </span>
          </div>
        </div>

        <div className="p-2">
          <p className="text-[11px] font-semibold text-gray-900 leading-snug line-clamp-2 mb-1.5">
            {c.excerpt ?? c.title}
          </p>
          <div className="flex items-center gap-1 mb-2">
            <span className="text-[9px]">🎨</span>
            <span className="text-[9px] text-gray-500 truncate">
              {c.is_anonymous ? '匿名' : (c.user_profiles?.nickname ?? '用户')} · {c.gpa}
            </span>
          </div>
          <div className="flex items-center gap-2">
            <button className="flex items-center gap-0.5 text-gray-400">
              <Heart size={11} /><span className="text-[9px]">{c.like_count}</span>
            </button>
            <button className="flex items-center gap-0.5 text-gray-400">
              <MessageCircle size={11} /><span className="text-[9px]">{c.comment_count}</span>
            </button>
            <button className="ml-auto text-gray-400"><Bookmark size={11} /></button>
          </div>
        </div>
      </article>
    </Link>
  );
}
