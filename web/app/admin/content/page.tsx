"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import {
  ArrowLeft,
  CheckCircle2,
  ExternalLink,
  FileCheck2,
  Loader2,
  Paperclip,
  RefreshCw,
  Search,
  ShieldAlert,
  XCircle,
} from "lucide-react";

type ContentType = "events" | "opportunities" | "artworks" | "artists" | "marketplace";
type ReviewStatus = "draft" | "reviewing" | "published" | "rejected" | "archived" | "closed" | "hidden";

type ReviewItem = {
  type: ContentType;
  id: string;
  title: string;
  status: ReviewStatus;
  owner_user_id?: string | null;
  summary?: string | null;
  supplemental_materials?: string[];
  created_at?: string | null;
  updated_at?: string | null;
};

type ApiListResponse = {
  success: boolean;
  data: ReviewItem[];
  count?: number;
  error?: string;
};

type SignMaterialResponse = {
  success: boolean;
  signed_url?: string | null;
  error?: string;
};

const TYPE_OPTIONS: Array<{ value: "all" | ContentType; label: string }> = [
  { value: "all", label: "全部类型" },
  { value: "events", label: "活动" },
  { value: "opportunities", label: "机会" },
  { value: "artworks", label: "作品" },
  { value: "artists", label: "艺术家" },
  { value: "marketplace", label: "市集商品" },
];

const STATUS_OPTIONS: Array<{ value: "all" | ReviewStatus; label: string }> = [
  { value: "reviewing", label: "待审核" },
  { value: "published", label: "已发布" },
  { value: "rejected", label: "未通过" },
  { value: "archived", label: "已归档" },
  { value: "all", label: "全部状态" },
];

const TYPE_LABELS: Record<ContentType, string> = {
  events: "活动",
  opportunities: "机会",
  artworks: "作品",
  artists: "艺术家",
  marketplace: "市集商品",
};

