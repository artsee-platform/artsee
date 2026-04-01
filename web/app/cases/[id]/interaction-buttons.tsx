'use client'

import { useState, useTransition } from 'react'
import { Heart, Bookmark, MessageCircle } from 'lucide-react'
import { toggleLike } from '@/lib/actions'

type Props = {
  caseId: string
  initialLikeCount: number
  initialSaveCount: number
  initialCommentCount: number
  initialLiked: boolean
}

export function InteractionButtons({
  caseId,
  initialLikeCount,
  initialSaveCount,
  initialCommentCount,
  initialLiked,
}: Props) {
  const [liked, setLiked] = useState(initialLiked)
  const [likeCount, setLikeCount] = useState(initialLikeCount)
  const [isPending, startTransition] = useTransition()

  const handleLike = () => {
    if (isPending) return
    const next = !liked
    setLiked(next)
    setLikeCount(c => next ? c + 1 : Math.max(0, c - 1))
    startTransition(async () => {
      const res = await toggleLike(caseId, 'case')
      if ('error' in res) {
        // revert on error
        setLiked(!next)
        setLikeCount(c => next ? Math.max(0, c - 1) : c + 1)
      }
    })
  }

  return (
    <div className="mx-4 mt-3 flex gap-3">
      <button
        onClick={handleLike}
        className={`flex-1 flex items-center justify-center gap-2 py-2.5 border rounded-xl text-xs font-medium transition-colors ${
          liked
            ? 'border-rose-300 bg-rose-50 text-rose-500'
            : 'border-gray-200 bg-white text-gray-600'
        }`}
      >
        <Heart size={14} className={liked ? 'fill-rose-500' : ''} />
        {likeCount} 赞
      </button>
      <button className="flex-1 flex items-center justify-center gap-2 py-2.5 border border-gray-200 bg-white rounded-xl text-xs font-medium text-gray-600">
        <Bookmark size={14} />
        {initialSaveCount} 收藏
      </button>
      <button
        onClick={() => document.getElementById('comments')?.scrollIntoView({ behavior: 'smooth' })}
        className="flex-1 flex items-center justify-center gap-2 py-2.5 border border-gray-200 bg-white rounded-xl text-xs font-medium text-gray-600"
      >
        <MessageCircle size={14} />
        {initialCommentCount} 评论
      </button>
    </div>
  )
}
