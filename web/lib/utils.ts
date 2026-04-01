import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

// 颜色映射：院校关键词 → 渐变色（模糊匹配）
export const schoolGradients: Record<string, string> = {
  '牛津': 'from-blue-600 to-indigo-700',
  '剑桥': 'from-sky-500 to-blue-600',
  '帝国理工': 'from-purple-600 to-violet-700',
  'UCL': 'from-emerald-500 to-teal-600',
  '伦敦大学学院': 'from-emerald-500 to-teal-600',
  '爱丁堡': 'from-rose-500 to-pink-600',
  '中央圣马丁': 'from-blue-500 to-indigo-600',
  '坎伯韦尔': 'from-fuchsia-500 to-purple-600',
  '皇家艺术': 'from-red-500 to-rose-600',
  '综合艺术院校': 'from-violet-500 to-purple-600',
  '格拉斯哥': 'from-teal-500 to-cyan-600',
  '鲁斯金': 'from-blue-400 to-indigo-500',
  '切尔西': 'from-cyan-500 to-blue-600',
  '伦敦时装': 'from-pink-500 to-rose-600',
  '伦敦传播': 'from-indigo-500 to-blue-600',
  '伦敦艺术大学': 'from-blue-500 to-cyan-600',
  '柏林': 'from-slate-600 to-blue-700',
  '佛罗伦萨': 'from-amber-600 to-yellow-700',
  '巴黎': 'from-violet-500 to-purple-600',
}

export function getSchoolGradient(name: string): string {
  const key = Object.keys(schoolGradients).find(k => name.includes(k))
  return key ? schoolGradients[key] : 'from-blue-500 to-indigo-600'
}

export function getSchoolInitial(name: string): string {
  const map: Record<string, string> = {
    '牛津': 'Ox', '剑桥': 'Cam', '帝国理工': 'IC',
    'UCL': 'UCL', '爱丁堡': 'Edin', '中央圣马丁': 'CSM',
    '坎伯韦尔': 'CAM', '皇家艺术': 'RCA', '综合艺术院校': 'Art',
    '格拉斯哥': 'GSA', '鲁斯金': 'Rus', '切尔西': 'CCA',
    '伦敦时装': 'LCF', '伦敦传播': 'LCC', '伦敦艺术大学': 'UAL',
    '柏林': 'UdK', '佛罗伦萨': 'AFAM', '巴黎': 'ENSBA',
  }
  const key = Object.keys(map).find(k => name.includes(k))
  return key ? map[key] : name.slice(0, 2)
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
  interview: 'bg-blue-100 text-blue-700',
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
