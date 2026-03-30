'use client'

import { useState } from 'react'
import { Heart, Loader2 } from 'lucide-react'
import { toggleFavorite } from '@/lib/actions'
import { useRouter } from 'next/navigation'

export function FavoriteButton({ programId, initialFavorited, isLoggedIn }: {
  programId: number
  initialFavorited: boolean
  isLoggedIn: boolean
}) {
  const [favorited, setFavorited] = useState(initialFavorited)
  const [loading, setLoading] = useState(false)
  const router = useRouter()

  async function handle() {
    if (!isLoggedIn) {
      router.push('/auth/login')
      return
    }
    setLoading(true)
    const res = await toggleFavorite(programId)
    if ('favorited' in res && res.favorited !== undefined) setFavorited(res.favorited)
    setLoading(false)
  }

  return (
    <button
      onClick={handle}
      disabled={loading}
      className={`flex-1 flex items-center justify-center gap-1.5 py-2.5 rounded-xl text-xs font-medium shadow-sm transition-all ${
        favorited
          ? 'bg-[#FF6A00] text-white'
          : 'border border-gray-200 bg-white text-gray-600'
      }`}
    >
      {loading ? <Loader2 size={14} className="animate-spin" /> : <Heart size={14} className={favorited ? 'fill-white' : ''} />}
      {favorited ? '已收藏' : '收藏'}
    </button>
  )
}
