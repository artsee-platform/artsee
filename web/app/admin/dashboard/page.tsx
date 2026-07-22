"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import {
  ArrowLeft,
  BarChart3,
  Building2,
  Crown,
  FileCheck2,
  FileText,
  GraduationCap,
  IdCard,
  Loader2,
  RefreshCw,
  ShieldAlert,
  UsersRound,
  WalletCards,
} from "lucide-react";

type CountMap = Record<string, number>;

type ContentTypeMetric = {
  type: string;
  total: number;
  reviewing: number;
  published: number;
  by_status: CountMap;
};

type MetricsResponse = {
  success: boolean;
  generated_at: string;
  summary: {
    users_total: number;
    users_active: number;
    users_restricted: number;
    members_active: number;
    members_expired: number;
    creators_total: number;
    organizations_total: number;
    organizations_subscribed: number;
    content_reviewing: number;
    verifications_pending: number;
    consultations_open: number;
    consultations_converted: number;
    contracts_total: number;
    contracts_pending: number;
    contracts_confirmed: number;
    mentors_pending: number;
    mentor_bookings_requested: number;
    paid_order_amount: number;
    paid_membership_amount: number;
    paid_org_subscription_amount: number;
    available_earning_amount: number;
    requested_withdrawal_amount: number;
    requested_refund_amount: number;
    processing_payout_amount: number;
  };
  sections: {
    users: {
      total: number;
      by_status: CountMap;
      by_role: CountMap;
      by_user_type: CountMap;
      by_user_role: CountMap;
      by_creator_level: CountMap;
      by_membership_status: CountMap;
      by_stored_membership_status: CountMap;
    };
    organizations: {
      total: number;
      by_status: CountMap;
      by_type: CountMap;
      by_subscription_status: CountMap;
      by_stored_subscription_status: CountMap;
    };
    content: {
      total: number;
      reviewing: number;
      by_type: ContentTypeMetric[];
    };
    verifications: {
      total: number;
      by_status: CountMap;
      by_type: CountMap;
    };
    consultations: {
      total: number;
      by_status: CountMap;
    };
    contracts: {
      total: number;
      by_status: CountMap;
    };
    mentors: {
      total: number;
      by_status: CountMap;
      by_verification_status: CountMap;
    };
    commerce: {
      mentor_bookings: {
        total: number;
        by_status: CountMap;
        by_payment_status: CountMap;
      };
      orders: {
        total: number;
        by_status: CountMap;
        by_product_type: CountMap;
        amount_by_status: CountMap;
        amount_by_product_type: CountMap;
      };
      earnings: {
        total: number;
        by_status: CountMap;
        net_amount_by_status: CountMap;
        platform_fee_amount: number;
      };
      withdrawals: {
        total: number;
        by_status: CountMap;
        amount_by_status: CountMap;
      };
      refunds: {
        total: number;
        by_status: CountMap;
        amount_by_status: CountMap;
      };
      payout_batches: {
        total: number;
        by_status: CountMap;
        amount_by_status: CountMap;
      };
    };
  };
  error?: string;
};

type ExpireSubscriptionsResponse = {
  success: boolean;
  ran_at: string;
  data: {
    expired_memberships: number;
    expired_organizations: number;
  };
  error?: string;
};

const CONTENT_LABELS: Record<string, string> = {
  events: "活动",
  opportunities: "机会",
  artworks: "作品",
  artists: "艺术家",
};

function getToken() {
  if (typeof window === "undefined") return "";
  return (
    localStorage.getItem("artiqore_access_token") ||
    localStorage.getItem("access_token") ||
    ""
  );
}

