'use client'

import { useState, useMemo } from 'react'
import { PostCard } from '@/components/forum/post-card'
import Link from 'next/link'
import type { Post } from '@/lib/supabase/types'
import { PenSquare } from 'lucide-react'

const tabs = ['问答', '讨论', '资讯'] as const
const hotTags = ['🔥 热门', '牛津', 'CSM', '作品集', '雅思备考', '面试经验']

const typeMap: Record<typeof tabs[number], Post['type']> = {
  '问答': 'question',
  '讨论': 'discussion',
  '资讯': 'news',
}

export function ForumClient({ posts }: { posts: Post[] }) {
  const [activeTab, setActiveTab] = useState<typeof tabs[number]>('问答')
  const [activeTag, setActiveTag] = useState('🔥 热门')

  const filtered = useMemo(() => {
    let list = posts.filter(p => p.type === typeMap[activeTab])
    if (activeTag !== '🔥 热门') {
      list = list.filter(p =>
        p.tags?.some(t => t.includes(activeTag)) ||
        p.title?.includes(activeTag) ||
        p.content?.includes(activeTag)
      )
    }
    return list
  }, [posts, activeTab, activeTag])

  return (
    <div className="pb-4">
      {/* Tab + 发布按钮 */}
      <div className="flex items-center gap-2 px-4 pt-3 pb-2 border-b border-gray-100">
        <div className="flex flex-1 bg-gray-100 rounded-xl p-0.5">
          {tabs.map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`flex-1 py-1.5 rounded-lg text-xs font-medium transition-colors ${
                activeTab === tab ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500'
              }`}
            >
              {tab}
            </button>
          ))}
        </div>
        <Link href="/forum/new" className="w-8 h-8 bg-[#FF6A00] rounded-xl flex items-center justify-center flex-shrink-0">
          <PenSquare size={15} className="text-white" />
        </Link>
      </div>

      {/* 热门 tags */}
      <div className="flex gap-2 px-4 py-2 overflow-x-auto scrollbar-hide">
        {hotTags.map((tag) => (
          <button
            key={tag}
            onClick={() => setActiveTag(tag)}
            className={`flex-shrink-0 text-[10px] px-2.5 py-1 rounded-full font-medium whitespace-nowrap transition-colors ${
              activeTag === tag ? 'bg-[#FF6A00] text-white' : 'bg-gray-100 text-gray-600'
            }`}
          >
            {tag}
          </button>
        ))}
      </div>

      {/* 帖子列表 */}
      {filtered.length > 0 ? (
        filtered.map((post) => <PostCard key={post.id} post={post} />)
      ) : (
        <div className="flex flex-col items-center justify-center py-16 text-gray-400">
          <span className="text-3xl mb-2">💬</span>
          <p className="text-sm">还没有内容，来发第一帖！</p>
        </div>
      )}
    </div>
  )
}
