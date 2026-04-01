import { createClient } from '@/lib/supabase/server'
import { getSchoolGradient, getSchoolInitial } from '@/lib/utils'
import Link from 'next/link'

export async function StoryBar() {
  const supabase = await createClient()
  const { data: schools } = await supabase
    .from('schools')
    .select('id, name_zh, name_en')
    .eq('status', 'active')
    .order('id')
    .limit(10)

  const items = schools ?? []

  return (
    <div className="flex gap-3 px-4 py-3 overflow-x-auto scrollbar-hide">
      {items.map((s) => (
        <Link key={s.id} href={`/explore?school=${encodeURIComponent(s.name_zh)}`} className="flex flex-col items-center gap-1 flex-shrink-0">
          <div
            className={`w-14 h-14 rounded-full bg-gradient-to-br ${getSchoolGradient(s.name_zh)} flex items-center justify-center ring-2 ring-[#1A4B8C]/40 ring-offset-2`}
          >
            <span className="text-white text-xs font-bold">{getSchoolInitial(s.name_zh)}</span>
          </div>
          <span className="text-[10px] text-gray-600 max-w-[52px] text-center leading-tight">
            {s.name_zh}
          </span>
        </Link>
      ))}
    </div>
  )
}
