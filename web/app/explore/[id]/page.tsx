import { createClient } from '@/lib/supabase/server'
import { notFound } from 'next/navigation'
import Link from 'next/link'
import { ArrowLeft, Globe, BookOpen, Clock, Calendar, Users, FileText, Video, Heart } from 'lucide-react'
import { getSchoolGradient, getSchoolInitial } from '@/lib/utils'
import { FavoriteButton } from './favorite-button'

export default async function ProgramDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await createClient()

  const { data: program } = await supabase
    .from('programs')
    .select(`
      *,
      schools ( * ),
      program_admissions ( * ),
      program_fees ( * )
    `)
    .eq('id', parseInt(id))
    .single()

  if (!program) notFound()

  const { data: { user } } = await supabase.auth.getUser()

  let isFavorited = false
  if (user) {
    const { data: fav } = await supabase
      .from('user_favorites')
      .select('id')
      .eq('user_id', user.id)
      .eq('program_id', program.id)
      .single()
    isFavorited = !!fav
  }

  const school = program.schools
  const admission = Array.isArray(program.program_admissions)
    ? program.program_admissions[0]
    : program.program_admissions
  const fee = Array.isArray(program.program_fees)
    ? program.program_fees[0]
    : program.program_fees

  const gradient = school ? getSchoolGradient(school.name_zh) : 'from-gray-500 to-slate-600'
  const initial = school ? getSchoolInitial(school.name_zh) : '?'

  return (
    <div className="pb-6">
      {/* 顶部 Banner */}
      <div className={`relative bg-gradient-to-br ${gradient} px-4 pt-3 pb-6`}>
        <Link href="/explore" className="inline-flex items-center gap-1 text-white/80 text-xs mb-3">
          <ArrowLeft size={14} /> 返回探索
        </Link>
        <div className="flex items-start gap-3">
          <div className="w-14 h-14 rounded-2xl bg-white/20 backdrop-blur-sm flex items-center justify-center flex-shrink-0">
            <span className="text-white text-sm font-bold">{initial}</span>
          </div>
          <div className="flex-1">
            <h1 className="text-white font-bold text-base leading-snug">{program.program_name}</h1>
            <p className="text-white/80 text-xs mt-0.5">{school?.name_zh}</p>
            <p className="text-white/60 text-[10px] mt-0.5">{school?.city}，{school?.country}</p>
          </div>
        </div>

        {/* 快速数据 */}
        <div className="grid grid-cols-3 gap-2 mt-4">
          {[
            { label: 'IELTS', value: admission?.ielts_overall ? `${admission.ielts_overall}` : '---' },
            { label: '学制', value: program.duration_text ?? '---' },
            { label: '国际学费', value: fee?.international_tuition_fee ? `£${Math.round(Number(fee.international_tuition_fee)/1000)}k` : '面议' },
          ].map(item => (
            <div key={item.label} className="bg-white/15 backdrop-blur-sm rounded-xl p-2 text-center">
              <p className="text-white font-semibold text-sm">{item.value}</p>
              <p className="text-white/70 text-[10px]">{item.label}</p>
            </div>
          ))}
        </div>
      </div>

      {/* 操作按钮 */}
      <div className="flex gap-2 px-4 -mt-3">
        <FavoriteButton programId={program.id} initialFavorited={isFavorited} isLoggedIn={!!user} />
        {school?.official_website && (
          <a href={school.official_website} target="_blank" rel="noopener noreferrer"
            className="flex-1 flex items-center justify-center gap-1.5 py-2.5 border border-gray-200 bg-white rounded-xl text-xs font-medium text-gray-600 shadow-sm">
            <Globe size={14} /> 官网
          </a>
        )}
      </div>

      {/* 标签 */}
      <div className="flex gap-2 px-4 mt-3 flex-wrap">
        {program.degree_type && <Tag color="blue">{program.degree_type}</Tag>}
        {program.requires_interview && <Tag color="amber">需要面试</Tag>}
        {program.requires_portfolio && <Tag color="purple">需作品集</Tag>}
        {program.requires_personal_statement && <Tag color="green">需文书</Tag>}
      </div>

      {/* 项目简介 */}
      {program.program_overview && (
        <Section title="项目简介" icon={<FileText size={14} className="text-[#FF6A00]" />}>
          <p className="text-xs text-gray-600 leading-relaxed">{program.program_overview}</p>
        </Section>
      )}

      {/* 申请要求 */}
      <Section title="申请要求" icon={<BookOpen size={14} className="text-blue-500" />}>
        <div className="space-y-2">
          {admission?.ielts_overall && (
            <ReqRow label="IELTS 总分" value={`${admission.ielts_overall}（单项最低见官网）`} />
          )}
          {admission?.toefl_ibt && (
            <ReqRow label="TOEFL IBT" value={`${admission.toefl_ibt} 分`} />
          )}
          {admission?.reference_count && (
            <ReqRow label="推荐信" value={`${admission.reference_count} 封`} />
          )}
          {admission?.academic_requirements && (
            <ReqRow label="学历要求" value={admission.academic_requirements} />
          )}
          {program.minimum_education && (
            <ReqRow label="最低学历" value={JSON.stringify(program.minimum_education)} />
          )}
        </div>
      </Section>

      {/* 作品集要求 */}
      {admission?.portfolio_requirements && (
        <Section title="作品集要求" icon={<Video size={14} className="text-purple-500" />}>
          <p className="text-xs text-gray-600 leading-relaxed">{admission.portfolio_requirements}</p>
        </Section>
      )}

      {/* 截止日期 */}
      {(admission?.regular_deadline || admission?.priority_deadline) && (
        <Section title="申请截止日期" icon={<Calendar size={14} className="text-green-500" />}>
          <div className="space-y-2">
            {admission.priority_deadline && (
              <ReqRow label="优先截止" value={admission.priority_deadline} highlight />
            )}
            {admission.regular_deadline && (
              <ReqRow label="常规截止" value={admission.regular_deadline} />
            )}
            {admission.deadline_notes && (
              <p className="text-[10px] text-gray-500 mt-1">{admission.deadline_notes}</p>
            )}
          </div>
        </Section>
      )}

      {/* 核心课程 */}
      {program.core_courses && (
        <Section title="核心课程" icon={<Users size={14} className="text-teal-500" />}>
          <p className="text-xs text-gray-600 leading-relaxed whitespace-pre-line">{program.core_courses}</p>
        </Section>
      )}

      {/* 职业发展 */}
      {program.career_paths && (
        <Section title="职业发展方向" icon={<Heart size={14} className="text-rose-500" />}>
          <p className="text-xs text-gray-600 leading-relaxed">{program.career_paths}</p>
        </Section>
      )}

      {/* 学费详情 */}
      {fee && (
        <Section title="费用信息" icon={<Clock size={14} className="text-orange-500" />}>
          <div className="space-y-2">
            {fee.international_tuition_fee && (
              <ReqRow label="国际生学费" value={`${fee.currency_code ?? 'GBP'} ${Number(fee.international_tuition_fee).toLocaleString()}`} />
            )}
            {fee.domestic_tuition_fee && (
              <ReqRow label="本地生学费" value={`${fee.currency_code ?? 'GBP'} ${Number(fee.domestic_tuition_fee).toLocaleString()}`} />
            )}
            {fee.additional_fees_note && (
              <p className="text-[10px] text-gray-500 mt-1">{fee.additional_fees_note}</p>
            )}
          </div>
        </Section>
      )}
    </div>
  )
}

