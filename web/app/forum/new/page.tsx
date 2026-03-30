'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { ArrowLeft, Loader2 } from 'lucide-react'
import { createPost } from '@/lib/actions'
import Link from 'next/link'

const typeOptions = [
  { value: 'question', label: '❓ 问答', desc: '提出你的问题，获取社区解答' },
  { value: 'discussion', label: '💬 讨论', desc: '发起话题讨论，交流经验' },
  { value: 'news', label: '📰 资讯', desc: '分享行业资讯和最新消息' },
] as const

const inputCls = 'w-full px-3 py-2.5 rounded-xl border border-gray-200 text-sm focus:outline-none focus:border-[#FF6A00] transition-colors bg-white'

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="text-xs font-medium text-gray-600 mb-1.5 block">{label}</label>
      {children}
    </div>
  )
}

export default function NewPostPage() {
  const router = useRouter()
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [type, setType] = useState<'question' | 'discussion' | 'news'>('question')

  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault()
    setLoading(true)
    setError('')
    const fd = new FormData(e.currentTarget)
    fd.set('type', type)
    const res = await createPost(fd)
    if ('error' in res && res.error) {
      setError(res.error)
      setLoading(false)
    } else if ('id' in res) {
      router.push(`/forum/${res.id}`)
    }
  }

  return (
    <div className="pb-8">
      <div className="px-4 pt-3 pb-2 border-b border-gray-100 flex items-center gap-2">
        <Link href="/forum"><ArrowLeft size={18} className="text-gray-600" /></Link>
        <h1 className="text-sm font-semibold text-gray-900">发布帖子</h1>
      </div>

      <form onSubmit={handleSubmit} className="px-4 pt-4 space-y-4">
        {/* 类型选择 */}
        <Field label="帖子类型 *">
          <div className="space-y-2">
            {typeOptions.map(opt => (
              <label key={opt.value} className="flex items-center gap-3 p-3 rounded-xl border cursor-pointer transition-colors peer"
                style={{ borderColor: type === opt.value ? '#FF6A00' : '#e5e7eb', backgroundColor: type === opt.value ? '#fff7f0' : 'white' }}>
                <input type="radio" name="type" value={opt.value} className="sr-only"
                  checked={type === opt.value} onChange={() => setType(opt.value)} />
                <div className="flex-1">
                  <p className="text-xs font-semibold text-gray-800">{opt.label}</p>
                  <p className="text-[10px] text-gray-500 mt-0.5">{opt.desc}</p>
                </div>
                <div className={`w-4 h-4 rounded-full border-2 flex items-center justify-center ${type === opt.value ? 'border-[#FF6A00]' : 'border-gray-300'}`}>
                  {type === opt.value && <div className="w-2 h-2 rounded-full bg-[#FF6A00]" />}
                </div>
              </label>
            ))}
          </div>
        </Field>

        <Field label="标题 *">
          <input name="title" required placeholder={type === 'question' ? '例：牛津MFA面试是怎么准备的？' : type === 'discussion' ? '例：聊聊CSM申请的那些坑' : '例：2026 UCL截止日期更新'} className={inputCls} />
        </Field>

        <Field label="标签（逗号分隔）">
          <input name="tags" placeholder="例：牛津,面试,作品集" className={inputCls} />
        </Field>

        <Field label="内容 *">
          <textarea name="content" required rows={8}
            placeholder="详细描述你的问题或想分享的内容..."
            className={`${inputCls} resize-none`} />
        </Field>

        {error && <div className="bg-red-50 text-red-600 text-xs px-3 py-2 rounded-lg">{error}</div>}

        <button type="submit" disabled={loading}
          className="w-full py-3 bg-gradient-to-r from-[#FF6A00] to-[#FF9A3C] text-white rounded-xl font-semibold text-sm flex items-center justify-center gap-2 disabled:opacity-60">
          {loading && <Loader2 size={15} className="animate-spin" />}
          发布帖子
        </button>
      </form>
    </div>
  )
}
