import { stories } from "@/lib/mock-data";

export function StoryBar() {
  return (
    <div className="flex gap-3 px-4 py-3 overflow-x-auto scrollbar-hide">
      {stories.map((s) => (
        <button key={s.id} className="flex flex-col items-center gap-1 flex-shrink-0">
          {/* 头像圆圈 */}
          <div
            className={`w-14 h-14 rounded-full bg-gradient-to-br ${s.color} flex items-center justify-center ring-2 ring-[#FF6A00]/40 ring-offset-2`}
          >
            <span className="text-white text-xs font-bold">{s.initial}</span>
          </div>
          <span className="text-[10px] text-gray-600 max-w-[52px] text-center leading-tight">
            {s.name}
          </span>
        </button>
      ))}
    </div>
  );
}
