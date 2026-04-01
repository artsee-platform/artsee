'use client'

import { useState, useEffect } from 'react'
import { X, Plus, Trash2, Save, ChevronLeft } from 'lucide-react'

type Draft = {
  id: string
  title: string
  content: string
  updatedAt: string
}

function loadDrafts(): Draft[] {
  try {
    return JSON.parse(localStorage.getItem('artsee_drafts') ?? '[]')
  } catch {
    return []
  }
}

function saveDrafts(drafts: Draft[]) {
  localStorage.setItem('artsee_drafts', JSON.stringify(drafts))
}

export function DraftModal({ onClose }: { onClose: () => void }) {
  const [drafts, setDrafts] = useState<Draft[]>([])
  const [editing, setEditing] = useState<Draft | null>(null)
  const [saved, setSaved] = useState(false)

  useEffect(() => {
    setDrafts(loadDrafts())
  }, [])

  const createNew = () => {
    const draft: Draft = {
      id: Date.now().toString(),
      title: '新文书草稿',
      content: '',
      updatedAt: new Date().toISOString(),
    }
    const updated = [draft, ...drafts]
    setDrafts(updated)
    saveDrafts(updated)
    setEditing(draft)
  }

  const saveDraft = (d: Draft) => {
    const updated = drafts.map(x => x.id === d.id ? d : x)
    setDrafts(updated)
    saveDrafts(updated)
    setSaved(true)
    setTimeout(() => setSaved(false), 1500)
  }

  const deleteDraft = (id: string) => {
    if (!confirm('确定删除这份草稿？')) return
    const updated = drafts.filter(x => x.id !== id)
    setDrafts(updated)
    saveDrafts(updated)
    if (editing?.id === id) setEditing(null)
  }

  const formatDate = (iso: string) => {
    const d = new Date(iso)
    return `${d.getMonth() + 1}/${d.getDate()} ${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`
  }

  return (
    <div className="fixed inset-0 bg-black/40 z-50 flex items-end justify-center">
      <div className="bg-white rounded-t-3xl w-full max-w-[390px] flex flex-col" style={{ height: '80vh' }}>
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-gray-100 flex-shrink-0">
          {editing ? (
            <button onClick={() => setEditing(null)} className="flex items-center gap-1 text-[#1A4B8C] text-sm">
              <ChevronLeft size={16} /> 草稿列表
            </button>
          ) : (
            <h3 className="font-semibold text-gray-900">文书草稿</h3>
          )}
          <div className="flex items-center gap-2">
            {editing && (
              <button
                onClick={() => saveDraft({ ...editing, updatedAt: new Date().toISOString() })}
                className="text-xs text-white bg-[#1A4B8C] px-3 py-1 rounded-full font-medium flex items-center gap-1"
              >
                <Save size={11} /> {saved ? '已保存' : '保存'}
              </button>
            )}
            <button onClick={onClose}><X size={18} className="text-gray-400" /></button>
          </div>
        </div>

        {editing ? (
          /* 编辑视图 */
          <div className="flex flex-col flex-1 overflow-hidden">
            <div className="px-4 pt-3 flex-shrink-0">
              <input
                value={editing.title}
                onChange={e => setEditing({ ...editing, title: e.target.value })}
                placeholder="草稿标题"
                className="w-full text-base font-semibold text-gray-900 outline-none border-b border-gray-100 pb-2 mb-0"
              />
            </div>
            <textarea
              value={editing.content}
              onChange={e => setEditing({ ...editing, content: e.target.value })}
              placeholder="开始写你的文书内容...&#10;&#10;可以在这里记录个人陈述、动机信、推荐信要点等任何内容。"
              className="flex-1 resize-none outline-none px-4 py-3 text-sm text-gray-700 leading-relaxed scrollbar-hide"
            />
            <div className="px-4 py-2 text-[10px] text-gray-400 flex-shrink-0 border-t border-gray-50">
              {editing.content.length} 字 · 自动草稿
            </div>
          </div>
        ) : (
          /* 列表视图 */
          <div className="flex-1 overflow-y-auto scrollbar-hide">
            <div className="px-4 pt-3">
              <button
                onClick={createNew}
                className="w-full flex items-center justify-center gap-2 py-3 border-2 border-dashed border-[#1A4B8C]/30 rounded-2xl text-sm text-[#1A4B8C] font-medium mb-3"
              >
                <Plus size={16} /> 新建文书草稿
              </button>

              {drafts.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-16 text-gray-400">
                  <span className="text-4xl mb-3">📝</span>
                  <p className="text-sm">还没有文书草稿</p>
                  <p className="text-xs mt-1">点击上方新建你的第一份草稿</p>
                </div>
              ) : (
                <div className="space-y-2">
                  {drafts.map(d => (
                    <div
                      key={d.id}
                      className="bg-white border border-gray-100 rounded-2xl p-3 flex items-start gap-3 active:bg-gray-50"
                    >
                      <button className="flex-1 text-left" onClick={() => setEditing(d)}>
                        <p className="text-sm font-semibold text-gray-900 line-clamp-1">{d.title || '无标题'}</p>
                        <p className="text-[11px] text-gray-500 mt-0.5 line-clamp-2 leading-relaxed">
                          {d.content || '（空白草稿）'}
                        </p>
                        <p className="text-[10px] text-gray-400 mt-1.5">{formatDate(d.updatedAt)} 修改</p>
                      </button>
                      <button onClick={() => deleteDraft(d.id)} className="text-gray-300 p-1">
                        <Trash2 size={14} />
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
