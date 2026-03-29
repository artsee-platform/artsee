import { CaseCard } from "./case-card";
import type { Case } from "@/lib/mock-data";

export function WaterfallGrid({ items }: { items: Case[] }) {
  // 分两列：奇数列、偶数列
  const leftCol = items.filter((_, i) => i % 2 === 0);
  const rightCol = items.filter((_, i) => i % 2 === 1);

  return (
    <div className="flex gap-3 px-4">
      {/* 左列 */}
      <div className="flex-1 flex flex-col gap-3">
        {leftCol.map((c, i) => (
          <CaseCard key={c.id} c={c} tall={i % 3 === 0} />
        ))}
      </div>
      {/* 右列 */}
      <div className="flex-1 flex flex-col gap-3 mt-6">
        {rightCol.map((c, i) => (
          <CaseCard key={c.id} c={c} tall={i % 3 === 1} />
        ))}
      </div>
    </div>
  );
}
