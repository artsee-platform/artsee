import { createClient } from '@/lib/supabase/server'
import { notFound } from 'next/navigation'
import Link from 'next/link'
import { ArrowLeft, Calendar } from 'lucide-react'
import { resultLabel, resultColor, timeAgo } from '@/lib/utils'
import { InteractionButtons } from './interaction-buttons'

export default async function CaseDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await createClient()

  const { data: c } = await supabase
    .from('cases')
    .select('*, user_profiles(nickname, avatar_url)')
    .eq('id', id)
    .single()

  if (!c) notFound()

  const { data: { user } } = await supabase.auth.getUser()

  // Check if current user has liked this case
  let initialLiked = false
  if (user) {
    const { data: like } = await supabase
      .from('likes')
      .select('id')
      .eq('user_id', user.id)
      .eq('target_id', id)
      .eq('target_type', 'case')
      .single()
    initialLiked = !!like
  }

  const result = c.result as keyof typeof resultLabel
  const gradient = c.cover_gradient ?? 'from-blue-500 to-purple-600'

  return (
    <div className="pb-6">
      <div className={`relative bg-gradient-to-br ${gradient} px-4 pt-3 pb-8`}>
        <Link href="/cases" className="inline-flex items-center gap-1 text-white/80 text-xs mb-3">
          <ArrowLeft size={14} /> 返回案例
        </Link>
        <div className="flex items-start justify-between">
          <span className={`text-[10px] font-semibold px-2 py-1 rounded-full ${resultColor[result]}`}>
            {resultLabel[result]}
          </span>
          <span className="text-white/70 text-[10px]">{c.year ?? timeAgo(c.created_at)} 申请</span>
        </div>
        <h1 className="text-white font-bold text-base leading-snug mt-2">{c.title}</h1>
      </div>

      {/* 申请人信息卡 */}
      <div className="mx-4 -mt-4 bg-white rounded-2xl p-4 shadow-md border border-gray-100">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-full bg-gradient-to-br from-[#1A4B8C] to-[#4A90D9] flex items-center justify-center">
            <span className="text-white text-sm">🎨</span>
          </div>
          <div className="flex-1">
            <p className="text-sm font-semibold text-gray-900">
              {c.is_anonymous ? '匿名用户' : (c.user_profiles?.nickname ?? '用户')}
            </p>
            <p className="text-xs text-gray-500">{c.undergrad} · GPA {c.gpa}</p>
          </div>
        </div>
        <div className="grid grid-cols-2 gap-2 mt-3">
          <div className="bg-gray-50 rounded-xl p-2 text-center">
            <p className="text-xs font-semibold text-gray-800">{c.target_school}</p>
            <p className="text-[10px] text-gray-500 mt-0.5">目标院校</p>
          </div>
          <div className="bg-gray-50 rounded-xl p-2 text-center">
            <p className="text-xs font-semibold text-gray-800 truncate">{c.target_program}</p>
            <p className="text-[10px] text-gray-500 mt-0.5">申请专业</p>
          </div>
        </div>
      </div>

      {/* 标签 */}
      {c.tags?.length > 0 && (
        <div className="flex gap-2 px-4 mt-3 flex-wrap">
          {c.tags.map((tag: string) => (
            <span key={tag} className="text-[10px] bg-blue-50 text-[#1A4B8C] border border-blue-200 px-2 py-0.5 rounded-full">
              #{tag}
            </span>
          ))}
        </div>
      )}

      {/* 正文 */}
      <div className="mx-4 mt-3 bg-white rounded-2xl p-4 border border-gray-100">
        <h2 className="text-sm font-semibold text-gray-900 mb-3">申请心得</h2>
        <div className="text-xs text-gray-600 leading-relaxed whitespace-pre-wrap">
          {c.content ?? c.excerpt ?? '暂无详细内容'}
        </div>
      </div>

      {/* 互动 */}
      <InteractionButtons
        caseId={id}
        initialLikeCount={c.like_count}
        initialSaveCount={c.save_count}
        initialCommentCount={c.comment_count}
        initialLiked={initialLiked}
      />

      {/* 发布时间 */}
      <div className="mx-4 mt-2 flex items-center gap-1 text-[10px] text-gray-400">
        <Calendar size={10} /> 发布于 {timeAgo(c.created_at)}
      </div>
    </div>
  )
}
