export function StatBar() {
  const stats = [
    { label: "关注", value: "86" },
    { label: "粉丝", value: "312" },
    { label: "获赞", value: "1.2k" },
    { label: "收藏", value: "47" },
  ];

  return (
    <div className="flex divide-x divide-gray-100 bg-white border-t border-gray-100">
      {stats.map((s) => (
        <button key={s.label} className="flex-1 flex flex-col items-center py-3">
          <span className="text-sm font-bold text-gray-900">{s.value}</span>
          <span className="text-[10px] text-gray-400 mt-0.5">{s.label}</span>
        </button>
      ))}
    </div>
  );
}
