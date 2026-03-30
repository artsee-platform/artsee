'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { ArrowLeft, Loader2 } from 'lucide-react'
import { createCase } from '@/lib/actions'
import Link from 'next/link'

const schools = ['牛津大学','剑桥大学','帝国理工+RCA','UCL','爱丁堡大学','中央圣马丁','坎伯韦尔艺术学院','皇家艺术学院','其他']
const programs = ['MFA Fine Art','MA Fine Art','MPhil Architecture','Innovation Design Engineering','Fine Art MFA','Contemporary Art Practice MA','其他']

export default function NewCasePage() {
  const router = useRouter()
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault()
    setLoading(true)
    setError('')
    const fd = new FormData(e.currentTarget)
    const res = await createCase(fd)
    if ('error' in res && res.error) {
      setError(res.error)
      setLoading(false)
    } else if ('id' in res) {
      router.push(`/cases/${res.id}`)
    }
  }

  return (
    <div className="pb-8">
      <div className="px-4 pt-3 pb-2 border-b border-gray-100 flex items-center gap-2">
        <Link href="/cases"><ArrowLeft size={18} className="text-gray-600" /></Link>
        <h1 className="text-sm font-semibold text-gray-900">分享申请案例</h1>
      </div>

      <form onSubmit={handleSubmit} className="px-4 pt-4 space-y-4">
        <Field label="案例标题 *">
          <input name="title" required placeholder="例：牛津MFA录取经历分享" className={inputCls} />
        </Field>

        <div className="grid grid-cols-2 gap-3">
          <Field label="本科院校">
            <input name="undergrad" placeholder="例：中央美术学院" className={inputCls} />
          </Field>
          <Field label="GPA">
            <input name="gpa" placeholder="例：3.8/4.0" className={inputCls} />
          </Field>
        </div>

        <Field label="目标院校 *">
          <select name="target_school" required className={inputCls}>
            <option value="">请选择</option>
            {schools.map(s => <option key={s} value={s}>{s}</option>)}
          </select>
        </Field>

        <Field label="申请专业 *">
          <select name="target_program" required className={inputCls}>
            <option value="">请选择</option>
            {programs.map(p => <option key={p} value={p}>{p}</option>)}
          </select>
        </Field>

        <Field label="申请结果 *">
          <div className="flex gap-2">
            {(['admitted','waitlisted','rejected'] as const).map(r => (
              <label key={r} className="flex-1">
                <input type="radio" name="result" value={r} className="sr-only peer" defaultChecked={r==='admitted'} />
                <div className={`text-center py-2 rounded-xl border text-xs font-medium cursor-pointer peer-checked:border-[#FF6A00] peer-checked:bg-orange-50 peer-checked:text-[#FF6A00] border-gray-200 text-gray-500`}>
                  {r === 'admitted' ? '🎉 录取' : r === 'waitlisted' ? '⏳ 等候' : '❌ 拒绝'}
                </div>
              </label>
            ))}
          </div>
        </Field>

        <div className="grid grid-cols-2 gap-3">
          <Field label="申请年份">
            <input name="year" placeholder="例：2025" className={inputCls} />
          </Field>
          <Field label="标签（逗号分隔）">
            <input name="tags" placeholder="例：纯艺,作品集" className={inputCls} />
          </Field>
        </div>

        <Field label="一句话摘要">
          <input name="excerpt" placeholder="在列表页展示的简短描述" className={inputCls} />
        </Field>

        <Field label="申请心得 *">
          <textarea name="content" required rows={8} placeholder="分享你的备考经历、作品集准备、面试经验..." className={`${inputCls} resize-none`} />
        </Field>

        <label className="flex items-center gap-2 text-xs text-gray-600">
          <input type="checkbox" name="is_anonymous" className="rounded" />
          匿名发布（隐藏用户名）
        </label>

        {error && <div className="bg-red-50 text-red-600 text-xs px-3 py-2 rounded-lg">{error}</div>}

        <button type="submit" disabled={loading}
          className="w-full py-3 bg-gradient-to-r from-[#FF6A00] to-[#FF9A3C] text-white rounded-xl font-semibold text-sm flex items-center justify-center gap-2 disabled:opacity-60">
          {loading && <Loader2 size={15} className="animate-spin" />}
          发布案例
        </button>
      </form>
    </div>
  )
}

const inputCls = 'w-full px-3 py-2.5 rounded-xl border border-gray-200 text-sm focus:outline-none focus:border-[#FF6A00] transition-colors bg-white'

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="text-xs font-medium text-gray-600 mb-1.5 block">{label}</label>
      {children}
    </div>
  )
}
