"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import {
  AlertTriangle,
  ArrowLeft,
  CheckCircle2,
  CircleX,
  ExternalLink,
  FileCode2,
  Loader2,
  PlugZap,
  RefreshCw,
  ShieldCheck,
} from "lucide-react";

import type {
  IntegrationReadinessItem,
  IntegrationReadinessReport,
  IntegrationReadinessStatus,
} from "@/lib/api/integration-readiness";

const STATUS_ORDER: Record<IntegrationReadinessStatus, number> = {
  blocked: 0,
  attention: 1,
  ready: 2,
};

const STATUS_META: Record<
  IntegrationReadinessStatus,
  { label: string; card: string; badge: string }
> = {
  ready: {
    label: "已就绪",
    card: "border-emerald-700/20",
    badge: "bg-emerald-700/10 text-emerald-800",
  },
  attention: {
    label: "待验收",
    card: "border-amber-600/25",
    badge: "bg-amber-500/12 text-amber-800",
  },
  blocked: {
    label: "有阻塞",
    card: "border-[#d90429]/25",
    badge: "bg-[#d90429]/8 text-[#b00020]",
  },
};

function readToken() {
  if (typeof window === "undefined") return "";
  return (
    localStorage.getItem("artiqore_access_token") ||
    localStorage.getItem("access_token") ||
    ""
  );
}

function sortIntegrations(items: IntegrationReadinessItem[]) {
  return [...items].sort(
    (left, right) => STATUS_ORDER[left.status] - STATUS_ORDER[right.status]
  );
}

