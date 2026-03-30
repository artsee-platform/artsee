import { CaseCard } from "./case-card";
import type { Case } from "@/lib/supabase/types";

export function WaterfallGrid({ items }: { items: Case[] }) {
  const leftCol = items.filter((_, i) => i % 2 === 0);
  const rightCol = items.filter((_, i) => i % 2 === 1);

  return (
    <div className="flex gap-3 px-4">
      <div className="flex-1 flex flex-col gap-3">
        {leftCol.map((c, i) => <CaseCard key={c.id} c={c} tall={i % 3 === 0} />)}
      </div>
      <div className="flex-1 flex flex-col gap-3 mt-6">
        {rightCol.map((c, i) => <CaseCard key={c.id} c={c} tall={i % 3 === 1} />)}
      </div>
    </div>
  );
}
