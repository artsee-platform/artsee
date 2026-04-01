import Link from "next/link";
import { MapPin, Clock, BookOpen, ChevronRight, Star } from "lucide-react";
import { getSchoolGradient, getSchoolInitial } from "@/lib/utils";
import type { Program } from "@/lib/supabase/types";

export function UniversityCard({ program }: { program: Program }) {
  const school = program.schools
  const admission = Array.isArray(program.program_admissions) ? program.program_admissions[0] : program.program_admissions
  const fee = Array.isArray(program.program_fees) ? program.program_fees[0] : program.program_fees

  // 如果 name_zh 是占位值，优先用英文名
  const isPlaceholder = !school?.name_zh || school.name_zh === '综合艺术院校'
  const schoolDisplayName = isPlaceholder
    ? (school?.name_en ?? '未知院校')
    : school!.name_zh

  const gradient = school ? getSchoolGradient(schoolDisplayName) : 'from-gray-400 to-gray-600'
  const initial = school ? getSchoolInitial(schoolDisplayName) : '?'

  const cityDisplay = school?.city === 'Various' ? '' : (school?.city ?? '')
  const countryDisplay = school?.country === 'Various' ? '英国' : (school?.country ?? '')
  const tuition = fee?.international_tuition_fee
    ? `£${Math.round(Number(fee.international_tuition_fee) / 1000)}k/年`
    : '面议'

  const ielts = admission?.ielts_overall ? `${admission.ielts_overall}` : '---'
  const deadline = admission?.regular_deadline
    ? admission.regular_deadline.slice(5)
    : '滚动'

  return (
    <Link href={`/explore/${program.id}`}>
      <article className="mx-4 mb-3 bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden active:scale-[0.99] transition-transform">
        <div className="flex items-center gap-3 p-3">
          <div className={`w-12 h-12 rounded-xl bg-gradient-to-br ${gradient} flex items-center justify-center flex-shrink-0`}>
            <span className="text-white text-[10px] font-bold text-center leading-tight">{initial}</span>
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-1.5">
              <h3 className="text-sm font-semibold text-gray-900 truncate">{schoolDisplayName}</h3>
              {school?.qs_art_rank && (
                <span className="flex-shrink-0 flex items-center gap-0.5 text-[9px] text-blue-700 bg-blue-50 px-1.5 py-0.5 rounded-full">
                  <Star size={8} />QS #{school.qs_art_rank}
                </span>
              )}
            </div>
            <p className="text-xs text-gray-500 truncate mt-0.5">{program.program_name}</p>
            {school && (
              <div className="flex items-center gap-1 mt-0.5">
                <MapPin size={10} className="text-gray-400" />
                <span className="text-[10px] text-gray-400">{school.city ?? ''}，{school.country ?? ''}</span>
              </div>
            )}
          </div>
          <ChevronRight size={16} className="text-gray-300 flex-shrink-0" />
        </div>

        <div className="flex items-center border-t border-gray-50 divide-x divide-gray-100">
          <div className="flex-1 flex flex-col items-center py-2">
            <div className="flex items-center gap-1">
              <BookOpen size={11} className="text-blue-500" />
              <span className="text-[10px] font-semibold text-gray-700">{ielts}</span>
            </div>
            <span className="text-[9px] text-gray-400 mt-0.5">IELTS</span>
          </div>
          <div className="flex-1 flex flex-col items-center py-2">
            <div className="flex items-center gap-1">
              <Clock size={11} className="text-green-500" />
              <span className="text-[10px] font-semibold text-gray-700 truncate max-w-[60px] text-center">{program.duration_text ?? '---'}</span>
            </div>
            <span className="text-[9px] text-gray-400 mt-0.5">学制</span>
          </div>
          <div className="flex-1 flex flex-col items-center py-2">
            <span className="text-[10px] font-semibold text-gray-700">{tuition}</span>
            <span className="text-[9px] text-gray-400 mt-0.5">国际学费</span>
          </div>
          <div className="flex-1 flex flex-col items-center py-2">
            <span className={`text-[10px] font-semibold ${deadline === '滚动' ? 'text-green-600' : 'text-blue-600'}`}>
              {deadline}
            </span>
            <span className="text-[9px] text-gray-400 mt-0.5">截止日期</span>
          </div>
        </div>

        <div className="flex items-center gap-2 px-3 pb-3 pt-1 flex-wrap">
          {program.requires_interview && (
            <span className="text-[9px] bg-blue-50 text-blue-700 border border-blue-200 px-2 py-0.5 rounded-full">需要面试</span>
          )}
          {program.requires_portfolio && (
            <span className="text-[9px] bg-purple-50 text-purple-600 border border-purple-200 px-2 py-0.5 rounded-full">需作品集</span>
          )}
          {admission?.reference_count && (
            <span className="text-[9px] bg-gray-50 text-gray-500 border border-gray-200 px-2 py-0.5 rounded-full">
              推荐信 ×{admission.reference_count}
            </span>
          )}
          {program.degree_type && (
            <span className="text-[9px] bg-blue-50 text-blue-600 border border-blue-200 px-2 py-0.5 rounded-full">
              {program.degree_type}
            </span>
          )}
        </div>
      </article>
    </Link>
  );
}
