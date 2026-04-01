import { StoryBar } from '@/components/home/story-bar'
import { createClient } from '@/lib/supabase/server'
import Link from 'next/link'
import { Heart, MessageCircle, Bookmark } from 'lucide-react'
import { timeAgo, getSchoolGradient } from '@/lib/utils'
import type { Case } from '@/lib/supabase/types'
import type { Post } from '@/lib/supabase/types'

type FeedItem =
  | { kind: 'case'; data: Case }
  | { kind: 'post'; data: Post }

export default async function HomePage() {
  const supabase = await createClient()

  const [{ data: cases }, { data: posts }] = await Promise.all([
    supabase
      .from('cases')
      .select('*, user_profiles(nickname)')
      .eq('status', 'published')
      .order('created_at', { ascending: false })
      .limit(5),
    supabase
      .from('posts')
      .select('*, user_profiles(nickname)')
      .eq('status', 'published')
      .order('created_at', { ascending: false })
      .limit(5),
  ])

  // Interleave cases and posts for a mixed feed
  const feed: FeedItem[] = []
  const cList = cases ?? []
  const pList = posts ?? []
  const maxLen = Math.max(cList.length, pList.length)
  for (let i = 0; i < maxLen; i++) {
    if (i < cList.length) feed.push({ kind: 'case', data: cList[i] })
    if (i < pList.length) feed.push({ kind: 'post', data: pList[i] })
  }

  return (
    <div className="pb-4">
      {/* 精选推荐 banner */}
      <div className="mx-4 mt-3 mb-1 rounded-2xl overflow-hidden bg-gradient-to-r from-[#1A4B8C] to-[#4A90D9] p-4 text-white">
        <p className="text-[10px] font-medium opacity-80 mb-0.5">🎉 今日精选</p>
        <h2 className="text-sm font-bold leading-snug">
          2026秋季英国艺术留学
          <br />
          申请季正式开启
        </h2>
        <p className="text-[10px] opacity-80 mt-1">牛津 · 剑桥 · UCL · CSM 同步更新 →</p>
      </div>

      {/* Story 院校条 */}
      <StoryBar />

      {/* 分区标题 */}
      <div className="flex items-center justify-between px-4 mb-2">
        <h2 className="text-sm font-semibold text-gray-900">发现 · 精选</h2>
        <Link href="/cases" className="text-xs text-[#1A4B8C] font-medium">查看全部</Link>
      </div>

      {/* 混合信息流 */}
      {feed.map((item, idx) =>
        item.kind === 'case' ? (
          <CaseFeedCard key={`case-${item.data.id}`} c={item.data} />
        ) : (
          <PostFeedCard key={`post-${item.data.id}`} p={item.data} />
        )
      )}

      {feed.length === 0 && (
        <div className="flex flex-col items-center py-16 text-gray-400">
          <span className="text-3xl mb-2">🎨</span>
          <p className="text-sm">内容加载中...</p>
        </div>
      )}
    </div>
  )
}

function CaseFeedCard({ c }: { c: Case }) {
  const gradient = c.cover_gradient ?? getSchoolGradient(c.target_school ?? '')
  return (
    <Link href={`/cases/${c.id}`}>
      <article className="mx-4 mb-4 rounded-2xl overflow-hidden bg-white shadow-sm border border-gray-100">
        <div className={`h-44 bg-gradient-to-br ${gradient} relative`}>
          <span className="absolute top-3 left-3 text-[10px] font-semibold px-2 py-0.5 rounded-full bg-[#1A4B8C] text-white">
            案例
          </span>
          {c.target_school && (
            <span className="absolute bottom-3 left-3 text-[10px] font-medium bg-black/40 text-white px-2 py-0.5 rounded-full backdrop-blur-sm">
              {c.target_school}
            </span>
          )}
        </div>
        <div className="p-3">
          <h3 className="text-sm font-semibold text-gray-900 leading-snug line-clamp-2 mb-1">
            {c.title}
          </h3>
          <p className="text-xs text-gray-500 leading-relaxed line-clamp-2 mb-3">
            {c.excerpt ?? c.content ?? ''}
          </p>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="w-6 h-6 rounded-full bg-gradient-to-br from-[#1A4B8C] to-[#4A90D9] flex items-center justify-center text-white text-[9px] font-bold">
                {c.is_anonymous ? '匿' : (c.user_profiles?.nickname?.[0] ?? '?')}
              </div>
              <span className="text-xs text-gray-500">{c.is_anonymous ? '匿名' : (c.user_profiles?.nickname ?? '用户')}</span>
              <span className="text-xs text-gray-300">·</span>
              <span className="text-xs text-gray-400">{timeAgo(c.created_at)}</span>
            </div>
            <div className="flex items-center gap-3">
              <div className="flex items-center gap-1 text-gray-400">
                <Heart size={14} /><span className="text-[11px]">{c.like_count}</span>
              </div>
              <div className="flex items-center gap-1 text-gray-400">
                <MessageCircle size={14} /><span className="text-[11px]">{c.comment_count}</span>
              </div>
              <Bookmark size={14} className="text-gray-400" />
            </div>
          </div>
        </div>
      </article>
    </Link>
  )
}

function PostFeedCard({ p }: { p: Post }) {
  const typeColor = { question: 'bg-blue-500', discussion: 'bg-purple-500', news: 'bg-green-500' }
  const typeLabel = { question: '问答', discussion: '讨论', news: '资讯' }
  const bg = { question: 'from-blue-400 to-indigo-500', discussion: 'from-purple-400 to-pink-500', news: 'from-green-400 to-teal-500' }
  return (
    <Link href={`/forum/${p.id}`}>
      <article className="mx-4 mb-4 rounded-2xl overflow-hidden bg-white shadow-sm border border-gray-100">
        <div className={`h-24 bg-gradient-to-br ${bg[p.type]} relative flex items-center px-4`}>
          <span className={`absolute top-3 left-3 text-[10px] font-semibold px-2 py-0.5 rounded-full ${typeColor[p.type]} text-white`}>
            {typeLabel[p.type]}
          </span>
          <h3 className="text-white font-bold text-sm leading-snug mt-4 line-clamp-2">{p.title}</h3>
        </div>
        <div className="p-3">
          <p className="text-xs text-gray-500 leading-relaxed line-clamp-2 mb-3">{p.content}</p>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="w-6 h-6 rounded-full bg-gray-200 flex items-center justify-center text-xs font-bold text-gray-600">
                {p.user_profiles?.nickname?.[0] ?? '?'}
              </div>
              <span className="text-xs text-gray-500">{p.user_profiles?.nickname ?? '用户'}</span>
              <span className="text-xs text-gray-300">·</span>
              <span className="text-xs text-gray-400">{timeAgo(p.created_at)}</span>
            </div>
            <div className="flex items-center gap-3">
              <div className="flex items-center gap-1 text-gray-400">
                <Heart size={14} /><span className="text-[11px]">{p.like_count}</span>
              </div>
              <div className="flex items-center gap-1 text-gray-400">
                <MessageCircle size={14} /><span className="text-[11px]">{p.answer_count}</span>
              </div>
            </div>
          </div>
        </div>
      </article>
    </Link>
  )
}
