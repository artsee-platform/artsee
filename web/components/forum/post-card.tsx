import { ThumbsUp, MessageCircle, Eye, BadgeCheck } from "lucide-react";
import type { Post } from "@/lib/mock-data";

const typeStyle: Record<Post["type"], { label: string; cls: string }> = {
  question:   { label: "问答", cls: "bg-blue-100 text-blue-600" },
  discussion: { label: "讨论", cls: "bg-purple-100 text-purple-600" },
  news:       { label: "资讯", cls: "bg-green-100 text-green-600" },
};

export function PostCard({ post }: { post: Post }) {
  const ts = typeStyle[post.type];
  return (
    <article className="px-4 py-3 border-b border-gray-100">
      {/* 作者行 */}
      <div className="flex items-center gap-2 mb-2">
        <div className="w-7 h-7 rounded-full bg-gray-100 flex items-center justify-center text-sm">
          {post.authorAvatar}
        </div>
        <div className="flex items-center gap-1">
          <span className="text-xs font-medium text-gray-800">{post.authorName}</span>
          {post.isMentor && (
            <BadgeCheck size={13} className="text-[#FF6A00]" />
          )}
        </div>
        <span className="text-[10px] text-gray-400 ml-auto">{post.createdAt}</span>
      </div>

      {/* 帖子内容 */}
      <div className="flex gap-2">
        <div className="flex-1">
          <div className="flex items-start gap-2 mb-1">
            <span className={`text-[9px] font-semibold px-1.5 py-0.5 rounded flex-shrink-0 mt-0.5 ${ts.cls}`}>
              {ts.label}
            </span>
            <h3 className="text-sm font-semibold text-gray-900 leading-snug line-clamp-2">
              {post.title}
            </h3>
          </div>
          <p className="text-xs text-gray-500 line-clamp-2 leading-relaxed mb-2">
            {post.content}
          </p>

          {/* 标签 */}
          <div className="flex gap-1.5 mb-2 flex-wrap">
            {post.tags.map((tag) => (
              <span key={tag} className="text-[9px] text-gray-400 bg-gray-50 border border-gray-200 px-1.5 py-0.5 rounded">
                #{tag}
              </span>
            ))}
          </div>

          {/* 互动数据 */}
          <div className="flex items-center gap-4">
            <button className="flex items-center gap-1 text-gray-400">
              <ThumbsUp size={12} />
              <span className="text-[10px]">{post.likeCount}</span>
            </button>
            <button className="flex items-center gap-1 text-gray-400">
              <MessageCircle size={12} />
              <span className="text-[10px]">{post.answerCount} 回答</span>
            </button>
            <div className="flex items-center gap-1 text-gray-300">
              <Eye size={12} />
              <span className="text-[10px]">{post.viewCount}</span>
            </div>
          </div>
        </div>
      </div>
    </article>
  );
}
