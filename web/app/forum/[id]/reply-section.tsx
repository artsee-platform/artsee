'use client'

import { useState, useTransition } from 'react'
import { createReply } from '@/lib/actions'
import { Send, Loader2 } from 'lucide-react'
import { useRouter } from 'next/navigation'

export function ReplySection({ postId }: { postId: string }) {
  const [content, setContent] = useState('')
  const [error, setError] = useState('')
  const [isPending, startTransition] = useTransition()
  const router = useRouter()

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!content.trim()) return
    setError('')
    startTransition(async () => {
      const res = await createReply(postId, content.trim())
      if ('error' in res && res.error) {
        setError(res.error)
      } else {
        setContent('')
        router.refresh()
      }
    })
  }

  return (
    <form onSubmit={handleSubmit} className="mt-3">
      {error && (
        <div className="bg-red-50 text-red-600 text-xs px-3 py-2 rounded-lg mb-2">{error}</div>
      )}
      <div className="flex gap-2">
        <textarea
          value={content}
          onChange={e => setContent(e.target.value)}
          rows={2}
          placeholder="写下你的回答或想法..."
          className="flex-1 px-3 py-2 rounded-xl border border-gray-200 text-sm focus:outline-none focus:border-[#1A4B8C] transition-colors resize-none"
        />
        <button
          type="submit"
          disabled={isPending || !content.trim()}
          className="w-10 h-10 bg-[#1A4B8C] rounded-xl flex items-center justify-center flex-shrink-0 self-end disabled:opacity-50"
        >
          {isPending ? <Loader2 size={16} className="text-white animate-spin" /> : <Send size={16} className="text-white" />}
        </button>
      </div>
    </form>
  )
}
