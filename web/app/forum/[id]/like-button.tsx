'use client'

import { useState, useTransition } from 'react'
import { ThumbsUp } from 'lucide-react'
import { toggleLike } from '@/lib/actions'

type Props = {
  postId: string
  initialLikeCount: number
  initialLiked: boolean
}

export function LikeButton({ postId, initialLikeCount, initialLiked }: Props) {
  const [liked, setLiked] = useState(initialLiked)
  const [likeCount, setLikeCount] = useState(initialLikeCount)
  const [isPending, startTransition] = useTransition()

  const handleLike = () => {
    if (isPending) return
    const next = !liked
    setLiked(next)
    setLikeCount(c => next ? c + 1 : Math.max(0, c - 1))
    startTransition(async () => {
      const res = await toggleLike(postId, 'post')
      if ('error' in res) {
        setLiked(!next)
        setLikeCount(c => next ? Math.max(0, c - 1) : c + 1)
      }
    })
  }

  return (
    <button
      onClick={handleLike}
      className={`flex items-center gap-1 transition-colors ${
        liked ? 'text-[#1A4B8C]' : 'text-gray-400'
      }`}
    >
      <ThumbsUp size={12} className={liked ? 'fill-[#1A4B8C]' : ''} />
      <span className="text-[10px]">{likeCount}</span>
    </button>
  )
}
