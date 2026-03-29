"use client";

import { useState } from "react";
import { PostCard } from "@/components/forum/post-card";
import { posts } from "@/lib/mock-data";
import { PenSquare } from "lucide-react";

const tabs = ["问答", "讨论", "资讯"];

export default function ForumPage() {
  const [activeTab, setActiveTab] = useState("问答");

  const typeMap: Record<string, string> = {
    "问答": "question",
    "讨论": "discussion",
    "资讯": "news",
  };

  const filtered = posts.filter((p) => p.type === typeMap[activeTab]);

  return (
    <div className="pb-4">
      {/* Tab + 发布按钮 */}
      <div className="flex items-center gap-2 px-4 pt-3 pb-2 border-b border-gray-100">
        <div className="flex flex-1 bg-gray-100 rounded-xl p-0.5">
          {tabs.map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`flex-1 py-1.5 rounded-lg text-xs font-medium transition-colors ${
                activeTab === tab ? "bg-white text-gray-900 shadow-sm" : "text-gray-500"
              }`}
            >
              {tab}
            </button>
          ))}
        </div>
        <button className="w-8 h-8 bg-[#FF6A00] rounded-xl flex items-center justify-center flex-shrink-0">
          <PenSquare size={15} className="text-white" />
        </button>
      </div>

      {/* 热门 tags */}
      <div className="flex gap-2 px-4 py-2 overflow-x-auto scrollbar-hide">
        {["🔥 热门", "牛津", "CSM", "作品集", "雅思备考", "面试经验"].map((tag) => (
          <button
            key={tag}
            className="flex-shrink-0 text-[10px] px-2.5 py-1 rounded-full bg-gray-100 text-gray-600 font-medium whitespace-nowrap"
          >
            {tag}
          </button>
        ))}
      </div>

      {/* 帖子列表 */}
      {filtered.length > 0 ? (
        filtered.map((post) => <PostCard key={post.id} post={post} />)
      ) : (
        <div className="flex flex-col items-center justify-center py-16 text-gray-400">
          <span className="text-3xl mb-2">💬</span>
          <p className="text-sm">还没有内容，来发第一帖！</p>
        </div>
      )}
    </div>
  );
}
