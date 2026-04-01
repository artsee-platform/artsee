'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter, useSearchParams } from 'next/navigation'
import { Eye, EyeOff, Loader2 } from 'lucide-react'

export default function LoginPage() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const redirect = searchParams.get('redirect') ?? '/'

  const [mode, setMode] = useState<'login' | 'register'>('login')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [nickname, setNickname] = useState('')
  const [showPwd, setShowPwd] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  const supabase = createClient()

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    setSuccess('')
    setLoading(true)

    try {
      if (mode === 'login') {
        const { error } = await supabase.auth.signInWithPassword({ email, password })
        if (error) throw error
        router.push(redirect)
        router.refresh()
      } else {
        const { data, error } = await supabase.auth.signUp({
          email, password,
          options: { data: { nickname } }
        })
        if (error) throw error
        if (data.user) {
          // 写入 user_profiles
          await supabase.from('user_profiles').upsert({
            id: data.user.id,
            nickname: nickname || email.split('@')[0],
            user_type: 'student',
            role: 'user',
          })
          setSuccess('注册成功！请检查邮箱完成验证，然后登录。')
          setMode('login')
        }
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : '操作失败'
      if (msg.includes('Invalid login credentials')) setError('邮箱或密码错误')
      else if (msg.includes('User already registered')) setError('该邮箱已注册，请直接登录')
      else setError(msg)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-white to-indigo-50 flex items-center justify-center p-4">
      <div className="w-full max-w-sm">
        {/* Logo */}
        <div className="flex flex-col items-center mb-8">
          <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-[#1A4B8C] to-[#4A90D9] flex items-center justify-center mb-3 shadow-lg">
            <span className="text-white text-2xl font-bold">艺</span>
          </div>
          <h1 className="text-2xl font-bold text-gray-900">艺见心</h1>
          <p className="text-sm text-gray-500 mt-1">艺术留学一站式平台</p>
        </div>

        {/* 卡片 */}
        <div className="bg-white rounded-3xl shadow-xl p-6">
          {/* Tab */}
          <div className="flex bg-gray-100 rounded-xl p-1 mb-6">
            {(['login', 'register'] as const).map(m => (
              <button
                key={m}
                onClick={() => { setMode(m); setError(''); setSuccess('') }}
                className={`flex-1 py-2 rounded-lg text-sm font-medium transition-all ${
                  mode === m ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500'
                }`}
              >
                {m === 'login' ? '登录' : '注册'}
              </button>
            ))}
          </div>

          <form onSubmit={handleSubmit} className="space-y-4">
            {mode === 'register' && (
              <div>
                <label className="text-xs font-medium text-gray-600 mb-1 block">昵称</label>
                <input
                  type="text"
                  value={nickname}
                  onChange={e => setNickname(e.target.value)}
                  placeholder="你的昵称（可后续修改）"
                  className="w-full px-4 py-3 rounded-xl border border-gray-200 text-sm focus:outline-none focus:border-[#1A4B8C] transition-colors"
                />
              </div>
            )}

            <div>
              <label className="text-xs font-medium text-gray-600 mb-1 block">邮箱</label>
              <input
                type="email"
                value={email}
                onChange={e => setEmail(e.target.value)}
                placeholder="your@email.com"
                required
                className="w-full px-4 py-3 rounded-xl border border-gray-200 text-sm focus:outline-none focus:border-[#1A4B8C] transition-colors"
              />
            </div>

            <div>
              <label className="text-xs font-medium text-gray-600 mb-1 block">密码</label>
              <div className="relative">
                <input
                  type={showPwd ? 'text' : 'password'}
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  placeholder={mode === 'register' ? '至少6位' : '请输入密码'}
                  required
                  minLength={6}
                  className="w-full px-4 py-3 pr-10 rounded-xl border border-gray-200 text-sm focus:outline-none focus:border-[#1A4B8C] transition-colors"
                />
                <button
                  type="button"
                  onClick={() => setShowPwd(!showPwd)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400"
                >
                  {showPwd ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
            </div>

            {error && (
              <div className="bg-red-50 text-red-600 text-xs px-3 py-2 rounded-lg">
                {error}
              </div>
            )}
            {success && (
              <div className="bg-green-50 text-green-600 text-xs px-3 py-2 rounded-lg">
                {success}
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full py-3 bg-gradient-to-r from-[#1A4B8C] to-[#4A90D9] text-white rounded-xl font-semibold text-sm flex items-center justify-center gap-2 disabled:opacity-60 transition-opacity"
            >
              {loading && <Loader2 size={16} className="animate-spin" />}
              {mode === 'login' ? '登录' : '创建账号'}
            </button>
          </form>

          <p className="text-center text-xs text-gray-400 mt-4">
            继续即表示同意
            <span className="text-[#1A4B8C]">用户协议</span>和
            <span className="text-[#1A4B8C]">隐私政策</span>
          </p>
        </div>

        <button
          onClick={() => router.push('/')}
          className="w-full text-center text-sm text-gray-500 mt-4 py-2"
        >
          先逛逛，不登录 →
        </button>
      </div>
    </div>
  )
}