function Section({ title, icon, children }: { title: string; icon: React.ReactNode; children: React.ReactNode }) {
  return (
    <div className="mx-4 mt-3 bg-white rounded-2xl p-4 border border-gray-100">
      <div className="flex items-center gap-2 mb-3">
        {icon}
        <h2 className="text-sm font-semibold text-gray-900">{title}</h2>
      </div>
      {children}
    </div>
  )
}

function ReqRow({ label, value, highlight }: { label: string; value: string; highlight?: boolean }) {
  return (
    <div className="flex items-start justify-between gap-2">
      <span className="text-[11px] text-gray-500 flex-shrink-0">{label}</span>
      <span className={`text-[11px] font-medium text-right ${highlight ? 'text-[#FF6A00]' : 'text-gray-700'}`}>{value}</span>
    </div>
  )
}

function Tag({ children, color }: { children: React.ReactNode; color: string }) {
  const colorMap: Record<string, string> = {
    blue: 'bg-blue-50 text-blue-600 border-blue-200',
    amber: 'bg-amber-50 text-amber-600 border-amber-200',
    purple: 'bg-purple-50 text-purple-600 border-purple-200',
    green: 'bg-green-50 text-green-600 border-green-200',
  }
  return (
    <span className={`text-[10px] px-2 py-0.5 rounded-full border font-medium ${colorMap[color]}`}>
      {children}
    </span>
  )
}
