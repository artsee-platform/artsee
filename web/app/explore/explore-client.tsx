'use client'

import { useState, useMemo } from 'react'
import { FilterChips } from '@/components/explore/filter-chips'
import { UniversityCard } from '@/components/explore/university-card'
import { Search } from 'lucide-react'
import type { Program } from '@/lib/supabase/types'

export function ExploreClient({ programs }: { programs: Program[] }) {
  const [search, setSearch] = useState('')
  const [degree, setDegree] = useState('全部')
  const [major, setMajor] = useState('全部')
  const [ielts, setIelts] = useState('全部')

  const filtered = useMemo(() => {
    return programs.filter(p => {
      if (degree !== '全部' && !p.degree_type?.toLowerCase().includes(degree.toLowerCase())) return false
      if (major !== '全部' && !p.program_name.toLowerCase().includes(major.toLowerCase())) return false
      if (ielts !== '全部') {
        const min = parseFloat(ielts)
        const req = p.program_admissions?.[0]?.ielts_overall
        if (!req || req < min) return false
      }
      if (search) {
        const q = search.toLowerCase()
        const matchSchool = p.schools?.name_zh?.toLowerCase().includes(q) || p.schools?.name_en?.toLowerCase().includes(q)
        const matchProgram = p.program_name.toLowerCase().includes(q)
        if (!matchSchool && !matchProgram) return false
      }
      return true
    })
  }, [programs, degree, major, ielts, search])

  return (
    <div className="pb-4">
      <div className="px-4 pt-3 pb-2">
        <div className="flex items-center gap-2 bg-gray-100 rounded-xl px-3 py-2.5">
          <Search size={15} className="text-gray-400 flex-shrink-0" />
          <input
            value={search}
            onChange={e => setSearch(e.target.value)}
            placeholder="搜索院校、专业..."
            className="flex-1 bg-transparent text-sm text-gray-700 placeholder-gray-400 outline-none"
          />
        </div>
      </div>

      <FilterChips onFilter={(d, m, i) => { setDegree(d); setMajor(m); setIelts(i) }} />

      <div className="flex items-center justify-between px-4 py-2">
        <span className="text-xs text-gray-500">共 {filtered.length} 个项目</span>
      </div>

      {filtered.map(p => <UniversityCard key={p.id} program={p} />)}

      {filtered.length === 0 && (
        <div className="text-center py-12 text-gray-400 text-sm">
          <p className="text-2xl mb-2">🔍</p>
          <p>没有找到匹配的专业</p>
          <p className="text-xs mt-1">试试清除筛选条件</p>
        </div>
      )}
    </div>
  )
}
