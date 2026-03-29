import { StoryBar } from "@/components/home/story-bar";
import { FeedCard } from "@/components/home/feed-card";
import { feedItems } from "@/lib/mock-data";

export default function HomePage() {
  return (
    <div className="pb-4">
      {/* 精选推荐 banner */}
      <div className="mx-4 mt-3 mb-1 rounded-2xl overflow-hidden bg-gradient-to-r from-[#FF6A00] to-[#FF9A3C] p-4 text-white">
        <p className="text-[10px] font-medium opacity-80 mb-0.5">🎉 今日精选</p>
        <h2 className="text-sm font-bold leading-snug">
          2026秋季英国艺术留学
          <br />
          申请季正式开启
        </h2>
        <p className="text-[10px] opacity-80 mt-1">牛津 · 剑桥 · UCL · CSM 同步更新 →</p>
      </div>

      {/* Story 院校条 */}
      <StoryBar />

      {/* 分区标题 */}
      <div className="flex items-center justify-between px-4 mb-2">
        <h2 className="text-sm font-semibold text-gray-900">发现 · 精选</h2>
        <button className="text-xs text-[#FF6A00] font-medium">查看全部</button>
      </div>

      {/* 信息流 */}
      {feedItems.map((item) => (
        <FeedCard key={item.id} item={item} />
      ))}
    </div>
  );
}
