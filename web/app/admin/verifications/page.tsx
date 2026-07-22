"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import {
  ArrowLeft,
  CheckCircle2,
  IdCard,
  Loader2,
  RefreshCw,
  Search,
  ShieldAlert,
  XCircle,
} from "lucide-react";

type VerificationType = "student" | "artist" | "collector" | "business";
type VerificationStatus = "pending" | "approved" | "rejected";

type UserProfile = {
  id: string;
  nickname?: string | null;
  role?: string | null;
  user_type?: string | null;
  user_role?: string | null;
  is_verified?: boolean | null;
  status?: string | null;
};

type Verification = {
  id: string;
  user_id: string;
  type: VerificationType;
  materials?: Record<string, unknown> | null;
  status: VerificationStatus;
  review_note?: string | null;
  created_at?: string | null;
  updated_at?: string | null;
  user?: UserProfile | null;
};

type ApiListResponse = {
  success: boolean;
  data: Verification[];
  count?: number;
  error?: string;
};

const TYPE_OPTIONS: Array<{ value: "all" | VerificationType; label: string }> = [
  { value: "all", label: "全部类型" },
  { value: "business", label: "机构入驻" },
  { value: "student", label: "学生" },
  { value: "artist", label: "艺术家" },
  { value: "collector", label: "收藏者" },
];

const STATUS_OPTIONS: Array<{ value: "all" | VerificationStatus; label: string }> = [
  { value: "pending", label: "待审核" },
  { value: "approved", label: "已通过" },
  { value: "rejected", label: "未通过" },
  { value: "all", label: "全部状态" },
];

const TYPE_LABELS: Record<VerificationType, string> = {
  student: "学生",
  artist: "艺术家",
  collector: "收藏者",
  business: "机构入驻",
};

const STATUS_META: Record<VerificationStatus, { label: string; className: string }> = {
  pending: {
    label: "待审核",
    className: "bg-amber-50 text-amber-700 ring-amber-200",
  },
  approved: {
    label: "已通过",
    className: "bg-emerald-50 text-emerald-700 ring-emerald-200",
  },
  rejected: {
    label: "未通过",
    className: "bg-rose-50 text-rose-700 ring-rose-200",
  },
};

const BUSINESS_ROLE_LABELS: Record<string, string> = {
  gallery_exhibition: "画廊 / 美术馆 / 展览机构",
  official_association: "官方协会 / 行业组织",
  school_official: "院校官方 / 招生部门",
  official_partner: "官方合作组织",
  study_abroad_agency: "留学服务（已下线）",
  portfolio_training: "作品集服务（已下线）",
  event_organizer: "活动主办方",
  hotel_culture_space: "文旅空间",
  brand_partner: "品牌合作方",
  art_media_community: "艺术媒体",
  other_service: "其他服务商",
};

function getToken() {
  if (typeof window === "undefined") return "";
  return localStorage.getItem("artiqore_access_token") || localStorage.getItem("access_token") || "";
}

function compactId(id?: string | null) {
  if (!id) return "-";
  return `${id.slice(0, 8)}…${id.slice(-4)}`;
}