const STATUS_META: Record<ReviewStatus, { label: string; className: string }> = {
  draft: {
    label: "草稿",
    className: "bg-zinc-100 text-zinc-600 ring-zinc-200",
  },
  reviewing: {
    label: "待审核",
    className: "bg-amber-50 text-amber-700 ring-amber-200",
  },
  published: {
    label: "已发布",
    className: "bg-emerald-50 text-emerald-700 ring-emerald-200",
  },
  rejected: {
    label: "未通过",
    className: "bg-rose-50 text-rose-700 ring-rose-200",
  },
  archived: {
    label: "已归档",
    className: "bg-zinc-100 text-zinc-600 ring-zinc-200",
  },
  closed: {
    label: "已关闭",
    className: "bg-blue-50 text-blue-700 ring-blue-200",
  },
  hidden: {
    label: "已隐藏",
    className: "bg-zinc-100 text-zinc-600 ring-zinc-200",
  },
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

export default function AdminContentPage() {
  const [rows, setRows] = useState<ReviewItem[]>([]);
  const [count, setCount] = useState(0);
  const [type, setType] = useState<"all" | ContentType>("all");
  const [status, setStatus] = useState<"all" | ReviewStatus>("reviewing");
  const [reviewNote, setReviewNote] = useState("");
  const [keyword, setKeyword] = useState("");
  const [loading, setLoading] = useState(true);
  const [actingId, setActingId] = useState("");
  const [openingMaterial, setOpeningMaterial] = useState("");
  const [error, setError] = useState("");

  const filteredRows = useMemo(() => {
    const word = keyword.trim().toLowerCase();
    if (!word) return rows;
    return rows.filter((row) => {
      return (
        row.title.toLowerCase().includes(word) ||
        row.id.toLowerCase().includes(word) ||
        (row.summary ?? "").toLowerCase().includes(word)
      );
    });
  }, [keyword, rows]);

  const metrics = useMemo(() => {
    return rows.reduce(
      (acc, row) => {
        acc.total += 1;
        acc[row.type] = (acc[row.type] ?? 0) + 1;
        return acc;
      },
      {
        total: 0,
        events: 0,
        opportunities: 0,
        artworks: 0,
        artists: 0,
        marketplace: 0,
      } as Record<
        ContentType | "total",
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
      const body = await apiFetch<ApiListResponse>(`/api/v1/admin/content?${params.toString()}`);
      setRows(body.data ?? []);
      setCount(body.count ?? body.data?.length ?? 0);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }

  async function review(row: ReviewItem, nextStatus: "approved" | "rejected") {
    setActingId(`${row.type}:${row.id}:${nextStatus}`);
    setError("");
    try {
      await apiFetch(`/api/v1/admin/content/${row.type}/${row.id}/review`, {
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

  async function openMaterial(material: string, index: number) {
    setOpeningMaterial(`${material}:${index}`);
    setError("");
    try {
      const body = await apiFetch<SignMaterialResponse>("/api/v1/uploads/materials/sign", {
        method: "POST",
        body: JSON.stringify({ url: material }),
      });
      if (!body.signed_url) throw new Error("材料签名链接生成失败");
      window.open(body.signed_url, "_blank", "noopener,noreferrer");
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setOpeningMaterial("");
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
                <FileCheck2 size={20} />
              </span>
              <div>
                <h1 className="text-2xl font-black tracking-normal">内容审核</h1>
                <p className="mt-1 text-sm font-medium text-black/52">
                  集中处理活动、合作机会、艺术家档案、作品展示和市集商品。审核通过后内容进入公开区。
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

        <section className="grid gap-3 md:grid-cols-6">
          <Metric label="当前列表" value={`${metrics.total}`} />
          <Metric label="活动" value={`${metrics.events}`} />
          <Metric label="机会" value={`${metrics.opportunities}`} />
          <Metric label="作品" value={`${metrics.artworks}`} />
          <Metric label="艺术家" value={`${metrics.artists}`} />
          <Metric label="市集商品" value={`${metrics.marketplace}`} />
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
                placeholder="在当前列表内搜索标题、摘要或 ID"
                className="h-10 w-full rounded-lg border border-black/10 bg-[#f7f5ef] pl-9 pr-3 text-sm font-semibold outline-none focus:border-[#003399]/40"
              />
            </label>
            <textarea
              value={reviewNote}
              onChange={(event) => setReviewNote(event.target.value)}
              placeholder="审核备注，可选。通过或拒绝后会随站内通知发送给提交者。"
              className="min-h-10 w-full resize-y rounded-lg border border-black/10 bg-[#f7f5ef] px-3 py-2 text-sm font-medium outline-none focus:border-[#003399]/40"
            />
          </div>
        </section>

        <section className="overflow-hidden rounded-lg border border-black/10 bg-white shadow-sm">
          <div className="flex items-center justify-between border-b border-black/8 px-4 py-3">
            <p className="text-sm font-black">审核内容</p>
            <p className="text-xs font-bold text-black/42">
              API 共 {count} 条，当前显示 {filteredRows.length} 条
            </p>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full min-w-[1040px] border-collapse text-left text-sm">
              <thead className="bg-[#f7f5ef] text-xs font-black text-black/48">
                <tr>
                  <th className="px-4 py-3">内容</th>
                  <th className="px-4 py-3">类型</th>
                  <th className="px-4 py-3">提交者</th>
                  <th className="px-4 py-3">状态</th>
                  <th className="px-4 py-3">更新时间</th>
                  <th className="px-4 py-3 text-right">操作</th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr>
                    <td colSpan={6} className="px-4 py-12 text-center text-sm font-bold text-black/46">
                      <Loader2 size={18} className="mx-auto mb-2 animate-spin text-[#003399]" />
                      正在加载审核内容
                    </td>
                  </tr>
                ) : filteredRows.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="px-4 py-12 text-center text-sm font-bold text-black/46">
                      当前筛选下暂无内容
                    </td>
                  </tr>
                ) : (
                  filteredRows.map((row) => (
                    <tr key={`${row.type}:${row.id}`} className="border-t border-black/6 align-middle">
                      <td className="px-4 py-3">
                        <div className="max-w-[360px] truncate font-black text-black/82">{row.title}</div>
                        <div className="mt-1 max-w-[420px] truncate text-xs font-semibold text-black/42">
                          {row.summary || compactId(row.id)}
                        </div>
                        {row.supplemental_materials?.length ? (
                          <div className="mt-2 flex max-w-[420px] flex-wrap gap-1.5">
                            {row.supplemental_materials.map((material, index) => (
                              <button
                                key={`${material}:${index}`}
                                onClick={() => openMaterial(material, index)}
                                disabled={openingMaterial === `${material}:${index}`}
                                className="inline-flex h-7 items-center gap-1.5 rounded-lg border border-[#003399]/15 bg-[#003399]/5 px-2 text-xs font-black text-[#003399] hover:border-[#003399]/30 disabled:cursor-wait disabled:opacity-60"
                                title={material}
                              >
                                {openingMaterial === `${material}:${index}` ? (
                                  <Loader2 size={13} className="animate-spin" />
                                ) : (
                                  <Paperclip size={13} />
                                )}
                                材料 {index + 1}
                                <ExternalLink size={12} />
                              </button>
                            ))}
                          </div>
                        ) : null}
                      </td>
                      <td className="px-4 py-3">
                        <span className="inline-flex rounded-full bg-[#003399]/8 px-2.5 py-1 text-xs font-black text-[#003399] ring-1 ring-[#003399]/12">
                          {TYPE_LABELS[row.type]}
                        </span>
                      </td>
                      <td className="px-4 py-3 font-mono text-xs font-bold text-black/54">
                        {compactId(row.owner_user_id)}
                      </td>
                      <td className="px-4 py-3">
                        <StatusBadge status={row.status} />
                      </td>
                      <td className="px-4 py-3 font-semibold text-black/54">
                        {dateText(row.updated_at ?? row.created_at)}
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex justify-end gap-2">
                          <ActionButton
                            label="通过"
                            icon={<CheckCircle2 size={14} />}
                            disabled={row.status === "published"}
                            loading={actingId === `${row.type}:${row.id}:approved`}
                            onClick={() => review(row, "approved")}
                          />
                          <ActionButton
                            label="拒绝"
                            icon={<XCircle size={14} />}
                            danger
                            disabled={row.status === "rejected" || row.status === "archived"}
                            loading={actingId === `${row.type}:${row.id}:rejected`}
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

function StatusBadge({ status }: { status: ReviewStatus }) {
  const meta = STATUS_META[status] ?? STATUS_META.reviewing;
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
