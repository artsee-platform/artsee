import type { ApplicationTracker } from "@/lib/supabase/types";
import { statusLabel, statusColor, tierLabel, tierColor } from "@/lib/utils";
import { ChevronRight } from "lucide-react";

const statusStep = ["planning", "preparing", "submitted", "interview", "admitted"];

export function TrackerCard({ tracker }: { tracker: ApplicationTracker }) {
  const currentStep = statusStep.indexOf(tracker.status);
  const isFinished = tracker.status === "admitted" || tracker.status === "rejected" || tracker.status === "waitlisted";

  return (
    <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-3 mb-3">
      {/* 院校信息 */}
      <div className="flex items-center justify-between mb-2">
        <div>
          <div className="flex items-center gap-1.5">
            <h3 className="text-sm font-semibold text-gray-900">{tracker.school_name}</h3>
            <span className={`text-[9px] font-bold ${tierColor[tracker.tier]}`}>
              [{tierLabel[tracker.tier]}]
            </span>
          </div>
          <p className="text-[10px] text-gray-500">{tracker.program_name}</p>
        </div>
        <div className="flex items-center gap-1">
          <span className={`text-[9px] font-medium px-2 py-0.5 rounded-full ${statusColor[tracker.status]}`}>
            {statusLabel[tracker.status]}
          </span>
          <ChevronRight size={14} className="text-gray-300" />
        </div>
      </div>

      {/* 进度条（仅非终态显示） */}
      {!isFinished && (
        <div className="flex items-center gap-1 mt-2">
          {statusStep.slice(0, -1).map((step, i) => (
            <div key={step} className="flex items-center flex-1">
              <div
                className={`w-full h-1 rounded-full transition-colors ${
                  i <= currentStep ? "bg-[#1A4B8C]" : "bg-gray-200"
                }`}
              />
            </div>
          ))}
        </div>
      )}

      {/* 截止日期 */}
      <div className="flex items-center justify-between mt-2">
        <span className="text-[10px] text-gray-400">
          截止：{tracker.deadline ?? '—'}
        </span>
        {isFinished && tracker.status === "admitted" && (
          <span className="text-[10px] text-green-600 font-medium">🎉 恭喜录取！</span>
        )}
      </div>
    </div>
  );
}