function dateText(value?: string | null) {
  if (!value) return "-";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "-";
  return date.toLocaleString("zh-CN", {
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function materialTitle(row: Verification) {
  const materials = row.materials ?? {};
  return (
    stringValue(materials.company_name) ||
    stringValue(materials.organization_name) ||
    stringValue(materials.display_name) ||
    stringValue(materials.legal_name) ||
    row.user?.nickname ||
    "未填写名称"
  );
}

function materialSummary(row: Verification) {
  const materials = row.materials ?? {};
  if (row.type === "business") {
    const role = stringValue(materials.requested_role || materials.user_role);
    const roleLabel = BUSINESS_ROLE_LABELS[role] ?? role;
    const contact = stringValue(materials.contact);
    const note = stringValue(materials.note);
    return [roleLabel, contact, note].filter(Boolean).join(" / ") || "未提交机构资料";
  }
  const contact = stringValue(materials.contact);
  const note = stringValue(materials.note);
  return [contact, note].filter(Boolean).join(" / ") || "未提交材料摘要";
}

async function apiFetch<T>(path: string, init?: RequestInit): Promise<T> {
  const token = getToken();
  const res = await fetch(path, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(init?.headers ?? {}),
    },
  });
  const body = (await res.json().catch(() => ({}))) as { error?: string };
  if (!res.ok || body.error) {
    throw new Error(body.error || `请求失败 ${res.status}`);
  }
  return body as T;
}

export default function AdminVerificationsPage() {
  const [rows, setRows] = useState<Verification[]>([]);
  const [count, setCount] = useState(0);
  const [type, setType] = useState<"all" | VerificationType>("all");
  const [status, setStatus] = useState<"all" | VerificationStatus>("pending");
  const [keyword, setKeyword] = useState("");
  const [reviewNote, setReviewNote] = useState("");
  const [loading, setLoading] = useState(true);
  const [actingId, setActingId] = useState("");
  const [error, setError] = useState("");

  const filteredRows = useMemo(() => {
    const word = keyword.trim().toLowerCase();
    if (!word) return rows;
    return rows.filter((row) => {
      return (
        row.id.toLowerCase().includes(word) ||
        row.user_id.toLowerCase().includes(word) ||
        materialTitle(row).toLowerCase().includes(word) ||
        materialSummary(row).toLowerCase().includes(word) ||
        (row.user?.nickname ?? "").toLowerCase().includes(word)
      );
    });
  }, [keyword, rows]);

  const metrics = useMemo(() => {
    return rows.reduce(
      (acc, row) => {
        acc.total += 1;
        acc[row.status] = (acc[row.status] ?? 0) + 1;
        return acc;
      },
      { total: 0, pending: 0, approved: 0, rejected: 0 } as Record<
        VerificationStatus | "total",
        number
      >
    );
  }, [rows]);

  async function load() {
    setLoading(true);
    setError("");
    try {
      const params = new URLSearchParams({ limit: "80", offset: "0" });
      if (type !== "all") params.set("type", type);
      if (status !== "all") params.set("status", status);
      const body = await apiFetch<ApiListResponse>(`/api/v1/admin/verifications?${params.toString()}`);
      setRows(body.data ?? []);
      setCount(body.count ?? body.data?.length ?? 0);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }

  async function review(row: Verification, nextStatus: "approved" | "rejected") {
    setActingId(`${row.id}:${nextStatus}`);
    setError("");
    try {
      await apiFetch(`/api/v1/admin/verifications/${row.id}/review`, {
        method: "POST",
        body: JSON.stringify({
          status: nextStatus,
          review_note: reviewNote.trim() || undefined,
        }),
      });
      await load();
      setReviewNote("");
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setActingId("");
    }
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [type, status]);

  return (
    <div className="min-h-screen bg-[#f7f5ef] px-4 py-5 text-[#1a1a1a] md:px-8">
      <div className="mx-auto flex max-w-7xl flex-col gap-5">
        <header className="flex flex-col gap-4 border-b border-black/10 pb-5 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <Link
              href="/admin"
              className="mb-3 inline-flex items-center gap-2 text-sm font-bold text-black/48 hover:text-[#003399]"
            >
              <ArrowLeft size={16} />
              运营后台
            </Link>
            <div className="flex items-center gap-3">
              <span className="inline-flex h-10 w-10 items-center justify-center rounded-lg bg-[#003399]/8 text-[#003399]">
                <IdCard size={20} />
              </span>
              <div>
                <h1 className="text-2xl font-black tracking-normal">身份认证审核</h1>
                <p className="mt-1 text-sm font-medium text-black/52">
                  审核学生、艺术家、收藏者和机构入驻申请。机构入驻通过后会自动生成机构档案。
                </p>
              </div>
            </div>
          </div>
          <button
            onClick={load}
            className="inline-flex h-10 items-center justify-center gap-2 rounded-lg bg-[#003399] px-4 text-sm font-bold text-white shadow-sm disabled:opacity-60"
            disabled={loading}
          >
            {loading ? <Loader2 size={16} className="animate-spin" /> : <RefreshCw size={16} />}
            刷新
          </button>
        </header>

        {error ? (
          <div className="flex items-center gap-2 rounded-lg border border-rose-200 bg-rose-50 px-4 py-3 text-sm font-bold text-rose-700">
            <ShieldAlert size={16} />
            {error}
          </div>
        ) : null}

        <section className="grid gap-3 md:grid-cols-4">
          <Metric label="当前列表" value={`${metrics.total}`} />
          <Metric label="待审核" value={`${metrics.pending}`} />
          <Metric label="已通过" value={`${metrics.approved}`} />
          <Metric label="未通过" value={`${metrics.rejected}`} />
        </section>

        <section className="rounded-lg border border-black/10 bg-white p-4 shadow-sm">
          <div className="flex flex-col gap-3 xl:flex-row xl:items-center xl:justify-between">
            <div className="flex flex-wrap gap-2">
              {TYPE_OPTIONS.map((option) => (
                <button
                  key={option.value}
                  onClick={() => setType(option.value)}
                  className={`h-9 rounded-lg px-3 text-sm font-bold ring-1 transition ${
                    type === option.value
                      ? "bg-[#003399] text-white ring-[#003399]"
                      : "bg-white text-black/58 ring-black/10 hover:text-[#003399]"
                  }`}
                >
                  {option.label}
                </button>
              ))}
            </div>
            <div className="flex flex-wrap gap-2">
              {STATUS_OPTIONS.map((option) => (
                <button
                  key={option.value}
                  onClick={() => setStatus(option.value)}
                  className={`h-9 rounded-lg px-3 text-sm font-bold ring-1 transition ${
                    status === option.value
                      ? "bg-[#003399] text-white ring-[#003399]"
                      : "bg-white text-black/58 ring-black/10 hover:text-[#003399]"
                  }`}
                >
                  {option.label}
                </button>
              ))}
            </div>
          </div>

          <div className="mt-3 grid gap-2 lg:grid-cols-[320px_1fr]">
            <label className="relative">
              <Search
                size={15}
                className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-black/34"
              />
              <input
                value={keyword}
                onChange={(event) => setKeyword(event.target.value)}
                placeholder="在当前列表内搜索名称、材料或 ID"
                className="h-10 w-full rounded-lg border border-black/10 bg-[#f7f5ef] pl-9 pr-3 text-sm font-semibold outline-none focus:border-[#003399]/40"
              />
            </label>
            <textarea
              value={reviewNote}
              onChange={(event) => setReviewNote(event.target.value)}
              placeholder="审核备注，可选。通过或拒绝后会随站内通知发送给申请人。"
              className="min-h-10 w-full resize-y rounded-lg border border-black/10 bg-[#f7f5ef] px-3 py-2 text-sm font-medium outline-none focus:border-[#003399]/40"
            />
          </div>
        </section>

        <section className="overflow-hidden rounded-lg border border-black/10 bg-white shadow-sm">
          <div className="flex items-center justify-between border-b border-black/8 px-4 py-3">
            <p className="text-sm font-black">认证申请</p>
            <p className="text-xs font-bold text-black/42">
              API 共 {count} 条，当前显示 {filteredRows.length} 条
            </p>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full min-w-[1080px] border-collapse text-left text-sm">
              <thead className="bg-[#f7f5ef] text-xs font-black text-black/48">
                <tr>
                  <th className="px-4 py-3">申请人</th>
                  <th className="px-4 py-3">认证类型</th>
                  <th className="px-4 py-3">材料摘要</th>
                  <th className="px-4 py-3">状态</th>
                  <th className="px-4 py-3">提交时间</th>
                  <th className="px-4 py-3 text-right">操作</th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr>
                    <td colSpan={6} className="px-4 py-12 text-center text-sm font-bold text-black/46">
                      <Loader2 size={18} className="mx-auto mb-2 animate-spin text-[#003399]" />
                      正在加载认证申请
                    </td>
                  </tr>
                ) : filteredRows.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="px-4 py-12 text-center text-sm font-bold text-black/46">
                      当前筛选下暂无认证申请
                    </td>
                  </tr>
                ) : (
                  filteredRows.map((row) => (
                    <tr key={row.id} className="border-t border-black/6 align-middle">
                      <td className="px-4 py-3">
                        <div className="font-black text-black/82">{materialTitle(row)}</div>
                        <div className="mt-1 font-mono text-[11px] font-semibold text-black/36">
                          user {compactId(row.user_id)} / request {compactId(row.id)}
                        </div>
                        <div className="mt-1 text-xs font-semibold text-black/42">
                          当前：{row.user?.user_type || "-"} / {row.user?.user_role || "-"}
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        <span className="inline-flex rounded-full bg-[#003399]/8 px-2.5 py-1 text-xs font-black text-[#003399] ring-1 ring-[#003399]/12">
                          {TYPE_LABELS[row.type]}
                        </span>
                      </td>
                      <td className="px-4 py-3">
                        <div className="max-w-[360px] truncate text-xs font-semibold text-black/52">
                          {materialSummary(row)}
                        </div>
                        {row.review_note ? (
                          <div className="mt-1 max-w-[360px] truncate text-xs font-semibold text-rose-600/80">
                            备注：{row.review_note}
                          </div>
                        ) : null}
                      </td>
                      <td className="px-4 py-3">
                        <StatusBadge status={row.status} />
                      </td>
                      <td className="px-4 py-3 font-semibold text-black/54">
                        {dateText(row.created_at)}
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex justify-end gap-2">
                          <ActionButton
                            label="通过"
                            icon={<CheckCircle2 size={14} />}
                            disabled={row.status === "approved"}
                            loading={actingId === `${row.id}:approved`}
                            onClick={() => review(row, "approved")}
                          />
                          <ActionButton
                            label="拒绝"
                            icon={<XCircle size={14} />}
                            danger
                            disabled={row.status === "rejected"}
                            loading={actingId === `${row.id}:rejected`}
                            onClick={() => review(row, "rejected")}
                          />
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </div>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-black/10 bg-white p-4 shadow-sm">
      <p className="text-xs font-black text-black/38">{label}</p>
      <p className="mt-2 text-xl font-black text-[#1a1a1a]">{value}</p>
    </div>
  );
}

function StatusBadge({ status }: { status: VerificationStatus }) {
  const meta = STATUS_META[status] ?? STATUS_META.pending;
  return (
    <span className={`inline-flex rounded-full px-2.5 py-1 text-xs font-black ring-1 ${meta.className}`}>
      {meta.label}
    </span>
  );
}

function ActionButton({
  label,
  icon,
  disabled,
  loading,
  danger,
  onClick,
}: {
  label: string;
  icon: React.ReactNode;
  disabled?: boolean;
  loading?: boolean;
  danger?: boolean;
  onClick: () => void;
}) {
  return (
    <button
      onClick={onClick}
      disabled={disabled || loading}
      className={`inline-flex h-9 items-center justify-center gap-1.5 rounded-lg border px-3 text-xs font-black transition disabled:cursor-not-allowed disabled:opacity-40 ${
        danger
          ? "border-rose-200 bg-rose-50 text-rose-700 hover:border-rose-300"
          : "border-black/10 bg-white text-black/68 hover:border-[#003399]/30 hover:text-[#003399]"
      }`}
    >
      {loading ? <Loader2 size={14} className="animate-spin" /> : icon}
      {label}
    </button>
  );
}