function money(amount: number) {
  return `¥${(amount / 100).toLocaleString("zh-CN", {
    minimumFractionDigits: amount % 100 === 0 ? 0 : 2,
    maximumFractionDigits: 2,
  })}`;
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

export default function AdminDashboardPage() {
  const [metrics, setMetrics] = useState<MetricsResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [syncingExpiration, setSyncingExpiration] = useState(false);
  const [expirationResult, setExpirationResult] = useState("");
  const [error, setError] = useState("");

  const summaryCards = useMemo(() => {
    if (!metrics) return [];
    return [
      {
        label: "总用户",
        value: `${metrics.summary.users_total}`,
        hint: `创作者 ${metrics.summary.creators_total} / 受限 ${metrics.summary.users_restricted}`,
        icon: UsersRound,
      },
      {
        label: "有效会员",
        value: `${metrics.summary.members_active}`,
        hint: `过期 ${metrics.summary.members_expired} / 会员收入 ${money(metrics.summary.paid_membership_amount)}`,
        icon: Crown,
      },
      {
        label: "入驻机构",
        value: `${metrics.summary.organizations_subscribed}/${metrics.summary.organizations_total}`,
        hint: `机构订阅 ${money(metrics.summary.paid_org_subscription_amount)}`,
        icon: Building2,
      },
      {
        label: "待审内容",
        value: `${metrics.summary.content_reviewing}`,
        hint: "活动 / 机会 / 作品 / 艺术家",
        icon: FileCheck2,
      },
      {
        label: "待审身份",
        value: `${metrics.summary.verifications_pending}`,
        hint: "机构入驻 / 学生 / 艺术家",
        icon: IdCard,
      },
      {
        label: "开放咨询",
        value: `${metrics.summary.consultations_open}`,
        hint: `已转化 ${metrics.summary.consultations_converted}`,
        icon: BarChart3,
      },
      {
        label: "合同存档",
        value: `${metrics.summary.contracts_pending}`,
        hint: `共 ${metrics.summary.contracts_total} / 已确认 ${metrics.summary.contracts_confirmed}`,
        icon: FileText,
      },
      {
        label: "待审导师",
        value: `${metrics.summary.mentors_pending}`,
        hint: `待处理预约 ${metrics.summary.mentor_bookings_requested}`,
        icon: GraduationCap,
      },
      {
        label: "已支付订单",
        value: money(metrics.summary.paid_order_amount),
        hint: `可提现 ${money(metrics.summary.available_earning_amount)}`,
        icon: WalletCards,
      },
      {
        label: "提现处理中",
        value: money(metrics.summary.requested_withdrawal_amount),
        hint: "requested + approved",
        icon: WalletCards,
      },
    ];
  }, [metrics]);

  async function load() {
    setLoading(true);
    setError("");
    try {
      const body = await apiFetch<MetricsResponse>("/api/v1/admin/metrics");
      setMetrics(body);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }

  async function syncExpiration() {
    setSyncingExpiration(true);
    setError("");
    setExpirationResult("");
    try {
      const body = await apiFetch<ExpireSubscriptionsResponse>(
        "/api/v1/admin/maintenance/expire-subscriptions",
        { method: "POST" }
      );
      setExpirationResult(
        `已同步：会员 ${body.data.expired_memberships} / 机构 ${body.data.expired_organizations}`
      );
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setSyncingExpiration(false);
    }
  }

  useEffect(() => {
    load();
  }, []);

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
                <BarChart3 size={20} />
              </span>
              <div>
                <h1 className="text-2xl font-black tracking-normal">数据看板</h1>
                <p className="mt-1 text-sm font-medium text-black/52">
                  聚合用户、内容、咨询、导师服务和交易数据。当前版本读取最近最多 2000 行快照。
                </p>
              </div>
            </div>
          </div>
          <div className="flex flex-col gap-2 sm:flex-row sm:items-center">
            <span className="text-xs font-bold text-black/40">
              更新时间 {dateText(metrics?.generated_at)}
            </span>
            <button
              onClick={syncExpiration}
              className="inline-flex h-10 items-center justify-center gap-2 rounded-lg border border-black/10 bg-white px-4 text-sm font-bold text-black/70 shadow-sm disabled:opacity-60"
              disabled={loading || syncingExpiration}
            >
              {syncingExpiration ? (
                <Loader2 size={16} className="animate-spin" />
              ) : (
                <RefreshCw size={16} />
              )}
              同步过期状态
            </button>
            <button
              onClick={load}
              className="inline-flex h-10 items-center justify-center gap-2 rounded-lg bg-[#003399] px-4 text-sm font-bold text-white shadow-sm disabled:opacity-60"
              disabled={loading}
            >
              {loading ? <Loader2 size={16} className="animate-spin" /> : <RefreshCw size={16} />}
              刷新
            </button>
          </div>
        </header>

        {error ? (
          <div className="flex items-center gap-2 rounded-lg border border-rose-200 bg-rose-50 px-4 py-3 text-sm font-bold text-rose-700">
            <ShieldAlert size={16} />
            {error}
          </div>
        ) : null}

        {expirationResult ? (
          <div className="rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm font-bold text-emerald-700">
            {expirationResult}
          </div>
        ) : null}

        {loading && !metrics ? (
          <div className="rounded-lg border border-black/10 bg-white px-4 py-16 text-center text-sm font-bold text-black/46">
            <Loader2 size={18} className="mx-auto mb-2 animate-spin text-[#003399]" />
            正在加载运营指标
          </div>
        ) : metrics ? (
          <>
            <section className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
              {summaryCards.map((card) => {
                const Icon = card.icon;
                return (
                  <div
                    key={card.label}
                    className="rounded-lg border border-black/10 bg-white p-4 shadow-sm"
                  >
                    <div className="mb-3 flex items-center justify-between gap-3">
                      <span className="inline-flex h-9 w-9 items-center justify-center rounded-lg bg-[#003399]/8 text-[#003399]">
                        <Icon size={18} />
                      </span>
                      <span className="text-xs font-black text-black/34">{card.label}</span>
                    </div>
                    <p className="text-2xl font-black">{card.value}</p>
                    <p className="mt-1 text-xs font-bold text-black/42">{card.hint}</p>
                  </div>
                );
              })}
            </section>

            <section className="grid gap-4 xl:grid-cols-2">
              <Panel title="用户结构">
                <MetricRows
                  data={metrics.sections.users.by_status}
                  total={metrics.sections.users.total}
                />
                <div className="mt-4 border-t border-black/8 pt-4">
                  <p className="mb-2 text-xs font-black text-black/38">会员状态</p>
                  <MetricRows
                    data={metrics.sections.users.by_membership_status}
                    total={metrics.sections.users.total}
                  />
                </div>
                <div className="mt-4 border-t border-black/8 pt-4">
                  <p className="mb-2 text-xs font-black text-black/38">系统角色</p>
                  <MetricRows
                    data={metrics.sections.users.by_role}
                    total={metrics.sections.users.total}
                  />
                </div>
                <div className="mt-4 border-t border-black/8 pt-4">
                  <p className="mb-2 text-xs font-black text-black/38">创作者等级</p>
                  <MetricRows
                    data={metrics.sections.users.by_creator_level}
                    total={metrics.sections.users.total}
                  />
                </div>
              </Panel>

              <Panel title="机构与会员制">
                <div className="grid gap-4 lg:grid-cols-2">
                  <div>
                    <p className="mb-2 text-xs font-black text-black/38">机构订阅状态</p>
                    <MetricRows
                      data={metrics.sections.organizations.by_subscription_status}
                      total={metrics.sections.organizations.total}
                    />
                  </div>
                  <div>
                    <p className="mb-2 text-xs font-black text-black/38">机构类型</p>
                    <MetricRows
                      data={metrics.sections.organizations.by_type}
                      total={metrics.sections.organizations.total}
                    />
                  </div>
                  <div>
                    <p className="mb-2 text-xs font-black text-black/38">会员与机构收入</p>
                    <MoneyRows
                      data={{
                        membership: metrics.summary.paid_membership_amount,
                        org_subscription: metrics.summary.paid_org_subscription_amount,
                      }}
                    />
                  </div>
                  <div>
                    <p className="mb-2 text-xs font-black text-black/38">合同存档状态</p>
                    <MetricRows
                      data={metrics.sections.contracts.by_status}
                      total={metrics.sections.contracts.total}
                    />
                  </div>
                </div>
              </Panel>

              <Panel title="内容审核">
                <div className="grid gap-2 sm:grid-cols-2">
                  {metrics.sections.content.by_type.map((item) => (
                    <div key={item.type} className="rounded-lg border border-black/8 bg-[#f7f5ef] p-3">
                      <div className="mb-2 flex items-center justify-between">
                        <p className="text-sm font-black">{CONTENT_LABELS[item.type] ?? item.type}</p>
                        <p className="text-xs font-bold text-black/40">共 {item.total}</p>
                      </div>
                      <MetricRows data={item.by_status} total={Math.max(item.total, 1)} compact />
                    </div>
                  ))}
                </div>
              </Panel>

              <Panel title="咨询与导师">
                <div className="grid gap-4 lg:grid-cols-2">
                  <div>
                    <p className="mb-2 text-xs font-black text-black/38">身份认证</p>
                    <MetricRows
                      data={metrics.sections.verifications.by_status}
                      total={metrics.sections.verifications.total}
                    />
                    <div className="mt-4 border-t border-black/8 pt-4">
                      <p className="mb-2 text-xs font-black text-black/38">认证类型</p>
                      <MetricRows
                        data={metrics.sections.verifications.by_type}
                        total={metrics.sections.verifications.total}
                      />
                    </div>
                  </div>
                  <div>
                    <p className="mb-2 text-xs font-black text-black/38">咨询状态</p>
                    <MetricRows
                      data={metrics.sections.consultations.by_status}
                      total={metrics.sections.consultations.total}
                    />
                  </div>
                  <div>
                    <p className="mb-2 text-xs font-black text-black/38">导师认证</p>
                    <MetricRows
                      data={metrics.sections.mentors.by_verification_status}
                      total={metrics.sections.mentors.total}
                    />
                  </div>
                </div>
              </Panel>

              <Panel title="订单与收益">
                <div className="grid gap-4 lg:grid-cols-2">
                  <div>
                    <p className="mb-2 text-xs font-black text-black/38">订单金额</p>
                    <MoneyRows data={metrics.sections.commerce.orders.amount_by_status} />
                  </div>
                  <div>
                    <p className="mb-2 text-xs font-black text-black/38">商品收入</p>
                    <MoneyRows data={metrics.sections.commerce.orders.amount_by_product_type} />
                  </div>
                  <div>
                    <p className="mb-2 text-xs font-black text-black/38">提现金额</p>
                    <MoneyRows data={metrics.sections.commerce.withdrawals.amount_by_status} />
                  </div>
                  <div>
                    <p className="mb-2 text-xs font-black text-black/38">导师收益</p>
                    <MoneyRows data={metrics.sections.commerce.earnings.net_amount_by_status} />
                  </div>
                  <div>
                    <p className="mb-2 text-xs font-black text-black/38">预约付款</p>
                    <MetricRows
                      data={metrics.sections.commerce.mentor_bookings.by_payment_status}
                      total={metrics.sections.commerce.mentor_bookings.total}
                    />
                  </div>
                </div>
              </Panel>
            </section>
          </>
        ) : null}
      </div>
    </div>
  );
}

function Panel({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="rounded-lg border border-black/10 bg-white p-4 shadow-sm">
      <h2 className="mb-4 text-base font-black">{title}</h2>
      {children}
    </section>
  );
}

function MetricRows({ data, total, compact }: { data: CountMap; total: number; compact?: boolean }) {
  const rows = Object.entries(data).sort((a, b) => b[1] - a[1]);
  if (rows.length === 0) {
    return <p className="text-sm font-bold text-black/42">暂无数据</p>;
  }
  return (
    <div className={compact ? "space-y-2" : "space-y-3"}>
      {rows.map(([key, value]) => {
        const percent = total > 0 ? Math.round((value / total) * 100) : 0;
        return (
          <div key={key}>
            <div className="mb-1 flex items-center justify-between gap-3 text-xs font-black">
              <span className="truncate text-black/58">{key}</span>
              <span className="text-black/40">{value}</span>
            </div>
            <div className="h-2 overflow-hidden rounded-full bg-black/6">
              <div className="h-full rounded-full bg-[#003399]" style={{ width: `${Math.max(percent, 4)}%` }} />
            </div>
          </div>
        );
      })}
    </div>
  );
}

function MoneyRows({ data }: { data: CountMap }) {
  const rows = Object.entries(data).sort((a, b) => b[1] - a[1]);
  if (rows.length === 0) {
    return <p className="text-sm font-bold text-black/42">暂无金额</p>;
  }
  return (
    <div className="space-y-2">
      {rows.map(([key, value]) => (
        <div key={key} className="flex items-center justify-between rounded-lg bg-[#f7f5ef] px-3 py-2">
          <span className="text-xs font-black text-black/52">{key}</span>
          <span className="text-sm font-black">{money(value)}</span>
        </div>
      ))}
    </div>
  );
}