export default function AdminIntegrationsPage() {
  const [report, setReport] = useState<IntegrationReadinessReport | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const loadReport = useCallback(async (signal?: AbortSignal) => {
    setLoading(true);
    setError("");
    try {
      const response = await fetch("/api/v1/admin/integrations/readiness", {
        cache: "no-store",
        headers: { Authorization: `Bearer ${readToken()}` },
        signal,
      });
      const body = (await response.json().catch(() => ({}))) as
        | IntegrationReadinessReport
        | { error?: string; message?: string };
      if (!response.ok || !("integrations" in body)) {
        throw new Error(
          "error" in body
            ? body.error || body.message || "自检请求失败"
            : "自检请求失败"
        );
      }
      setReport(body);
    } catch (cause) {
      if (cause instanceof DOMException && cause.name === "AbortError") return;
      setError(cause instanceof Error ? cause.message : "自检请求失败");
    } finally {
      if (!signal?.aborted) setLoading(false);
    }
  }, []);

  useEffect(() => {
    const controller = new AbortController();
    void loadReport(controller.signal);
    return () => controller.abort();
  }, [loadReport]);

  const integrations = report ? sortIntegrations(report.integrations) : [];

  return (
    <main className="min-h-screen bg-[#f7f5ef] px-5 py-6 text-[#1a1a1a] md:px-8">
      <div className="mx-auto flex max-w-6xl flex-col gap-6">
        <header className="flex flex-col gap-4 border-b border-black/10 pb-5 md:flex-row md:items-end md:justify-between">
          <div>
            <Link
              href="/admin"
              className="mb-4 inline-flex items-center gap-2 text-sm font-bold text-black/58 hover:text-[#003399]"
            >
              <ArrowLeft size={16} />
              返回运营后台
            </Link>
            <div className="mb-2 flex items-center gap-2 text-xs font-black uppercase tracking-[0.16em] text-[#003399]">
              <PlugZap size={15} />
              Integration readiness
            </div>
            <h1 className="text-2xl font-black tracking-normal md:text-3xl">
              第三方集成自检
            </h1>
            <p className="mt-2 max-w-3xl text-sm font-medium leading-6 text-black/56">
              汇总高德、Supabase 与腾讯云各链路的环境、迁移、控制台和验收状态。
            </p>
          </div>
          <button
            type="button"
            onClick={() => void loadReport()}
            disabled={loading}
            className="inline-flex h-10 items-center justify-center gap-2 rounded-lg bg-[#003399] px-4 text-sm font-bold text-white hover:bg-[#002a80] disabled:cursor-not-allowed disabled:opacity-60"
          >
            {loading ? (
              <Loader2 size={16} className="animate-spin" />
            ) : (
              <RefreshCw size={16} />
            )}
            {loading ? "检查中" : "重新检查"}
          </button>
        </header>

        <section className="flex items-start gap-3 rounded-lg border border-[#003399]/15 bg-[#003399]/5 p-4 text-sm font-medium leading-6 text-black/64">
          <ShieldCheck size={19} className="mt-0.5 shrink-0 text-[#003399]" />
          <p>
            这是只读、脱敏检查：不会返回任何凭证值，不会调用高德或腾讯云收费 API。控制台与真机结果仅通过人工确认开关记录。
          </p>
        </section>

        {error ? (
          <section
            role="alert"
            className="rounded-lg border border-[#d90429]/20 bg-[#d90429]/6 p-4"
          >
            <div className="flex items-center gap-2 font-black text-[#b00020]">
              <AlertTriangle size={18} />
              无法完成自检
            </div>
            <p className="mt-2 text-sm font-medium text-black/60">{error}</p>
          </section>
        ) : null}

        {report ? (
          <>
            <section className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              {[
                ["集成总数", report.summary.total, "text-[#1a1a1a]"],
                ["已就绪", report.summary.ready, "text-emerald-700"],
                ["待验收", report.summary.attention, "text-amber-700"],
                ["有阻塞", report.summary.blocked, "text-[#d90429]"],
              ].map(([label, count, color]) => (
                <div
                  key={String(label)}
                  className="rounded-lg border border-black/10 bg-white p-4 shadow-sm"
                >
                  <div className="text-xs font-bold text-black/48">{label}</div>
                  <div className={`mt-2 text-3xl font-black ${color}`}>{count}</div>
                </div>
              ))}
            </section>

            <div className="flex flex-wrap items-center justify-between gap-2 text-xs font-medium text-black/45">
              <span>运行环境：{report.environment}</span>
              <time dateTime={report.generated_at}>
                最近检查：{new Date(report.generated_at).toLocaleString("zh-CN")}
              </time>
            </div>

            <section className="grid gap-4 lg:grid-cols-2">
              {integrations.map((item) => {
                const status = STATUS_META[item.status];
                return (
                  <article
                    key={item.id}
                    className={`rounded-lg border bg-white p-5 shadow-sm ${status.card}`}
                  >
                    <div className="flex items-start justify-between gap-4">
                      <div>
                        <h2 className="text-lg font-black">{item.name}</h2>
                        <p className="mt-1 text-sm font-medium leading-6 text-black/52">
                          {item.description}
                        </p>
                      </div>
                      <span
                        className={`shrink-0 rounded-full px-2.5 py-1 text-xs font-black ${status.badge}`}
                      >
                        {status.label}
                      </span>
                    </div>

                    <div className="mt-5 divide-y divide-black/7 border-y border-black/7">
                      {item.requirements.map((requirement) => (
                        <div
                          key={`${item.id}-${requirement.key}`}
                          className="flex items-start gap-3 py-3"
                        >
                          {requirement.satisfied ? (
                            <CheckCircle2
                              size={18}
                              className="mt-0.5 shrink-0 text-emerald-700"
                              aria-label="已满足"
                            />
                          ) : (
                            <CircleX
                              size={18}
                              className="mt-0.5 shrink-0 text-[#d90429]"
                              aria-label="未满足"
                            />
                          )}
                          <div className="min-w-0 flex-1">
                            <div className="flex flex-wrap items-center gap-2">
                              <span className="text-sm font-bold">{requirement.label}</span>
                              <span className="rounded bg-black/5 px-1.5 py-0.5 text-[10px] font-black uppercase text-black/45">
                                {requirement.severity === "blocking" ? "阻塞" : "提醒"}
                              </span>
                            </div>
                            <code className="mt-1 block break-all text-xs font-semibold text-[#003399]/75">
                              {requirement.key}
                            </code>
                            {!requirement.satisfied ? (
                              <p className="mt-1.5 text-xs font-medium leading-5 text-black/48">
                                {requirement.remediation}
                              </p>
                            ) : null}
                          </div>
                        </div>
                      ))}
                    </div>

                    <div className="mt-4 flex flex-wrap gap-3 text-xs font-bold">
                      <a
                        href={item.documentationUrl}
                        target="_blank"
                        rel="noreferrer"
                        className="inline-flex items-center gap-1.5 text-[#003399] hover:underline"
                      >
                        官方文档
                        <ExternalLink size={13} />
                      </a>
                      <span className="inline-flex min-w-0 items-center gap-1.5 text-black/46">
                        <FileCode2 size={13} className="shrink-0" />
                        <code className="break-all">{item.guidePath}</code>
                      </span>
                    </div>
                  </article>
                );
              })}
            </section>
          </>
        ) : loading ? (
          <div
            aria-live="polite"
            className="flex min-h-52 items-center justify-center gap-3 rounded-lg border border-black/10 bg-white text-sm font-bold text-black/50"
          >
            <Loader2 size={20} className="animate-spin text-[#003399]" />
            正在执行只读探测…
          </div>
        ) : null}
      </div>
    </main>
  );
}
