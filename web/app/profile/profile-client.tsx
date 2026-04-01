'use client'

import { useState } from 'react'
import { TrackerCard } from '@/components/profile/tracker-card'
import { LogOut, BookOpen, Heart, FileText, Plus, X, Loader2, Pencil } from 'lucide-react'
import Link from 'next/link'
import type { UserProfile, ApplicationTracker } from '@/lib/supabase/types'
import { resultLabel, resultColor, timeAgo } from '@/lib/utils'
import { signOut, createTrackerEntry, updateProfile } from '@/lib/actions'
import { DraftModal } from '@/components/profile/draft-modal'

const profileTabs = ['申请追踪', '我的案例', '我的收藏'] as const

type MyCaseRow = {
  id: string
  title: string
  target_school: string | null
  result: 'admitted' | 'waitlisted' | 'rejected'
  like_count: number
  comment_count: number
  created_at: string
  cover_gradient: string | null
}

type FavoriteRow = {
  id: number
  programs?: { id: number; program_name: string; schools?: { name_zh: string } | null } | null
  created_at: string
}

type Props = {
  profile: UserProfile | null
  trackers: ApplicationTracker[]
  myCases: MyCaseRow[]
  favorites: FavoriteRow[]
}

export function ProfileClient({ profile, trackers, myCases, favorites }: Props) {
  const [activeTab, setActiveTab] = useState<typeof profileTabs[number]>('申请追踪')
  const [showAddTracker, setShowAddTracker] = useState(false)
  const [addingTracker, setAddingTracker] = useState(false)
  const [trackerError, setTrackerError] = useState('')
  const [showEditProfile, setShowEditProfile] = useState(false)
  const [editingProfile, setEditingProfile] = useState(false)
  const [editError, setEditError] = useState('')
  const [showDraft, setShowDraft] = useState(false)

  const nickname = profile?.nickname ?? '艺见用户'
  const bio = profile?.bio ?? '目标：英国艺术院校 · 努力备考中'

  return (
    <>
      <div className="pb-4">
      {/* 个人信息头部 */}
      <div className="relative">
        <div className="h-28 bg-gradient-to-br from-[#1A4B8C] via-[#2A6BC2] to-[#4A90D9]" />
        <button
          onClick={async () => {
            if (confirm('确定要退出登录吗？')) {
              await signOut()
              window.location.href = '/'
            }
          }}
          className="absolute top-3 right-3 w-8 h-8 bg-white/20 backdrop-blur-sm rounded-full flex items-center justify-center"
          title="退出登录"
        >
          <LogOut size={15} className="text-white" />
        </button>
        <div className="absolute left-4 bottom-0 translate-y-1/2">
          <div className="w-16 h-16 rounded-full bg-white border-2 border-white shadow-md flex items-center justify-center text-2xl">
            🎨
          </div>
        </div>
      </div>

      {/* 用户名 & 简介 */}
      <div className="pt-10 px-4 pb-3">
        <div className="flex items-end justify-between">
          <div>
            <h2 className="text-base font-bold text-gray-900">{nickname}</h2>
            <p className="text-[11px] text-gray-500 mt-0.5">
              {profile?.location ? `${profile.location} | ` : ''}{bio}
            </p>
          </div>
          <button
            onClick={() => { setShowEditProfile(true); setEditError('') }}
            className="text-xs border border-[#1A4B8C] text-[#1A4B8C] px-3 py-1 rounded-full font-medium flex items-center gap-1"
          >
            <Pencil size={11} />
            编辑资料
          </button>
        </div>
      </div>

      {/* 统计条 */}
      <div className="flex divide-x divide-gray-100 bg-white border-t border-gray-100">
        {[
          { label: '关注', value: profile?.following_count ?? 0 },
          { label: '粉丝', value: profile?.followers_count ?? 0 },
          { label: '案例', value: myCases.length },
          { label: '收藏', value: favorites.length },
        ].map(s => (
          <button key={s.label} className="flex-1 flex flex-col items-center py-3">
            <span className="text-sm font-bold text-gray-900">{s.value}</span>
            <span className="text-[10px] text-gray-400 mt-0.5">{s.label}</span>
          </button>
        ))}
      </div>

      {/* 快捷工具 */}
      <div className="grid grid-cols-4 gap-2 px-4 py-3 border-b border-gray-100">
        {[
          { icon: BookOpen, label: '选校清单', color: 'bg-blue-50 text-blue-500', href: '/explore', onClick: undefined },
          { icon: Heart, label: '我的收藏', color: 'bg-rose-50 text-rose-500', href: undefined, onClick: () => setActiveTab('我的收藏') },
          { icon: FileText, label: '文书草稿', color: 'bg-purple-50 text-purple-500', href: undefined, onClick: () => setShowDraft(true) },
          { icon: Plus, label: '分享案例', color: 'bg-blue-50 text-[#1A4B8C]', href: '/cases/new', onClick: undefined },
        ].map(({ icon: Icon, label, color, href, onClick }) =>
          href ? (
            <Link key={label} href={href} className="flex flex-col items-center gap-1">
              <div className={`w-10 h-10 rounded-xl ${color} flex items-center justify-center`}>
                <Icon size={18} />
              </div>
              <span className="text-[9px] text-gray-500 text-center leading-tight">{label}</span>
            </Link>
          ) : (
            <button key={label} onClick={onClick} className="flex flex-col items-center gap-1">
              <div className={`w-10 h-10 rounded-xl ${color} flex items-center justify-center`}>
                <Icon size={18} />
              </div>
              <span className="text-[9px] text-gray-500 text-center leading-tight">{label}</span>
            </button>
          )
        )}
      </div>

      {/* Tab 切换 */}
      <div className="flex border-b border-gray-100">
        {profileTabs.map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`flex-1 py-2.5 text-xs font-medium border-b-2 transition-colors ${
              activeTab === tab
                ? 'border-[#1A4B8C] text-[#1A4B8C]'
                : 'border-transparent text-gray-400'
            }`}
          >
            {tab}
          </button>
        ))}
      </div>

      {/* 内容区 */}
      <div className="px-4 pt-3">
        {activeTab === '申请追踪' && (
          <>
            <div className="flex items-center justify-between mb-3">
              <p className="text-xs text-gray-500">共 {trackers.length} 所学校</p>
              <button onClick={() => { setShowAddTracker(true); setTrackerError('') }} className="flex items-center gap-1 text-xs text-[#1A4B8C] font-medium">
                <Plus size={12} />
                添加学校
              </button>
            </div>
            {trackers.length > 0
              ? trackers.map(t => <TrackerCard key={t.id} tracker={t} />)
              : (
                <div className="flex flex-col items-center justify-center py-12 text-gray-400">
                  <span className="text-3xl mb-2">📋</span>
                  <p className="text-sm mb-3">还没有追踪的学校</p>
                  <p className="text-xs text-gray-400">前往探索页选择心仪院校</p>
                </div>
              )}
          </>
        )}

        {activeTab === '我的案例' && (
          <>
            {myCases.length > 0 ? (
              <div className="space-y-3">
                {myCases.map(c => (
                  <Link key={c.id} href={`/cases/${c.id}`}>
                    <div className={`rounded-xl overflow-hidden border border-gray-100 shadow-sm`}>
                      <div className={`h-16 bg-gradient-to-br ${c.cover_gradient ?? 'from-blue-500 to-purple-600'} flex items-center px-3`}>
                        <span className={`text-[9px] font-semibold px-1.5 py-0.5 rounded-full ${resultColor[c.result]}`}>
                          {resultLabel[c.result]}
                        </span>
                      </div>
                      <div className="p-3 bg-white">
                        <p className="text-xs font-semibold text-gray-900 line-clamp-1">{c.title}</p>
                        <div className="flex items-center justify-between mt-1">
                          <span className="text-[10px] text-gray-500">{c.target_school}</span>
                          <span className="text-[10px] text-gray-400">{timeAgo(c.created_at)}</span>
                        </div>
                      </div>
                    </div>
                  </Link>
                ))}
              </div>
            ) : (
              <div className="flex flex-col items-center justify-center py-12 text-gray-400">
                <span className="text-3xl mb-2">📝</span>
                <p className="text-sm mb-3">还没有分享过案例</p>
                <Link href="/cases/new" className="bg-[#1A4B8C] text-white text-xs px-4 py-2 rounded-full font-medium">
                  分享我的申请经历
                </Link>
              </div>
            )}
          </>
        )}

        {activeTab === '我的收藏' && (
          <>
            {favorites.length > 0 ? (
              <div className="space-y-2">
                {favorites.map(f => (
                  <Link key={f.id} href={`/explore/${f.programs?.id ?? '#'}`}>
                    <div className="bg-white rounded-xl border border-gray-100 p-3 flex items-center justify-between">
                      <div>
                        <p className="text-xs font-semibold text-gray-900">{f.programs?.program_name ?? '项目'}</p>
                        <p className="text-[10px] text-gray-500 mt-0.5">{f.programs?.schools?.name_zh ?? ''}</p>
                      </div>
                      <Heart size={14} className="text-rose-500 fill-rose-500" />
                    </div>
                  </Link>
                ))}
              </div>
            ) : (
              <div className="flex flex-col items-center justify-center py-12 text-gray-400">
                <span className="text-3xl mb-2">🔖</span>
                <p className="text-sm mb-3">还没有收藏内容</p>
                <Link href="/explore" className="bg-[#1A4B8C] text-white text-xs px-4 py-2 rounded-full font-medium">
                  去探索院校
                </Link>
              </div>
            )}
          </>
        )}
      </div>
    </div>

      {/* 添加追踪 Modal */}
      {showAddTracker && (
        <div className="fixed inset-0 bg-black/40 z-50 flex items-end justify-center">
          <div className="bg-white rounded-t-3xl w-full max-w-[390px] p-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="font-semibold text-gray-900">添加申请学校</h3>
              <button onClick={() => setShowAddTracker(false)}><X size={18} className="text-gray-400" /></button>
            </div>
            <form action={async (fd: FormData) => {
              setAddingTracker(true)
              setTrackerError('')
              const res = await createTrackerEntry(fd)
              setAddingTracker(false)
              if ('error' in res) { setTrackerError(res.error ?? '操作失败'); return }
              setShowAddTracker(false)
            }}>
              <div className="space-y-3">
                <input name="school_name" required placeholder="院校名称" className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm outline-none focus:border-[#1A4B8C]" />
                <input name="program_name" required placeholder="专业方向" className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm outline-none focus:border-[#1A4B8C]" />
                <select name="tier" className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm outline-none focus:border-[#1A4B8C]">
                  <option value="reach">冲刺</option>
                  <option value="match">匹配</option>
                  <option value="safety">保底</option>
                </select>
                <select name="status" className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm outline-none focus:border-[#1A4B8C]">
                  <option value="planning">规划中</option>
                  <option value="preparing">准备材料</option>
                  <option value="submitted">已提交</option>
                </select>
                {trackerError && <p className="text-xs text-red-500">{trackerError}</p>}
                <button type="submit" disabled={addingTracker} className="w-full py-3 bg-[#1A4B8C] text-white rounded-xl font-semibold text-sm flex items-center justify-center gap-2 disabled:opacity-60">
                  {addingTracker ? <Loader2 size={14} className="animate-spin" /> : null}
                  添加
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* 编辑资料 Modal */}      {showEditProfile && (
        <div className="fixed inset-0 bg-black/40 z-50 flex items-end justify-center">
          <div className="bg-white rounded-t-3xl w-full max-w-[390px] p-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="font-semibold text-gray-900">编辑资料</h3>
              <button onClick={() => setShowEditProfile(false)}><X size={18} className="text-gray-400" /></button>
            </div>
            <form action={async (fd: FormData) => {
              setEditingProfile(true)
              setEditError('')
              const res = await updateProfile(fd)
              setEditingProfile(false)
              if ('error' in res) { setEditError(res.error ?? '保存失败'); return }
              setShowEditProfile(false)
            }}>
              <div className="space-y-3">
                <div>
                  <label className="text-xs text-gray-500 mb-1 block">昵称</label>
                  <input
                    name="nickname"
                    defaultValue={profile?.nickname ?? ''}
                    placeholder="你的昵称"
                    maxLength={20}
                    className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm outline-none focus:border-[#1A4B8C]"
                  />
                </div>
                <div>
                  <label className="text-xs text-gray-500 mb-1 block">简介</label>
                  <textarea
                    name="bio"
                    defaultValue={profile?.bio ?? ''}
                    placeholder="介绍一下自己..."
                    maxLength={80}
                    rows={2}
                    className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm outline-none focus:border-[#1A4B8C] resize-none"
                  />
                </div>
                <div>
                  <label className="text-xs text-gray-500 mb-1 block">所在地</label>
                  <input
                    name="location"
                    defaultValue={profile?.location ?? ''}
                    placeholder="城市 / 国家"
                    maxLength={30}
                    className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm outline-none focus:border-[#1A4B8C]"
                  />
                </div>
                {editError && <p className="text-xs text-red-500">{editError}</p>}
                <button type="submit" disabled={editingProfile} className="w-full py-3 bg-[#1A4B8C] text-white rounded-xl font-semibold text-sm flex items-center justify-center gap-2 disabled:opacity-60">
                  {editingProfile ? <Loader2 size={14} className="animate-spin" /> : null}
                  保存
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* 文书草稿 Modal */}
      {showDraft && <DraftModal onClose={() => setShowDraft(false)} />}
    </>
  )
}
