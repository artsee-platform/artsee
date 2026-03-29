import { Heart, MessageCircle, Bookmark } from "lucide-react";
import type { FeedItem } from "@/lib/mock-data";

export function FeedCard({ item }: { item: FeedItem }) {
  const typeLabel = {
    case: "案例",
    news: "资讯",
    topic: "话题",
  }[item.type];

  const typeBg = {
    case: "bg-[#FF6A00] text-white",
    news: "bg-gray-700 text-white",
    topic: "bg-purple-500 text-white",
  }[item.type];

  return (
    <article className="mx-4 mb-4 rounded-2xl overflow-hidden bg-white shadow-sm border border-gray-100">
      {/* 封面图（渐变色代替图片） */}
      <div className={`h-44 bg-gradient-to-br ${item.coverGradient} relative`}>
        {/* 类型 badge */}
        <span className={`absolute top-3 left-3 text-[10px] font-semibold px-2 py-0.5 rounded-full ${typeBg}`}>
          {typeLabel}
        </span>
        {/* 学校 tag */}
        {item.schoolTag && (
          <span className="absolute bottom-3 left-3 text-[10px] font-medium bg-black/40 text-white px-2 py-0.5 rounded-full backdrop-blur-sm">
            {item.schoolTag}
          </span>
        )}
      </div>

      {/* 内容区 */}
      <div className="p-3">
        <h3 className="text-sm font-semibold text-gray-900 leading-snug line-clamp-2 mb-1">
          {item.title}
        </h3>
        <p className="text-xs text-gray-500 leading-relaxed line-clamp-2 mb-3">
          {item.excerpt}
        </p>

        {/* 作者 + 互动 */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-6 h-6 rounded-full bg-gray-100 flex items-center justify-center text-xs">
              {item.authorAvatar}
            </div>
            <span className="text-xs text-gray-500">{item.authorName}</span>
            <span className="text-xs text-gray-300">·</span>
            <span className="text-xs text-gray-400">{item.createdAt}</span>
          </div>

          <div className="flex items-center gap-3">
            <button className="flex items-center gap-1 text-gray-400">
              <Heart size={14} />
              <span className="text-[11px]">{item.likeCount}</span>
            </button>
            <button className="flex items-center gap-1 text-gray-400">
              <MessageCircle size={14} />
              <span className="text-[11px]">{item.commentCount}</span>
            </button>
            <button className="text-gray-400">
              <Bookmark size={14} />
            </button>
          </div>
        </div>
      </div>
    </article>
  );
}
