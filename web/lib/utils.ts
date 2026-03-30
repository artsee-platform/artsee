import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

// 颜色映射：院校 → 渐变色
export const schoolGradients: Record<string, string> = {
  '牛津大学': 'from-blue-600 to-indigo-700',
  '剑桥大学': 'from-sky-500 to-blue-600',
  '帝国理工+RCA': 'from-purple-600 to-violet-700',
  '帝国理工学院': 'from-purple-600 to-violet-700',
  'UCL': 'from-emerald-500 to-teal-600',
  '伦敦大学学院': 'from-emerald-500 to-teal-600',
  '爱丁堡大学': 'from-rose-500 to-pink-600',
  '中央圣马丁': 'from-orange-500 to-amber-600',
  '坎伯韦尔艺术学院': 'from-fuchsia-500 to-purple-600',
  '皇家艺术学院': 'from-red-500 to-rose-600',
  '综合艺术院校': 'from-violet-500 to-purple-600',
}

export function getSchoolGradient(name: string): string {
  return schoolGradients[name] ?? 'from-gray-500 to-slate-600'
}

export function getSchoolInitial(name: string): string {
  const map: Record<string, string> = {
    '牛津大学': 'Ox', '剑桥大学': 'Cam', '帝国理工+RCA': 'IDE',
    'UCL': 'UCL', '伦敦大学学院': 'UCL', '爱丁堡大学': 'Edin',
    '中央圣马丁': 'CSM', '坎伯韦尔艺术学院': 'CAM', '皇家艺术学院': 'RCA',
    '综合艺术院校': 'Art',
  }
  return map[name] ?? name.slice(0, 3)
}

export const resultLabel = {
  admitted: '🎉 录取',
  waitlisted: '⏳ 等候',
  rejected: '❌ 拒绝',
} as const

export const resultColor = {
  admitted: 'bg-green-100 text-green-700',
  waitlisted: 'bg-yellow-100 text-yellow-700',
  rejected: 'bg-red-100 text-red-600',
} as const

export const statusLabel = {
  planning: '规划中', preparing: '准备材料', submitted: '已提交',
  interview: '面试中', admitted: '已录取', rejected: '已拒绝', waitlisted: '等候名单',
} as const

export const statusColor = {
  planning: 'bg-gray-100 text-gray-600',
  preparing: 'bg-blue-100 text-blue-700',
  submitted: 'bg-purple-100 text-purple-700',
  interview: 'bg-amber-100 text-amber-700',
  admitted: 'bg-green-100 text-green-700',
  rejected: 'bg-red-100 text-red-600',
  waitlisted: 'bg-yellow-100 text-yellow-700',
} as const

export const tierLabel = { reach: '冲刺', match: '匹配', safety: '保底' } as const
export const tierColor = { reach: 'text-red-500', match: 'text-blue-500', safety: 'text-green-500' } as const

export function timeAgo(dateStr: string): string {
  const diff = Date.now() - new Date(dateStr).getTime()
  const m = Math.floor(diff / 60000)
  if (m < 1) return '刚刚'
  if (m < 60) return `${m}分钟前`
  const h = Math.floor(m / 60)
  if (h < 24) return `${h}小时前`
  const d = Math.floor(h / 24)
  if (d < 30) return `${d}天前`
  return new Date(dateStr).toLocaleDateString('zh-CN', { month: 'short', day: 'numeric' })
}
