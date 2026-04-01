import { createClient } from '@/lib/supabase/server'
import { notFound } from 'next/navigation'
import Link from 'next/link'
import { ArrowLeft, Eye, BadgeCheck, MessageCircle } from 'lucide-react'
import { timeAgo } from '@/lib/utils'
import { ReplySection } from './reply-section'
import { LikeButton } from './like-button'

const typeStyle: Record<string, { label: string; cls: string; bg: string }> = {
  question:   { label: '问答', cls: 'text-blue-600',   bg: 'from-blue-500 to-indigo-600' },
  discussion: { label: '讨论', cls: 'text-purple-600', bg: 'from-purple-500 to-pink-600' },
  news:       { label: '资讯', cls: 'text-green-600',  bg: 'from-green-500 to-teal-600' },
}

export default async function ForumPostPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await createClient()

  const { data: post } = await supabase
    .from('posts')
    .select('*, user_profiles(nickname, avatar_url)')
    .eq('id', id)
    .single()

  if (!post) notFound()

  const [{ data: replies }, { data: { user } }] = await Promise.all([
    supabase
      .from('post_replies')
      .select('*, user_profiles(nickname)')
      .eq('post_id', id)
      .order('created_at'),
    supabase.auth.getUser(),
  ])

  let initialLiked = false
  if (user) {
    const { data: like } = await supabase
      .from('likes')
      .select('id')
      .eq('user_id', user.id)
      .eq('target_id', id)
      .eq('target_type', 'post')
      .single()
    initialLiked = !!like
  }

  const ts = typeStyle[post.type] ?? typeStyle.discussion

  return (
    <div className="pb-8">
      {/* 顶部渐变 banner */}
      <div className={`bg-gradient-to-br ${ts.bg} px-4 pt-3 pb-6`}>
        <Link href="/forum" className="inline-flex items-center gap-1 text-white/80 text-xs mb-3">
          <ArrowLeft size={14} /> 返回论坛
        </Link>
        <span className="text-[10px] font-semibold bg-white/20 text-white px-2 py-0.5 rounded-full">
          {ts.label}
        </span>
        <h1 className="text-white font-bold text-base leading-snug mt-2">{post.title}</h1>
      </div>

      {/* 作者卡片 */}
      <div className="mx-4 -mt-4 bg-white rounded-2xl p-3 shadow-md border border-gray-100 flex items-center gap-3">
        <div className="w-9 h-9 rounded-full bg-gradient-to-br from-[#1A4B8C] to-[#4A90D9] flex items-center justify-center text-white font-bold text-sm">
          {post.user_profiles?.nickname?.[0] ?? '?'}
        </div>
        <div className="flex-1">
          <div className="flex items-center gap-1">
            <span className="text-sm font-semibold text-gray-900">
              {post.user_profiles?.nickname ?? '用户'}
            </span>
            {post.is_mentor_post && <BadgeCheck size={14} className="text-[#1A4B8C]" />}
          </div>
          <p className="text-[10px] text-gray-400">{timeAgo(post.created_at)}</p>
        </div>
        <div className="flex items-center gap-3 text-gray-400">
          <div className="flex items-center gap-1">
            <Eye size={12} /><span className="text-[10px]">{post.view_count}</span>
          </div>
          <LikeButton postId={id} initialLikeCount={post.like_count} initialLiked={initialLiked} />
        </div>
      </div>

      {/* 标签 */}
      {post.tags?.length > 0 && (
        <div className="flex gap-2 px-4 mt-3 flex-wrap">
          {post.tags.map((tag: string) => (
            <span key={tag} className="text-[10px] bg-blue-50 text-[#1A4B8C] border border-blue-200 px-2 py-0.5 rounded-full">
              #{tag}
            </span>
          ))}
        </div>
      )}

      {/* 正文 */}
      <div className="mx-4 mt-3 bg-white rounded-2xl p-4 border border-gray-100">
        <div className="text-sm text-gray-700 leading-relaxed whitespace-pre-wrap">
          {post.content ?? '暂无内容'}
        </div>
      </div>

      {/* 回复区 */}
      <div className="mx-4 mt-4">
        <h2 className="text-sm font-semibold text-gray-900 mb-3 flex items-center gap-1">
          <MessageCircle size={14} className="text-[#1A4B8C]" />
          {replies?.length ?? 0} 条回复
        </h2>
        {replies?.map(r => (
          <div key={r.id} className="bg-white rounded-xl border border-gray-100 p-3 mb-2">
            <div className="flex items-center gap-2 mb-1.5">
              <div className="w-6 h-6 rounded-full bg-gradient-to-br from-gray-400 to-gray-600 flex items-center justify-center text-white text-[10px] font-bold">
                {r.user_profiles?.nickname?.[0] ?? '?'}
              </div>
              <span className="text-xs font-medium text-gray-700">{r.user_profiles?.nickname ?? '用户'}</span>
              <span className="text-[10px] text-gray-400 ml-auto">{timeAgo(r.created_at)}</span>
            </div>
            <p className="text-xs text-gray-600 leading-relaxed">{r.content}</p>
          </div>
        ))}

        <ReplySection postId={id} />
      </div>
    </div>
  )
}
