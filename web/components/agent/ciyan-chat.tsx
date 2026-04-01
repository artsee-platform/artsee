'use client'

import { useState, useRef, useEffect } from 'react'
import { X, Send, ChevronDown } from 'lucide-react'

type Message = {
  role: 'user' | 'assistant'
  content: string
  streaming?: boolean
}

const QUICK_PROMPTS = [
  '我适合申请哪些学校？',
  '如何准备艺术留学作品集？',
  '英国艺术院校申请时间线是什么？',
  '帮我分析冲刺/匹配/保底比例',
]

export function CiyanChat() {
  const [open, setOpen] = useState(false)
  const [messages, setMessages] = useState<Message[]>([
    {
      role: 'assistant',
      content: '你好呀！我是瓷言 🎨 你的艺术留学顾问～\n\n有什么我可以帮你的吗？比如选校建议、作品集准备、或者申请时间规划～',
    },
  ])
  const [input, setInput] = useState('')
  const [loading, setLoading] = useState(false)
  const messagesEndRef = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLTextAreaElement>(null)

  useEffect(() => {
    if (open) {
      messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
    }
  }, [messages, open])

  useEffect(() => {
    if (open) {
      setTimeout(() => inputRef.current?.focus(), 300)
    }
  }, [open])

  const sendMessage = async (text: string) => {
    if (!text.trim() || loading) return

    const userMessage: Message = { role: 'user', content: text.trim() }
    const newMessages = [...messages, userMessage]
    setMessages(newMessages)
    setInput('')
    setLoading(true)

    // Add placeholder for assistant
    const assistantPlaceholder: Message = { role: 'assistant', content: '', streaming: true }
    setMessages([...newMessages, assistantPlaceholder])

    try {
      const res = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          messages: newMessages.map(m => ({ role: m.role, content: m.content })),
        }),
      })

      if (!res.ok) throw new Error('API error')

      const reader = res.body?.getReader()
      const decoder = new TextDecoder()
      let assistantText = ''

      if (reader) {
        while (true) {
          const { done, value } = await reader.read()
          if (done) break

          const chunk = decoder.decode(value, { stream: true })
          const lines = chunk.split('\n')

          for (const line of lines) {
            if (line.startsWith('data: ')) {
              const data = line.slice(6)
              if (data === '[DONE]') break
              try {
                const parsed = JSON.parse(data)
                if (parsed.text) {
                  assistantText += parsed.text
                  setMessages(prev => {
                    const updated = [...prev]
                    updated[updated.length - 1] = {
                      role: 'assistant',
                      content: assistantText,
                      streaming: true,
                    }
                    return updated
                  })
                }
              } catch {
                // ignore parse errors
              }
            }
          }
        }
      }

      // Finalize message (remove streaming flag)
      setMessages(prev => {
        const updated = [...prev]
        updated[updated.length - 1] = { role: 'assistant', content: assistantText }
        return updated
      })
    } catch {
      setMessages(prev => {
        const updated = [...prev]
        updated[updated.length - 1] = {
          role: 'assistant',
          content: '抱歉，我好像出了点问题 😅 请稍后再试～',
        }
        return updated
      })
    } finally {
      setLoading(false)
    }
  }

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      sendMessage(input)
    }
  }

  return (
    <>
      {/* Floating Button */}
      <button
        onClick={() => setOpen(true)}
        className={`absolute bottom-20 right-4 w-12 h-12 rounded-full shadow-lg flex items-center justify-center text-white font-bold text-lg transition-all z-30 ${
          open ? 'scale-0 opacity-0' : 'scale-100 opacity-100'
        }`}
        style={{
          background: 'linear-gradient(135deg, #1A4B8C 0%, #4A90D9 50%, #1A4B8C 100%)',
          backgroundSize: '200% 200%',
        }}
        aria-label="打开瓷言AI助手"
      >
        <span className="font-serif">瓷</span>
      </button>

      {/* Chat Panel */}
      <div
        className={`absolute inset-x-0 bottom-0 z-40 flex flex-col rounded-t-2xl bg-white shadow-2xl transition-transform duration-300 ease-out ${
          open ? 'translate-y-0' : 'translate-y-full'
        }`}
        style={{ height: '72vh' }}
      >
        {/* Header */}
        <div
          className="flex items-center justify-between px-4 py-3 rounded-t-2xl flex-shrink-0"
          style={{ background: 'linear-gradient(135deg, #1A4B8C, #4A90D9)' }}
        >
          <div className="flex items-center gap-2">
            {/* Avatar */}
            <div className="w-8 h-8 rounded-full bg-white/20 flex items-center justify-center border border-white/30">
              <span className="text-white font-serif text-sm">瓷</span>
            </div>
            <div>
              <p className="text-white font-semibold text-sm">瓷言</p>
              <p className="text-white/70 text-[10px]">艺术留学 AI 顾问</p>
            </div>
          </div>
          <button
            onClick={() => setOpen(false)}
            className="w-7 h-7 rounded-full bg-white/20 flex items-center justify-center hover:bg-white/30 transition-colors"
          >
            <ChevronDown size={16} className="text-white" />
          </button>
        </div>

        {/* Messages */}
        <div className="flex-1 overflow-y-auto px-4 py-3 space-y-3 scrollbar-hide">
          {messages.map((msg, i) => (
            <div key={i} className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'} gap-2`}>
              {msg.role === 'assistant' && (
                <div className="w-7 h-7 rounded-full flex-shrink-0 flex items-center justify-center mt-0.5"
                  style={{ background: 'linear-gradient(135deg, #1A4B8C, #4A90D9)' }}>
                  <span className="text-white font-serif text-xs">瓷</span>
                </div>
              )}
              <div
                className={`max-w-[78%] px-3 py-2 rounded-2xl text-sm leading-relaxed whitespace-pre-wrap ${
                  msg.role === 'user'
                    ? 'bg-[#1A4B8C] text-white rounded-tr-sm'
                    : 'bg-gray-100 text-gray-800 rounded-tl-sm'
                }`}
              >
                {msg.content}
                {msg.streaming && (
                  <span className="inline-block w-1.5 h-4 bg-[#1A4B8C] ml-0.5 animate-pulse rounded-sm align-middle" />
                )}
              </div>
            </div>
          ))}
          <div ref={messagesEndRef} />
        </div>

        {/* Quick Prompts (only when no conversation beyond greeting) */}
        {messages.length <= 1 && (
          <div className="px-4 pb-2 flex gap-2 overflow-x-auto scrollbar-hide flex-shrink-0">
            {QUICK_PROMPTS.map(prompt => (
              <button
                key={prompt}
                onClick={() => sendMessage(prompt)}
                className="flex-shrink-0 text-[11px] px-3 py-1.5 rounded-full border border-[#1A4B8C]/30 text-[#1A4B8C] bg-blue-50 hover:bg-blue-100 transition-colors whitespace-nowrap"
              >
                {prompt}
              </button>
            ))}
          </div>
        )}

        {/* Input */}
        <div className="flex items-end gap-2 px-4 py-3 border-t border-gray-100 flex-shrink-0">
          <textarea
            ref={inputRef}
            value={input}
            onChange={e => setInput(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="问我任何艺术留学的问题～"
            rows={1}
            className="flex-1 resize-none rounded-xl border border-gray-200 px-3 py-2 text-sm outline-none focus:border-[#1A4B8C] transition-colors max-h-24 scrollbar-hide"
            style={{ minHeight: '38px' }}
          />
          <button
            onClick={() => sendMessage(input)}
            disabled={!input.trim() || loading}
            className="w-9 h-9 rounded-xl flex items-center justify-center transition-all flex-shrink-0"
            style={{
              background: input.trim() && !loading
                ? 'linear-gradient(135deg, #1A4B8C, #4A90D9)'
                : '#e5e7eb',
            }}
          >
            <Send size={15} className={input.trim() && !loading ? 'text-white' : 'text-gray-400'} />
          </button>
        </div>
      </div>

      {/* Backdrop */}
      {open && (
        <div
          className="absolute inset-0 bg-black/20 z-30"
          onClick={() => setOpen(false)}
          style={{ bottom: '72vh' }}
        />
      )}
    </>
  )
}
